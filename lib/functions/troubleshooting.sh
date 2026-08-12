#!/bin/bash
################################################################################
# Troubleshooting & Fixes — cluster logic functions
################################################################################

_TROUBLESHOOTING_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_TROUBLESHOOTING_LIB_DIR/lib/utils/colors.sh"
source "$_TROUBLESHOOTING_LIB_DIR/lib/utils/common.sh"

# Fix GPU Operator CUDA Compatibility
# Downgrades GPU Operator to v24.6.x which uses CUDA 12.x (compatible with vLLM)
fix_gpu_operator_cuda_compatibility() {
    print_header "Fix GPU Operator CUDA Compatibility"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    echo -e "${YELLOW}Issue:${NC} GPU Operator v24.9.x ships with CUDA 13, but vLLM in RHOAI"
    echo "       requires CUDA 12.x. This causes 'NVIDIA driver too old' errors."
    echo ""
    echo -e "${GREEN}Solution:${NC} Downgrade GPU Operator to v24.6.x (CUDA 12.x compatible)"
    echo "          and set InstallPlanApproval to Manual to prevent auto-upgrades."
    echo ""
    
    # Check current version
    local current_version=$(oc get csv -n nvidia-gpu-operator 2>/dev/null | grep gpu-operator | awk '{print $1}' | sed 's/gpu-operator-certified.//')
    local current_channel=$(oc get subscription gpu-operator-certified -n nvidia-gpu-operator -o jsonpath='{.spec.channel}' 2>/dev/null)
    
    if [ -z "$current_version" ]; then
        print_error "GPU Operator not found. Please install it first."
        return 1
    fi
    
    echo -e "${CYAN}Current Status:${NC}"
    echo "  Version: $current_version"
    echo "  Channel: $current_channel"
    echo ""
    
    # Check CUDA version
    local cuda_version=$(oc exec -n nvidia-gpu-operator $(oc get pods -n nvidia-gpu-operator -o name 2>/dev/null | grep driver | head -1) -c nvidia-driver-ctr -- nvidia-smi 2>/dev/null | grep "CUDA Version" | awk '{print $9}' || echo "unknown")
    echo "  CUDA Version: $cuda_version"
    echo ""
    
    if [[ "$current_channel" == "v24.6" ]]; then
        print_success "GPU Operator is already on v24.6 channel (CUDA 12.x compatible)"
        echo ""
        read -p "Do you want to check/fix InstallPlanApproval to Manual? (y/N): " fix_approval
        if [[ "$fix_approval" =~ ^[Yy]$ ]]; then
            oc patch subscription gpu-operator-certified -n nvidia-gpu-operator --type=merge -p '{"spec":{"installPlanApproval":"Manual"}}'
            print_success "InstallPlanApproval set to Manual"
        fi
        return 0
    fi
    
    echo -e "${YELLOW}Available channels:${NC}"
    oc get packagemanifest gpu-operator-certified -n openshift-marketplace -o jsonpath='{.status.channels[*].name}' 2>/dev/null | tr ' ' '\n' | grep -E "^v24\.|^v23\." | sort -V | tail -5
    echo ""
    
    echo -e "${RED}Warning:${NC} This will:"
    echo "  1. Delete the current GPU Operator subscription and CSV"
    echo "  2. Install GPU Operator v24.6.x"
    echo "  3. Set InstallPlanApproval to Manual (prevents auto-upgrades)"
    echo "  4. The driver pods will be recreated (may take a few minutes)"
    echo ""
    
    read -p "Proceed with downgrade to v24.6? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    echo ""
    print_step "Deleting current GPU Operator..."
    oc delete subscription gpu-operator-certified -n nvidia-gpu-operator 2>/dev/null || true
    oc delete csv -n nvidia-gpu-operator -l operators.coreos.com/gpu-operator-certified.nvidia-gpu-operator 2>/dev/null || true
    sleep 5
    
    print_step "Creating new subscription with v24.6 channel..."
    oc apply -f "$_TROUBLESHOOTING_LIB_DIR/lib/manifests/operators/gpu-operator-subscription-v246.yaml"
    
    print_step "Waiting for InstallPlan..."
    local timeout=120
    local elapsed=0
    local installplan=""
    
    while [ $elapsed -lt $timeout ]; do
        installplan=$(oc get subscription gpu-operator-certified -n nvidia-gpu-operator \
            -o jsonpath='{.status.installPlanRef.name}' 2>/dev/null || true)
        if [ -n "$installplan" ]; then
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    if [ -n "$installplan" ]; then
        approve_installplan "gpu-operator-certified" "nvidia-gpu-operator"
    else
        print_warning "InstallPlan not found after ${timeout}s. Approve it manually:"
        echo "  oc get installplan -n nvidia-gpu-operator"
        echo "  oc patch installplan <name> -n nvidia-gpu-operator --type merge -p '{\"spec\":{\"approved\":true}}'"
    fi
    
    print_step "Waiting for GPU Operator to be ready..."
    local timeout=180
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if oc get csv -n nvidia-gpu-operator 2>/dev/null | grep -q "gpu-operator.*Succeeded"; then
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        echo "  Waiting... (${elapsed}s)"
    done
    
    # Check final status
    echo ""
    local new_version=$(oc get csv -n nvidia-gpu-operator 2>/dev/null | grep gpu-operator | awk '{print $1}')
    if [ -n "$new_version" ]; then
        print_success "GPU Operator installed: $new_version"
    else
        print_warning "GPU Operator installation in progress. Check status with:"
        echo "  oc get csv -n nvidia-gpu-operator"
    fi
    
    echo ""
    print_info "Note: Driver pods will be recreated. This may take a few minutes."
    print_info "Check driver status with: oc get pods -n nvidia-gpu-operator | grep driver"
    echo ""
    print_info "After drivers are ready, restart your model pods to use the new CUDA version."
}

