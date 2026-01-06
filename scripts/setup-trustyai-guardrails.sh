#!/bin/bash
################################################################################
# TrustyAI Guardrails Setup Script
# 
# This script sets up TrustyAI GuardrailsOrchestrator for AI safety
# 
# Prerequisites:
# - OpenShift cluster with RHOAI 3.0 installed
# - TrustyAI operator installed (check: oc get csv -A | grep trustyai)
# - oc CLI logged in
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source utilities
source "$ROOT_DIR/lib/utils/colors.sh"

# Default namespace
DEFAULT_NAMESPACE="guardrails-demo"

################################################################################
# Functions
################################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check oc login
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift. Please run 'oc login' first."
        exit 1
    fi
    print_success "Logged in as: $(oc whoami)"
    
    # Check for TrustyAI CRDs
    print_step "Checking for TrustyAI CRDs..."
    if oc get crd guardrailsorchestrators.trustyai.opendatahub.io &>/dev/null; then
        print_success "GuardrailsOrchestrator CRD found"
    else
        print_warning "GuardrailsOrchestrator CRD not found"
        print_info "You may need to install the TrustyAI operator first"
        echo ""
        echo "To install TrustyAI operator:"
        echo "  1. Go to OpenShift Console → Operators → OperatorHub"
        echo "  2. Search for 'TrustyAI'"
        echo "  3. Install the operator"
        echo ""
        read -p "Continue anyway? (y/N): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy] ]]; then
            exit 1
        fi
    fi
    
    # Check for TrustyAI operator CSV
    print_step "Checking for TrustyAI operator..."
    if oc get csv -A 2>/dev/null | grep -q trustyai; then
        print_success "TrustyAI operator is installed"
    else
        print_warning "TrustyAI operator CSV not found"
    fi
}

create_namespace() {
    local namespace=$1
    
    print_step "Creating namespace: $namespace"
    if oc get namespace "$namespace" &>/dev/null; then
        print_info "Namespace $namespace already exists"
    else
        oc create namespace "$namespace"
        print_success "Created namespace: $namespace"
    fi
}

deploy_guardrails_orchestrator() {
    local namespace=$1
    
    print_header "Deploying GuardrailsOrchestrator"
    
    # Apply the manifests
    print_step "Applying GuardrailsOrchestrator manifests..."
    oc apply -f "$ROOT_DIR/lib/manifests/trustyai/guardrails-orchestrator.yaml" -n "$namespace"
    
    print_success "GuardrailsOrchestrator manifests applied"
    
    # Wait for deployment
    print_step "Waiting for GuardrailsOrchestrator to be ready..."
    
    local timeout=300
    local elapsed=0
    local interval=10
    
    while [ $elapsed -lt $timeout ]; do
        # Check if the orchestrator pod is running
        local ready_pods=$(oc get pods -n "$namespace" -l app=guardrails-orchestrator -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -c "Running" || echo "0")
        
        if [ "$ready_pods" -gt 0 ]; then
            print_success "GuardrailsOrchestrator is running!"
            break
        fi
        
        echo -n "."
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    if [ $elapsed -ge $timeout ]; then
        print_warning "Timeout waiting for GuardrailsOrchestrator"
        print_info "Check status with: oc get pods -n $namespace"
    fi
}

get_guardrails_url() {
    local namespace=$1
    
    print_header "GuardrailsOrchestrator Endpoints"
    
    # Get route URL
    local route_url=$(oc get route guardrails-orchestrator -n "$namespace" -o jsonpath='{.spec.host}' 2>/dev/null)
    
    if [ -n "$route_url" ]; then
        print_success "External URL: https://$route_url"
    fi
    
    # Get service URL (for internal use)
    local svc_url="guardrails-orchestrator.$namespace.svc.cluster.local:8080"
    print_info "Internal URL: http://$svc_url"
    
    echo ""
    echo "To test the guardrails API:"
    echo ""
    echo "  # Health check"
    echo "  curl -k https://$route_url/health"
    echo ""
    echo "  # Check text for PII"
    echo "  curl -k -X POST https://$route_url/api/v1/text/contents \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"content\": \"My email is test@example.com\"}'"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Sets up TrustyAI GuardrailsOrchestrator for AI safety"
    echo ""
    echo "OPTIONS:"
    echo "  -n, --namespace NAME    Namespace to deploy to (default: $DEFAULT_NAMESPACE)"
    echo "  -c, --check-only        Only check prerequisites, don't deploy"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                      # Deploy to default namespace"
    echo "  $0 -n my-project        # Deploy to specific namespace"
    echo "  $0 --check-only         # Just check if prerequisites are met"
}

################################################################################
# Main
################################################################################

NAMESPACE="$DEFAULT_NAMESPACE"
CHECK_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -c|--check-only)
            CHECK_ONLY=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

print_header "TrustyAI Guardrails Setup"
echo ""
echo "Namespace: $NAMESPACE"
echo ""

# Check prerequisites
check_prerequisites

if [ "$CHECK_ONLY" = true ]; then
    print_success "Prerequisites check complete"
    exit 0
fi

# Create namespace
create_namespace "$NAMESPACE"

# Deploy GuardrailsOrchestrator
deploy_guardrails_orchestrator "$NAMESPACE"

# Show endpoints
get_guardrails_url "$NAMESPACE"

print_header "Setup Complete!"
echo ""
echo "Next steps:"
echo "  1. Configure your LlamaStack to use the guardrails endpoint"
echo "  2. Update your demo app to call guardrails for input/output checking"
echo "  3. Test with: curl -k https://\$(oc get route guardrails-orchestrator -n $NAMESPACE -o jsonpath='{.spec.host}')/health"
echo ""

