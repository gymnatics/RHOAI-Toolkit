#!/bin/bash
################################################################################
# RHOAI installation and configuration functions
################################################################################

# Source required utilities
# Use a local variable to avoid overwriting caller's SCRIPT_DIR
_RHOAI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_RHOAI_LIB_DIR/lib/utils/colors.sh"
source "$_RHOAI_LIB_DIR/lib/utils/common.sh"
source "$_RHOAI_LIB_DIR/lib/utils/rhoai-version.sh" 2>/dev/null || true
source "$_RHOAI_LIB_DIR/lib/functions/storage-backend.sh" 2>/dev/null || true

# Functions split out of this file during the Oct 2026 modularization
# (Priority 3 of the consolidated toolkit plan) -- sourced here so every
# existing caller that does `source lib/functions/rhoai.sh` keeps getting
# all of these functions transparently, with zero call-site changes required.
source "$_RHOAI_LIB_DIR/lib/functions/feast.sh" 2>/dev/null || true
source "$_RHOAI_LIB_DIR/lib/functions/maas-verify.sh" 2>/dev/null || true
source "$_RHOAI_LIB_DIR/lib/functions/model-registry.sh" 2>/dev/null || true
source "$_RHOAI_LIB_DIR/lib/functions/pipeline-server.sh" 2>/dev/null || true

# Resolve RHOAI OLM channel for a given version by querying the cluster catalog.
# Priority: stable-<version> > fast-<major>.x > cluster default > hardcoded fallback
get_rhoai_channel() {
    local version="$1"

    local channels
    channels=$(oc get packagemanifest rhods-operator -n openshift-marketplace \
        -o jsonpath='{.status.channels[*].name}' 2>/dev/null)

    if [ -n "$channels" ]; then
        if echo "$channels" | tr ' ' '\n' | grep -qx "stable-${version}"; then
            echo "stable-${version}"
            return 0
        fi
        local major="${version%%.*}"
        if echo "$channels" | tr ' ' '\n' | grep -qx "fast-${major}.x"; then
            echo "fast-${major}.x"
            return 0
        fi
        local default_ch
        default_ch=$(oc get packagemanifest rhods-operator -n openshift-marketplace \
            -o jsonpath='{.status.defaultChannel}' 2>/dev/null)
        if [ -n "$default_ch" ]; then
            echo "$default_ch"
            return 0
        fi
    fi

    # Cluster unreachable — last-resort fallback
    echo "fast-3.x"
}

# Fetch available RHOAI channels from the cluster
# Returns newline-separated list of channels
get_available_rhoai_channels() {
    local channels=$(oc get packagemanifest rhods-operator -n openshift-marketplace \
        -o jsonpath='{.status.channels[*].name}' 2>/dev/null)
    
    if [ -z "$channels" ]; then
        print_error "Unable to fetch RHOAI channels. Are you connected to a cluster?"
        return 1
    fi
    
    echo "$channels" | tr ' ' '\n' | sort -V
}

# Get the default RHOAI channel from the cluster
get_default_rhoai_channel() {
    oc get packagemanifest rhods-operator -n openshift-marketplace \
        -o jsonpath='{.status.defaultChannel}' 2>/dev/null
}

