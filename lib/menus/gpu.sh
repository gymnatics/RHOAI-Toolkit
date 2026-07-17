#!/bin/bash
################################################################################
# gpu.sh — GPU MachineSet and Hardware Profile interactive functions
# Extracted from rhoai-toolkit.sh
################################################################################

_GPU_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

create_gpu_machineset_interactive() {
    print_header "Create GPU MachineSet"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        echo "Please login first: oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to OpenShift cluster"
    
    local cluster_url=$(oc whoami --show-server 2>/dev/null)
    echo "Cluster: $cluster_url"
    echo ""
    
    local gpu_nodes=$(oc get nodes -l node-role.kubernetes.io/gpu-worker --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local gpu_machinesets=$(oc get machineset -n openshift-machine-api -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | contains("gpu")) | .metadata.name' 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$gpu_nodes" -gt 0 ] || [ "$gpu_machinesets" -gt 0 ]; then
        print_info "Existing GPU resources found:"
        if [ "$gpu_nodes" -gt 0 ]; then
            echo "  GPU Nodes: $gpu_nodes"
            oc get nodes -l node-role.kubernetes.io/gpu-worker --no-headers 2>/dev/null | awk '{print "    - " $1}'
        fi
        if [ "$gpu_machinesets" -gt 0 ]; then
            echo "  GPU MachineSets: $gpu_machinesets"
            oc get machineset -n openshift-machine-api -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | contains("gpu")) | "    - " + .metadata.name' 2>/dev/null
        fi
        echo ""
    else
        print_info "No existing GPU resources found"
        echo ""
    fi
    
    local gpu_script="$SCRIPT_DIR/scripts/create-gpu-machineset.sh"
    if [ ! -f "$gpu_script" ]; then
        print_error "GPU MachineSet script not found at: $gpu_script"
        return 1
    fi
    
    print_step "Launching GPU MachineSet creation script..."
    echo ""
    
    "$gpu_script"
    
    local result=$?
    echo ""
    
    if [ $result -eq 0 ]; then
        print_success "GPU MachineSet creation completed"
    else
        print_warning "GPU MachineSet creation returned with code: $result"
    fi
    
    return $result
}

create_hardware_profile_interactive() {
    print_header "Create GPU Hardware Profile"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        echo "Please login first: oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to OpenShift cluster"
    echo ""
    
    local default_ns="redhat-ods-applications"
    
    echo -e "${CYAN}Enter the namespace where you want to create the hardware profile${NC}"
    echo -e "${YELLOW}Default: ${GREEN}redhat-ods-applications${YELLOW} (global scope - visible in all projects)${NC}"
    echo -e "${YELLOW}Or specify a project namespace for project-scoped profiles${NC}"
    echo ""
    read -p "Namespace [default: redhat-ods-applications]: " input_ns
    local target_ns="${input_ns:-$default_ns}"
    
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_error "Namespace '$target_ns' does not exist"
        read -p "Do you want to create it? (y/n): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc create namespace "$target_ns"
            print_success "Namespace created"
        else
            return 1
        fi
    fi
    
    echo ""
    print_step "Configuring hardware profile resources..."
    echo ""
    
    echo -e "${CYAN}CPU Configuration:${NC}"
    read -p "Default CPU count [2]: " cpu_default
    cpu_default="${cpu_default:-2}"
    read -p "Minimum CPU count [1]: " cpu_min
    cpu_min="${cpu_min:-1}"
    read -p "Maximum CPU count [16]: " cpu_max
    cpu_max="${cpu_max:-16}"
    
    echo ""
    
    echo -e "${CYAN}Memory Configuration:${NC}"
    read -p "Default Memory (e.g., 16Gi) [16Gi]: " mem_default
    mem_default="${mem_default:-16Gi}"
    read -p "Minimum Memory (e.g., 1Gi) [1Gi]: " mem_min
    mem_min="${mem_min:-1Gi}"
    read -p "Maximum Memory (e.g., 64Gi) [64Gi]: " mem_max
    mem_max="${mem_max:-64Gi}"
    
    echo ""
    
    echo -e "${CYAN}GPU Configuration:${NC}"
    read -p "Default GPU count [1]: " gpu_default
    gpu_default="${gpu_default:-1}"
    read -p "Minimum GPU count [1]: " gpu_min
    gpu_min="${gpu_min:-1}"
    read -p "Maximum GPU count [8]: " gpu_max
    gpu_max="${gpu_max:-8}"
    
    echo ""
    
    read -p "Hardware profile name [gpu-profile]: " profile_name
    profile_name="${profile_name:-gpu-profile}"
    read -p "Display name [GPU Profile]: " display_name
    display_name="${display_name:-GPU Profile}"
    
    echo ""
    print_step "Creating hardware profile '$profile_name' in namespace '$target_ns'..."
    echo ""
    
    local template="$_GPU_MENU_DIR/lib/manifests/templates/hardwareprofile-custom.yaml.tmpl"
    export NAMESPACE="$target_ns"
    export PROFILE_NAME="$profile_name"
    export DISPLAY_NAME="$display_name"
    export DEFAULT_CPU="$cpu_default"
    export MIN_CPU="$cpu_min"
    export MAX_CPU="$cpu_max"
    export DEFAULT_MEM="$mem_default"
    export MIN_MEM="$mem_min"
    export MAX_MEM="$mem_max"
    export DEFAULT_GPU="$gpu_default"
    export MIN_GPU="$gpu_min"
    export MAX_GPU="$gpu_max"
    
    envsubst < "$template" | oc apply -f -
    
    local apply_result=$?
    unset NAMESPACE PROFILE_NAME DISPLAY_NAME DEFAULT_CPU MIN_CPU MAX_CPU DEFAULT_MEM MIN_MEM MAX_MEM DEFAULT_GPU MIN_GPU MAX_GPU
    
    if [ $apply_result -eq 0 ]; then
        echo ""
        print_success "Hardware profile '$profile_name' created successfully in namespace '$target_ns'"
        echo ""
        
        print_step "Verifying..."
        oc get hardwareprofile "$profile_name" -n "$target_ns" -o custom-columns=NAME:.metadata.name,DISPLAY:.metadata.annotations.'opendatahub\.io/display-name',DISABLED:.metadata.annotations.'opendatahub\.io/disabled'
        
        echo ""
        if [ "$target_ns" == "redhat-ods-applications" ]; then
            print_info "✓ Global profile created - visible in ALL data science projects"
            print_info "The hardware profile should now appear in the RHOAI dashboard"
            print_info "when deploying models in any project."
        else
            print_info "✓ Project-scoped profile created - visible only in '$target_ns'"
            print_info "The hardware profile will appear in the RHOAI dashboard"
            print_info "when deploying models in the '$target_ns' project."
            echo ""
            print_warning "To create a global profile visible in all projects,"
            print_warning "create it in the 'redhat-ods-applications' namespace."
        fi
        echo ""
        
        return 0
    else
        print_error "Failed to create hardware profile"
        return 1
    fi
}

