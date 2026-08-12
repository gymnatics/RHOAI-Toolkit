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
    
    cat <<EOF | oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge --patch-file=/dev/stdin
spec:
  dashboardConfig:
    genAiStudio: true
    modelAsService: true
    disableModelRegistry: false
    disableModelCatalog: false
    disableKServeMetrics: false
    disableLMEval: false
    disableKueue: false
    mcpCatalog: true
EOF
    
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
    
    print_step "Creating LLMInferenceService '$model_name' in namespace '$namespace'..."
    
    export MODEL_NAME="$model_name"
    export NAMESPACE="$namespace"
    export AUTH_ANNOTATION="$auth_annotation"
    export MODEL_URI="$model_uri"
    export GPU_COUNT="$gpu_count"
    export MEMORY_LIMIT="$memory_limit"
    envsubst '${MODEL_NAME} ${NAMESPACE} ${AUTH_ANNOTATION} ${MODEL_URI} ${GPU_COUNT} ${MEMORY_LIMIT}' \
        < "$_RHOAI_LIB_DIR/lib/manifests/templates/llminferenceservice.yaml.tmpl" | oc apply -f -
    unset MODEL_NAME NAMESPACE AUTH_ANNOTATION MODEL_URI GPU_COUNT MEMORY_LIMIT
    
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
# Feature Store (Feast) Functions
################################################################################

# Check if Feast operator is enabled
check_feast_operator() {
    local feast_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.feastoperator.managementState}' 2>/dev/null || echo "Unknown")
    
    if [[ "$feast_state" == "Managed" ]]; then
        return 0
    else
        return 1
    fi
}

# Enable Feast operator in DSC
enable_feast_operator() {
    print_header "Enabling Feast Operator"
    
    if check_feast_operator; then
        print_success "Feast operator already enabled"
        return 0
    fi
    
    print_step "Patching DataScienceCluster to enable feastoperator..."
    oc patch datasciencecluster default-dsc --type='merge' \
        -p '{"spec":{"components":{"feastoperator":{"managementState":"Managed"}}}}'
    
    if [ $? -eq 0 ]; then
        print_success "Feast operator enabled"
        
        # Wait for Feast operator to be ready
        print_step "Waiting for Feast operator to be ready..."
        local timeout=120
        local elapsed=0
        until oc get crd featurestores.feast.dev &>/dev/null; do
            if [ $elapsed -ge $timeout ]; then
                print_warning "Timeout waiting for Feast CRD (continuing anyway)"
                break
            fi
            echo "Waiting for FeatureStore CRD... (${elapsed}s elapsed)"
            sleep 10
            elapsed=$((elapsed + 10))
        done
        
        print_success "Feast operator is ready"
    else
        print_error "Failed to enable Feast operator"
        return 1
    fi
}