# Interactive channel selection for RHOAI
# Usage: select_rhoai_channel
# Sets SELECTED_RHOAI_CHANNEL variable
select_rhoai_channel() {
    print_header "RHOAI Channel Selection"
    
    print_step "Fetching available channels from cluster..."
    
    local channels_raw=$(oc get packagemanifest rhods-operator -n openshift-marketplace \
        -o jsonpath='{.status.channels[*].name}' 2>/dev/null)
    
    if [ -z "$channels_raw" ]; then
        print_error "Unable to fetch RHOAI channels from cluster"
        print_info "Make sure you're connected to an OpenShift cluster with access to redhat-operators"
        return 1
    fi
    
    local default_channel=$(get_default_rhoai_channel)
    
    # Convert to array and sort
    local channels=()
    while IFS= read -r channel; do
        [ -n "$channel" ] && channels+=("$channel")
    done < <(echo "$channels_raw" | tr ' ' '\n' | sort -V)
    
    if [ ${#channels[@]} -eq 0 ]; then
        print_error "No channels found"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}Available RHOAI Channels:${NC}"
    echo ""
    
    # Categorize channels for better display
    local stable_channels=()
    local fast_channels=()
    local other_channels=()
    
    for channel in "${channels[@]}"; do
        if [[ "$channel" == stable* ]]; then
            stable_channels+=("$channel")
        elif [[ "$channel" == fast* ]]; then
            fast_channels+=("$channel")
        else
            other_channels+=("$channel")
        fi
    done
    
    local idx=1
    local channel_map=()
    
    # Display fast channels first (latest/preview)
    if [ ${#fast_channels[@]} -gt 0 ]; then
        echo -e "${MAGENTA}Fast Channels (Latest/Preview):${NC}"
        for channel in "${fast_channels[@]}"; do
            local marker=""
            [ "$channel" = "$default_channel" ] && marker=" ${GREEN}[default]${NC}"
            echo -e "  ${YELLOW}$idx)${NC} $channel$marker"
            channel_map+=("$channel")
            ((idx++))
        done
        echo ""
    fi
    
    # Display stable channels
    if [ ${#stable_channels[@]} -gt 0 ]; then
        echo -e "${MAGENTA}Stable Channels:${NC}"
        for channel in "${stable_channels[@]}"; do
            local marker=""
            [ "$channel" = "$default_channel" ] && marker=" ${GREEN}[default]${NC}"
            echo -e "  ${YELLOW}$idx)${NC} $channel$marker"
            channel_map+=("$channel")
            ((idx++))
        done
        echo ""
    fi
    
    # Display other channels
    if [ ${#other_channels[@]} -gt 0 ]; then
        echo -e "${MAGENTA}Other Channels:${NC}"
        for channel in "${other_channels[@]}"; do
            local marker=""
            [ "$channel" = "$default_channel" ] && marker=" ${GREEN}[default]${NC}"
            echo -e "  ${YELLOW}$idx)${NC} $channel$marker"
            channel_map+=("$channel")
            ((idx++))
        done
        echo ""
    fi
    
    echo -e "${CYAN}Channel Types:${NC}"
    echo "  • fast-3.x  : RHOAI 3.x (latest features, GenAI, MaaS)"
    echo "  • stable    : Production-ready releases"
    echo "  • stable-X.Y: Specific version streams"
    echo ""
    
    # Find default channel index
    local default_idx=1
    for i in "${!channel_map[@]}"; do
        if [ "${channel_map[$i]}" = "$default_channel" ]; then
            default_idx=$((i + 1))
            break
        fi
    done
    
    local max_idx=${#channel_map[@]}
    local choice=""
    
    while true; do
        read -p "Select channel (1-$max_idx) [default: $default_idx]: " choice
        choice=$(echo "$choice" | tr -d '[:space:]')
        
        # Use default if empty
        if [ -z "$choice" ]; then
            choice=$default_idx
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$max_idx" ]; then
            break
        else
            print_error "Invalid choice. Please select 1-$max_idx."
        fi
    done
    
    SELECTED_RHOAI_CHANNEL="${channel_map[$((choice - 1))]}"
    print_success "Selected channel: $SELECTED_RHOAI_CHANNEL"
    
    # Provide version info based on channel
    echo ""
    case "$SELECTED_RHOAI_CHANNEL" in
        fast-3.x|fast)
            print_info "This channel provides RHOAI 3.x with latest features"
            ;;
        stable)
            print_info "This channel provides the latest stable RHOAI release"
            ;;
        stable-*)
            local version="${SELECTED_RHOAI_CHANNEL#stable-}"
            print_info "This channel provides RHOAI $version.x releases"
            ;;
    esac
    
    return 0
}

# Interactive upgrade approval selection
# Usage: select_install_plan_approval
# Sets SELECTED_INSTALL_PLAN_APPROVAL variable
select_install_plan_approval() {
    echo ""
    echo -e "${CYAN}Upgrade Approval Mode:${NC}"
    echo ""
    echo -e "  ${YELLOW}1)${NC} Automatic ${GREEN}[default]${NC}"
    echo "     Operator upgrades are installed automatically when available."
    echo "     Best for: Development, testing, staying current"
    echo ""
    echo -e "  ${YELLOW}2)${NC} Manual"
    echo "     You must approve each upgrade before it's installed."
    echo "     Best for: Production, controlled upgrades, stability"
    echo ""
    
    local choice=""
    while true; do
        read -p "Select approval mode (1-2) [default: 1]: " choice
        choice=$(echo "$choice" | tr -d '[:space:]')
        
        # Use default if empty
        if [ -z "$choice" ]; then
            choice=1
        fi
        
        case "$choice" in
            1)
                SELECTED_INSTALL_PLAN_APPROVAL="Automatic"
                break
                ;;
            2)
                SELECTED_INSTALL_PLAN_APPROVAL="Manual"
                break
                ;;
            *)
                print_error "Invalid choice. Please select 1 or 2."
                ;;
        esac
    done
    
    print_success "Selected approval mode: $SELECTED_INSTALL_PLAN_APPROVAL"
    
    if [ "$SELECTED_INSTALL_PLAN_APPROVAL" = "Manual" ]; then
        echo ""
        print_info "With Manual approval, you'll need to approve InstallPlans:"
        echo "  oc get installplan -n redhat-ods-operator"
        echo "  oc patch installplan <name> -n redhat-ods-operator --type merge -p '{\"spec\":{\"approved\":true}}'"
    fi
    
    return 0
}

# Get current InstallPlanApproval setting for RHOAI
get_current_install_plan_approval() {
    oc get subscription rhods-operator -n redhat-ods-operator \
        -o jsonpath='{.spec.installPlanApproval}' 2>/dev/null
}

# Install RHOAI Operator with interactive channel and approval selection
# Usage: install_rhoai_operator_interactive
install_rhoai_operator_interactive() {
    print_header "Installing Red Hat OpenShift AI Operator"
    
    # Check if already installed
    if check_operator_installed "rhods-operator" "redhat-ods-operator"; then
        print_success "RHOAI Operator already installed"
        
        # Show current settings
        local current_channel=$(oc get subscription rhods-operator -n redhat-ods-operator \
            -o jsonpath='{.spec.channel}' 2>/dev/null)
        local current_approval=$(get_current_install_plan_approval)
        
        echo ""
        echo -e "${CYAN}Current Settings:${NC}"
        [ -n "$current_channel" ] && echo "  Channel: $current_channel"
        [ -n "$current_approval" ] && echo "  Upgrade Approval: $current_approval"
        echo ""
        
        read -p "Do you want to modify these settings? (y/N): " modify_settings
        if [[ ! "$modify_settings" =~ ^[Yy]$ ]]; then
            return 0
        fi
        
        echo ""
        echo -e "${CYAN}What would you like to change?${NC}"
        echo -e "  ${YELLOW}1)${NC} Channel only"
        echo -e "  ${YELLOW}2)${NC} Upgrade approval mode only"
        echo -e "  ${YELLOW}3)${NC} Both channel and approval mode"
        echo -e "  ${YELLOW}0)${NC} Cancel"
        echo ""
        
        local modify_choice=""
        read -p "Select option (0-3): " modify_choice
        
        case "$modify_choice" in
            1)
                if ! select_rhoai_channel; then
                    return 1
                fi
                print_step "Updating RHOAI subscription channel..."
                oc patch subscription rhods-operator -n redhat-ods-operator \
                    --type merge -p "{\"spec\":{\"channel\":\"$SELECTED_RHOAI_CHANNEL\"}}"
                print_success "Channel updated to: $SELECTED_RHOAI_CHANNEL"
                ;;
            2)
                select_install_plan_approval
                print_step "Updating RHOAI subscription approval mode..."
                oc patch subscription rhods-operator -n redhat-ods-operator \
                    --type merge -p "{\"spec\":{\"installPlanApproval\":\"$SELECTED_INSTALL_PLAN_APPROVAL\"}}"
                print_success "Approval mode updated to: $SELECTED_INSTALL_PLAN_APPROVAL"
                ;;
            3)
                if ! select_rhoai_channel; then
                    return 1
                fi
                select_install_plan_approval
                print_step "Updating RHOAI subscription..."
                oc patch subscription rhods-operator -n redhat-ods-operator \
                    --type merge -p "{\"spec\":{\"channel\":\"$SELECTED_RHOAI_CHANNEL\",\"installPlanApproval\":\"$SELECTED_INSTALL_PLAN_APPROVAL\"}}"
                print_success "Updated - Channel: $SELECTED_RHOAI_CHANNEL, Approval: $SELECTED_INSTALL_PLAN_APPROVAL"
                ;;
            0|*)
                print_info "No changes made"
                return 0
                ;;
        esac
        
        # Handle pending InstallPlan if Manual approval
        if [ "$SELECTED_INSTALL_PLAN_APPROVAL" = "Manual" ] || [ "$current_approval" = "Manual" ]; then
            echo ""
            local pending_ip=$(oc get installplan -n redhat-ods-operator -o jsonpath='{.items[?(@.spec.approved==false)].metadata.name}' 2>/dev/null)
            if [ -n "$pending_ip" ]; then
                print_warning "Pending InstallPlan detected: $pending_ip"
                read -p "Approve this InstallPlan now? (y/N): " approve_ip
                if [[ "$approve_ip" =~ ^[Yy]$ ]]; then
                    oc patch installplan "$pending_ip" -n redhat-ods-operator \
                        --type merge -p '{"spec":{"approved":true}}'
                    print_success "InstallPlan approved"
                fi
            fi
        fi
        
        return 0
    fi
    
    # New installation - select channel interactively
    if ! select_rhoai_channel; then
        print_warning "Channel selection failed, using default channel"
        SELECTED_RHOAI_CHANNEL=$(get_default_rhoai_channel)
        if [ -z "$SELECTED_RHOAI_CHANNEL" ]; then
            SELECTED_RHOAI_CHANNEL="fast-3.x"
        fi
    fi
    
    # Select upgrade approval mode
    select_install_plan_approval
    
    echo ""
    print_step "Installing RHOAI Operator..."
    echo "  Channel: $SELECTED_RHOAI_CHANNEL"
    echo "  Approval: $SELECTED_INSTALL_PLAN_APPROVAL"
    echo ""
    
    oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/rhoai/rhoai-namespace.yaml"
    oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/rhoai/rhoai-operatorgroup.yaml"
    export RHOAI_CHANNEL="$SELECTED_RHOAI_CHANNEL"
    export INSTALL_PLAN_APPROVAL="$SELECTED_INSTALL_PLAN_APPROVAL"
    envsubst '${RHOAI_CHANNEL} ${INSTALL_PLAN_APPROVAL}' < "$_RHOAI_LIB_DIR/lib/manifests/rhoai/rhoai-subscription.yaml" | oc apply -f -
    unset RHOAI_CHANNEL INSTALL_PLAN_APPROVAL
    
    # Manual approval: auto-approve the initial InstallPlan so the operator installs,
    # while keeping Manual mode for future upgrades
    if [ "$SELECTED_INSTALL_PLAN_APPROVAL" = "Manual" ]; then
        print_step "Waiting for initial InstallPlan to be created..."
        
        local timeout=180
        local elapsed=0
        local installplan=""
        
        while [ $elapsed -lt $timeout ]; do
            installplan=$(oc get subscription rhods-operator -n redhat-ods-operator \
                -o jsonpath='{.status.installPlanRef.name}' 2>/dev/null || true)
            if [ -n "$installplan" ]; then
                break
            fi
            sleep 5
            elapsed=$((elapsed + 5))
            [ $((elapsed % 15)) -eq 0 ] && echo "  Waiting for OLM to generate InstallPlan... (${elapsed}s elapsed)"
        done
        
        if [ -n "$installplan" ]; then
            print_step "Auto-approving initial InstallPlan: $installplan"
            print_info "Future upgrades will still require manual approval"
            approve_installplan "rhods-operator" "redhat-ods-operator"
        else
            print_warning "InstallPlan not found after ${timeout}s. Approve it manually:"
            echo "  oc get installplan -n redhat-ods-operator"
            echo "  oc patch installplan <name> -n redhat-ods-operator --type merge -p '{\"spec\":{\"approved\":true}}'"
        fi
    fi
    
    # Wait for operator to be ready
    print_step "Waiting for RHOAI operator to be ready (this may take 2-3 minutes)..."
    sleep 30
    
    local timeout=300
    local elapsed=0
    until oc get crd datascienceclusters.datasciencecluster.opendatahub.io &>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Timeout waiting for RHOAI operator CRDs (continuing anyway)"
            break
        fi
        echo "Waiting for DataScienceCluster CRD... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_success "RHOAI Operator is ready"
    echo ""
    echo -e "${CYAN}Installation Summary:${NC}"
    echo "  Channel: $SELECTED_RHOAI_CHANNEL"
    echo "  Upgrade Approval: $SELECTED_INSTALL_PLAN_APPROVAL"
    
    if [ "$SELECTED_INSTALL_PLAN_APPROVAL" = "Manual" ]; then
        echo ""
        print_info "Future upgrades will require manual approval:"
        echo "  oc get installplan -n redhat-ods-operator"
        echo "  oc patch installplan <name> -n redhat-ods-operator --type merge -p '{\"spec\":{\"approved\":true}}'"
    fi
}

