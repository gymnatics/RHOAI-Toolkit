#!/bin/bash
################################################################################
# Integrated OpenShift + RHOAI + GPU Setup Workflow (Modular Version)
# 
# This script orchestrates the complete installation of:
# - OpenShift cluster (optional)
# - GPU worker nodes (optional)
# - RHOAI with all dependencies
# - GenAI Playground and MaaS UI features
#
# This is a refactored version using modular functions and separate manifests
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all required libraries
source "$SCRIPT_DIR/lib/utils/colors.sh"
source "$SCRIPT_DIR/lib/utils/common.sh"
source "$SCRIPT_DIR/lib/functions/operators.sh"
source "$SCRIPT_DIR/lib/functions/rhoai.sh"

# Global variables
SKIP_OPENSHIFT=false
SKIP_GPU=false
SKIP_RHOAI=false
RHOAI_VERSION=""

################################################################################
# Parse command line arguments
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-openshift)
                SKIP_OPENSHIFT=true
                shift
                ;;
            --skip-gpu)
                SKIP_GPU=true
                shift
                ;;
            --skip-rhoai)
                SKIP_RHOAI=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Integrated OpenShift + RHOAI + GPU Setup Workflow

OPTIONS:
    --skip-openshift    Skip OpenShift installation (use existing cluster)
    --skip-gpu          Skip GPU worker node creation
    --skip-rhoai        Skip RHOAI installation
    --help              Show this help message

EXAMPLES:
    # Full installation (OpenShift + GPU + RHOAI)
    $0

    # Install RHOAI on existing cluster with GPU nodes
    $0 --skip-openshift --skip-gpu

    # Install only RHOAI (no OpenShift, no GPU)
    $0 --skip-openshift --skip-gpu

EOF
}

################################################################################
# RHOAI Version Selection
################################################################################

select_rhoai_version() {
    print_header "Select RHOAI Version"
    
    echo -e "${BLUE}Available RHOAI versions:${NC}"
    echo ""
    echo "  1) RHOAI 2.17 (OpenShift 4.16+)"
    echo "  2) RHOAI 2.18 (OpenShift 4.16+)"
    echo "  3) RHOAI 2.19 (OpenShift 4.17+)"
    echo "  4) RHOAI 2.20 (OpenShift 4.17+)"
    echo "  5) RHOAI 2.21 (OpenShift 4.17+)"
    echo "  6) RHOAI 2.22 (OpenShift 4.18+)"
    echo "  7) RHOAI 2.23 (OpenShift 4.19+)"
    echo "  8) RHOAI 2.24 (OpenShift 4.20+)"
    echo "  9) RHOAI 2.25 (OpenShift 4.20+)"
    echo " 10) RHOAI 3.0 (OpenShift 4.19+) ⭐ NEW!"
    echo ""
    
    while true; do
        read -p "Enter choice [1-10]: " choice
        
        case $choice in
            1) RHOAI_VERSION="2.17"; break ;;
            2) RHOAI_VERSION="2.18"; break ;;
            3) RHOAI_VERSION="2.19"; break ;;
            4) RHOAI_VERSION="2.20"; break ;;
            5) RHOAI_VERSION="2.21"; break ;;
            6) RHOAI_VERSION="2.22"; break ;;
            7) RHOAI_VERSION="2.23"; break ;;
            8) RHOAI_VERSION="2.24"; break ;;
            9) RHOAI_VERSION="2.25"; break ;;
            10) RHOAI_VERSION="3.0"; break ;;
            *) echo "Invalid choice. Please enter 1-10." ;;
        esac
    done
    
    print_success "Selected RHOAI version: $RHOAI_VERSION"
}

################################################################################
# Main Installation Phases
################################################################################

install_openshift() {
    print_header "PHASE 1: OpenShift Installation"
    
    if [ "$SKIP_OPENSHIFT" = true ]; then
        print_warning "Skipping OpenShift installation (--skip-openshift flag)"
        return
    fi
    
    if [ -f "$SCRIPT_DIR/scripts/openshift-installer-master.sh" ]; then
        print_step "Calling OpenShift installer script..."
        "$SCRIPT_DIR/scripts/openshift-installer-master.sh"
    else
        print_warning "OpenShift installer script not found"
        print_info "Please install OpenShift manually or run: ./scripts/openshift-installer-master.sh"
        read -p "Press Enter when OpenShift is installed and you're logged in with oc..."
    fi
}

install_gpu_nodes() {
    print_header "PHASE 2: GPU Worker Nodes"
    
    if [ "$SKIP_GPU" = true ]; then
        print_warning "Skipping GPU node creation (--skip-gpu flag)"
        return
    fi
    
    echo -e "${YELLOW}GPU nodes can be created now or later.${NC}"
    echo "You can always create GPU nodes later using: ./scripts/create-gpu-machineset.sh"
    echo ""
    read -p "Create GPU nodes now? (y/n): " create_gpu
    
    if [[ "$create_gpu" =~ ^[Yy]$ ]]; then
        if [ -f "$SCRIPT_DIR/scripts/create-gpu-machineset.sh" ]; then
            "$SCRIPT_DIR/scripts/create-gpu-machineset.sh"
        else
            print_error "GPU MachineSet script not found at ./scripts/create-gpu-machineset.sh"
        fi
    else
        print_info "Skipping GPU node creation. You can create them later."
    fi
}