# Deploy Banking Demo - Version-Aware
# Source: https://github.com/RHRolun/banking-feature-store
deploy_banking_demo() {
    local namespace="${1:-}"
    
    print_header "Deploy Banking Demo"
    
    # Detect RHOAI version
    local rhoai_33_plus=false
    if type detect_rhoai_version &>/dev/null; then
        detect_rhoai_version
        echo ""
        if is_rhoai_33_or_higher 2>/dev/null; then
            rhoai_33_plus=true
            echo -e "${GREEN}RHOAI 3.3+ detected${NC} - will apply enhanced dashboard visibility settings"
        else
            echo -e "${CYAN}RHOAI ${RHOAI_VERSION:-<3.3} detected${NC}"
        fi
    else
        # Fallback version detection
        local csv_version=$(oc get csv -n redhat-ods-operator -o jsonpath='{.items[?(@.spec.displayName=="Red Hat OpenShift AI")].spec.version}' 2>/dev/null | head -1)
        if [ -n "$csv_version" ]; then
            echo -e "${CYAN}RHOAI version: $csv_version${NC}"
            local major=$(echo "$csv_version" | cut -d. -f1)
            local minor=$(echo "$csv_version" | cut -d. -f2)
            if [ "$major" -gt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -ge 3 ]); then
                rhoai_33_plus=true
                echo -e "${GREEN}RHOAI 3.3+ detected${NC} - will apply enhanced dashboard visibility settings"
            fi
        fi
    fi
    echo ""
    
    # Check if Feast operator is enabled
    if ! check_feast_operator; then
        print_warning "Feast operator is not enabled"
        read -p "Enable Feast operator now? (Y/n): " enable_feast
        enable_feast=${enable_feast:-Y}
        
        if [[ "$enable_feast" =~ ^[Yy]$ ]]; then
            enable_feast_operator
        else
            print_error "Feast operator must be enabled first"
            return 1
        fi
    else
        print_success "Feast operator is enabled"
    fi
    
    # Get namespace
    if [ -z "$namespace" ]; then
        local current_ns=$(oc project -q 2>/dev/null || echo "banking")
        read -p "Enter namespace for banking demo [$current_ns]: " namespace
        namespace=${namespace:-$current_ns}
    fi
    
    # Check if namespace exists
    if ! oc get namespace "$namespace" &>/dev/null; then
        print_step "Creating namespace $namespace..."
        oc new-project "$namespace" 2>/dev/null || oc create namespace "$namespace"
    fi
    
    # Label namespace for RHOAI dashboard
    print_step "Labeling namespace for RHOAI dashboard..."
    oc label namespace "$namespace" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true
    
    # Banking demo configuration
    local git_url="https://github.com/RHRolun/banking-feature-store"
    local git_ref="rbac"
    local feast_project="banking"
    
    echo ""
    echo -e "${CYAN}Banking Demo Repository:${NC} $git_url"
    echo -e "${CYAN}Branch:${NC} $git_ref"
    echo ""
    
    # RBAC warning
    print_warning "For RBAC to work correctly, you should fork the repo and update permissions.py"
    echo -e "  In feature_repo/permissions.py, change line 47 to:"
    echo -e "  ${CYAN}prod_namespaces = [\"$namespace\"]${NC}"
    echo ""
    read -p "Enter your forked repo URL (or press Enter to use original): " custom_url
    if [ -n "$custom_url" ]; then
        git_url="$custom_url"
    fi
    
    # Check if FeatureStore already exists
    if oc get featurestore "$feast_project" -n "$namespace" &>/dev/null; then
        print_warning "FeatureStore 'banking' already exists in $namespace"
        read -p "Delete and recreate? (y/N): " recreate
        if [[ "$recreate" =~ ^[Yy]$ ]]; then
            print_step "Deleting existing FeatureStore..."
            oc delete featurestore "$feast_project" -n "$namespace"
            sleep 5
        else
            print_info "Keeping existing FeatureStore"
            return 0
        fi
    fi
    
    # Create FeatureStore with version-appropriate configuration
    print_step "Creating FeatureStore 'banking' in namespace '$namespace'..."
    
    # Two-step approach (from CAI guide): create with restAPI: false first,
    # wait for pod, then flip to true. Avoids race condition during startup.
    export FEAST_LABELS="    feature-store-ui: enabled"
    if [ "$rhoai_33_plus" = true ]; then
        export FEAST_LABELS="    feature-store-ui: enabled
    opendatahub.io/dashboard: \"true\""
    fi
    export FEAST_PROJECT="$feast_project"
    export GIT_REF="$git_ref"
    export GIT_URL="$git_url"
    envsubst '${FEAST_LABELS} ${FEAST_PROJECT} ${GIT_REF} ${GIT_URL}' \
        < "$_RHOAI_LIB_DIR/lib/manifests/feast/featurestore-restapi-false.yaml" | oc apply -n "$namespace" -f -
    unset FEAST_LABELS FEAST_PROJECT GIT_REF GIT_URL
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create FeatureStore"
        return 1
    fi
    
    print_success "FeatureStore CR created"
    
    # Wait for Feast pod to be ready
    print_step "Waiting for Feast pod to be ready..."
    local timeout=180
    local elapsed=0
    local feast_pod=""
    
    while [ $elapsed -lt $timeout ]; do
        feast_pod=$(oc get pods -n "$namespace" -o name 2>/dev/null | grep "feast-$feast_project" | head -1 | sed 's|pod/||')
        if [ -n "$feast_pod" ]; then
            local pod_status=$(oc get pod "$feast_pod" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
            if [ "$pod_status" = "Running" ]; then
                # Check if containers are ready
                local ready=$(oc get pod "$feast_pod" -n "$namespace" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
                if [ "$ready" = "true" ]; then
                    break
                fi
            fi
        fi
        echo "Waiting for Feast pod... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    if [ -z "$feast_pod" ]; then
        print_warning "Timeout waiting for Feast pod"
        echo ""
        print_info "You can manually run these commands later:"
        echo "  oc exec -n $namespace \$(oc get pods -n $namespace -o name | grep feast) -c registry -- feast apply"
        return 1
    fi
    
    print_success "Feast pod is running: $feast_pod"

    # Step 2: Now enable restAPI (two-step pattern from CAI guide)
    print_step "Enabling registry REST API (step 2 of 2)..."
    oc patch featurestore "$feast_project" -n "$namespace" --type=merge \
        -p '{"spec":{"services":{"registry":{"local":{"server":{"restAPI":true}}}}}}'
    print_success "Registry REST API enabled"
    sleep 10
    
    # Run feast apply
    echo ""
    read -p "Run 'feast apply' to register features? (Y/n): " run_apply
    run_apply=${run_apply:-Y}
    
    if [[ "$run_apply" =~ ^[Yy]$ ]]; then
        print_step "Running feast apply (this may take a minute)..."
        if oc exec -n "$namespace" "$feast_pod" -c registry -- feast apply; then
            print_success "Features registered successfully"
            
            # Run feast materialize
            echo ""
            read -p "Run 'feast materialize' to populate online store? (Y/n): " run_materialize
            run_materialize=${run_materialize:-Y}
            
            if [[ "$run_materialize" =~ ^[Yy]$ ]]; then
                print_step "Running feast materialize..."
                if oc exec -n "$namespace" "$feast_pod" -c registry -- bash -c "feast materialize 2025-01-01T00:00:00 \$(date -u +'%Y-%m-%dT%H:%M:%S')"; then
                    print_success "Features materialized successfully"
                else
                    print_warning "Materialization had issues (features may still work)"
                fi
            fi
        else
            print_warning "feast apply had issues - you may need to run it manually"
        fi
    fi
    
    # Verify services
    echo ""
    print_step "Verifying Feature Store services..."
    sleep 5
    
    local registry_svc=$(oc get svc -n "$namespace" -o name 2>/dev/null | grep "feast-$feast_project-registry$" | head -1)
    local rest_svc=$(oc get svc -n "$namespace" -o name 2>/dev/null | grep "feast-$feast_project-registry-rest" | head -1)
    
    if [ -n "$registry_svc" ]; then
        print_success "Registry service exists"
    else
        print_warning "Registry service not found"
    fi
    
    if [ -n "$rest_svc" ]; then
        print_success "Registry REST service exists (required for dashboard)"
    else
        print_warning "Registry REST service not found yet - may take a few minutes"
    fi
    
    # Show final status
    echo ""
    print_header "Banking Demo Deployment Complete"
    echo ""
    oc get featurestore -n "$namespace"
    echo ""
    echo -e "${YELLOW}Services:${NC}"
    oc get svc -n "$namespace" 2>/dev/null | grep feast || echo "  (waiting for services...)"
    echo ""
    
    # Version-specific instructions
    if [ "$rhoai_33_plus" = true ]; then
        echo -e "${CYAN}RHOAI 3.3+ Dashboard Access:${NC}"
        echo "  1. Wait 2-5 minutes for dashboard to discover the Feature Store"
        echo "  2. Go to: Projects → $namespace → Feature Store Integration"
        echo "  3. Select 'feast-banking-client' from the dropdown"
        echo ""
        echo "If Feature Store doesn't appear after 5 minutes:"
        echo "  Run: ./rhoai-toolkit.sh → Feature Store → Diagnose Feature Store"
    else
        echo -e "${CYAN}Dashboard Access:${NC}"
        echo "  Go to: Projects → $namespace → Feature Store Integration"
        echo "  Select 'feast-banking-client' from the dropdown"
    fi
    echo ""
    
    # Create workbench + clone repo
    local _wb_lib="$_RHOAI_LIB_DIR/lib/functions/workbench.sh"
    if [ -f "$_wb_lib" ]; then
        source "$_wb_lib"
        ensure_workbench "$namespace" "feature-store"
    fi

    # Inject notebook environment
    local _nb_env_lib="$_RHOAI_LIB_DIR/lib/functions/notebook-env.sh"
    if [ -f "$_nb_env_lib" ]; then
        source "$_nb_env_lib"
        inject_notebook_env "$namespace" \
            "FEAST_PROJECT=$feast_project" \
            "FEAST_NAME=$feast_project"
    fi

    # Demo usage instructions
    echo -e "${CYAN}Demo Usage:${NC}"
    echo "  1. Open the 'feature-store' workbench in the RHOAI dashboard"
    echo "  2. Copy Feature Store client config from dashboard"
    echo "  3. Open RHOAI-Toolkit/demo/feast-demo/notebooks/"
    echo "     feast-online-retrieval.ipynb  -- query features in real time"
    echo "     feast-banking-complex.ipynb   -- advanced feature engineering"
    echo ""
    echo "  Original repo: $git_url"
    echo ""
}

# Setup Feature Store in a namespace (generic/custom)
setup_feature_store() {
    local namespace="${1:-}"
    local git_url="${2:-}"
    local git_ref="${3:-rbac}"
    local feast_project="${4:-banking}"
    
    print_header "Setting up Feature Store (Feast)"
    
    # Detect RHOAI version for version-specific configuration
    if type detect_rhoai_version &>/dev/null; then
        detect_rhoai_version
        echo ""
        if is_rhoai_33_or_higher 2>/dev/null; then
            print_info "RHOAI 3.3+ detected - will apply enhanced dashboard visibility settings"
        else
            print_info "RHOAI ${RHOAI_VERSION:-<3.3} detected"
        fi
    fi
    
    # Check if Feast operator is enabled
    if ! check_feast_operator; then
        print_warning "Feast operator is not enabled"
        read -p "Enable Feast operator now? (Y/n): " enable_feast
        enable_feast=${enable_feast:-Y}
        
        if [[ "$enable_feast" =~ ^[Yy]$ ]]; then
            enable_feast_operator
        else
            print_error "Feast operator must be enabled first"
            return 1
        fi
    fi
    
    # Get namespace if not provided
    if [ -z "$namespace" ]; then
        local current_ns=$(oc project -q 2>/dev/null || echo "default")
        read -p "Enter namespace for Feature Store [$current_ns]: " namespace
        namespace=${namespace:-$current_ns}
    fi
    
    # Check if namespace exists
    if ! oc get namespace "$namespace" &>/dev/null; then
        print_step "Creating namespace $namespace..."
        oc new-project "$namespace" || oc create namespace "$namespace"
    fi
    
    # Label namespace for RHOAI dashboard (required for all versions, critical for 3.3+)
    print_step "Labeling namespace for RHOAI dashboard..."
    oc label namespace "$namespace" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true
    
    # Get git URL if not provided
    if [ -z "$git_url" ]; then
        echo ""
        echo -e "${CYAN}Feature Store requires a Git repository with feature definitions.${NC}"
        echo ""
        echo -e "${YELLOW}Options:${NC}"
        echo "  1) Use banking demo (https://github.com/RHRolun/banking-feature-store)"
        echo "  2) Enter custom Git URL"
        echo ""
        read -p "Choose option [1]: " git_option
        git_option=${git_option:-1}
        
        if [[ "$git_option" == "1" ]]; then
            git_url="https://github.com/RHRolun/banking-feature-store"
            feast_project="banking"
            
            echo ""
            print_warning "For RBAC to work correctly, you should fork this repo and update permissions.py"
            echo -e "${CYAN}In feature_repo/permissions.py, change line 47 to: prod_namespaces = [\"$namespace\"]${NC}"
            echo ""
            read -p "Enter your forked repo URL (or press Enter to use original): " custom_url
            if [ -n "$custom_url" ]; then
                git_url="$custom_url"
            fi
        else
            read -p "Enter Git repository URL: " git_url
            read -p "Enter Feast project name [banking]: " feast_project
            feast_project=${feast_project:-banking}
        fi
    fi
    
    # Get git ref
    read -p "Enter Git branch/ref [$git_ref]: " input_ref
    git_ref=${input_ref:-$git_ref}
    
    # Check if FeatureStore already exists
    if oc get featurestore "$feast_project" -n "$namespace" &>/dev/null; then
        print_warning "FeatureStore '$feast_project' already exists in $namespace"
        read -p "Delete and recreate? (y/N): " recreate
        if [[ "$recreate" =~ ^[Yy]$ ]]; then
            oc delete featurestore "$feast_project" -n "$namespace"
            sleep 5
        else
            print_info "Keeping existing FeatureStore"
            return 0
        fi
    fi
    
    # Create FeatureStore with version-appropriate configuration
    print_step "Creating FeatureStore '$feast_project' in namespace '$namespace'..."
    
    # Determine labels based on RHOAI version
    export EXTRA_LABELS=""
    if type is_rhoai_33_or_higher &>/dev/null && is_rhoai_33_or_higher; then
        # RHOAI 3.3+ requires additional labels for dashboard visibility
        export EXTRA_LABELS='    opendatahub.io/dashboard: "true"'
        print_info "Adding RHOAI 3.3+ specific labels for dashboard visibility"
    fi
    export FEAST_PROJECT="$feast_project"
    export GIT_REF="$git_ref"
    export GIT_URL="$git_url"
    envsubst '${EXTRA_LABELS} ${FEAST_PROJECT} ${GIT_REF} ${GIT_URL}' \
        < "$_RHOAI_LIB_DIR/lib/manifests/feast/featurestore-restapi-true.yaml" | oc apply -n "$namespace" -f -
    unset EXTRA_LABELS FEAST_PROJECT GIT_REF GIT_URL
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create FeatureStore"
        return 1
    fi
    
    print_success "FeatureStore CR created"
    
    # Wait for Feast pod to be ready
    print_step "Waiting for Feast pod to be ready..."
    local timeout=120
    local elapsed=0
    until oc get pods -n "$namespace" -l "app=feast-$feast_project" -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Timeout waiting for Feast pod"
            break
        fi
        echo "Waiting for Feast pod... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    # Get pod name
    local feast_pod=$(oc get pods -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep "feast-$feast_project" || oc get pods -n "$namespace" -o name 2>/dev/null | grep "feast-$feast_project" | head -1 | sed 's|pod/||')
    
    if [ -z "$feast_pod" ]; then
        feast_pod=$(oc get pods -n "$namespace" -o name 2>/dev/null | grep feast | head -1 | sed 's|pod/||')
    fi
    
    if [ -n "$feast_pod" ]; then
        print_success "Feast pod is running: $feast_pod"
        
        # Run feast apply
        echo ""
        read -p "Run 'feast apply' to register features? (Y/n): " run_apply
        run_apply=${run_apply:-Y}
        
        if [[ "$run_apply" =~ ^[Yy]$ ]]; then
            print_step "Running feast apply..."
            oc exec -n "$namespace" "$feast_pod" -c registry -- feast apply
            
            if [ $? -eq 0 ]; then
                print_success "Features registered successfully"
                
                # Run feast materialize
                read -p "Run 'feast materialize' to populate online store? (Y/n): " run_materialize
                run_materialize=${run_materialize:-Y}
                
                if [[ "$run_materialize" =~ ^[Yy]$ ]]; then
                    print_step "Running feast materialize..."
                    oc exec -n "$namespace" "$feast_pod" -c registry -- bash -c "feast materialize 2025-01-01T00:00:00 \$(date -u +'%Y-%m-%dT%H:%M:%S')"
                    
                    if [ $? -eq 0 ]; then
                        print_success "Features materialized successfully"
                    else
                        print_warning "Materialization had issues (features may still work)"
                    fi
                fi
            else
                print_warning "feast apply had issues"
            fi
        fi
    else
        print_warning "Could not find Feast pod"
        echo ""
        print_info "You can manually run these commands later:"
        echo "  oc exec -n $namespace <feast-pod> -c registry -- feast apply"
        echo "  oc exec -n $namespace <feast-pod> -c registry -- feast materialize 2025-01-01T00:00:00 \$(date -u +'%Y-%m-%dT%H:%M:%S')"
    fi
    
    # Verify services exist (important for 3.3+)
    echo ""
    print_step "Verifying Feature Store services..."
    local registry_rest_svc=$(oc get svc -n "$namespace" -o name 2>/dev/null | grep "feast-$feast_project-registry-rest" | head -1)
    if [ -n "$registry_rest_svc" ]; then
        print_success "Registry REST service exists (required for dashboard)"
    else
        print_warning "Registry REST service not found yet - may take a few minutes"
        if type is_rhoai_33_or_higher &>/dev/null && is_rhoai_33_or_higher; then
            echo "  This service is required for RHOAI 3.3+ dashboard visibility"
        fi
    fi
    
    # Show status
    echo ""
    print_header "Feature Store Setup Complete"
    echo ""
    oc get featurestore -n "$namespace"
    echo ""
    echo -e "${YELLOW}Services:${NC}"
    oc get svc -n "$namespace" 2>/dev/null | grep feast || echo "  (waiting for services...)"
    echo ""
    
    # Version-specific instructions
    if type is_rhoai_33_or_higher &>/dev/null && is_rhoai_33_or_higher; then
        print_info "RHOAI 3.3+ Dashboard Access:"
        print_info "  1. Wait 2-5 minutes for dashboard to discover the Feature Store"
        print_info "  2. Go to: Projects → $namespace → Feature Store Integration"
        print_info "  3. Select 'feast-$feast_project-client' from the dropdown"
        echo ""
        print_info "If Feature Store doesn't appear, run:"
        echo "  ./rhoai-toolkit.sh → Feature Store → Diagnose Feature Store"
    else
        print_info "Access Feature Store in RHOAI Dashboard:"
        print_info "  Projects → $namespace → Feature store integration"
    fi
    echo ""
}

# Show Feature Store status
show_feast_status() {
    print_header "Feature Store Status"
    
    # Detect RHOAI version if function is available
    if type detect_rhoai_version &>/dev/null; then
        detect_rhoai_version
        echo ""
        echo -e "RHOAI Version: ${CYAN}$RHOAI_VERSION${NC}"
    fi
    
    # Check if Feast operator is enabled
    local feast_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.feastoperator.managementState}' 2>/dev/null || echo "Unknown")
    echo ""
    echo -e "Feast Operator: ${CYAN}$feast_state${NC}"
    echo ""
    
    # List all FeatureStores with additional info
    echo -e "${YELLOW}FeatureStores across all namespaces:${NC}"
    local featurestores=$(oc get featurestore -A -o json 2>/dev/null)
    
    if [ -n "$featurestores" ] && echo "$featurestores" | jq -e '.items | length > 0' &>/dev/null; then
        echo "$featurestores" | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name) - Labels: \(.metadata.labels // "none")"'
        echo ""
        
        # Check for potential issues
        echo -e "${YELLOW}Checking for potential issues:${NC}"
        echo "$featurestores" | jq -r '.items[] | select(.metadata.labels["feature-store-ui"] != "enabled") | "  ⚠ \(.metadata.namespace)/\(.metadata.name): Missing feature-store-ui label"' 2>/dev/null
        echo "$featurestores" | jq -r '.items[] | select(.spec.services.registry.local.server.restAPI != true) | "  ⚠ \(.metadata.namespace)/\(.metadata.name): restAPI not enabled"' 2>/dev/null
        
        local issues_found=$(echo "$featurestores" | jq '[.items[] | select(.metadata.labels["feature-store-ui"] != "enabled" or .spec.services.registry.local.server.restAPI != true)] | length')
        if [ "$issues_found" = "0" ]; then
            echo -e "  ${GREEN}✓ No configuration issues detected${NC}"
        else
            echo ""
            echo -e "${CYAN}Run 'Diagnose Feature Store' for detailed analysis and fixes${NC}"
        fi
    else
        echo "No FeatureStores found"
    fi
    echo ""
    
    # Show Feast pods
    echo -e "${YELLOW}Feast pods:${NC}"
    oc get pods -A -l app.kubernetes.io/managed-by=feast-operator 2>/dev/null || \
    oc get pods -A 2>/dev/null | grep -i feast || echo "No Feast pods found"
    echo ""
}