# Install RHOAI Operator
install_rhoai_operator() {
    local rhoai_version="$1"
    local channel=$(get_rhoai_channel "$rhoai_version")
    
    print_header "Installing Red Hat OpenShift AI Operator (version $rhoai_version)"
    
    # Check if already installed
    if check_operator_installed "rhods-operator" "redhat-ods-operator"; then
        print_success "RHOAI Operator already installed"
        return 0
    fi
    
    print_step "Installing RHOAI Operator (channel: $channel)..."
    
    oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/rhoai/rhoai-namespace.yaml"
    oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/rhoai/rhoai-operatorgroup.yaml"
    export RHOAI_CHANNEL="$channel"
    export INSTALL_PLAN_APPROVAL="Automatic"
    envsubst '${RHOAI_CHANNEL} ${INSTALL_PLAN_APPROVAL}' < "$_RHOAI_LIB_DIR/lib/manifests/rhoai/rhoai-subscription.yaml" | oc apply -f -
    unset RHOAI_CHANNEL INSTALL_PLAN_APPROVAL
    
    # Wait for operator to be ready
    print_step "Waiting for RHOAI operator to be ready (this may take 2-3 minutes)..."
    sleep 30
    
    local timeout=300
    local elapsed=0
    until oc get crd datascienceclusters.datasciencecluster.opendatahub.io &>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Timeout waiting for RHOAI operator CRDs (continuing anyway)"
            break
        fi
        echo "Waiting for DataScienceCluster CRD... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_success "RHOAI Operator is ready"
}

# Initialize RHOAI (DSCInitialization)
initialize_rhoai() {
    print_header "Initializing RHOAI"
    
    if oc get dscinitializations.dscinitialization.opendatahub.io default-dsci &>/dev/null; then
        print_success "RHOAI already initialized"
        return 0
    fi
    
    # Wait for RHOAI operator webhook service to be ready
    print_step "Waiting for RHOAI operator webhook service to be ready..."
    local webhook_timeout=180
    local webhook_elapsed=0
    
    until oc get svc -n redhat-ods-operator | grep -q "rhods-operator"; do
        if [ $webhook_elapsed -ge $webhook_timeout ]; then
            print_error "Timeout waiting for RHOAI operator webhook service"
            return 1
        fi
        echo "Waiting for webhook service... (${webhook_elapsed}s elapsed)"
        sleep 10
        webhook_elapsed=$((webhook_elapsed + 10))
    done
    
    # Additional wait for webhook to be fully functional
    print_step "Waiting for webhook to be fully registered..."
    sleep 30
    
    # Verify webhook endpoints are ready
    local endpoint_check=0
    until oc get endpoints -n redhat-ods-operator rhods-operator-service &>/dev/null && \
          [ "$(oc get endpoints -n redhat-ods-operator rhods-operator-service -o jsonpath='{.subsets[*].addresses}' 2>/dev/null)" != "" ]; do
        if [ $endpoint_check -ge 60 ]; then
            print_warning "Webhook endpoints not fully ready, proceeding anyway"
            break
        fi
        echo "Waiting for webhook endpoints... (${endpoint_check}s elapsed)"
        sleep 10
        endpoint_check=$((endpoint_check + 10))
    done
    
    print_success "RHOAI operator webhook is ready"
    
    print_step "Creating DSCInitialization..."
    
    # Use replace if exists, apply if not (handles conversion webhook issues better)
    if oc get dscinitialization default-dsci &>/dev/null 2>&1; then
        print_step "DSCInitialization exists but may be in wrong version, replacing..."
        oc replace -f "$_RHOAI_LIB_DIR/lib/manifests/rhoai/dscinitialization-v1-servicemesh.yaml"
    else
        oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/rhoai/dscinitialization-v1-servicemesh.yaml"
    fi
    
    if [ $? -eq 0 ]; then
        print_success "RHOAI initialized"
    else
        print_error "Failed to initialize RHOAI"
        print_info "This may be due to webhook timing. Check:"
        print_info "  oc get pods -n redhat-ods-operator"
        print_info "  oc get svc -n redhat-ods-operator"
        return 1
    fi
}

# Create DataScienceCluster (RHOAI 2.x)
create_datasciencecluster_v1() {
    print_header "Creating DataScienceCluster (v1)"
    
    if oc get datascienceclusters.datasciencecluster.opendatahub.io default-dsc &>/dev/null; then
        print_success "DataScienceCluster already exists"
        return 0
    fi
    
    print_step "Creating DataScienceCluster..."
    apply_manifest "$_RHOAI_LIB_DIR/lib/manifests/rhoai/datasciencecluster-v1.yaml" "DataScienceCluster v1"
    
    print_success "DataScienceCluster created"
}

# Create DataScienceCluster (RHOAI 3.x with GenAI/MaaS)
create_datasciencecluster_v2() {
    print_header "Creating DataScienceCluster (v2 - with GenAI/MaaS)"
    
    if oc get datascienceclusters.datasciencecluster.opendatahub.io default-dsc &>/dev/null; then
        print_success "DataScienceCluster already exists"
        return 0
    fi
    
    print_step "Creating DataScienceCluster with GenAI and MaaS components..."
    apply_manifest "$_RHOAI_LIB_DIR/lib/manifests/rhoai/datasciencecluster-v2.yaml" "DataScienceCluster v2"
    
    print_success "DataScienceCluster created with GenAI and MaaS support"
}

# Configure RHOAI Dashboard
configure_rhoai_dashboard() {
    print_header "Configuring RHOAI Dashboard"
    
    print_step "Enabling GenAI Studio and Model as a Service..."

    oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge \
        --patch-file="$_RHOAI_LIB_DIR/lib/manifests/rhoai/odh-dashboard-config-patch.yaml"
    
    print_success "Dashboard configured"
}

# Create GPU Hardware Profile
create_gpu_hardware_profile() {
    print_header "Creating GPU Hardware Profile"
    
    # Get current namespace or use default
    local current_ns=$(oc project -q 2>/dev/null || echo "default")
    
    # Template file location
    local template_file="$_RHOAI_LIB_DIR/lib/manifests/templates/hardwareprofile-gpu.yaml.tmpl"
    
    # Function to create hardware profile in a namespace
    create_profile_in_namespace() {
        local namespace=$1
        
        if oc get hardwareprofile gpu-profile -n "$namespace" &>/dev/null; then
            print_success "GPU hardware profile already exists in $namespace"
            return 0
        fi
        
        print_step "Creating GPU hardware profile in $namespace..."
        
        # Apply template with namespace substitution
        if [ -f "$template_file" ]; then
            # Export all variables with defaults (envsubst doesn't support bash default syntax)
            export NAMESPACE="$namespace"
            export PROFILE_NAME="gpu-profile"
            export DISPLAY_NAME="GPU Profile"
            export DEFAULT_CPU="2"
            export MAX_CPU="16"
            export DEFAULT_MEM="16Gi"
            export MAX_MEM="64Gi"
            export DEFAULT_GPU="1"
            export MAX_GPU="8"
            
            # Use envsubst with explicit variable list to avoid issues
            envsubst '${NAMESPACE} ${PROFILE_NAME} ${DISPLAY_NAME} ${DEFAULT_CPU} ${MAX_CPU} ${DEFAULT_MEM} ${MAX_MEM} ${DEFAULT_GPU} ${MAX_GPU}' < "$template_file" | oc apply -f -
            
            # Unset variables
            unset NAMESPACE PROFILE_NAME DISPLAY_NAME DEFAULT_CPU MAX_CPU DEFAULT_MEM MAX_MEM DEFAULT_GPU MAX_GPU
        else
            print_warning "Template not found at $template_file, using static manifest"
            sed "s/namespace: redhat-ods-applications/namespace: $namespace/" \
                "$_RHOAI_LIB_DIR/lib/manifests/rhoai/hardware-profile-gpu.yaml" | oc apply -f -
        fi
        print_success "GPU hardware profile created in $namespace"
    }
    
    # Create in redhat-ods-applications (for reference)
    create_profile_in_namespace "redhat-ods-applications"
    
    # Also create in current namespace if it's different and not a system namespace
    if [[ "$current_ns" != "redhat-ods-applications" ]] && \
       [[ "$current_ns" != "default" ]] && \
       [[ "$current_ns" != "openshift-"* ]]; then
        print_info "Also creating profile in current namespace: $current_ns"
        create_profile_in_namespace "$current_ns"
    fi
    
    print_success "GPU hardware profile setup complete"
    print_info "Note: Hardware profiles in RHOAI 3.0 are namespace-scoped for model deployment"
    print_info "Use './scripts/create-hardware-profile.sh <namespace>' to create in other namespaces"
}

