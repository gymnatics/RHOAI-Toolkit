#!/bin/bash
################################################################################
# troubleshooting.sh — Troubleshooting & GPU menus for rhoai-toolkit.sh
################################################################################

_TROUBLESHOOTING_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

show_troubleshooting_submenu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 Troubleshooting & Fixes                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}GPU / CUDA Issues:${NC}"
    echo -e "${YELLOW}1)${NC} Fix GPU Operator CUDA Compatibility ${GREEN}[Common Fix]${NC}"
    echo "    Downgrade GPU Operator to v24.6.x for vLLM compatibility"
    echo "    (Fixes: 'NVIDIA driver too old' error with CUDA 13)"
    echo ""
    echo -e "${YELLOW}2)${NC} Pin NVIDIA Driver Version (CUDA 12.8) ${GREEN}[CAI 3.2 Fix]${NC}"
    echo "    Pin driver to 570.195.03 for vLLM compatibility"
    echo ""
    echo -e "${YELLOW}3)${NC} Check GPU Operator Status"
    echo "    View current version, driver, and CUDA compatibility"
    echo ""
    echo -e "${YELLOW}4)${NC} Uncordon GPU Nodes"
    echo "    Re-enable scheduling on GPU nodes after maintenance"
    echo ""
    echo -e "${RED}Operator Issues:${NC}"
    echo -e "${YELLOW}5)${NC} Fix Operator Channel Issues"
    echo "    Re-sync operators with correct channels (Kueue, LWS, etc.)"
    echo ""
    echo -e "${YELLOW}6)${NC} Check All Operator Status"
    echo "    View status of all RHOAI-related operators"
    echo ""
    echo -e "${RED}Model Serving Issues:${NC}"
    echo -e "${YELLOW}7)${NC} Restart Failed Model Pods"
    echo "    Delete and recreate pods for stuck InferenceServices"
    echo ""
    echo -e "${YELLOW}8)${NC} Restart RHOAI Controllers"
    echo "    Restart odh-model-controller and kserve-controller"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to RHOAI Management"
    echo ""
}

show_gpu_clusterpolicy_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║             GPU & ClusterPolicy Management                     ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${MAGENTA}ClusterPolicy:${NC}"
    echo -e "${YELLOW}1)${NC} Show ClusterPolicy Status"
    echo "    View current ClusterPolicy state and configuration"
    echo ""
    echo -e "${YELLOW}2)${NC} Create/Apply ClusterPolicy"
    echo "    Create ClusterPolicy for GPU nodes (required for GPU workloads)"
    echo ""
    echo -e "${YELLOW}3)${NC} Delete ClusterPolicy"
    echo "    Remove ClusterPolicy (for troubleshooting/recreation)"
    echo ""
    echo -e "${MAGENTA}GPU Operator:${NC}"
    echo -e "${YELLOW}4)${NC} Check GPU Operator Status"
    echo "    View operator version, driver, CUDA compatibility"
    echo ""
    echo -e "${YELLOW}5)${NC} Downgrade GPU Operator to v24.6"
    echo "    Fix CUDA compatibility issues with vLLM"
    echo ""
    echo -e "${YELLOW}6)${NC} Pin NVIDIA Driver Version"
    echo "    Pin driver to specific version for stability"
    echo ""
    echo -e "${MAGENTA}GPU Nodes:${NC}"
    echo -e "${YELLOW}7)${NC} Show GPU Nodes"
    echo "    List all GPU nodes and their status"
    echo ""
    echo -e "${YELLOW}8)${NC} Uncordon GPU Nodes"
    echo "    Re-enable scheduling on cordoned GPU nodes"
    echo ""
    echo -e "${YELLOW}9)${NC} Run nvidia-smi on GPU Node"
    echo "    Check GPU driver and CUDA version on a node"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to Main Menu"
    echo ""
}

# Troubleshooting submenu handler
troubleshooting_submenu() {
    while true; do
        show_troubleshooting_submenu
        read -p "Select an option (1-8, 0): " ts_choice
        
        case $ts_choice in
            1)
                fix_gpu_operator_cuda_compatibility
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                pin_nvidia_driver_version
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                check_gpu_operator_status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                uncordon_gpu_nodes
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                print_info "Re-running operator channel validation..."
                echo ""
                if [ -f "$_TROUBLESHOOTING_MENU_DIR/scripts/install-rhoai-minimal.sh" ]; then
                    source "$_TROUBLESHOOTING_MENU_DIR/lib/utils/common.sh" 2>/dev/null || true
                    echo "Checking operator channels..."
                    echo ""
                    echo "Kueue available channels:"
                    oc get packagemanifest kueue-operator -n openshift-marketplace -o jsonpath='{.status.channels[*].name}' 2>/dev/null && echo ""
                    echo ""
                    echo "LWS available channels:"
                    oc get packagemanifest leader-worker-set -n openshift-marketplace -o jsonpath='{.status.channels[*].name}' 2>/dev/null && echo ""
                    echo ""
                    print_info "To fix channel issues, re-run: ./scripts/install-rhoai-minimal.sh"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                check_all_operator_status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                restart_failed_model_pods
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                print_header "Restart RHOAI Controllers"
                echo "This will restart odh-model-controller and kserve-controller-manager"
                echo "Useful when authentication/Authorino changes aren't being picked up"
                echo ""
                read -p "Continue? (y/N): " restart_confirm
                if [[ "$restart_confirm" =~ ^[Yy]$ ]]; then
                    print_step "Restarting odh-model-controller..."
                    oc delete pod -n redhat-ods-applications -l app=odh-model-controller 2>/dev/null || true
                    print_step "Restarting kserve-controller-manager..."
                    oc delete pod -n redhat-ods-applications -l control-plane=kserve-controller-manager 2>/dev/null || true
                    print_success "Controllers restarted"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                print_error "Invalid option. Please select 1-8 or 0."
                sleep 1
                ;;
        esac
    done
}