install_rhoai() {
    print_header "PHASE 3: RHOAI Installation"
    
    if [ "$SKIP_RHOAI" = true ]; then
        print_warning "Skipping RHOAI installation (--skip-rhoai flag)"
        return
    fi
    
    # Select RHOAI version
    select_rhoai_version
    
    echo ""
    print_info "This will install:"
    echo "  • Node Feature Discovery (NFD)"
    echo "  • NVIDIA GPU Operator"
    echo "  • Red Hat Connectivity Link (RHCL/Kuadrant)"
    if [[ "$RHOAI_VERSION" == "3.0" ]]; then
        echo "  • Leader Worker Set (LWS) Operator"
        echo "  • Kueue Operator"
    fi
    echo "  • Red Hat OpenShift AI $RHOAI_VERSION"
    echo "  • GenAI Playground"
    echo "  • Model as a Service (MaaS) UI"
    echo ""
    
    read -p "Press Enter to continue with RHOAI installation..."
    
    # Install prerequisite operators using modular functions
    install_nfd_operator
    install_gpu_operator
    install_rhcl_operator
    
    # Install RHOAI 3.0 specific operators
    if [[ "$RHOAI_VERSION" == "3.0" ]]; then
        install_lws_operator
        install_kueue_operator
    fi
    
    # Install RHOAI operator
    install_rhoai_operator "$RHOAI_VERSION"
    
    # Initialize RHOAI
    initialize_rhoai
    
    # Wait for Service Mesh to be ready
    print_step "Waiting for Service Mesh to be installed (this may take 5-10 minutes)..."
    sleep 30
    
    local sm_timeout=600
    local sm_elapsed=0
    until oc get smcp data-science-smcp -n istio-system &>/dev/null; do
        if [ $sm_elapsed -ge $sm_timeout ]; then
            print_warning "Service Mesh not ready yet (continuing anyway)"
            break
        fi
        echo "Waiting for Service Mesh Control Plane... (${sm_elapsed}s elapsed)"
        sleep 15
        sm_elapsed=$((sm_elapsed + 15))
    done
    
    # Create DataScienceCluster
    if [[ "$RHOAI_VERSION" == "3.0" ]]; then
        create_datasciencecluster_v2
    else
        create_datasciencecluster_v1
    fi
    
    # Wait for RHOAI dashboard to be ready
    print_step "Waiting for RHOAI dashboard to be ready..."
    sleep 30
    
    local dash_timeout=300
    local dash_elapsed=0
    until oc get route rhods-dashboard -n redhat-ods-applications &>/dev/null; do
        if [ $dash_elapsed -ge $dash_timeout ]; then
            print_warning "Dashboard not ready yet (continuing anyway)"
            break
        fi
        echo "Waiting for RHOAI dashboard... (${dash_elapsed}s elapsed)"
        sleep 10
        dash_elapsed=$((dash_elapsed + 10))
    done
    
    # Configure dashboard for GenAI and MaaS
    if [[ "$RHOAI_VERSION" == "3.0" ]]; then
        configure_rhoai_dashboard
        create_gpu_hardware_profile
        enable_user_workload_monitoring
    fi
    
    print_success "RHOAI $RHOAI_VERSION installed successfully"
}

################################################################################
# Main execution
################################################################################

main() {
    print_header "Integrated OpenShift + RHOAI + GPU Setup (Modular)"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check prerequisites
    print_step "Checking prerequisites..."
    if ! command -v oc &> /dev/null; then
        print_error "oc CLI not found. Please install OpenShift CLI."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found. Some features may not work properly."
        echo "Install with: brew install jq"
    fi
    
    print_success "Prerequisites check passed"
    echo ""
    
    # Execute installation phases
    install_openshift
    install_gpu_nodes
    install_rhoai
    
    # Final summary
    print_header "Installation Complete!"
    
    echo -e "${GREEN}✓ All components installed successfully${NC}"
    echo ""
    echo "RHOAI Dashboard:"
    if oc get route rhods-dashboard -n redhat-ods-applications &>/dev/null; then
        DASHBOARD_URL=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}')
        echo "  https://$DASHBOARD_URL"
    else
        echo "  Run: oc get route rhods-dashboard -n redhat-ods-applications"
    fi
    echo ""
    echo "Next steps:"
    echo "  1. Access the RHOAI dashboard using the URL above"
    echo "  2. Create GPU MachineSets if needed: ./scripts/create-gpu-machineset.sh"
    echo "  3. Set up MaaS API infrastructure: ./scripts/setup-maas.sh"
    echo ""
    
    if [[ "$RHOAI_VERSION" == "3.0" ]]; then
        echo -e "${CYAN}GenAI Playground and Model as a Service UI are enabled!${NC}"
        echo "To set up MaaS API infrastructure, run: ./scripts/setup-maas.sh"
        echo ""
    fi
}

# Run main function
main "$@"

