#!/bin/bash

################################################################################
# Deploy Model (Interactive)
################################################################################
# This script provides an interactive interface to deploy models using
# available serving runtimes (llm-d, vLLM, etc.) in RHOAI.
#
# Features:
# - Auto-detect available serving runtimes
# - Pre-defined model catalog (Qwen3, Llama, Granite)
# - Custom model URI support
# - Namespace selection/creation
# - Hardware profile detection and selection
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
    print_header "Interactive Model Deployment"
    
    echo -e "${YELLOW}This script will help you deploy a model using available serving runtimes.${NC}"
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
    
    # Deploy model interactively (will auto-detect available runtimes)
    deploy_model_interactive
    
    if [ $? -eq 0 ]; then
        echo ""
        print_header "Deployment Complete!"
        echo ""
        print_success "Your model deployment has been initiated."
        echo ""
        print_info "Next steps:"
        echo "  1. Wait 5-10 minutes for the model to be ready"
        echo "  2. Check status: oc get llmisvc -A  (or inferenceservice -A)"
        echo "  3. Generate token: ./demo/generate-maas-token.sh"
        echo "  4. Test model: ./demo/test-maas-api.sh"
        echo ""
    else
        print_error "Model deployment failed or was cancelled."
        exit 1
    fi
}

main "$@"

