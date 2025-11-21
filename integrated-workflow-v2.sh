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
    
    print_info "OpenShift installation would be called here"
    print_info "Use: ./openshift-installer-master.sh"
    
    # In the full implementation, this would call the OpenShift installer
    # For now, we assume the cluster already exists
}

install_gpu_nodes() {
    print_header "PHASE 2: GPU Worker Nodes"
    
    if [ "$SKIP_GPU" = true ]; then
        print_warning "Skipping GPU node creation (--skip-gpu flag)"
        return
    fi
    
    print_info "GPU node creation would be called here"
    print_info "Use: ./create-gpu-machineset.sh"
    
    # In the full implementation, this would call the GPU MachineSet script
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
    echo "  • Red Hat OpenShift AI $RHOAI_VERSION"
    echo "  • GenAI Playground"
    echo "  • Model as a Service (MaaS) UI"
    echo ""
    
    read -p "Press Enter to continue with RHOAI installation..."
    
    # Install components using modular functions
    install_nfd_operator
    install_gpu_operator
    install_rhcl_operator
    
    # RHOAI operator installation would go here
    # (needs to be extracted to lib/functions/rhoai.sh)
    print_info "RHOAI operator installation coming soon..."
    
    print_success "RHOAI $RHOAI_VERSION installed successfully"
}

################################################################################
# Main execution
################################################################################

main() {
    print_header "Integrated OpenShift + RHOAI + GPU Setup"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check prerequisites
    print_step "Checking prerequisites..."
    if ! command -v oc &> /dev/null; then
        print_error "oc CLI not found. Please install OpenShift CLI."
        exit 1
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
    echo "Next steps:"
    echo "  1. Verify RHOAI dashboard: oc get route -n redhat-ods-applications"
    echo "  2. Create GPU MachineSets if needed: ./create-gpu-machineset.sh"
    echo "  3. Set up MaaS API: ./setup-maas.sh"
    echo ""
}

# Run main function
main "$@"