# Configure Kueue ResourceFlavor for GPU nodes with taints
configure_gpu_resourceflavor() {
    print_header "Configuring Kueue ResourceFlavor for GPU Nodes"
    
    # Check if nvidia-gpu-flavor exists, create it if not
    if ! oc get resourceflavor nvidia-gpu-flavor &>/dev/null; then
        print_warning "ResourceFlavor 'nvidia-gpu-flavor' not found"
        
        # Check if Kueue is Unmanaged (won't auto-create resources)
        local kueue_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.kueue.managementState}' 2>/dev/null || echo "Unknown")
        
        if [[ "$kueue_state" == "Unmanaged" ]]; then
            print_info "Kueue is 'Unmanaged' - creating ResourceFlavor manually..."
            
            oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/kueue/resourceflavor-gpu-basic.yaml"
            
            if oc get resourceflavor nvidia-gpu-flavor &>/dev/null; then
                print_success "ResourceFlavor created"
            else
                print_error "Failed to create ResourceFlavor"
                return 1
            fi
        else
            print_info "Kueue managementState: $kueue_state"
            print_info "This will be created automatically by RHOAI when Kueue is enabled"
            print_info "Skipping ResourceFlavor configuration for now"
            return 0
        fi
    else
        print_success "ResourceFlavor 'nvidia-gpu-flavor' already exists"
    fi
    
    print_step "Checking for GPU nodes..."
    
    # Check if GPU nodes exist
    local gpu_nodes=$(oc get nodes -l nvidia.com/gpu.present=true -o name 2>/dev/null)
    if [ -z "$gpu_nodes" ]; then
        print_warning "No GPU nodes found with label nvidia.com/gpu.present=true"
        echo ""
        echo -e "${YELLOW}GPU nodes will be detected when they are added.${NC}"
        echo -e "${YELLOW}Run this configuration again after adding GPU nodes.${NC}"
        echo ""
        
        # Configure with node selector only for now
        print_step "Configuring ResourceFlavor with node selector..."
        oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/kueue/resourceflavor-gpu-selector.yaml"
        
        if [ $? -eq 0 ]; then
            print_success "ResourceFlavor configured (will auto-detect GPU nodes when added)"
        fi
        return 0
    fi
    
    # Show GPU nodes found
    local node_count=$(echo "$gpu_nodes" | wc -l | tr -d ' ')
    print_success "Found $node_count GPU node(s):"
    echo "$gpu_nodes" | sed 's/node\//  - /'
    echo ""
    
    # Check if GPU nodes have taints
    print_step "Checking GPU node taints..."
    local has_taint=$(oc get nodes -l nvidia.com/gpu.present=true -o json | jq -r '.items[].spec.taints[]? | select(.key=="nvidia.com/gpu") | .key' | head -1)
    
    if [ -n "$has_taint" ]; then
        print_info "✓ GPU nodes are tainted with nvidia.com/gpu:NoSchedule"
        echo ""
        echo -e "${CYAN}GPU nodes are tainted to prevent non-GPU workloads.${NC}"
        echo -e "${CYAN}ResourceFlavor needs toleration to schedule GPU workloads.${NC}"
        echo ""
        
        read -p "Configure ResourceFlavor with GPU toleration? (Y/n): " add_toleration
        add_toleration=${add_toleration:-Y}
        
        if [[ "$add_toleration" =~ ^[Yy]$ ]]; then
            print_step "Updating nvidia-gpu-flavor ResourceFlavor with toleration..."
            
            oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/kueue/resourceflavor-gpu-toleration.yaml"
            
            if [ $? -eq 0 ]; then
                print_success "ResourceFlavor configured with GPU toleration"
                echo ""
                print_info "✓ Node selector: nvidia.com/gpu.present=true"
                print_info "✓ Toleration: nvidia.com/gpu:NoSchedule"
            else
                print_error "Failed to configure ResourceFlavor"
                return 1
            fi
        else
            print_warning "Skipping toleration configuration"
            print_warning "GPU workloads may fail with 'untolerated taint' error"
        fi
    else
        print_info "✓ GPU nodes are NOT tainted"
        echo ""
        echo -e "${YELLOW}GPU nodes are not tainted.${NC}"
        echo -e "${YELLOW}This means any workload can be scheduled on GPU nodes.${NC}"
        echo ""
        echo -e "${CYAN}Recommendation: Taint GPU nodes to reserve them for GPU workloads only.${NC}"
        echo -e "${CYAN}Command: oc adm taint nodes -l nvidia.com/gpu.present=true nvidia.com/gpu=:NoSchedule${NC}"
        echo ""
        
        read -p "Do you want to taint GPU nodes now? (y/N): " taint_nodes
        taint_nodes=${taint_nodes:-N}
        
        if [[ "$taint_nodes" =~ ^[Yy]$ ]]; then
            print_step "Tainting GPU nodes..."
            oc adm taint nodes -l nvidia.com/gpu.present=true nvidia.com/gpu=:NoSchedule --overwrite
            
            if [ $? -eq 0 ]; then
                print_success "GPU nodes tainted successfully"
                echo ""
                print_step "Updating ResourceFlavor with toleration..."
                
                oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/kueue/resourceflavor-gpu-toleration.yaml"
                
                if [ $? -eq 0 ]; then
                    print_success "ResourceFlavor configured with GPU toleration"
                    echo ""
                    print_info "✓ Node selector: nvidia.com/gpu.present=true"
                    print_info "✓ Toleration: nvidia.com/gpu:NoSchedule"
                fi
            else
                print_error "Failed to taint GPU nodes"
                return 1
            fi
        else
            print_step "Configuring ResourceFlavor without toleration..."
            
            oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/kueue/resourceflavor-gpu-selector.yaml"
            
            if [ $? -eq 0 ]; then
                print_success "ResourceFlavor configured with node selector only"
                echo ""
                print_info "✓ Node selector: nvidia.com/gpu.present=true"
                print_info "✓ No tolerations (GPU nodes not tainted)"
            else
                print_error "Failed to configure ResourceFlavor"
                return 1
            fi
        fi
    fi
}

# Enable User Workload Monitoring
enable_user_workload_monitoring() {
    print_header "Enabling User Workload Monitoring"
    
    if oc get configmap user-workload-monitoring-config -n openshift-user-workload-monitoring &>/dev/null; then
        print_success "User workload monitoring already enabled"
        return 0
    fi
    
    print_step "Creating user workload monitoring ConfigMap..."
    
    oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/monitoring/user-workload-monitoring-config.yaml"
    
    print_success "User workload monitoring enabled"
}

# Enable Cluster Monitoring for KServe metrics (per CAI Guide 3.2 Section 0)
# This is different from user-workload-monitoring - it's in openshift-monitoring namespace
enable_cluster_monitoring_for_kserve() {
    print_header "Enable Cluster Monitoring for KServe Metrics"
    
    echo ""
    echo -e "${CYAN}This enables UserWorkloadMonitoring to capture KServe metrics${NC}"
    echo -e "${CYAN}(per CAI Guide Section 0, Step 5)${NC}"
    echo ""
    
    if oc get configmap cluster-monitoring-config -n openshift-monitoring &>/dev/null; then
        print_info "cluster-monitoring-config already exists, checking settings..."
        local current=$(oc get configmap cluster-monitoring-config -n openshift-monitoring -o jsonpath='{.data.config\.yaml}' 2>/dev/null)
        if echo "$current" | grep -q "enableUserWorkload: true"; then
            print_success "UserWorkload monitoring already enabled"
            return 0
        fi
    fi
    
    print_step "Creating/updating cluster-monitoring-config ConfigMap..."
    
    oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/monitoring/cluster-monitoring-config.yaml"
    
    if [ $? -eq 0 ]; then
        print_success "Cluster monitoring configured for KServe metrics"
    else
        print_error "Failed to configure cluster monitoring"
    fi
}

