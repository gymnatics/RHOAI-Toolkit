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
source "$SCRIPT_DIR/lib/functions/model-deployment.sh"

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
# Helper Functions
################################################################################

approve_pending_installplans() {
    # Check for any pending InstallPlans and approve them automatically
    local pending_plans=$(oc get installplan -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.approved==false) | "\(.metadata.namespace) \(.metadata.name)"' 2>/dev/null)
    
    if [ -n "$pending_plans" ]; then
        echo "$pending_plans" | while read -r namespace plan_name; do
            if [ -n "$namespace" ] && [ -n "$plan_name" ]; then
                print_info "Approving pending InstallPlan: $plan_name in namespace $namespace"
                oc patch installplan "$plan_name" -n "$namespace" --type merge -p '{"spec":{"approved":true}}' &>/dev/null
            fi
        done
    fi
}

################################################################################
# Main Installation Phases
################################################################################

install_openshift() {
    print_header "PHASE 1: OpenShift Installation"
    
    # Check if user explicitly cleared kubeconfig in complete-setup.sh
    if [ "${FORCE_NEW_CLUSTER}" = "true" ]; then
        print_info "Kubeconfig was cleared - proceeding with fresh installation"
        # Skip the existing cluster check
    # Check if already connected to a cluster
    elif oc whoami &>/dev/null; then
        local cluster_url=$(oc whoami --show-server 2>/dev/null || echo "unknown")
        local cluster_user=$(oc whoami 2>/dev/null || echo "unknown")
        
        print_success "Already connected to an OpenShift cluster!"
        echo "  Cluster: $cluster_url"
        echo "  User: $cluster_user"
        echo ""
        
        if [ "$SKIP_OPENSHIFT" = true ]; then
            print_info "Using existing cluster (--skip-openshift flag)"
            return
        fi
        
        echo -e "${YELLOW}Do you want to:${NC}"
        echo "  1) Use this existing cluster"
        echo "  2) Install a new OpenShift cluster (will require logout)"
        echo ""
        read -p "Enter choice [1-2] (default: 1): " cluster_choice
        cluster_choice=${cluster_choice:-1}
        
        if [ "$cluster_choice" = "1" ]; then
            print_success "Using existing cluster"
            return
        else
            print_warning "You'll need to logout and install a new cluster"
            read -p "Press Enter to continue..."
        fi
    else
        if [ "$SKIP_OPENSHIFT" = true ]; then
            print_error "No cluster connection found, but --skip-openshift was specified"
            print_info "Please login to your OpenShift cluster first: oc login <cluster-url>"
            exit 1
        fi
        
        print_info "No existing OpenShift cluster connection detected"
    fi
    
    # Proceed with installation
    if [ -f "$SCRIPT_DIR/scripts/openshift-installer-master.sh" ]; then
        print_step "Calling OpenShift installer script..."
        "$SCRIPT_DIR/scripts/openshift-installer-master.sh" --install-only
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
    
    # Check if GPU nodes already exist
    local gpu_nodes=$(oc get nodes -l node-role.kubernetes.io/gpu-worker --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local gpu_machinesets=$(oc get machineset -n openshift-machine-api -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | contains("gpu")) | .metadata.name' 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$gpu_nodes" -gt 0 ] || [ "$gpu_machinesets" -gt 0 ]; then
        print_success "GPU resources already exist in the cluster!"
        if [ "$gpu_nodes" -gt 0 ]; then
            echo "  GPU Nodes: $gpu_nodes"
            oc get nodes -l node-role.kubernetes.io/gpu-worker --no-headers 2>/dev/null | awk '{print "    - " $1}'
        fi
        if [ "$gpu_machinesets" -gt 0 ]; then
            echo "  GPU MachineSets: $gpu_machinesets"
            oc get machineset -n openshift-machine-api -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | contains("gpu")) | "    - " + .metadata.name' 2>/dev/null
        fi
        echo ""
        read -p "Do you want to create additional GPU nodes? (y/n, default: n): " create_more
        create_more=${create_more:-n}
        
        if [[ ! "$create_more" =~ ^[Yy]$ ]]; then
            print_info "Using existing GPU resources"
            return
        fi
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
    
    # Check if RHOAI is already installed
    if oc get datascienceclusters.datasciencecluster.opendatahub.io default-dsc &>/dev/null; then
        print_success "RHOAI is already installed in this cluster!"
        
        # Try to detect version
        local rhoai_channel=$(oc get subscription rhods-operator -n redhat-ods-operator -o jsonpath='{.spec.channel}' 2>/dev/null || echo "unknown")
        echo "  Channel: $rhoai_channel"
        
        # Check dashboard
        if oc get route rhods-dashboard -n redhat-ods-applications &>/dev/null; then
            local dashboard_url=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null)
            echo "  Dashboard: https://$dashboard_url"
        fi
        echo ""
        
        echo -e "${YELLOW}Do you want to:${NC}"
        echo "  1) Use existing RHOAI installation"
        echo "  2) Reinstall RHOAI (will delete existing installation)"
        echo ""
        read -p "Enter choice [1-2] (default: 1): " rhoai_choice
        rhoai_choice=${rhoai_choice:-1}
        
        if [ "$rhoai_choice" = "1" ]; then
            print_success "Using existing RHOAI installation"
            return
        else
            print_warning "Reinstalling RHOAI will delete all existing data science projects!"
            read -p "Are you sure? (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                print_info "Keeping existing RHOAI installation"
                return
            fi
            print_step "Uninstalling existing RHOAI..."
            oc delete datasciencecluster default-dsc 2>/dev/null || true
            oc delete dscinitializations default-dsci 2>/dev/null || true
            sleep 10
        fi
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
    
    # Approve any pending InstallPlans (Service Mesh may require approval)
    print_step "Checking for pending operator InstallPlans..."
    approve_pending_installplans
    
    # Initialize RHOAI
    initialize_rhoai
    
    # Note: Service Mesh Control Plane is created automatically by DataScienceCluster
    # deployment, not by DSCInitialization. No need to wait for it here.
    print_info "Service Mesh will be deployed automatically with DataScienceCluster"
    
    # Create DataScienceCluster
    if [[ "$RHOAI_VERSION" == "3.0" ]]; then
        create_datasciencecluster_v2
    else
        create_datasciencecluster_v1
    fi
    
    # Wait for RHOAI dashboard to be ready
    print_step "Waiting for RHOAI dashboard deployment to be ready..."
    
    # First, wait for the dashboard deployment and service to exist
    local deploy_timeout=300
    local deploy_elapsed=0
    until oc get deployment rhods-dashboard -n redhat-ods-applications &>/dev/null && \
          oc get svc rhods-dashboard -n redhat-ods-applications &>/dev/null; do
        if [ $deploy_elapsed -ge $deploy_timeout ]; then
            print_error "Dashboard deployment/service not ready after ${deploy_timeout}s"
            return 1
        fi
        echo "Waiting for dashboard deployment and service... (${deploy_elapsed}s elapsed)"
        sleep 10
        deploy_elapsed=$((deploy_elapsed + 10))
    done
    
    # Wait for deployment to be ready (2/2 replicas)
    print_step "Waiting for dashboard pods to be ready..."
    oc wait --for=condition=Available deployment/rhods-dashboard \
        -n redhat-ods-applications --timeout=300s || true
    
    print_success "Dashboard deployment is ready"
    
    # Check if route exists, create it if not (handles RHOAI 3.0 fresh install timing issue)
    print_step "Checking for dashboard route..."
    if ! oc get route rhods-dashboard -n redhat-ods-applications &>/dev/null; then
        print_warning "Dashboard route not found (common on fresh RHOAI 3.0 installs)"
        print_step "Creating dashboard route..."
        
        cat <<'EOF' | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: rhods-dashboard
  namespace: redhat-ods-applications
  labels:
    app: rhods-dashboard
spec:
  port:
    targetPort: https
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: reencrypt
  to:
    kind: Service
    name: rhods-dashboard
    weight: 100
  wildcardPolicy: None
EOF
        
        if oc get route rhods-dashboard -n redhat-ods-applications &>/dev/null; then
            print_success "Dashboard route created successfully"
        else
            print_error "Failed to create dashboard route"
            return 1
        fi
    else
        print_success "Dashboard route already exists"
    fi
    
    # Configure dashboard for GenAI and MaaS
    if [[ "$RHOAI_VERSION" == "3.0" ]]; then
        configure_rhoai_dashboard
        create_gpu_hardware_profile
        configure_gpu_resourceflavor
        setup_llmd_infrastructure  # Setup llm-d infrastructure (per CAI Guide)
        enable_user_workload_monitoring
        
        # Optional: Deploy a model interactively
        echo ""
        deploy_llmd_model_interactive || true  # Don't fail if user skips or deployment fails
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
    
    # Ensure we exit with success
    return 0
}

# Run main function
main "$@"

