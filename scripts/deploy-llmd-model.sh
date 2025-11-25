#!/bin/bash

################################################################################
# Deploy Model with llm-d (Interactive)
################################################################################
# This script provides an interactive interface to deploy models using llm-d
# serving runtime in RHOAI 3.0.
#
# Features:
# - Pre-defined model catalog (Qwen3, Llama, Granite)
# - Custom model URI support
# - Namespace selection/creation
# - Resource configuration
# - Tool calling configuration
# - Authentication setup
#
# Usage: ./scripts/deploy-llmd-model.sh
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required libraries
source "$SCRIPT_DIR/../lib/utils/colors.sh"
source "$SCRIPT_DIR/../lib/utils/common.sh"
source "$SCRIPT_DIR/../lib/functions/model-deployment.sh"

################################################################################
# Main
################################################################################

main() {
    print_header "Interactive Model Deployment with llm-d"
    
    echo -e "${YELLOW}This script will help you deploy a model using llm-d serving runtime.${NC}"
    echo ""
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift. Please run 'oc login' first."
        exit 1
    fi
    print_success "Logged in to OpenShift: $(oc whoami --show-server)"
    echo ""
    
    # Check if RHOAI is installed
    if ! oc get datasciencecluster default-dsc &>/dev/null; then
        print_error "RHOAI does not appear to be installed."
        print_info "Please run ./complete-setup.sh first."
        exit 1
    fi
    print_success "RHOAI is installed"
    echo ""
    
    # Check if llm-d prerequisites are met
    print_step "Checking llm-d prerequisites..."
    
    local missing_prereqs=false
    
    if ! oc get gatewayclass openshift-ai-inference &>/dev/null; then
        print_warning "GatewayClass 'openshift-ai-inference' not found"
        missing_prereqs=true
    fi
    
    if ! oc get gateway openshift-ai-inference -n openshift-ingress &>/dev/null; then
        print_warning "Gateway 'openshift-ai-inference' not found"
        missing_prereqs=true
    fi
    
    if ! oc get leaderworkersetoperator cluster -n openshift-lws-operator &>/dev/null; then
        print_warning "LeaderWorkerSetOperator instance not found"
        missing_prereqs=true
    fi
    
    if [ "$missing_prereqs" = true ]; then
        print_error "Some llm-d prerequisites are missing."
        print_info "Run ./scripts/setup-llmd.sh to configure llm-d infrastructure."
        echo ""
        read -p "Continue anyway? (y/N): " continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "All llm-d prerequisites are configured"
    fi
    
    echo ""
    
    # Deploy model interactively
    deploy_llmd_model_interactive
    
    if [ $? -eq 0 ]; then
        echo ""
        print_header "Deployment Complete!"
        echo ""
        print_success "Your model deployment has been initiated."
        echo ""
        print_info "Next steps:"
        echo "  1. Wait 5-10 minutes for the model to be ready"
        echo "  2. Check status: oc get llmisvc -n <namespace>"
        echo "  3. Generate token: ./demo/generate-maas-token.sh"
        echo "  4. Test model: ./demo/test-maas-api.sh"
        echo ""
    else
        print_error "Model deployment failed or was cancelled."
        exit 1
    fi
}

main "$@"