# Configure DSCInitialization with Observability (RHOAI 3.2+)
# Includes metrics and traces storage configuration per CAI Guide Section 7
configure_dsci_observability() {
    print_header "Configure DSCInitialization Observability (RHOAI 3.2+)"
    
    echo ""
    echo -e "${CYAN}This configures (per CAI Guide Section 7):${NC}"
    echo "  • Metrics collection with persistent storage"
    echo "  • Distributed tracing with Tempo"
    echo ""
    echo -e "${YELLOW}Prerequisites:${NC}"
    echo "  • Cluster Observability Operator"
    echo "  • Red Hat build of OpenTelemetry"
    echo "  • Tempo Operator"
    echo ""
    
    read -p "Continue with observability configuration? (Y/n): " continue_obs
    continue_obs=${continue_obs:-Y}
    
    if [[ ! "$continue_obs" =~ ^[Yy]$ ]]; then
        print_info "Skipping observability configuration"
        return 0
    fi
    
    # Get configuration options
    read -p "Metrics retention period [90d]: " metrics_retention
    metrics_retention=${metrics_retention:-90d}
    
    read -p "Metrics storage size [5Gi]: " metrics_size
    metrics_size=${metrics_size:-5Gi}
    
    read -p "Traces sample ratio (0.0-1.0) [0.1]: " trace_ratio
    trace_ratio=${trace_ratio:-0.1}
    
    read -p "Traces retention period [2160h0m0s]: " trace_retention
    trace_retention=${trace_retention:-2160h0m0s}
    
    print_step "Updating DSCInitialization with observability settings..."
    
    export METRICS_RETENTION="$metrics_retention"
    export METRICS_SIZE="$metrics_size"
    export TRACE_RATIO="$trace_ratio"
    export TRACE_RETENTION="$trace_retention"
    envsubst '${METRICS_RETENTION} ${METRICS_SIZE} ${TRACE_RATIO} ${TRACE_RETENTION}' \
        < "$_RHOAI_LIB_DIR/lib/manifests/rhoai/dscinitialization-observability.yaml" | oc apply -f -
    unset METRICS_RETENTION METRICS_SIZE TRACE_RATIO TRACE_RETENTION
    
    if [ $? -eq 0 ]; then
        print_success "DSCInitialization updated with observability"
        echo ""
        print_info "Metrics will be stored with ${metrics_retention} retention"
        print_info "Traces will sample ${trace_ratio} of requests"
        print_warning "Note: There may be a bug with UIPlugin for viewing traces (RHOAIENG-38891)"
    else
        print_error "Failed to update DSCInitialization"
    fi
}

# Setup MCP Servers ConfigMap (per RHOAI 3.4 Gen AI Studio docs)
# Creates the gen-ai-aa-mcp-servers ConfigMap for Playground MCP tool access
setup_mcp_servers_configmap() {
    local namespace="${1:-redhat-ods-applications}"
    
    print_header "Setup MCP Servers ConfigMap (RHOAI 3.2+)"
    
    echo ""
    echo -e "${CYAN}This creates the MCP servers ConfigMap for the Gen AI Studio Playground${NC}"
    echo ""
    
    # Check if ConfigMap exists
    if oc get configmap gen-ai-aa-mcp-servers -n "$namespace" &>/dev/null; then
        print_info "MCP servers ConfigMap already exists"
        read -p "Replace with default configuration? (y/N): " replace_cm
        if [[ ! "$replace_cm" =~ ^[Yy]$ ]]; then
            print_info "Keeping existing configuration"
            return 0
        fi
    fi
    
    print_step "Creating MCP servers ConfigMap..."
    
    oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/mcp/mcp-servers-configmap.yaml"
    
    if [ $? -eq 0 ]; then
        print_success "MCP servers ConfigMap created"
        echo ""
        print_info "To use an MCP server in the Playground:"
        echo "  1. Click the lock icon (🔒) next to the MCP server"
        echo "  2. Login even if auth is not required"
        echo ""
        print_info "To add more MCP servers, edit the ConfigMap:"
        echo "  oc edit configmap gen-ai-aa-mcp-servers -n $namespace"
    else
        print_error "Failed to create MCP servers ConfigMap"
    fi
}

# Create prerequisites for MCP Catalog deployments (MCPServer CRs)
# The MCP Catalog UI creates MCPServer CRs but does NOT auto-create the
# ServiceAccount, RBAC, or config ConfigMap that the server image requires.
setup_mcp_catalog_prerequisites() {
    local namespace="${1:?Namespace required}"

    print_step "Setting up MCP Catalog prerequisites in $namespace..."

    # ServiceAccount for MCP server read-only cluster access
    if ! oc get sa mcp-viewer -n "$namespace" &>/dev/null; then
        print_step "Creating mcp-viewer ServiceAccount..."
        oc create serviceaccount mcp-viewer -n "$namespace"
        oc create clusterrolebinding "mcp-viewer-${namespace}" \
            --clusterrole=view \
            --serviceaccount="${namespace}:mcp-viewer" 2>/dev/null || true
        print_success "mcp-viewer ServiceAccount created with view ClusterRole"
    else
        print_success "mcp-viewer ServiceAccount already exists [SKIP]"
    fi

    # Config ConfigMap for OpenShift MCP Server (from MCP Catalog)
    if ! oc get configmap openshift-mcp-server-config -n "$namespace" &>/dev/null; then
        print_step "Creating openshift-mcp-server-config ConfigMap..."
        export NAMESPACE="$namespace"
        envsubst '${NAMESPACE}' < "$_RHOAI_LIB_DIR/lib/manifests/mcp/mcp-catalog-configmap.yaml" | oc apply -f -
        unset NAMESPACE
        print_success "openshift-mcp-server-config ConfigMap created"
    else
        print_success "openshift-mcp-server-config ConfigMap already exists [SKIP]"
    fi
}

# Setup llm-d infrastructure (per CAI Guide Section 3 - RHOAI 3.2)
setup_llmd_infrastructure() {
    print_header "Setting up llm-d Infrastructure (per CAI Guide 3.2)"
    
    echo ""
    echo -e "${CYAN}This will set up:${NC}"
    echo "  1. GatewayClass for inference"
    echo "  2. Gateway for inference endpoints"
    echo "  3. LeaderWorkerSet Operator (for multi-GPU/MoE)"
    echo "  4. RHCL (Kuadrant) for authentication (optional)"
    echo "  5. Authorino TLS configuration (optional)"
    echo ""
    
    # Step 1: Create GatewayClass
    print_step "Creating GatewayClass 'openshift-ai-inference'..."
    if oc get gatewayclass openshift-ai-inference &>/dev/null; then
        print_success "GatewayClass already exists"
    else
        oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/rhcl/gatewayclass-ai-inference.yaml"
        print_success "GatewayClass created"
    fi
    
    # Step 2: Create Gateway
    print_step "Creating Gateway 'openshift-ai-inference'..."
    if oc get gateway openshift-ai-inference -n openshift-ingress &>/dev/null; then
        print_success "Gateway already exists"
    else
        local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
        print_info "Cluster domain: $cluster_domain"
        
        export CLUSTER_DOMAIN="$cluster_domain"
        export CERT_NAME="default-gateway-tls"
        envsubst '${CLUSTER_DOMAIN} ${CERT_NAME}' < "$_RHOAI_LIB_DIR/lib/manifests/rhcl/gateway-inference.yaml" | oc apply -f -
        unset CLUSTER_DOMAIN CERT_NAME
        print_success "Gateway created"
        print_info "Gateway hostname: inference-gateway.apps.$cluster_domain"
    fi
    
    # Step 3: Create LeaderWorkerSetOperator instance (optional - for multi-GPU)
    print_step "Checking LeaderWorkerSet Operator..."
    if oc get leaderworkersetoperator cluster -n openshift-lws-operator &>/dev/null; then
        print_success "LeaderWorkerSetOperator instance already exists"
    else
        if oc get crd leaderworkersetoperators.operator.openshift.io &>/dev/null; then
            print_step "Creating LeaderWorkerSetOperator instance..."
            oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/operators/lws-operator-cr.yaml"
            print_success "LeaderWorkerSetOperator instance created"
        else
            print_warning "LWS Operator not installed (only needed for multi-GPU/MoE deployments)"
        fi
    fi
    
    # Step 4: Setup RHCL (Kuadrant) for authentication
    echo ""
    read -p "Setup RHCL (Kuadrant) for llm-d authentication? (y/N): " setup_rhcl
    if [[ "$setup_rhcl" =~ ^[Yy]$ ]]; then
        setup_rhcl_for_llmd
    else
        print_info "Skipping RHCL setup"
        print_warning "Without RHCL, llm-d authentication will not work properly"
    fi
    
    print_success "llm-d infrastructure setup complete"
    echo ""
    print_info "You can now deploy models using llm-d serving runtime"
    print_info "Remember to check 'Require authentication' checkbox in the UI"
}