# Check GPU Operator Status
check_gpu_operator_status() {
    print_header "GPU Operator Status"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    echo -e "${CYAN}GPU Operator:${NC}"
    local csv_info=$(oc get csv -n nvidia-gpu-operator 2>/dev/null | grep gpu-operator)
    if [ -n "$csv_info" ]; then
        echo "$csv_info"
    else
        print_warning "GPU Operator not installed"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}Subscription:${NC}"
    oc get subscription gpu-operator-certified -n nvidia-gpu-operator -o custom-columns=NAME:.metadata.name,CHANNEL:.spec.channel,APPROVAL:.spec.installPlanApproval 2>/dev/null || echo "  Not found"
    
    echo ""
    echo -e "${CYAN}ClusterPolicy:${NC}"
    oc get clusterpolicy gpu-cluster-policy -o custom-columns=NAME:.metadata.name,STATE:.status.state 2>/dev/null || echo "  Not found"
    
    echo ""
    echo -e "${CYAN}Driver Pods:${NC}"
    oc get pods -n nvidia-gpu-operator 2>/dev/null | grep driver || echo "  No driver pods found"
    
    echo ""
    echo -e "${CYAN}NVIDIA Driver & CUDA Version:${NC}"
    local driver_pod=$(oc get pods -n nvidia-gpu-operator -o name 2>/dev/null | grep driver | head -1)
    if [ -n "$driver_pod" ]; then
        oc exec -n nvidia-gpu-operator $driver_pod -c nvidia-driver-ctr -- nvidia-smi 2>/dev/null | head -10 || echo "  Unable to get nvidia-smi output"
    else
        echo "  No driver pod running"
    fi
    
    echo ""
    echo -e "${CYAN}GPU Nodes:${NC}"
    oc get nodes -l feature.node.kubernetes.io/pci-10de.present=true -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,SCHEDULABLE:.spec.unschedulable 2>/dev/null || echo "  No GPU nodes found"
}

# Uncordon GPU Nodes
uncordon_gpu_nodes() {
    print_header "Uncordon GPU Nodes"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    echo -e "${CYAN}Checking for cordoned GPU nodes...${NC}"
    echo ""
    
    local cordoned_nodes=$(oc get nodes -l feature.node.kubernetes.io/pci-10de.present=true -o json 2>/dev/null | jq -r '.items[] | select(.spec.unschedulable == true) | .metadata.name')
    
    if [ -z "$cordoned_nodes" ]; then
        print_success "No cordoned GPU nodes found. All GPU nodes are schedulable."
        echo ""
        echo "GPU Node Status:"
        oc get nodes -l feature.node.kubernetes.io/pci-10de.present=true 2>/dev/null || echo "  No GPU nodes found"
        return 0
    fi
    
    echo -e "${YELLOW}Found cordoned GPU nodes:${NC}"
    echo "$cordoned_nodes"
    echo ""
    
    read -p "Uncordon all these nodes? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    echo ""
    for node in $cordoned_nodes; do
        print_step "Uncordoning $node..."
        if oc adm uncordon "$node"; then
            print_success "Uncordoned: $node"
        else
            print_error "Failed to uncordon: $node"
        fi
    done
    
    echo ""
    print_success "Done! GPU nodes are now schedulable."
    echo ""
    echo "GPU Node Status:"
    oc get nodes -l feature.node.kubernetes.io/pci-10de.present=true 2>/dev/null
}

