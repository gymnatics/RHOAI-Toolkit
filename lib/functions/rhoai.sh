#!/bin/bash
################################################################################
# RHOAI installation and configuration functions
################################################################################

# Source required utilities
# Use a local variable to avoid overwriting caller's SCRIPT_DIR
_RHOAI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_RHOAI_LIB_DIR/lib/utils/colors.sh"
source "$_RHOAI_LIB_DIR/lib/utils/common.sh"

# Get RHOAI channel based on version (fallback/default mapping)
get_rhoai_channel() {
    local version="$1"
    
    case "$version" in
        2.17|2.18) echo "stable-2.18" ;;
        2.19|2.20) echo "stable-2.20" ;;
        2.21) echo "stable-2.21" ;;
        2.22) echo "stable-2.22" ;;
        2.23) echo "stable-2.23" ;;
        2.24|2.25) echo "stable" ;;
        3.0|3.1|3.2|3.3) echo "fast-3.x" ;;
        *) echo "stable" ;;
    esac
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
    
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: redhat-ods-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: redhat-ods-operator
  namespace: redhat-ods-operator
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  channel: $SELECTED_RHOAI_CHANNEL
  installPlanApproval: $SELECTED_INSTALL_PLAN_APPROVAL
  name: rhods-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
    
    # If Manual approval, need to approve the initial InstallPlan
    if [ "$SELECTED_INSTALL_PLAN_APPROVAL" = "Manual" ]; then
        print_step "Waiting for InstallPlan to be created..."
        sleep 10
        
        local timeout=60
        local elapsed=0
        local installplan=""
        
        while [ $elapsed -lt $timeout ]; do
            installplan=$(oc get installplan -n redhat-ods-operator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
            if [ -n "$installplan" ]; then
                break
            fi
            sleep 5
            elapsed=$((elapsed + 5))
        done
        
        if [ -n "$installplan" ]; then
            print_step "Approving initial InstallPlan: $installplan"
            oc patch installplan "$installplan" -n redhat-ods-operator \
                --type merge -p '{"spec":{"approved":true}}'
            print_success "InstallPlan approved"
        else
            print_warning "InstallPlan not found. You may need to approve it manually:"
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
    
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: redhat-ods-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: redhat-ods-operator
  namespace: redhat-ods-operator
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  channel: $channel
  installPlanApproval: Automatic
  name: rhods-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
    
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
        cat <<EOF | oc replace -f -
apiVersion: dscinitialization.opendatahub.io/v1
kind: DSCInitialization
metadata:
  name: default-dsci
spec:
  applicationsNamespace: redhat-ods-applications
  monitoring:
    managementState: Managed
    namespace: redhat-ods-monitoring
  serviceMesh:
    auth:
      audiences:
        - 'https://kubernetes.default.svc'
    controlPlane:
      metricsCollection: Istio
      name: data-science-smcp
      namespace: istio-system
    managementState: Managed
  trustedCABundle:
    customCABundle: ''
    managementState: Managed
EOF
    else
        cat <<EOF | oc apply -f -
apiVersion: dscinitialization.opendatahub.io/v1
kind: DSCInitialization
metadata:
  name: default-dsci
spec:
  applicationsNamespace: redhat-ods-applications
  monitoring:
    managementState: Managed
    namespace: redhat-ods-monitoring
  serviceMesh:
    auth:
      audiences:
        - 'https://kubernetes.default.svc'
    controlPlane:
      metricsCollection: Istio
      name: data-science-smcp
      namespace: istio-system
    managementState: Managed
  trustedCABundle:
    customCABundle: ''
    managementState: Managed
EOF
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
            print_warning "Template not found at $template_file, using inline YAML"
            # Fallback to inline YAML if template not found
            # IMPORTANT: nodeSelector and tolerations must be inside scheduling.node
            cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: gpu-profile
  namespace: $namespace
  annotations:
    opendatahub.io/display-name: GPU Profile
    opendatahub.io/description: 'GPU hardware profile for NVIDIA GPU workloads'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
spec:
  identifiers:
    - defaultCount: '2'
      displayName: CPU
      identifier: cpu
      maxCount: '16'
      minCount: 1
      resourceType: CPU
    - defaultCount: 16Gi
      displayName: Memory
      identifier: memory
      maxCount: 64Gi
      minCount: 1Gi
      resourceType: Memory
    - defaultCount: 1
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: 8
      minCount: 1
      resourceType: Accelerator
  scheduling:
    type: Node
    node:
      nodeSelector:
        nvidia.com/gpu.present: 'true'
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
EOF
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
            
            cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
EOF
            
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
        cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
EOF
        
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
            
            cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
EOF
            
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
                
                cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
EOF
                
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
            
            cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
EOF
            
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
    
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-workload-monitoring-config
  namespace: openshift-user-workload-monitoring
data:
  config.yaml: |
    prometheus:
      retention: 24h
      resources:
        requests:
          cpu: 200m
          memory: 2Gi
EOF
    
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
    
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
    alertmanagerMain:
      enableUserAlertmanagerConfig: true
EOF
    
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
    
    cat <<EOF | oc apply -f -
apiVersion: dscinitialization.opendatahub.io/v2
kind: DSCInitialization
metadata:
  name: default-dsci
spec:
  applicationsNamespace: redhat-ods-applications
  monitoring:
    alerting: {}
    managementState: Managed
    metrics:
      replicas: 1
      storage:
        retention: $metrics_retention
        size: $metrics_size
    namespace: redhat-ods-monitoring
    traces:
      sampleRatio: '$trace_ratio'
      storage:
        backend: pv
        retention: $trace_retention
  trustedCABundle:
    customCABundle: ''
    managementState: Managed
EOF
    
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

# Setup MCP Servers ConfigMap (per CAI Guide 3.2 Section 2)
# New JSON format for gen-ai-aa-mcp-servers
setup_mcp_servers_configmap() {
    local namespace="${1:-redhat-ods-applications}"
    
    print_header "Setup MCP Servers ConfigMap (RHOAI 3.2+)"
    
    echo ""
    echo -e "${CYAN}This creates the MCP servers ConfigMap in the new 3.2 format${NC}"
    echo -e "${CYAN}(per CAI Guide Section 2, Step 5)${NC}"
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
    
    cat <<'EOF' | oc apply -f -
kind: ConfigMap
apiVersion: v1
metadata:
  name: gen-ai-aa-mcp-servers
  namespace: redhat-ods-applications
data:
  GitHub-MCP-Server: |
    {
      "url": "https://api.githubcopilot.com/mcp",
      "description": "The GitHub MCP server enables exploration and interaction with repositories, code, and developer resources on GitHub. It provides programmatic access to repositories, issues, pull requests, and related project data, allowing automation and integration within development workflows. With this service, developers can query repositories, discover project metadata, and streamline code-related tasks through MCP-compatible tools."
    }
EOF
    
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
        cat <<'EOF' | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-ai-inference
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
        print_success "GatewayClass created"
    fi
    
    # Step 2: Create Gateway
    print_step "Creating Gateway 'openshift-ai-inference'..."
    if oc get gateway openshift-ai-inference -n openshift-ingress &>/dev/null; then
        print_success "Gateway already exists"
    else
        local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
        print_info "Cluster domain: $cluster_domain"
        
        cat <<EOF | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/rev: openshift-gateway
  name: openshift-ai-inference
  namespace: openshift-ingress
spec:
  gatewayClassName: openshift-ai-inference
  listeners:
    - allowedRoutes:
        namespaces:
          from: All
      hostname: inference-gateway.apps.$cluster_domain
      name: https
      port: 443
      protocol: HTTPS
      tls:
        certificateRefs:
          - group: ''
            kind: Secret
            name: default-gateway-tls
        mode: Terminate
EOF
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
            cat <<'EOF' | oc apply -f -
apiVersion: operator.openshift.io/v1
kind: LeaderWorkerSetOperator
metadata:
  name: cluster
  namespace: openshift-lws-operator
spec:
  managementState: Managed
  logLevel: Normal
  operatorLogLevel: Normal
EOF
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
        cat <<'EOF' | oc apply -f -
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
EOF
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
        cat <<'EOF' | oc apply -f -
apiVersion: operator.authorino.kuadrant.io/v1beta1
kind: Authorino
metadata:
  name: authorino
  namespace: kuadrant-system
spec:
  replicas: 1
  clusterWide: true
  listener:
    tls:
      enabled: true
      certSecretRef:
        name: authorino-server-cert
  oidcServer:
    tls:
      enabled: false
EOF
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
    
    cat <<EOF | oc apply -f -
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: $model_name
  namespace: $namespace
  labels:
    kueue.x-k8s.io/queue-name: default
    opendatahub.io/dashboard: "true"
    opendatahub.io/genai-asset: "true"
  annotations:
    security.opendatahub.io/enable-auth: "$auth_annotation"
spec:
  replicas: 1
  model:
    uri: $model_uri
    name: $model_name
  router:
    route: {}
    gateway: {}
    scheduler: {}
  template:
    containers:
    - name: main
      env:
        - name: VLLM_ADDITIONAL_ARGS
          value: "--enable-auto-tool-choice --tool-call-parser=hermes"
      resources:
        limits:
          cpu: '4'
          memory: $memory_limit
          nvidia.com/gpu: "$gpu_count"
        requests:
          cpu: '1'
          memory: 8Gi
          nvidia.com/gpu: "$gpu_count"
EOF
    
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

# Setup Feature Store in a namespace
setup_feature_store() {
    local namespace="${1:-}"
    local git_url="${2:-}"
    local git_ref="${3:-rbac}"
    local feast_project="${4:-banking}"
    
    print_header "Setting up Feature Store (Feast)"
    
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
    
    # Label namespace for RHOAI dashboard
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
    
    # Create FeatureStore
    print_step "Creating FeatureStore '$feast_project' in namespace '$namespace'..."
    
    cat <<EOF | oc apply -n "$namespace" -f -
apiVersion: feast.dev/v1alpha1
kind: FeatureStore
metadata:
  labels:
    feature-store-ui: enabled
  name: $feast_project
spec:
  feastProject: $feast_project
  feastProjectDir:
    git:
      ref: $git_ref
      url: '$git_url'
  services:
    offlineStore:
      server:
        logLevel: debug
    onlineStore:
      server:
        logLevel: debug
    registry:
      local:
        server:
          restAPI: true
EOF
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create FeatureStore"
        return 1
    fi
    
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
    
    # Show status
    echo ""
    print_header "Feature Store Setup Complete"
    echo ""
    oc get featurestore -n "$namespace"
    echo ""
    oc get svc -n "$namespace" | grep feast
    echo ""
    print_info "Access Feature Store in RHOAI Dashboard:"
    print_info "  Projects → $namespace → Feature store integration"
    echo ""
}

# Show Feature Store status
show_feast_status() {
    print_header "Feature Store Status"
    
    # Check if Feast operator is enabled
    local feast_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.feastoperator.managementState}' 2>/dev/null || echo "Unknown")
    echo ""
    echo -e "Feast Operator: ${CYAN}$feast_state${NC}"
    echo ""
    
    # List all FeatureStores
    echo -e "${YELLOW}FeatureStores across all namespaces:${NC}"
    oc get featurestore -A 2>/dev/null || echo "No FeatureStores found"
    echo ""
    
    # Show Feast pods
    echo -e "${YELLOW}Feast pods:${NC}"
    oc get pods -A -l app.kubernetes.io/managed-by=feast-operator 2>/dev/null || \
    oc get pods -A 2>/dev/null | grep -i feast || echo "No Feast pods found"
    echo ""
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