create_hardware_profile_quick() {
    print_header "Quick GPU Hardware Profile Setup"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        return 1
    fi
    
    local template_dir="$SCRIPT_DIR/lib/manifests/templates"
    
    echo -e "${CYAN}Enter the namespace for hardware profiles${NC}"
    echo -e "${YELLOW}Default: redhat-ods-applications (global - visible in all projects)${NC}"
    echo ""
    read -p "Namespace [redhat-ods-applications]: " input_ns
    local target_ns="${input_ns:-redhat-ods-applications}"
    
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_error "Namespace '$target_ns' does not exist"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}Select GPU Hardware Profile Size:${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} Small  - For 4B-8B models (Qwen3-4B, Llama-3-8B)"
    echo "         CPU: 2 (max 8) | Memory: 8Gi (max 24Gi) | GPU: 1"
    echo "         Best for: g6e.xlarge, g6e.2xlarge"
    echo ""
    echo -e "${YELLOW}2)${NC} Medium - For 8B-30B models (Qwen-14B, quantized 70B)"
    echo "         CPU: 4 (max 16) | Memory: 32Gi (max 64Gi) | GPU: 1"
    echo "         Best for: g6e.4xlarge, g6e.8xlarge"
    echo ""
    echo -e "${YELLOW}3)${NC} Large  - For 70B+ models, multi-GPU"
    echo "         CPU: 16 (max 96) | Memory: 128Gi (max 512Gi) | GPU: 4-8"
    echo "         Best for: p5.48xlarge, g6e.48xlarge"
    echo ""
    echo -e "${YELLOW}4)${NC} All    - Create all three profiles ${GREEN}[Recommended]${NC}"
    echo ""
    
    read -p "Select option (1-4): " choice
    
    export NAMESPACE="$target_ns"
    
    case $choice in
        1)
            if [ -f "$template_dir/hardwareprofile-gpu-small.yaml.tmpl" ]; then
                envsubst < "$template_dir/hardwareprofile-gpu-small.yaml.tmpl" | oc apply -f -
                print_success "Created gpu-small profile"
            else
                print_error "Template not found"
                return 1
            fi
            ;;
        2)
            if [ -f "$template_dir/hardwareprofile-gpu-medium.yaml.tmpl" ]; then
                envsubst < "$template_dir/hardwareprofile-gpu-medium.yaml.tmpl" | oc apply -f -
                print_success "Created gpu-medium profile"
            else
                print_error "Template not found"
                return 1
            fi
            ;;
        3)
            if [ -f "$template_dir/hardwareprofile-gpu-large.yaml.tmpl" ]; then
                envsubst < "$template_dir/hardwareprofile-gpu-large.yaml.tmpl" | oc apply -f -
                print_success "Created gpu-large profile"
            else
                print_error "Template not found"
                return 1
            fi
            ;;
        4)
            for size in small medium large; do
                local template="$template_dir/hardwareprofile-gpu-${size}.yaml.tmpl"
                if [ -f "$template" ]; then
                    envsubst < "$template" | oc apply -f -
                    print_success "Created gpu-${size} profile"
                fi
            done
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    unset NAMESPACE
    
    echo ""
    print_header "Hardware Profiles in $target_ns"
    oc get hardwareprofile -n "$target_ns" 2>/dev/null || echo "No profiles found"
    
    echo ""
    print_info "These profiles include:"
    print_info "  • Node selector: nvidia.com/gpu.present=true"
    print_info "  • Toleration: nvidia.com/gpu:NoSchedule"
    print_info "  • Kueue scheduling with default queue"
    echo ""
    print_info "Use these when deploying models in the RHOAI dashboard"
}