# GPU & ClusterPolicy Management Menu
gpu_clusterpolicy_menu() {
    while true; do
        show_gpu_clusterpolicy_menu
        read -p "Select an option (1-9, 0): " gcp_choice
        
        case $gcp_choice in
            1)
                # Show ClusterPolicy Status
                print_header "ClusterPolicy Status"
                echo ""
                echo -e "${CYAN}ClusterPolicy:${NC}"
                oc get clusterpolicy -o wide 2>/dev/null || echo "  No ClusterPolicy found"
                echo ""
                local cp_status=$(oc get clusterpolicy gpu-cluster-policy -o jsonpath='{.status.state}' 2>/dev/null)
                if [ -n "$cp_status" ]; then
                    echo -e "${CYAN}State:${NC} $cp_status"
                    echo ""
                    echo -e "${CYAN}Component Status:${NC}"
                    oc get clusterpolicy gpu-cluster-policy -o jsonpath='{range .status.state}{@}{"\n"}{end}' 2>/dev/null
                    echo ""
                    echo -e "${CYAN}Driver Version:${NC}"
                    oc get clusterpolicy gpu-cluster-policy -o jsonpath='{.spec.driver.version}' 2>/dev/null && echo "" || echo "  Using default"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                # Create/Apply ClusterPolicy
                print_header "Create/Apply ClusterPolicy"
                echo ""
                if oc get clusterpolicy gpu-cluster-policy &>/dev/null; then
                    print_info "ClusterPolicy already exists"
                    local current_state=$(oc get clusterpolicy gpu-cluster-policy -o jsonpath='{.status.state}' 2>/dev/null)
                    echo "Current state: $current_state"
                    echo ""
                    read -p "Re-apply ClusterPolicy? (y/N): " reapply
                    if [[ ! "$reapply" =~ ^[Yy]$ ]]; then
                        continue
                    fi
                fi
                
                # Check for GPU nodes
                local gpu_nodes=$(oc get nodes -l feature.node.kubernetes.io/pci-10de.present=true --no-headers 2>/dev/null | wc -l | tr -d ' ')
                if [ "$gpu_nodes" -eq 0 ]; then
                    print_warning "No GPU nodes detected in the cluster"
                    echo "ClusterPolicy requires GPU nodes to function properly."
                    read -p "Create ClusterPolicy anyway? (y/N): " create_anyway
                    if [[ ! "$create_anyway" =~ ^[Yy]$ ]]; then
                        continue
                    fi
                fi
                
                print_step "Applying ClusterPolicy..."
                oc apply -f "$_TROUBLESHOOTING_MENU_DIR/lib/manifests/operators/gpu-clusterpolicy.yaml"
                print_success "ClusterPolicy applied"
                echo ""
                print_info "ClusterPolicy will take a few minutes to initialize."
                print_info "Check status with option 1 or: oc get clusterpolicy"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                # Delete ClusterPolicy
                print_header "Delete ClusterPolicy"
                echo ""
                if ! oc get clusterpolicy gpu-cluster-policy &>/dev/null; then
                    print_info "No ClusterPolicy found"
                    read -p "Press Enter to continue..."
                    continue
                fi
                
                print_warning "This will delete the ClusterPolicy and stop GPU workloads!"
                echo ""
                read -p "Are you sure? (type 'delete' to confirm): " confirm_delete
                if [ "$confirm_delete" = "delete" ]; then
                    print_step "Deleting ClusterPolicy..."
                    oc delete clusterpolicy gpu-cluster-policy
                    print_success "ClusterPolicy deleted"
                else
                    print_info "Operation cancelled"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                check_gpu_operator_status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                fix_gpu_operator_cuda_compatibility
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                pin_nvidia_driver_version
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                # Show GPU Nodes
                print_header "GPU Nodes"
                echo ""
                echo -e "${CYAN}GPU Nodes (NVIDIA PCI device present):${NC}"
                oc get nodes -l feature.node.kubernetes.io/pci-10de.present=true -o wide 2>/dev/null || echo "  No GPU nodes found"
                echo ""
                echo -e "${CYAN}GPU Nodes (nvidia.com/gpu.present label):${NC}"
                oc get nodes -l nvidia.com/gpu.present=true -o wide 2>/dev/null || echo "  No nodes with GPU present label"
                echo ""
                echo -e "${CYAN}GPU Resources:${NC}"
                oc get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu' 2>/dev/null | grep -v "<none>" || echo "  No GPU resources found"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                uncordon_gpu_nodes
                echo ""
                read -p "Press Enter to continue..."
                ;;
            9)
                # Run nvidia-smi
                print_header "Run nvidia-smi on GPU Node"
                echo ""
                local driver_pod=$(oc get pods -n nvidia-gpu-operator -o name 2>/dev/null | grep driver | head -1)
                if [ -z "$driver_pod" ]; then
                    print_error "No NVIDIA driver pod found"
                    echo "Make sure GPU Operator and ClusterPolicy are installed."
                    read -p "Press Enter to continue..."
                    continue
                fi
                
                echo -e "${CYAN}Running nvidia-smi on driver pod...${NC}"
                echo ""
                oc exec -n nvidia-gpu-operator $driver_pod -c nvidia-driver-ctr -- nvidia-smi 2>/dev/null || print_error "Failed to run nvidia-smi"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                print_error "Invalid option. Please select 1-9 or 0."
                sleep 1
                ;;
        esac
    done
}
