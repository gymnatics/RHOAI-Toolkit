#!/bin/bash
################################################################################
# Setup Demo Model for MaaS
################################################################################
# Deploys an LLMInferenceService model for MaaS demo.
# Handles all infrastructure prerequisites automatically.
#
# Usage:
#   ./setup-demo-model.sh                      # Interactive mode
#   ./setup-demo-model.sh -n myns -m qwen3-4b  # Specify namespace and model
#   ./setup-demo-model.sh --list               # List available models
#   ./setup-demo-model.sh --delete -n myns     # Delete model
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/manifests"

# Source library functions
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/infrastructure.sh"
source "$SCRIPT_DIR/lib/model-catalog.sh"
source "$SCRIPT_DIR/lib/model-discovery.sh"
source "$SCRIPT_DIR/lib/tiers.sh"

# Default values
NAMESPACE=""
MODEL_KEY=""
AUTH_ENABLED="true"
DELETE_MODE=false
LIST_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -m|--model)
            MODEL_KEY="$2"
            shift 2
            ;;
        --no-auth)
            AUTH_ENABLED="false"
            shift
            ;;
        --delete)
            DELETE_MODE=true
            shift
            ;;
        --list)
            LIST_MODE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -n, --namespace NS   Deploy to namespace NS"
            echo "  -m, --model KEY      Model from catalog (qwen3-4b, llama-3.2-3b, etc)"
            echo "  --no-auth            Disable authentication"
            echo "  --delete             Delete model"
            echo "  --list               List available models"
            echo "  -h, --help           Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

################################################################################
# List Mode
################################################################################

if [ "$LIST_MODE" = true ]; then
    list_catalog_models
    exit 0
fi

################################################################################
# Delete Mode
################################################################################

if [ "$DELETE_MODE" = true ]; then
    print_header "Delete Demo Model"
    
    check_oc_login || exit 1
    
    if [ -z "$NAMESPACE" ]; then
        list_models
        echo ""
        read -p "Namespace to delete from: " NAMESPACE
    fi
    
    if [ -z "$NAMESPACE" ]; then
        print_error "Namespace required"
        exit 1
    fi
    
    print_step "Deleting LLMInferenceServices in $NAMESPACE..."
    oc delete llminferenceservice --all -n "$NAMESPACE" 2>/dev/null || true
    
    print_success "Cleanup complete"
    exit 0
fi

################################################################################
# Deploy Mode
################################################################################

print_header "Setup Demo Model for MaaS"

# Check prerequisites
print_step "Checking prerequisites..."
check_oc_login || exit 1
check_rhoai || exit 1
check_llmisvc_crd || exit 1

# Check GPU nodes
if ! check_gpu_nodes; then
    print_warning "Continuing without GPU verification"
fi

# Setup infrastructure
print_header "Setting Up Infrastructure"

ensure_lws_crd "$MANIFESTS_DIR" || exit 1
ensure_gateway_tls || true
check_maas_gateway || print_warning "MaaS gateway not ready - model will deploy but may not be accessible externally"

# Select model
print_header "Model Selection"

if [ -z "$MODEL_KEY" ]; then
    list_catalog_models
    read -p "Enter model key: " MODEL_KEY
fi

if ! parse_model_info "$MODEL_KEY"; then
    print_error "Unknown model: $MODEL_KEY"
    list_catalog_models
    exit 1
fi

print_success "Selected: $MODEL_DISPLAY_NAME"
print_info "URI: $MODEL_URI"
print_info "Tool parser: $TOOL_PARSER"

# Set namespace
if [ -z "$NAMESPACE" ]; then
    read -p "Namespace [maas-demo]: " NAMESPACE
    NAMESPACE=${NAMESPACE:-maas-demo}
fi

# Create namespace if needed
if ! oc get project "$NAMESPACE" &>/dev/null; then
    print_step "Creating namespace: $NAMESPACE"
    oc new-project "$NAMESPACE"
fi
oc project "$NAMESPACE" >/dev/null
print_success "Using namespace: $NAMESPACE"

# Export variables for envsubst
export MODEL_NAME="$MODEL_KEY"
export MODEL_DISPLAY_NAME
export MODEL_URI
export TOOL_PARSER
export AUTH_ENABLED

################################################################################
# Deploy Model
################################################################################

print_header "Deploying Model"

print_step "Creating LLMInferenceService..."
apply_manifest "$MANIFESTS_DIR/llminferenceservice.yaml" "$NAMESPACE"
print_success "LLMInferenceService created"

# Wait for model
print_step "Waiting for model to be ready..."
echo "This may take several minutes for the first deployment..."