# Setup RHCL (Red Hat Connectivity Link / Kuadrant) for llm-d authentication
# Per CAI Guide Section 3 - RHOAI 3.2
setup_rhcl_for_llmd() {
    print_header "Setting up RHCL (Kuadrant) for llm-d Authentication"
    
    # Check if RHCL operator is installed
    if ! oc get csv -n kuadrant-system 2>/dev/null | grep -q rhcl; then
        print_warning "RHCL Operator not installed in kuadrant-system namespace"
        echo ""
        echo -e "${CYAN}To install RHCL:${NC}"
        echo "  1. Create namespace: oc create namespace kuadrant-system"
        echo "  2. Install 'Red Hat Connectivity Link' operator in kuadrant-system namespace"
        echo "  3. Re-run this setup"
        echo ""
        read -p "Create kuadrant-system namespace and continue? (y/N): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc create namespace kuadrant-system 2>/dev/null || true
            print_info "Namespace created. Please install RHCL operator from OperatorHub"
            return 1
        fi
        return 1
    fi
    
    # Step 1: Create Kuadrant instance
    print_step "Creating Kuadrant instance..."
    if oc get kuadrant kuadrant -n kuadrant-system &>/dev/null; then
        print_success "Kuadrant instance already exists"
    else
        oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/rhcl/kuadrant-instance.yaml"
        print_success "Kuadrant instance created"
        sleep 5
    fi
    
    # Step 2: Annotate Authorino service for TLS
    print_step "Configuring Authorino service for TLS..."
    if oc get svc authorino-authorino-authorization -n kuadrant-system &>/dev/null; then
        oc annotate svc/authorino-authorino-authorization \
            service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
            -n kuadrant-system --overwrite 2>/dev/null || true
        print_success "Authorino service annotated"
    else
        print_warning "Authorino service not found (may take a moment to create)"
    fi
    
    # Step 3: Update Authorino for TLS
    print_step "Enabling TLS on Authorino..."
    if oc get authorino authorino -n kuadrant-system &>/dev/null; then
        oc apply -f "$_RHOAI_LIB_DIR/lib/manifests/rhcl/authorino-tls.yaml"
        print_success "Authorino TLS enabled"
    else
        print_warning "Authorino not found yet (RHCL may still be initializing)"
    fi
    
    # Step 4: Restart controllers to pick up Authorino
    echo ""
    read -p "Restart odh-model-controller and kserve-controller? (recommended) (Y/n): " restart_controllers
    restart_controllers=${restart_controllers:-Y}
    if [[ "$restart_controllers" =~ ^[Yy]$ ]]; then
        print_step "Restarting controllers..."
        oc delete pod -n redhat-ods-applications -l app=odh-model-controller 2>/dev/null || true
        oc delete pod -n redhat-ods-applications -l control-plane=kserve-controller-manager 2>/dev/null || true
        print_success "Controllers restarted"
    fi
    
    # Verify AuthPolicy
    print_step "Checking for global AuthPolicy..."
    sleep 5
    if oc get authpolicy -n openshift-ingress 2>/dev/null | grep -q "openshift-ai-inference"; then
        print_success "Global AuthPolicy created"
    else
        print_warning "Global AuthPolicy not found yet (may take a moment)"
        print_info "Check with: oc get authpolicy -n openshift-ingress"
    fi
    
    print_success "RHCL setup complete"
    echo ""
    print_info "llm-d models with 'Require authentication' will now work"
    print_info "To disable auth on a model: oc annotate llmisvc/<name> security.opendatahub.io/enable-auth=false"
}

# Pin NVIDIA driver version for CUDA 12.8 compatibility (per CAI Guide)
# This fixes 'NVIDIA driver too old' errors with vLLM
pin_nvidia_driver_version() {
    print_header "Pin NVIDIA Driver Version (CUDA 12.8 Compatibility)"
    
    echo ""
    echo -e "${YELLOW}NOTE: Due to a known error with the latest NVIDIA GPU Operator,${NC}"
    echo -e "${YELLOW}you should pin the driver version to CUDA 12.8 (570.195.03)${NC}"
    echo -e "${YELLOW}to get vLLM to run without crashing.${NC}"
    echo ""
    
    # Check if ClusterPolicy exists
    if ! oc get clusterpolicy gpu-cluster-policy &>/dev/null; then
        print_error "ClusterPolicy 'gpu-cluster-policy' not found"
        print_info "Install NVIDIA GPU Operator first"
        return 1
    fi
    
    # Show current driver config
    local current_driver=$(oc get clusterpolicy gpu-cluster-policy -o jsonpath='{.spec.driver.version}' 2>/dev/null)
    echo -e "Current driver version: ${CYAN}${current_driver:-default}${NC}"
    echo ""
    
    read -p "Pin driver to version 570.195.03 (CUDA 12.8)? (Y/n): " pin_driver
    pin_driver=${pin_driver:-Y}
    
    if [[ "$pin_driver" =~ ^[Yy]$ ]]; then
        print_step "Patching ClusterPolicy with driver version 570.195.03..."
        
        oc patch clusterpolicy gpu-cluster-policy --type=merge -p '{
            "spec": {
                "driver": {
                    "repository": "nvcr.io/nvidia",
                    "image": "driver",
                    "version": "570.195.03"
                }
            }
        }'
        
        if [ $? -eq 0 ]; then
            print_success "ClusterPolicy patched"
            echo ""
            print_info "Driver pods will be recreated. This may take several minutes."
            print_info "Monitor with: oc get pods -n nvidia-gpu-operator | grep driver"
        else
            print_error "Failed to patch ClusterPolicy"
        fi
    else
        print_info "Skipping driver version pinning"
    fi
}

# Enable MLflow Operator (new in RHOAI 3.2+)
enable_mlflow_operator() {
    print_header "Enable MLflow Operator (RHOAI 3.2+)"
    
    echo ""
    echo -e "${CYAN}MLflow provides:${NC}"
    echo "  • Experiment tracking"
    echo "  • Model versioning"
    echo "  • Artifact storage"
    echo "  • Model registry integration"
    echo ""
    
    # Check current state
    local mlflow_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.mlflowoperator.managementState}' 2>/dev/null || echo "Unknown")
    echo -e "Current MLflow state: ${CYAN}$mlflow_state${NC}"
    
    if [[ "$mlflow_state" == "Managed" ]]; then
        print_success "MLflow operator already enabled"
        return 0
    fi
    
    read -p "Enable MLflow operator? (Y/n): " enable_mlflow
    enable_mlflow=${enable_mlflow:-Y}
    
    if [[ "$enable_mlflow" =~ ^[Yy]$ ]]; then
        print_step "Patching DataScienceCluster to enable mlflowoperator..."
        oc patch datasciencecluster default-dsc --type='merge' \
            -p '{"spec":{"components":{"mlflowoperator":{"managementState":"Managed"}}}}'
        
        if [ $? -eq 0 ]; then
            print_success "MLflow operator enabled"
            
            # Wait for CRD
            print_step "Waiting for MLflow CRD..."
            local timeout=60
            local elapsed=0
            until oc get crd mlflows.mlflow.opendatahub.io &>/dev/null; do
                if [ $elapsed -ge $timeout ]; then
                    print_warning "Timeout waiting for MLflow CRD"
                    break
                fi
                sleep 5
                elapsed=$((elapsed + 5))
            done
            
            echo ""
            print_info "To deploy MLflow, create an MLflow CR:"
            echo ""
            echo "  oc apply -f - <<EOF"
            echo "  apiVersion: mlflow.opendatahub.io/v1"
            echo "  kind: MLflow"
            echo "  metadata:"
            echo "    name: mlflow"
            echo "  spec:"
            echo "    storage:"
            echo "      accessModes:"
            echo "        - ReadWriteOnce"
            echo "      resources:"
            echo "        requests:"
            echo "          storage: 10Gi"
            echo "    backendStoreUri: \"sqlite:////mlflow/mlflow.db\""
            echo "    artifactsDestination: \"file:///mlflow/artifacts\""
            echo "    serveArtifacts: true"
            echo "  EOF"
        else
            print_error "Failed to enable MLflow operator"
        fi
    fi
}