# Check All Operator Status
check_all_operator_status() {
    print_header "RHOAI-Related Operator Status"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    echo -e "${CYAN}Core Operators:${NC}"
    echo ""
    
    # NFD
    echo -e "${YELLOW}NFD (Node Feature Discovery):${NC}"
    oc get csv -n openshift-nfd 2>/dev/null | grep -E "NAME|nfd" || echo "  Not installed"
    echo ""
    
    # GPU Operator
    echo -e "${YELLOW}NVIDIA GPU Operator:${NC}"
    oc get csv -n nvidia-gpu-operator 2>/dev/null | grep -E "NAME|gpu" || echo "  Not installed"
    echo ""
    
    # RHOAI
    echo -e "${YELLOW}Red Hat OpenShift AI:${NC}"
    oc get csv -n redhat-ods-operator 2>/dev/null | grep -E "NAME|rhods" || echo "  Not installed"
    echo ""
    
    # Kueue
    echo -e "${YELLOW}Kueue:${NC}"
    oc get csv -n openshift-operators 2>/dev/null | grep -E "NAME|kueue" || echo "  Not installed"
    echo ""
    
    # LWS
    echo -e "${YELLOW}Leader Worker Set (LWS):${NC}"
    oc get csv -n openshift-lws-operator 2>/dev/null | grep -E "NAME|leader-worker" || echo "  Not installed"
    echo ""
    
    # RHCL
    echo -e "${YELLOW}Red Hat Connectivity Link (RHCL):${NC}"
    oc get csv -n kuadrant-system 2>/dev/null | grep -E "NAME|rhcl" || echo "  Not installed"
    echo ""
    
    # DataScienceCluster
    echo -e "${CYAN}DataScienceCluster Status:${NC}"
    oc get datasciencecluster 2>/dev/null || echo "  Not found"
}

# Restart Failed Model Pods
restart_failed_model_pods() {
    print_header "Restart Failed Model Pods"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    echo -e "${CYAN}Checking for InferenceServices...${NC}"
    echo ""
    
    local isvc_list=$(oc get inferenceservice -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[0].status 2>/dev/null | grep -v "^NAMESPACE")
    
    if [ -z "$isvc_list" ]; then
        print_info "No InferenceServices found"
        return 0
    fi
    
    echo "InferenceServices:"
    echo "$isvc_list"
    echo ""
    
    # Find not-ready ones
    local failed_isvc=$(echo "$isvc_list" | grep -v "True" | awk '{print $1 "/" $2}')
    
    if [ -z "$failed_isvc" ]; then
        print_success "All InferenceServices are ready!"
        return 0
    fi
    
    echo -e "${YELLOW}Not-ready InferenceServices:${NC}"
    echo "$failed_isvc"
    echo ""
    
    read -p "Enter namespace/name to restart (or 'all' for all failed, 'q' to quit): " selection
    
    if [ "$selection" = "q" ]; then
        return 0
    fi
    
    if [ "$selection" = "all" ]; then
        for isvc in $failed_isvc; do
            local ns=$(echo "$isvc" | cut -d'/' -f1)
            local name=$(echo "$isvc" | cut -d'/' -f2)
            print_step "Restarting pods for $name in $ns..."
            oc delete pod -n "$ns" -l serving.kserve.io/inferenceservice="$name" 2>/dev/null || true
        done
    else
        local ns=$(echo "$selection" | cut -d'/' -f1)
        local name=$(echo "$selection" | cut -d'/' -f2)
        print_step "Restarting pods for $name in $ns..."
        oc delete pod -n "$ns" -l serving.kserve.io/inferenceservice="$name" 2>/dev/null || true
    fi
    
    print_success "Pods deleted. New pods will be created automatically."
    echo ""
    print_info "Check status with: oc get pods -n <namespace>"
}