# Diagnose Feature Store visibility issues (version-aware)
diagnose_feature_store_interactive() {
    print_header "Diagnose Feature Store"
    
    # Detect RHOAI version
    if type detect_rhoai_version &>/dev/null; then
        detect_rhoai_version
        echo ""
        echo -e "RHOAI Version: ${CYAN}$RHOAI_VERSION${NC}"
        
        if is_rhoai_33_or_higher; then
            echo -e "${YELLOW}Note: RHOAI 3.3+ has stricter requirements for Feature Store dashboard visibility${NC}"
            echo ""
        fi
    fi
    
    # List existing FeatureStores
    echo ""
    echo -e "${YELLOW}Existing FeatureStores:${NC}"
    oc get featurestore -A 2>/dev/null || echo "No FeatureStores found"
    echo ""
    
    read -p "Enter namespace: " namespace
    read -p "Enter FeatureStore name: " name
    
    if [ -z "$namespace" ] || [ -z "$name" ]; then
        print_error "Namespace and name are required"
        return 1
    fi
    
    # Use the diagnose function from rhoai-version.sh if available
    if type diagnose_featurestore &>/dev/null; then
        diagnose_featurestore "$namespace" "$name"
    else
        # Fallback to basic checks
        echo ""
        echo -e "${CYAN}Checking FeatureStore '$name' in namespace '$namespace'...${NC}"
        echo ""
        
        if ! oc get featurestore "$name" -n "$namespace" &>/dev/null; then
            print_error "FeatureStore '$name' not found in namespace '$namespace'"
            return 1
        fi
        
        # Check labels
        local labels=$(oc get featurestore "$name" -n "$namespace" -o jsonpath='{.metadata.labels}' 2>/dev/null)
        if echo "$labels" | grep -q "feature-store-ui"; then
            echo -e "${GREEN}✓ feature-store-ui label present${NC}"
        else
            echo -e "${RED}✗ feature-store-ui label missing${NC}"
            echo "  Fix: oc label featurestore $name -n $namespace feature-store-ui=enabled"
        fi
        
        # Check restAPI
        local rest_api=$(oc get featurestore "$name" -n "$namespace" -o jsonpath='{.spec.services.registry.local.server.restAPI}' 2>/dev/null)
        if [ "$rest_api" = "true" ]; then
            echo -e "${GREEN}✓ Registry restAPI enabled${NC}"
        else
            echo -e "${RED}✗ Registry restAPI not enabled${NC}"
            echo "  This is required for dashboard visibility"
        fi
        
        # Check pod status
        local feast_pod=$(oc get pods -n "$namespace" -o name 2>/dev/null | grep "feast-$name" | head -1)
        if [ -n "$feast_pod" ]; then
            local pod_status=$(oc get "$feast_pod" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
            echo -e "Feast pod status: ${CYAN}$pod_status${NC}"
        else
            echo -e "${YELLOW}⚠ No Feast pod found${NC}"
        fi
        
        # Check services
        echo ""
        echo -e "${YELLOW}Services:${NC}"
        oc get svc -n "$namespace" 2>/dev/null | grep feast || echo "No Feast services found"
    fi
}

# Delete Feature Store
delete_feature_store() {
    local namespace="${1:-}"
    local feast_project="${2:-}"
    
    print_header "Delete Feature Store"
    
    # List existing FeatureStores
    echo ""
    echo -e "${YELLOW}Existing FeatureStores:${NC}"
    oc get featurestore -A 2>/dev/null || echo "No FeatureStores found"
    echo ""
    
    if [ -z "$namespace" ]; then
        read -p "Enter namespace: " namespace
    fi
    
    if [ -z "$feast_project" ]; then
        read -p "Enter FeatureStore name: " feast_project
    fi
    
    if oc get featurestore "$feast_project" -n "$namespace" &>/dev/null; then
        read -p "Delete FeatureStore '$feast_project' in namespace '$namespace'? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            oc delete featurestore "$feast_project" -n "$namespace"
            print_success "FeatureStore deleted"
        else
            print_info "Cancelled"
        fi
    else
        print_warning "FeatureStore '$feast_project' not found in namespace '$namespace'"
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
# MaaS 3.4 Management Functions
# RHOAI 3.4 uses subscription-based MaaS (replaces 3.3 tier-based model)
# New CRDs: MaaSSubscription, MaaSAuthPolicy, MaaSModelRef, Tenant, ExternalModel
################################################################################

# Configure MaaS TLS using OpenShift service-ca (RHOAI 3.4 method)
# This replaces the cert-manager Certificate approach used in 3.3
configure_maas_tls_34() {
    print_header "Configuring MaaS TLS (RHOAI 3.4 service-ca method)"

    print_step "Step 1: Annotating Authorino service for service-ca cert generation..."
    oc annotate service authorino-authorino-authorization \
        -n kuadrant-system \
        service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
        --overwrite

    print_step "Step 2: Waiting for authorino-server-cert secret..."
    local elapsed=0
    while [ $elapsed -lt 60 ]; do
        if oc get secret authorino-server-cert -n kuadrant-system &>/dev/null; then
            print_success "authorino-server-cert secret generated"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    print_step "Step 3: Patching Authorino CR for TLS listener..."
    oc patch authorino authorino -n kuadrant-system --type=merge --patch '{
      "spec": {
        "listener": {
          "tls": {
            "enabled": true,
            "certSecretRef": {
              "name": "authorino-server-cert"
            }
          }
        }
      }
    }'

    print_step "Step 4: Setting TLS cert validation env vars on Authorino deployment..."
    oc -n kuadrant-system set env deployment/authorino \
        SSL_CERT_FILE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt \
        REQUESTS_CA_BUNDLE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt

    print_step "Step 5: Annotating maas-default-gateway for TLS bootstrap..."
    oc annotate gateway maas-default-gateway \
        -n openshift-ingress \
        security.opendatahub.io/authorino-tls-bootstrap="true" \
        --overwrite

    print_success "MaaS TLS configuration complete (service-ca method)"
}

# Verify the full MaaS 3.4 deployment
verify_maas_34() {
    print_header "Verifying MaaS 3.4 Deployment"

    local all_ok=true

    # PostgreSQL DB secret
    print_step "Checking maas-db-config secret..."
    if oc get secret maas-db-config -n redhat-ods-applications &>/dev/null; then
        local has_url=$(oc get secret maas-db-config -n redhat-ods-applications \
            -o jsonpath='{.data.DB_CONNECTION_URL}' 2>/dev/null)
        if [ -n "$has_url" ]; then
            print_success "  maas-db-config secret with DB_CONNECTION_URL"
        else
            print_warning "  maas-db-config exists but missing DB_CONNECTION_URL key"
            all_ok=false
        fi
    else
        print_warning "  maas-db-config secret not found (MaaS Tenant will be Degraded)"
        all_ok=false
    fi

    # CRDs
    print_step "Checking MaaS CRDs..."
    local expected_crds=("maassubscriptions.maas.opendatahub.io" "maasauthpolicies.maas.opendatahub.io" "maasmodelrefs.maas.opendatahub.io" "externalmodels.maas.opendatahub.io" "tenants.maas.opendatahub.io")
    for crd in "${expected_crds[@]}"; do
        if oc get crd "$crd" &>/dev/null; then
            print_success "  CRD: $crd"
        else
            print_warning "  CRD missing: $crd"
            all_ok=false
        fi
    done

    # User Workload Monitoring
    print_step "Checking User Workload Monitoring..."
    local uwm=$(oc get configmap cluster-monitoring-config -n openshift-monitoring \
        -o jsonpath='{.data.config\.yaml}' 2>/dev/null | grep -c "enableUserWorkload: true" || echo "0")
    if [ "$uwm" -gt 0 ]; then
        print_success "  User Workload Monitoring enabled"
    else
        print_warning "  User Workload Monitoring not enabled (MaaS Tenant may show Degraded)"
        all_ok=false
    fi

    # Tenant
    print_step "Checking Tenant CR..."
    local tenant_ready=$(oc get tenant default-tenant -n models-as-a-service \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$tenant_ready" = "True" ]; then
        print_success "  Tenant default-tenant is Ready"
    else
        local tenant_msg=$(oc get tenant default-tenant -n models-as-a-service \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
        print_warning "  Tenant status: ${tenant_ready:-not found} - ${tenant_msg:-no message}"
        all_ok=false
    fi

    # Gateway annotations
    print_step "Checking maas-default-gateway annotations..."
    local gw_managed=$(oc get gateway maas-default-gateway -n openshift-ingress \
        -o jsonpath='{.metadata.annotations.opendatahub\.io/managed}' 2>/dev/null)
    local gw_tls=$(oc get gateway maas-default-gateway -n openshift-ingress \
        -o jsonpath='{.metadata.annotations.security\.opendatahub\.io/authorino-tls-bootstrap}' 2>/dev/null)
    if [ "$gw_managed" = "false" ] && [ "$gw_tls" = "true" ]; then
        print_success "  Gateway annotations correct"
    else
        print_warning "  Gateway annotations incorrect or missing"
        all_ok=false
    fi

    # Authorino TLS
    print_step "Checking Authorino TLS..."
    local auth_tls=$(oc get authorino authorino -n kuadrant-system \
        -o jsonpath='{.spec.listener.tls.enabled}' 2>/dev/null)
    if [ "$auth_tls" = "true" ]; then
        print_success "  Authorino TLS listener enabled"
    else
        print_warning "  Authorino TLS listener not enabled"
        all_ok=false
    fi

    local auth_cert=$(oc get secret authorino-server-cert -n kuadrant-system &>/dev/null && echo "yes" || echo "no")
    if [ "$auth_cert" = "yes" ]; then
        print_success "  authorino-server-cert secret exists"
    else
        print_warning "  authorino-server-cert secret not found"
        all_ok=false
    fi

    # Dashboard flags
    print_step "Checking dashboard MaaS flags..."
    local maas_flag=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
        -o jsonpath='{.spec.dashboardConfig.modelAsService}' 2>/dev/null)
    local auth_policies_flag=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
        -o jsonpath='{.spec.dashboardConfig.maasAuthPolicies}' 2>/dev/null)
    if [ "$maas_flag" = "true" ] && [ "$auth_policies_flag" = "true" ]; then
        print_success "  Dashboard: modelAsService=true, maasAuthPolicies=true"
    else
        print_warning "  Dashboard MaaS flags: modelAsService=$maas_flag, maasAuthPolicies=$auth_policies_flag"
        all_ok=false
    fi

    echo ""
    if [ "$all_ok" = true ]; then
        print_success "MaaS 3.4 deployment fully verified"
    else
        print_warning "MaaS 3.4 deployment has issues - check warnings above"
    fi
}

# List MaaS subscriptions
list_maas_subscriptions() {
    print_header "MaaS Subscriptions"
    oc get maassubscriptions -n models-as-a-service -o wide 2>/dev/null || \
        print_info "No subscriptions found or MaaS namespace not created yet"
}

# List MaaS authorization policies
list_maas_auth_policies() {
    print_header "MaaS Authorization Policies"
    oc get maasauthpolicies -n models-as-a-service -o wide 2>/dev/null || \
        print_info "No authorization policies found"
}

# List MaaS model references
list_maas_models() {
    print_header "MaaS Model References"
    oc get maasmodelrefs -A -o wide 2>/dev/null || \
        print_info "No model references found"
}

# Show MaaS Tenant status
show_maas_tenant() {
    print_header "MaaS Tenant Status"
    oc get tenant -n models-as-a-service -o wide 2>/dev/null || \
        print_info "No tenant found"
    echo ""
    oc get tenant default-tenant -n models-as-a-service -o yaml 2>/dev/null | \
        grep -A 20 "status:" || true
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

################################################################################
# Model Registry Setup
################################################################################

# Full idempotent Model Registry setup workflow.
# Per RHAIE 3.3 Guide: enables the component, creates namespace, deploys MySQL,
# creates ModelRegistry CR, enables dashboard visibility, verifies.
# Skips any step that is already completed.
# Usage: setup_model_registry [registry-name]
setup_model_registry() {
    local registry_name="${1:-}"
    local registry_ns="rhoai-model-registries"
    
    print_header "Setup Model Registry"
    echo "  Full workflow per RHAIE 3.3 Guide Chapter 2-3"
    echo "  (Steps already completed will be skipped)"
    echo ""
    
    ############################################################################
    # Step 1: Enable modelregistry component in DSC
    ############################################################################
    print_step "Step 1: Checking modelregistry component in DataScienceCluster..."
    
    local mr_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.modelregistry.managementState}' 2>/dev/null || echo "")
    
    if [ "$mr_state" = "Managed" ]; then
        print_success "modelregistry already Managed in DSC [SKIP]"
    else
        print_step "Enabling modelregistry in DataScienceCluster..."
        oc patch datasciencecluster default-dsc --type=merge -p '{
            "spec": {
                "components": {
                    "modelregistry": {
                        "managementState": "Managed",
                        "registriesNamespace": "rhoai-model-registries"
                    }
                }
            }
        }'
        print_success "modelregistry enabled in DSC"
        
        # Wait for operator to reconcile
        print_step "Waiting for Model Registry operator to be ready..."
        local elapsed=0
        while [ $elapsed -lt 90 ]; do
            if oc get modelregistry default-modelregistry -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Ready"; then
                print_success "Model Registry operator is ready"
                break
            fi
            sleep 5
            elapsed=$((elapsed + 5))
        done
    fi
    
    ############################################################################
    # Step 2: Enable Model Registry in dashboard
    ############################################################################
    print_step "Step 2: Checking dashboard configuration..."
    
    local mr_disabled=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications -o jsonpath='{.spec.dashboardConfig.disableModelRegistry}' 2>/dev/null || echo "true")
    
    if [ "$mr_disabled" = "false" ]; then
        print_success "Model Registry enabled in dashboard [SKIP]"
    else
        print_step "Enabling Model Registry in dashboard..."
        oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
            --type=merge -p '{"spec":{"dashboardConfig":{"disableModelRegistry":false}}}'
        print_success "Model Registry enabled in dashboard"
    fi
    
    ############################################################################
    # Step 3: Ensure registries namespace exists
    ############################################################################
    print_step "Step 3: Checking namespace '$registry_ns'..."
    
    if oc get namespace "$registry_ns" &>/dev/null; then
        print_success "Namespace '$registry_ns' exists [SKIP]"
    else
        oc create namespace "$registry_ns"
        print_success "Namespace '$registry_ns' created"
    fi
    
    ############################################################################
    # Step 4: Get registry name (interactive or argument)
    ############################################################################
    if [ -z "$registry_name" ]; then
        echo ""
        # Show existing registries if any
        local existing=$(oc get modelregistry.modelregistry.opendatahub.io -n "$registry_ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        if [ -n "$existing" ]; then
            print_info "Existing registries: $existing"
        fi
        
        echo -e "${BLUE}Enter a name for the Model Registry:${NC}"
        echo "  Examples: team-models, production-registry, shared-registry"
        echo ""
        read -p "Registry name [model-registry]: " registry_name
        registry_name="${registry_name:-model-registry}"
    fi
    
    # Sanitize name (lowercase, alphanumeric + hyphens only)
    registry_name=$(echo "$registry_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/^-//;s/-$//')
    
    ############################################################################
    # Step 5: Check if this registry already exists and is ready
    ############################################################################
    print_step "Step 5: Checking if registry '$registry_name' exists..."
    
    local mr_exists=$(oc get modelregistry.modelregistry.opendatahub.io "$registry_name" -n "$registry_ns" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
    
    if [ "$mr_exists" = "True" ]; then
        print_success "Model Registry '$registry_name' already exists and is ready [SKIP]"
        _show_model_registry_summary "$registry_name" "$registry_ns"
        return 0
    fi
    
    ############################################################################
    # Step 6: Deploy MySQL database (if not already running for this registry)
    ############################################################################
    local mysql_deploy_name="${registry_name}-mysql"
    local mysql_svc_name="${registry_name}-mysql"
    local mysql_db="mlmddb"
    local mysql_user="mlmd"
    local mysql_password=""
    local mysql_root_password=""
    local password_source="generated"
    
    print_step "Step 6: Deploying MySQL 8.0 database..."
    
    # Check if MySQL is already running for this registry
    if oc get deployment "$mysql_deploy_name" -n "$registry_ns" &>/dev/null; then
        local mysql_ready=$(oc get pods -n "$registry_ns" -l app="$mysql_deploy_name" -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$mysql_ready" = "True" ]; then
            print_success "MySQL '$mysql_deploy_name' already running [SKIP]"
        else
            print_info "MySQL deployment exists but not ready, waiting..."
            local elapsed=0
            while [ $elapsed -lt 90 ]; do
                mysql_ready=$(oc get pods -n "$registry_ns" -l app="$mysql_deploy_name" -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
                if [ "$mysql_ready" = "True" ]; then
                    print_success "MySQL is ready"
                    break
                fi
                sleep 5
                elapsed=$((elapsed + 5))
            done
        fi
    else
        # Check if credentials secret already exists (re-use if so)
        if oc get secret "${mysql_deploy_name}-credentials" -n "$registry_ns" &>/dev/null; then
            print_info "Re-using existing MySQL credentials secret"
            password_source="existing-secret"
        else
            # Prompt for password or generate random
            echo ""
            local default_pw=$(head -c 16 /dev/urandom 2>/dev/null | base64 | tr -dc 'a-zA-Z0-9' | head -c 16 || echo "mlmd$(date +%s | tail -c 8)")
            echo -e "${BLUE}MySQL password configuration:${NC}"
            echo "  User: $mysql_user | Database: $mysql_db"
            echo ""
            read -p "MySQL password (leave empty for auto-generated): " user_password
            
            if [ -n "$user_password" ]; then
                mysql_password="$user_password"
                password_source="user-provided"
            else
                mysql_password="$default_pw"
                password_source="generated"
            fi
            
            local default_root_pw=$(head -c 16 /dev/urandom 2>/dev/null | base64 | tr -dc 'a-zA-Z0-9' | head -c 16 || echo "root$(date +%s | tail -c 8)")
            read -p "MySQL root password (leave empty for auto-generated): " user_root_password
            
            if [ -n "$user_root_password" ]; then
                mysql_root_password="$user_root_password"
            else
                mysql_root_password="$default_root_pw"
            fi
            
            export MYSQL_DEPLOY_NAME="$mysql_deploy_name"
            export REGISTRY_NS="$registry_ns"
            export MYSQL_DB="$mysql_db"
            export MYSQL_USER="$mysql_user"
            export MYSQL_PASSWORD="$mysql_password"
            export MYSQL_ROOT_PASSWORD="$mysql_root_password"
            envsubst '${MYSQL_DEPLOY_NAME} ${REGISTRY_NS} ${MYSQL_DB} ${MYSQL_USER} ${MYSQL_PASSWORD} ${MYSQL_ROOT_PASSWORD}' \
                < "$_RHOAI_LIB_DIR/lib/manifests/model-registry/mysql-secret.yaml" | oc apply -f -
            unset MYSQL_DEPLOY_NAME REGISTRY_NS MYSQL_DB MYSQL_USER MYSQL_PASSWORD MYSQL_ROOT_PASSWORD
            print_success "MySQL credentials secret created"
        fi
        
        export MYSQL_DEPLOY_NAME="$mysql_deploy_name"
        export REGISTRY_NS="$registry_ns"
        export MYSQL_SVC_NAME="$mysql_svc_name"
        envsubst '${MYSQL_DEPLOY_NAME} ${REGISTRY_NS} ${MYSQL_SVC_NAME}' \
            < "$_RHOAI_LIB_DIR/lib/manifests/model-registry/mysql-deploy.yaml" | oc apply -f -
        unset MYSQL_DEPLOY_NAME REGISTRY_NS MYSQL_SVC_NAME
        
        print_step "Waiting for MySQL to be ready..."
        local elapsed=0
        while [ $elapsed -lt 120 ]; do
            if oc get pods -n "$registry_ns" -l app="$mysql_deploy_name" -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
                print_success "MySQL is ready"
                break
            fi
            sleep 5
            elapsed=$((elapsed + 5))
            echo "  Waiting for MySQL... (${elapsed}s elapsed)"
        done
        
        if [ $elapsed -ge 120 ]; then
            print_warning "MySQL may not be fully ready yet (continuing)"
        fi
    fi
    
    ############################################################################
    # Step 7: Create ModelRegistry CR
    ############################################################################
    print_step "Step 7: Creating ModelRegistry '$registry_name'..."
    
    if oc get modelregistry.modelregistry.opendatahub.io "$registry_name" -n "$registry_ns" &>/dev/null; then
        print_info "ModelRegistry CR already exists, checking status..."
    else
        export REGISTRY_NAME="$registry_name"
        export REGISTRY_NS="$registry_ns"
        export MYSQL_SVC_NAME="$mysql_svc_name"
        export MYSQL_DB="$mysql_db"
        export MYSQL_USER="$mysql_user"
        export MYSQL_DEPLOY_NAME="$mysql_deploy_name"
        envsubst '${REGISTRY_NAME} ${REGISTRY_NS} ${MYSQL_SVC_NAME} ${MYSQL_DB} ${MYSQL_USER} ${MYSQL_DEPLOY_NAME}' \
            < "$_RHOAI_LIB_DIR/lib/manifests/model-registry/modelregistry-cr.yaml" | oc apply -f -
        unset REGISTRY_NAME REGISTRY_NS MYSQL_SVC_NAME MYSQL_DB MYSQL_USER MYSQL_DEPLOY_NAME
    fi
    
    # Wait for ModelRegistry to be ready
    print_step "Waiting for Model Registry to be ready..."
    local elapsed=0
    while [ $elapsed -lt 120 ]; do
        local mr_ready=$(oc get modelregistry.modelregistry.opendatahub.io "$registry_name" -n "$registry_ns" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$mr_ready" = "True" ]; then
            print_success "Model Registry '$registry_name' is ready!"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo "  Waiting for Model Registry... (${elapsed}s elapsed)"
    done
    
    ############################################################################
    # Step 8: Verify and show summary
    ############################################################################
    _show_model_registry_summary "$registry_name" "$registry_ns" "$mysql_svc_name" "$mysql_db" "$mysql_user" "$mysql_password" "$mysql_root_password" "$password_source"
}

# Internal helper: display model registry summary
_show_model_registry_summary() {
    local registry_name="$1"
    local registry_ns="$2"
    local mysql_svc="${3:-}"
    local mysql_db="${4:-}"
    local mysql_user="${5:-}"
    local mysql_password="${6:-}"
    local mysql_root_password="${7:-}"
    local password_source="${8:-}"
    
    echo ""
    print_header "Model Registry Setup Complete"
    echo ""
    echo -e "${BLUE}Registry Name:${NC}  $registry_name"
    echo -e "${BLUE}Namespace:${NC}      $registry_ns"
    echo ""
    
    # Show pods
    echo -e "${BLUE}Pods:${NC}"
    oc get pods -n "$registry_ns" -l "app.kubernetes.io/instance=$registry_name" --no-headers 2>/dev/null | sed 's/^/  /'
    oc get pods -n "$registry_ns" -l "app=${registry_name}-mysql" --no-headers 2>/dev/null | sed 's/^/  /'
    echo ""
    
    # Show REST route
    local rest_route=$(oc get route -n "$registry_ns" --no-headers 2>/dev/null | grep "$registry_name" | awk '{print $2}' | head -1)
    if [ -n "$rest_route" ]; then
        echo -e "${BLUE}REST API:${NC}       https://$rest_route"
        echo ""
    fi
    
    # MySQL connection details
    if [ -n "$mysql_svc" ]; then
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${MAGENTA}MySQL Connection Details${NC}"
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BLUE}Host:${NC}          ${mysql_svc}.${registry_ns}.svc.cluster.local"
        echo -e "  ${BLUE}Port:${NC}          3306"
        echo -e "  ${BLUE}Database:${NC}      $mysql_db"
        echo -e "  ${BLUE}User:${NC}          $mysql_user"
        if [ -n "$mysql_password" ] && [ "$password_source" != "existing-secret" ]; then
            echo -e "  ${BLUE}Password:${NC}      $mysql_password"
            echo -e "  ${BLUE}Root Password:${NC} $mysql_root_password"
            echo ""
            echo -e "  ${YELLOW}⚠ Save these credentials! They are stored in:${NC}"
            echo "    oc get secret ${registry_name}-mysql-credentials -n $registry_ns -o yaml"
        else
            echo -e "  ${BLUE}Password:${NC}      (stored in secret ${registry_name}-mysql-credentials)"
            echo ""
            echo -e "  ${CYAN}Retrieve credentials:${NC}"
            echo "    oc get secret ${registry_name}-mysql-credentials -n $registry_ns -o jsonpath='{.data.MYSQL_PASSWORD}' | base64 -d"
            echo "    oc get secret ${registry_name}-mysql-credentials -n $registry_ns -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d"
        fi
        echo ""
        echo -e "  ${CYAN}Connect from a pod:${NC}"
        echo "    mysql -h ${mysql_svc}.${registry_ns}.svc.cluster.local -u $mysql_user -p $mysql_db"
        echo ""
        echo -e "  ${CYAN}Port-forward for local access:${NC}"
        echo "    oc port-forward svc/${mysql_svc} 3306:3306 -n $registry_ns"
        echo "    mysql -h 127.0.0.1 -u $mysql_user -p $mysql_db"
        echo ""
    fi
    
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Dashboard Access:${NC}"
    echo "  Settings → Model resources and operations → AI registry settings"
    echo ""
    echo -e "${YELLOW}CLI:${NC}"
    echo "  oc get modelregistry.modelregistry.opendatahub.io -n $registry_ns"
    echo ""
    echo -e "${YELLOW}Python SDK:${NC}"
    if [ -n "$rest_route" ]; then
        echo "  from model_registry import ModelRegistry"
        echo "  registry = ModelRegistry(server_address=\"https://$rest_route\", author=\"user@example.com\")"
    else
        echo "  # Get route: oc get route -n $registry_ns | grep $registry_name"
    fi
    echo ""
    echo -e "${YELLOW}Permissions:${NC}"
    echo "  # Add users to auto-created group:"
    echo "  oc adm groups add-users ${registry_name}-users <username>"
    echo ""
}

################################################################################
# Pipeline Server Setup
################################################################################

# Setup Data Science Pipelines Application (DSPA) with S3 storage.
# Per RHAIE 3.3 Guide Chapter 1: configuring a pipeline server requires S3 storage.
# Offers: reuse existing MinIO or deploy new one.
# Usage: setup_pipeline_server [namespace]
setup_pipeline_server() {
    local target_ns="${1:-}"
    
    print_header "Setup Pipeline Server"
    echo "  Per RHAIE 3.3 Guide: Data Science Pipelines with S3 storage"
    echo "  (Steps already completed will be skipped)"
    echo ""
    
    ############################################################################
    # Step 1: Check aipipelines is enabled in DSC
    ############################################################################
    print_step "Step 1: Checking aipipelines component in DSC..."
    
    local pipelines_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.aipipelines.managementState}' 2>/dev/null || echo "")
    
    if [ "$pipelines_state" = "Managed" ]; then
        print_success "aipipelines already Managed in DSC [SKIP]"
    else
        print_step "Enabling aipipelines in DataScienceCluster..."
        oc patch datasciencecluster default-dsc --type=merge -p '{
            "spec": {
                "components": {
                    "aipipelines": {
                        "managementState": "Managed"
                    }
                }
            }
        }'
        print_success "aipipelines enabled in DSC"
        sleep 10
    fi
    
    ############################################################################
    # Step 2: Select target namespace
    ############################################################################
    if [ -z "$target_ns" ]; then
        echo ""
        print_step "Step 2: Select project namespace for pipeline server"
        
        local current_project=$(oc project -q 2>/dev/null)
        echo "  Current project: $current_project"
        echo ""
        read -p "Deploy pipeline server in namespace [$current_project]: " target_ns
        target_ns="${target_ns:-$current_project}"
    fi
    
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_warning "Namespace '$target_ns' does not exist"
        read -p "Create it? (Y/n): " create_ns
        if [[ ! "$create_ns" =~ ^[Nn]$ ]]; then
            oc new-project "$target_ns" 2>/dev/null || oc create namespace "$target_ns"
            oc label namespace "$target_ns" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true
            print_success "Namespace '$target_ns' created"
        else
            return 1
        fi
    fi
    
    # Ensure dashboard label
    oc label namespace "$target_ns" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true
    
    ############################################################################
    # Step 3: Check if DSPA already exists
    ############################################################################
    print_step "Step 3: Checking for existing pipeline server..."
    
    if oc get dspa -n "$target_ns" -o name &>/dev/null 2>&1; then
        local existing_dspa=$(oc get dspa -n "$target_ns" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ -n "$existing_dspa" ]; then
            local dspa_ready=$(oc get dspa "$existing_dspa" -n "$target_ns" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            if [ "$dspa_ready" = "True" ]; then
                print_success "Pipeline server '$existing_dspa' already running [SKIP]"
                _show_pipeline_server_summary "$target_ns" "$existing_dspa"
                return 0
            else
                print_warning "DSPA '$existing_dspa' exists but not ready"
                print_info "Checking status..."
                oc get dspa "$existing_dspa" -n "$target_ns" -o jsonpath='{.status.conditions}' 2>/dev/null | python3 -m json.tool 2>/dev/null | head -20
                echo ""
                read -p "Delete and recreate? (y/N): " recreate
                if [[ "$recreate" =~ ^[Yy]$ ]]; then
                    oc delete dspa "$existing_dspa" -n "$target_ns"
                    sleep 5
                else
                    return 0
                fi
            fi
        fi
    fi
    
    ############################################################################
    # Step 4: S3 Storage Configuration
    ############################################################################
    echo ""
    print_step "Step 4: S3 Storage for Pipeline Artifacts"
    echo ""
    echo -e "${BLUE}Pipeline server requires S3-compatible storage for artifacts.${NC}"
    echo ""
    
    # Detect existing MinIO deployments (build arrays for a numbered picker below,
    # so users select an entry instead of free-typing a namespace/name pair)
    local minio_deployments=$(oc get deployment -A --no-headers 2>/dev/null | grep -i minio | awk '{print $1 "\t" $2}')
    local -a detect_ns=() detect_dep=() detect_svc=() detect_port=()

    if [ -n "$minio_deployments" ]; then
        echo -e "${CYAN}Existing MinIO deployments found:${NC}"
        while IFS=$'\t' read -r ns name; do
            [ -z "$ns" ] && continue
            local minio_svc=$(oc get svc -n "$ns" --no-headers 2>/dev/null | grep minio | grep -v console | awk '{print $1}' | head -1)
            minio_svc="${minio_svc:-minio}"
            local minio_port=$(oc get svc "$minio_svc" -n "$ns" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
            minio_port="${minio_port:-9000}"
            echo "  $((${#detect_ns[@]} + 1))) $ns / $name  (service: $minio_svc, port: $minio_port)"
            detect_ns+=("$ns")
            detect_dep+=("$name")
            detect_svc+=("$minio_svc")
            detect_port+=("$minio_port")
        done <<< "$minio_deployments"
        echo ""
    fi
    
    echo -e "${YELLOW}Storage options:${NC}"
    echo "  1) Built-in MinIO + MariaDB (simplest, for dev/testing)"
    echo "  2) Use existing external S3 storage"
    echo "  3) Deploy standalone MinIO in this namespace"
    echo ""
    read -p "Select option [1]: " storage_choice
    storage_choice="${storage_choice:-1}"
    
    local s3_endpoint=""
    local s3_bucket="pipelines"
    local s3_access_key=""
    local s3_secret_key=""
    local s3_scheme="http"
    local s3_host=""
    local s3_port="9000"
    local credentials_secret_name="pipelines-s3-credentials"
    local use_builtin_storage=false
    local dspa_name="pipelines-definition"
    
    if [ "$storage_choice" = "1" ]; then
        # Built-in MinIO + MariaDB managed by the DSPA operator
        use_builtin_storage=true
        echo ""
        print_info "DSPA operator will deploy MinIO and MariaDB automatically"
        print_info "This is recommended for development and testing"
        echo ""
        
        read -p "  MinIO PVC size [10Gi]: " minio_pvc_size
        minio_pvc_size="${minio_pvc_size:-10Gi}"
        
        read -p "  MariaDB PVC size [10Gi]: " mariadb_pvc_size
        mariadb_pvc_size="${mariadb_pvc_size:-10Gi}"
        
    elif [ "$storage_choice" = "2" ]; then
        # Reuse existing external S3 -- pick from the detected list above rather
        # than free-typing a host, which invites pasting the "ns / name" display
        # format verbatim as the hostname (an easy, hard-to-notice mistake: it
        # silently produces an invalid host and empty credentials instead of an
        # error, and the DSPA just sits at Ready=False with no clear reason).
        echo ""
        local minio_ns="" minio_svc=""

        if [ "${#detect_ns[@]}" -gt 0 ]; then
            echo -e "${CYAN}Select which MinIO/S3 to use:${NC}"
            local i=1
            while [ "$i" -le "${#detect_ns[@]}" ]; do
                echo "  $i) ${detect_ns[$((i-1))]} / ${detect_dep[$((i-1))]}"
                i=$((i+1))
            done
            echo "  m) Enter connection details manually"
            echo ""
            read -p "Select [1]: " s3_choice
            s3_choice="${s3_choice:-1}"
        else
            s3_choice="m"
        fi

        if [[ "$s3_choice" =~ ^[0-9]+$ ]] && [ "$s3_choice" -ge 1 ] && [ "$s3_choice" -le "${#detect_ns[@]}" ]; then
            minio_ns="${detect_ns[$((s3_choice-1))]}"
            minio_svc="${detect_svc[$((s3_choice-1))]}"
            s3_port="${detect_port[$((s3_choice-1))]}"
            s3_host="${minio_svc}.${minio_ns}.svc.cluster.local"
            print_success "Using $s3_host:$s3_port"
        else
            echo ""
            print_info "Hostname only -- no namespace, no slashes. Example: minio-service.minio.svc.cluster.local"
            read -p "  S3 host: " s3_host
            read -p "  S3 port [$s3_port]: " input_port
            s3_port="${input_port:-$s3_port}"
            read -p "  S3 scheme (http/https) [$s3_scheme]: " input_scheme
            s3_scheme="${input_scheme:-$s3_scheme}"
        fi

        read -p "  Pipeline bucket name [$s3_bucket]: " input_bucket
        s3_bucket="${input_bucket:-$s3_bucket}"

        # Auto-detect credentials from a secret in the same namespace. Checks
        # several common key-naming conventions (AWS_*, lowercase accesskey/
        # secretkey, and MinIO's own minio_root_user/minio_root_password).
        if [ -n "$minio_ns" ]; then
            local detected_secret=$(oc get secret -n "$minio_ns" --no-headers 2>/dev/null | grep -E "minio|aws-connection" | awk '{print $1}' | head -1)
            if [ -n "$detected_secret" ]; then
                for key_pair in "AWS_ACCESS_KEY_ID:AWS_SECRET_ACCESS_KEY" "accesskey:secretkey" "minio_root_user:minio_root_password"; do
                    local ak_field="${key_pair%%:*}" sk_field="${key_pair##*:}"
                    s3_access_key=$(oc get secret "$detected_secret" -n "$minio_ns" -o jsonpath="{.data.${ak_field}}" 2>/dev/null | base64 -d 2>/dev/null)
                    s3_secret_key=$(oc get secret "$detected_secret" -n "$minio_ns" -o jsonpath="{.data.${sk_field}}" 2>/dev/null | base64 -d 2>/dev/null)
                    [ -n "$s3_access_key" ] && [ -n "$s3_secret_key" ] && break
                done
                if [ -n "$s3_access_key" ] && [ -n "$s3_secret_key" ]; then
                    print_success "Auto-detected credentials from secret '$detected_secret' in $minio_ns"
                fi
            fi
        fi

        if [ -z "$s3_access_key" ] || [ -z "$s3_secret_key" ]; then
            echo ""
            print_warning "Could not auto-detect credentials"
            read -p "  S3 access key: " s3_access_key
            read -p "  S3 secret key: " s3_secret_key
        fi

        # Best-effort: ensure the bucket exists so the DSPA doesn't fail later.
        # Non-fatal if we can't find an `mc`-capable pod (e.g. a non-MinIO S3).
        if [ -n "$minio_ns" ]; then
            local minio_pod=$(oc get pod -n "$minio_ns" -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
            [ -z "$minio_pod" ] && minio_pod=$(oc get pod -n "$minio_ns" --no-headers 2>/dev/null | grep -i minio | awk '{print $1}' | head -1)
            if [ -n "$minio_pod" ]; then
                if oc exec "$minio_pod" -n "$minio_ns" -- sh -c "mc alias set local ${s3_scheme}://localhost:${s3_port} '${s3_access_key}' '${s3_secret_key}' >/dev/null 2>&1 && mc mb --ignore-existing local/${s3_bucket} >/dev/null 2>&1" 2>/dev/null; then
                    print_success "Bucket '$s3_bucket' ready"
                else
                    print_warning "Could not confirm/create bucket '$s3_bucket' automatically"
                    print_info "Create it manually if the pipeline server fails to start: mc mb local/$s3_bucket"
                fi
            fi
        fi

        print_success "Using external S3: $s3_host:$s3_port (bucket: $s3_bucket)"

    else
        # Deploy standalone MinIO
        echo ""
        print_step "Deploying standalone MinIO in '$target_ns'..."
        
        s3_host="minio.${target_ns}.svc.cluster.local"
        s3_access_key="minio"
        s3_secret_key=$(head -c 16 /dev/urandom 2>/dev/null | base64 | tr -dc 'a-zA-Z0-9' | head -c 16 || echo "minio$(date +%s | tail -c 8)")
        
        read -p "  MinIO password (leave empty for auto-generated): " user_secret
        if [ -n "$user_secret" ]; then
            s3_secret_key="$user_secret"
        fi
        
        read -p "  Storage size [50Gi]: " storage_size
        storage_size="${storage_size:-50Gi}"
        
        export STORAGE_SIZE="$storage_size"
        export S3_ACCESS_KEY="$s3_access_key"
        export S3_SECRET_KEY="$s3_secret_key"
        envsubst '${STORAGE_SIZE} ${S3_ACCESS_KEY} ${S3_SECRET_KEY}' \
            < "$_RHOAI_LIB_DIR/lib/manifests/pipeline/minio-pipelines.yaml" | oc apply -f - -n "$target_ns"
        unset STORAGE_SIZE S3_ACCESS_KEY S3_SECRET_KEY
        
        # Wait for MinIO
        print_step "Waiting for MinIO to be ready..."
        local elapsed=0
        while [ $elapsed -lt 90 ]; do
            if oc get pods -n "$target_ns" -l app=minio -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
                print_success "MinIO is ready"
                break
            fi
            sleep 5
            elapsed=$((elapsed + 5))
        done
        
        print_info "MinIO credentials: $s3_access_key / $s3_secret_key"
    fi
    
    ############################################################################
    # Step 5: Create DSPA
    ############################################################################
    if [ "$use_builtin_storage" = true ]; then
        # Built-in approach: DSPA operator manages MinIO + MariaDB
        print_step "Step 5: Creating DataSciencePipelinesApplication (built-in storage)..."
        
        export DSPA_NAME="$dspa_name"
        export MARIADB_PVC_SIZE="$mariadb_pvc_size"
        export MINIO_PVC_SIZE="$minio_pvc_size"
        envsubst '${DSPA_NAME} ${MARIADB_PVC_SIZE} ${MINIO_PVC_SIZE}' \
            < "$_RHOAI_LIB_DIR/lib/manifests/pipeline/dspa-builtin.yaml" | oc apply -f - -n "$target_ns"
        unset DSPA_NAME MARIADB_PVC_SIZE MINIO_PVC_SIZE
    else
        # External storage approach: create credentials secret first
        print_step "Step 5: Creating S3 credentials secret..."
        
        if oc get secret "$credentials_secret_name" -n "$target_ns" &>/dev/null; then
            print_success "Credentials secret already exists [SKIP]"
        else
            export CREDENTIALS_SECRET_NAME="$credentials_secret_name"
            export S3_ACCESS_KEY="$s3_access_key"
            export S3_SECRET_KEY="$s3_secret_key"
            envsubst '${CREDENTIALS_SECRET_NAME} ${S3_ACCESS_KEY} ${S3_SECRET_KEY}' \
                < "$_RHOAI_LIB_DIR/lib/manifests/pipeline/dspa-credentials-secret.yaml" | oc apply -f - -n "$target_ns"
            unset CREDENTIALS_SECRET_NAME S3_ACCESS_KEY S3_SECRET_KEY
            print_success "Credentials secret created"
        fi
        
        print_step "Step 6: Creating DataSciencePipelinesApplication..."
        
        export DSPA_NAME="$dspa_name"
        export S3_HOST="$s3_host"
        export S3_PORT="$s3_port"
        export S3_BUCKET="$s3_bucket"
        export S3_SCHEME="$s3_scheme"
        export CREDENTIALS_SECRET_NAME="$credentials_secret_name"
        envsubst '${DSPA_NAME} ${S3_HOST} ${S3_PORT} ${S3_BUCKET} ${S3_SCHEME} ${CREDENTIALS_SECRET_NAME}' \
            < "$_RHOAI_LIB_DIR/lib/manifests/pipeline/dspa-external.yaml" | oc apply -f - -n "$target_ns"
        unset DSPA_NAME S3_HOST S3_PORT S3_BUCKET S3_SCHEME CREDENTIALS_SECRET_NAME
    fi
    
    ############################################################################
    # Wait for pipeline server to be ready
    ############################################################################
    print_step "Waiting for pipeline server to be ready..."
    local elapsed=0
    while [ $elapsed -lt 180 ]; do
        local ready=$(oc get dspa "$dspa_name" -n "$target_ns" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$ready" = "True" ]; then
            print_success "Pipeline server is ready!"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        if [ $((elapsed % 15)) -eq 0 ]; then
            local reason=$(oc get dspa "$dspa_name" -n "$target_ns" -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)
            echo "  Waiting... status: ${reason:-pending} (${elapsed}s elapsed)"
        fi
    done
    
    if [ $elapsed -ge 180 ]; then
        print_warning "Pipeline server may not be fully ready yet"
        print_info "Check: oc get dspa $dspa_name -n $target_ns -o yaml"
    fi
    
    _show_pipeline_server_summary "$target_ns" "$dspa_name"
}

# Internal helper: display pipeline server summary
_show_pipeline_server_summary() {
    local target_ns="$1"
    local dspa_name="${2:-pipelines-definition}"
    
    echo ""
    print_header "Pipeline Server Summary"
    echo ""
    echo -e "${BLUE}Namespace:${NC}     $target_ns"
    echo -e "${BLUE}DSPA Name:${NC}     $dspa_name"
    echo ""
    
    # Get route
    local pipeline_route=$(oc get route "ds-pipeline-${dspa_name}" -n "$target_ns" -o jsonpath='{.spec.host}' 2>/dev/null)
    if [ -n "$pipeline_route" ]; then
        echo -e "${BLUE}Pipeline API:${NC}  https://$pipeline_route"
    else
        echo -e "${BLUE}Pipeline API:${NC}  (route not yet available, check: oc get route -n $target_ns)"
    fi
    echo ""
    
    # Pods
    echo -e "${CYAN}Pods:${NC}"
    oc get pods -n "$target_ns" --no-headers 2>/dev/null | grep -E "ds-pipeline|mariadb|minio" | sed 's/^/  /'
    echo ""
    
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Next Steps:${NC}"
    echo ""
    echo "  1. Import a pipeline via Dashboard:"
    echo "     Projects → $target_ns → Pipelines → Import pipeline"
    echo ""
    echo "  2. Import via Python SDK:"
    echo "     from kfp import Client"
    echo "     token = !oc whoami -t"
    if [ -n "$pipeline_route" ]; then
        echo "     client = Client(host='https://$pipeline_route', existing_token=token[0], ssl_ca_cert=False)"
    else
        echo "     client = Client(host='https://ds-pipeline-${dspa_name}-${target_ns}.apps.<cluster>', existing_token=token[0])"
    fi
    echo "     client.list_pipelines()"
    echo ""
    echo "  3. Compile + upload a pipeline:"
    echo "     from kfp import compiler, dsl"
    echo "     compiler.Compiler().compile(my_pipeline, 'pipeline.yaml')"
    echo "     client.upload_pipeline('pipeline.yaml', pipeline_name='my-pipeline')"
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