# Deploy LLMInferenceService (llm-d model) - RHOAI 3.2+
deploy_llminferenceservice() {
    local namespace="${1:-}"
    local model_name="${2:-}"
    local model_uri="${3:-}"
    
    print_header "Deploy LLMInferenceService (llm-d)"
    
    # Get namespace
    if [ -z "$namespace" ]; then
        local current_ns=$(oc project -q 2>/dev/null || echo "default")
        read -p "Enter namespace [$current_ns]: " namespace
        namespace=${namespace:-$current_ns}
    fi
    
    # Get model name
    if [ -z "$model_name" ]; then
        read -p "Enter model name (e.g., qwen3-sample): " model_name
    fi
    
    # Get model URI
    if [ -z "$model_uri" ]; then
        echo ""
        echo -e "${CYAN}Model URI examples:${NC}"
        echo "  • oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b-fp8-dynamic:latest"
        echo "  • hf://RedHatAI/Qwen3-8B-FP8-dynamic"
        echo "  • oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct"
        echo ""
        read -p "Enter model URI: " model_uri
    fi
    
    # Authentication option
    echo ""
    read -p "Enable authentication? (Y/n): " enable_auth
    enable_auth=${enable_auth:-Y}
    local auth_annotation="true"
    if [[ ! "$enable_auth" =~ ^[Yy]$ ]]; then
        auth_annotation="false"
    fi
    
    # GPU resources
    read -p "Number of GPUs [1]: " gpu_count
    gpu_count=${gpu_count:-1}
    
    read -p "Memory limit [16Gi]: " memory_limit
    memory_limit=${memory_limit:-16Gi}

    # Tool-call parser: hermes/llama3_json/mistral are NOT interchangeable --
    # each is tied to a specific model family's tool-call output format.
    # Guess a default from the model name/URI, but always let the user
    # confirm/override rather than silently forcing one family's parser
    # onto a different model.
    local detected_parser="hermes"
    local name_and_uri_lower
    name_and_uri_lower=$(echo "${model_name} ${model_uri}" | tr '[:upper:]' '[:lower:]')
    case "$name_and_uri_lower" in
        *llama*) detected_parser="llama3_json" ;;
        *mistral*) detected_parser="mistral" ;;
        *qwen*|*granite*) detected_parser="hermes" ;;
        *) detected_parser="hermes" ;;  # most common in this toolkit's catalog, but just a guess
    esac
    echo ""
    echo -e "${CYAN}Tool-call parser (must match the model family -- hermes: Qwen, llama3_json: Llama, mistral: Mistral):${NC}"
    read -p "Tool parser [$detected_parser]: " tool_parser
    tool_parser=${tool_parser:-$detected_parser}

    print_step "Creating LLMInferenceService '$model_name' in namespace '$namespace'..."
    
    export MODEL_NAME="$model_name"
    export NAMESPACE="$namespace"
    export AUTH_ANNOTATION="$auth_annotation"
    export DISPLAY_NAME="$model_name"
    export MODEL_URI="$model_uri"
    export TOOL_PARSER="$tool_parser"
    export GPU_COUNT="$gpu_count"
    export MEMORY_LIMIT="$memory_limit"
    export MEMORY_REQUEST="8Gi"
    export CPU_LIMIT="4"
    export CPU_REQUEST="1"
    envsubst '${MODEL_NAME} ${NAMESPACE} ${AUTH_ANNOTATION} ${DISPLAY_NAME} ${MODEL_URI} ${TOOL_PARSER} ${GPU_COUNT} ${MEMORY_LIMIT} ${MEMORY_REQUEST} ${CPU_LIMIT} ${CPU_REQUEST}' \
        < "$_RHOAI_LIB_DIR/lib/manifests/templates/llminferenceservice.yaml.tmpl" | oc apply -f -
    unset MODEL_NAME NAMESPACE AUTH_ANNOTATION DISPLAY_NAME MODEL_URI TOOL_PARSER GPU_COUNT MEMORY_LIMIT MEMORY_REQUEST CPU_LIMIT CPU_REQUEST
    
    if [ $? -eq 0 ]; then
        print_success "LLMInferenceService created"
        echo ""
        print_info "Monitor deployment with:"
        echo "  oc get llmisvc -n $namespace"
        echo "  oc get pods -n $namespace"
        
        if [[ "$auth_annotation" == "true" ]]; then
            echo ""
            print_info "To get inference token:"
            echo "  TOKEN=\$(oc create token default -n $namespace)"
            echo "  curl -H \"Authorization: Bearer \$TOKEN\" <endpoint>/v1/models"
        fi
    else
        print_error "Failed to create LLMInferenceService"
    fi
}

################################################################################
# Guardrails Demo Deployment
################################################################################

# Deploy Guardrails Demo
# Deploys TrustyAI Guardrails Orchestrator with built-in PII detection
deploy_guardrails_demo() {
    print_header "Deploy Guardrails Demo [AI Safety]"
    
    echo "This will deploy TrustyAI Guardrails Orchestrator to protect your LLM"
    echo "with PII detection (email, SSN, credit card, phone numbers)."
    echo ""
    
    # Check if deploy script exists
    local script_path="$SCRIPT_DIR/../scripts/deploy-guardrails.sh"
    if [ ! -f "$script_path" ]; then
        script_path="./scripts/deploy-guardrails.sh"
    fi
    
    if [ -f "$script_path" ]; then
        bash "$script_path"
    else
        print_error "deploy-guardrails.sh not found"
        echo ""
        echo "Expected location: scripts/deploy-guardrails.sh"
        echo ""
        echo "Manual deployment:"
        echo "  1. Deploy a model: ./scripts/serve-model.sh s3 qwen3-8b Qwen/Qwen3-8B-Instruct"
        echo "  2. Deploy Guardrails manifests:"
        echo "     export MODEL_SERVICE_NAME=qwen3-8b-predictor"
        echo "     export ENABLE_AUTH=false"
        echo "     envsubst < lib/manifests/guardrails/orchestrator-config.yaml | oc apply -f -"
        echo "     oc apply -f lib/manifests/guardrails/gateway-config.yaml"
        echo "     envsubst < lib/manifests/guardrails/orchestrator-cr.yaml | oc apply -f -"
        return 1
    fi
}

################################################################################
# Dashboard Technology Preview Features (Interactive)
################################################################################