for i in {1..60}; do
    STATUS=$(oc get llminferenceservice "$MODEL_KEY" -n "$NAMESPACE" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    
    if [ "$STATUS" = "True" ]; then
        print_success "Model is ready!"
        break
    fi
    
    # Show progress
    REASON=$(oc get llminferenceservice "$MODEL_KEY" -n "$NAMESPACE" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)
    echo -ne "\r  Status: ${REASON:-Initializing}... (${i}/60)"
    
    sleep 10
done

echo ""

# Check final status
STATUS=$(oc get llminferenceservice "$MODEL_KEY" -n "$NAMESPACE" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)

if [ "$STATUS" != "True" ]; then
    print_warning "Model not ready yet. Check status with:"
    echo "  oc get llminferenceservice $MODEL_KEY -n $NAMESPACE -o yaml"
    echo ""
    echo "Common issues:"
    echo "  - GPU scheduling: check pod events"
    echo "  - Image pull: check pod logs"
fi

################################################################################
# Setup Tier Testing Resources
################################################################################

print_header "Setting up Tier Testing"

# Create tier groups, ServiceAccounts, RBAC, and tokens
setup_tier_testing "$NAMESPACE"

################################################################################
# Apply AuthPolicy Fix for Tier-Based Rate Limiting
################################################################################

print_header "Applying AuthPolicy Fix"

# Wait a moment for the AuthPolicy to be created by odh-model-controller
sleep 5

if check_authpolicy_tier_fix_needed; then
    print_step "Applying AuthPolicy fix for tier-based rate limiting..."
    apply_authpolicy_tier_fix "$MANIFESTS_DIR"
else
    print_success "AuthPolicy tier lookup already configured"
fi

################################################################################
# Apply Critical Tier Fixes
################################################################################

print_header "Applying Tier Rate Limiting Fixes"

# Fix 1: Update tier-to-group-mapping to use SA usernames
# (TokenReview doesn't return OpenShift groups, only system groups)
fix_tier_to_group_mapping "$NAMESPACE"

# Fix 2: Patch AuthPolicy to include username in tier lookup
fix_authpolicy_username_in_groups

# Fix 3: Delete conflicting UI-created TokenRateLimitPolicies
cleanup_ui_tier_policies

# Apply TokenRateLimitPolicy if CRD exists
if check_tokenratelimitpolicy_crd; then
    print_step "Applying TokenRateLimitPolicy..."
    if [ -f "$MANIFESTS_DIR/tiers/tokenratelimitpolicy.yaml" ]; then
        oc apply -f "$MANIFESTS_DIR/tiers/tokenratelimitpolicy.yaml" 2>/dev/null || true
        print_success "TokenRateLimitPolicy applied"
        
        # Verify our policy is enforced
        sleep 3
        local enforced
        enforced=$(oc get tokenratelimitpolicy maas-tier-token-rate-limits -n openshift-ingress \
            -o jsonpath='{.status.conditions[?(@.type=="Enforced")].status}' 2>/dev/null)
        if [ "$enforced" = "True" ]; then
            print_success "TokenRateLimitPolicy is enforced"
        else
            print_warning "TokenRateLimitPolicy may not be enforced - retrying..."
            cleanup_ui_tier_policies
            oc apply -f "$MANIFESTS_DIR/tiers/tokenratelimitpolicy.yaml" 2>/dev/null || true
        fi
    fi
fi

# Clear caches to ensure fresh tier resolution
clear_rate_limit_caches

################################################################################
# Summary
################################################################################

CLUSTER_DOMAIN=$(get_cluster_domain)
MAAS_ENDPOINT="inference-gateway.${CLUSTER_DOMAIN}"

print_header "Deployment Complete!"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Model Deployed Successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Model:      ${GREEN}${MODEL_DISPLAY_NAME}${NC}"
echo -e "  Namespace:  ${GREEN}${NAMESPACE}${NC}"
echo -e "  Endpoint:   ${GREEN}https://${MAAS_ENDPOINT}${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${CYAN}Test the API:${NC}"
echo ""
echo "# Generate token"
echo "TOKEN=\$(oc create token default -n $NAMESPACE --duration=1h --audience=https://kubernetes.default.svc)"
echo ""
echo "# Chat completion"
echo "curl -sk https://${MAAS_ENDPOINT}/${NAMESPACE}/${MODEL_KEY}/v1/chat/completions \\"
echo "  -H \"Authorization: Bearer \$TOKEN\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"model\": \"${MODEL_KEY}\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'"
echo ""

echo -e "${CYAN}Next steps:${NC}"
echo "  1. Deploy the Streamlit demo app:"
echo "     ./deploy-app.sh -n $NAMESPACE"
echo ""
echo "  2. Or run locally:"
echo "     ./run-demo.sh"