# Enable Technology Preview / Developer Preview dashboard features interactively.
# Shows current state and lets user pick which to enable.
enable_tp_features_interactive() {
    print_header "Enable Technology Preview Dashboard Features"

    if ! oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; then
        print_error "OdhDashboardConfig not found — RHOAI may not be installed"
        return 1
    fi

    # Define TP features: key|label|category
    local tp_features=(
        "automl|AutoML (automated model training)|ML Automation"
        "autorag|AutoRAG (automated RAG optimization)|ML Automation"
        "observabilityDashboard|MaaS Observability Dashboard|Observability"
        "guardrails|Guardrails (content filtering for deployments)|AI Safety"
        "connectionTest|Connection Test (verify credentials before saving)|Usability"
        "featureStoreAdmin|Feature Store Admin UI (create wizard)|Feature Store"
        "promptManagement|Prompt Management (MLflow prompt registry in Playground)|Gen AI Studio"
        "toolCalling|Tool Calling (filters/labels for model catalog)|Gen AI Studio"
        "externalModels|External Models (egress to external providers)|MaaS"
        "externalVectorStores|Vector Stores (AI asset endpoints)|Gen AI Studio"
        "genAiTracing|GenAI Tracing (request tracing)|Observability"
        "llmdTemplates|llm-d Templates (topology/routing config)|Model Serving"
        "llmGatewayField|LLM Gateway Field (gateway selection in deploy wizard)|Model Serving"
        "mcpRegistry|MCP Registry (Registry tab in MCP Servers)|MCP"
        "deploymentWizardYAMLViewer|Deployment Wizard YAML Viewer|Usability"
        "aiAssetCustomEndpoints|AI Asset Custom Endpoints|Gen AI Studio"
        "globalProjectPrompts|Global Project Prompts|Gen AI Studio"
    )

    # Read current state
    local current_config
    current_config=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
        -o jsonpath='{.spec.dashboardConfig}' 2>/dev/null)

    echo -e "${CYAN}Current Technology Preview feature status:${NC}"
    echo ""

    local idx=1
    local enabled_count=0
    local disabled_count=0
    for entry in "${tp_features[@]}"; do
        IFS='|' read -r key label category <<< "$entry"
        local value
        value=$(echo "$current_config" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$key','<not set>'))" 2>/dev/null || echo "<not set>")

        local status_icon
        if [ "$value" = "true" ] || [ "$value" = "True" ]; then
            status_icon="${GREEN}✓ ON ${NC}"
            enabled_count=$((enabled_count + 1))
        else
            status_icon="${YELLOW}○ OFF${NC}"
            disabled_count=$((disabled_count + 1))
        fi
        printf "  %s %2d) %-55s [%s]\n" "$(echo -e "$status_icon")" "$idx" "$label" "$category"
        ((idx++))
    done

    echo ""
    echo -e "  ${GREEN}$enabled_count enabled${NC}, ${YELLOW}$disabled_count disabled${NC} of ${#tp_features[@]} features"
    echo ""

    echo -e "${BLUE}Options:${NC}"
    echo -e "  ${YELLOW}a)${NC} Enable ALL Technology Preview features"
    echo -e "  ${YELLOW}s)${NC} Select specific features to enable"
    echo -e "  ${YELLOW}0)${NC} Cancel"
    echo ""

    read -p "Select option (a/s/0): " tp_option

    case "$tp_option" in
        a|A)
            echo ""
            print_step "Enabling all Technology Preview features..."

            local patch='{"spec":{"dashboardConfig":{'
            local first=true
            for entry in "${tp_features[@]}"; do
                IFS='|' read -r key label category <<< "$entry"
                if [ "$first" = true ]; then
                    patch+="\"$key\":true"
                    first=false
                else
                    patch+=",\"$key\":true"
                fi
            done
            patch+='}}}'

            if oc patch odhdashboardconfig odh-dashboard-config \
                -n redhat-ods-applications --type=merge -p "$patch" 2>/dev/null; then
                print_success "All ${#tp_features[@]} Technology Preview features enabled"
            else
                print_error "Failed to patch dashboard config"
                return 1
            fi
            ;;
        s|S)
            echo ""
            echo -e "${CYAN}Enter feature numbers to enable (comma-separated, e.g., 1,2,5):${NC}"
            read -p "Features: " selections

            if [ -z "$selections" ]; then
                print_info "No features selected"
                return 0
            fi

            local patch='{"spec":{"dashboardConfig":{'
            local first=true
            local selected_names=()

            IFS=',' read -ra nums <<< "$selections"
            for num in "${nums[@]}"; do
                num=$(echo "$num" | tr -d '[:space:]')
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#tp_features[@]} ]; then
                    local entry="${tp_features[$((num - 1))]}"
                    IFS='|' read -r key label category <<< "$entry"
                    if [ "$first" = true ]; then
                        patch+="\"$key\":true"
                        first=false
                    else
                        patch+=",\"$key\":true"
                    fi
                    selected_names+=("$label")
                fi
            done
            patch+='}}}'

            if [ ${#selected_names[@]} -eq 0 ]; then
                print_info "No valid features selected"
                return 0
            fi

            print_step "Enabling ${#selected_names[@]} features..."
            if oc patch odhdashboardconfig odh-dashboard-config \
                -n redhat-ods-applications --type=merge -p "$patch" 2>/dev/null; then
                print_success "Features enabled:"
                for name in "${selected_names[@]}"; do
                    echo "  ✓ $name"
                done
            else
                print_error "Failed to patch dashboard config"
                return 1
            fi
            ;;
        0)
            print_info "Cancelled"
            return 0
            ;;
        *)
            print_error "Invalid option"
            return 1
            ;;
    esac

    # Create prerequisites for features that need them
    local obs_now
    obs_now=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
        -o jsonpath='{.spec.dashboardConfig.observabilityDashboard}' 2>/dev/null)
    if [ "$obs_now" = "true" ]; then
        # Observability Dashboard needs the Thanos proxy secret to query metrics
        if ! oc get secret monitoring-thanos-proxy-secret -n redhat-ods-applications &>/dev/null; then
            print_step "Creating Thanos proxy secret (required for Observability Dashboard)..."
            local thanos_host
            thanos_host=$(oc get route thanos-querier -n openshift-monitoring -o jsonpath='{.spec.host}' 2>/dev/null)
            local thanos_token
            thanos_token=$(oc create token prometheus-k8s -n openshift-monitoring --duration=87600h 2>/dev/null)
            if [ -n "$thanos_token" ] && [ -n "$thanos_host" ]; then
                oc create secret generic monitoring-thanos-proxy-secret \
                    --from-literal=token="$thanos_token" \
                    --from-literal=host="$thanos_host" \
                    -n redhat-ods-applications 2>/dev/null && \
                    print_success "Thanos proxy secret created" || \
                    print_warning "Could not create Thanos proxy secret"
            fi
        fi
    fi

    # Restart dashboard pods so they pick up config changes immediately
    print_step "Restarting dashboard pods to apply changes..."
    oc rollout restart deployment/rhods-dashboard -n redhat-ods-applications &>/dev/null
    oc rollout status deployment/rhods-dashboard -n redhat-ods-applications --timeout=90s &>/dev/null && \
        print_success "Dashboard pods restarted" || \
        print_warning "Dashboard rollout timed out — pods may still be restarting"

    echo ""
    print_info "Refresh the RHOAI dashboard to see the new features"
    local dashboard_url
    dashboard_url=$(get_dashboard_url 2>/dev/null)
    [ -n "$dashboard_url" ] && echo "  $dashboard_url"
}

################################################################################
# MaaS Demo
################################################################################

# Run MaaS Interactive Demo
# Launches the CLI or Web demo for Model as a Service
run_maas_demo() {
    print_header "MaaS Demo [Interactive]"
    
    echo "Model as a Service (MaaS) Demo Options:"
    echo ""
    echo "1) CLI Demo (Terminal)"
    echo "   Interactive menu for chatting, comparing models"
    echo ""
    echo "2) Web Demo (Streamlit)"
    echo "   Visual interface for presentations"
    echo ""
    echo "3) Quick API Test"
    echo "   Test MaaS API with existing token"
    echo ""
    
    read -p "Select option (1-3): " demo_option
    
    case $demo_option in
        1)
            # CLI Demo
            local script_path="$SCRIPT_DIR/../demo/maas-demo/demo-maas.sh"
            if [ ! -f "$script_path" ]; then
                script_path="./demo/maas-demo/demo-maas.sh"
            fi
            
            if [ -f "$script_path" ]; then
                bash "$script_path"
            else
                print_error "demo-maas.sh not found"
                echo "Expected location: demo/maas-demo/demo-maas.sh"
            fi
            ;;
        2)
            # Web Demo
            local app_path="$SCRIPT_DIR/../demo/maas-demo/app.py"
            if [ ! -f "$app_path" ]; then
                app_path="./demo/maas-demo/app.py"
            fi
            
            if [ -f "$app_path" ]; then
                echo ""
                print_step "Starting Streamlit web demo..."
                echo ""
                echo "Requirements: pip install streamlit requests"
                echo ""
                read -p "Start web demo? (y/n): " start_web
                if [[ "$start_web" =~ ^[Yy]$ ]]; then
                    cd "$(dirname "$app_path")"
                    streamlit run app.py
                fi
            else
                print_error "app.py not found"
                echo "Expected location: demo/maas-demo/app.py"
            fi
            ;;
        3)
            # Quick API Test
            local test_path="$SCRIPT_DIR/../demo/test-maas-api.sh"
            if [ ! -f "$test_path" ]; then
                test_path="./demo/test-maas-api.sh"
            fi
            
            if [ -f "$test_path" ]; then
                bash "$test_path"
            else
                print_error "test-maas-api.sh not found"
                echo "Expected location: demo/test-maas-api.sh"
            fi
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

