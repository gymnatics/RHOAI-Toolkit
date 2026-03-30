#!/bin/bash
################################################################################
# Deploy MaaS Demo Streamlit App to OpenShift
################################################################################
# Deploys the Streamlit MaaS demo app to your OpenShift cluster.
#
# Usage:
#   ./deploy-app.sh                     # Interactive mode
#   ./deploy-app.sh -n maas-demo        # Specify namespace
#   ./deploy-app.sh -m maas-demo/qwen3-4b  # Specify model
#   ./deploy-app.sh --delete            # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/manifests"

# Source library functions
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/model-discovery.sh"

# Default values
APP_NAME="maas-demo"
APP_NAMESPACE=""
MODEL_NAMESPACE=""
MODEL_NAME=""
DELETE_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            APP_NAMESPACE="$2"
            shift 2
            ;;
        -m|--model)
            IFS='/' read -r MODEL_NAMESPACE MODEL_NAME <<< "$2"
            shift 2
            ;;
        --delete)
            DELETE_MODE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -n, --namespace NS    Deploy to namespace NS"
            echo "  -m, --model NS/NAME   Use model NS/NAME"
            echo "  --delete              Remove deployment"
            echo "  -h, --help            Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

################################################################################
# Delete Mode
################################################################################

if [ "$DELETE_MODE" = true ]; then
    print_header "Removing MaaS Demo App"
    
    if [ -z "$APP_NAMESPACE" ]; then
        read -p "Namespace to delete from: " APP_NAMESPACE
    fi
    
    if [ -z "$APP_NAMESPACE" ]; then
        print_error "Namespace required"
        exit 1
    fi
    
    print_step "Deleting resources from $APP_NAMESPACE..."
    
    oc delete route maas-demo -n "$APP_NAMESPACE" --ignore-not-found=true
    oc delete service maas-demo -n "$APP_NAMESPACE" --ignore-not-found=true
    oc delete deployment maas-demo -n "$APP_NAMESPACE" --ignore-not-found=true
    oc delete secret maas-demo-token -n "$APP_NAMESPACE" --ignore-not-found=true
    oc delete secret maas-demo-tier-tokens -n "$APP_NAMESPACE" --ignore-not-found=true
    oc delete configmap maas-demo-code -n "$APP_NAMESPACE" --ignore-not-found=true
    oc delete serviceaccount maas-demo-app -n "$APP_NAMESPACE" --ignore-not-found=true
    
    print_success "Cleanup complete"
    exit 0
fi

################################################################################
# Deploy Mode
################################################################################

print_header "Deploy MaaS Demo App to OpenShift"

# Check prerequisites
print_step "Checking prerequisites..."
check_oc_login || exit 1
print_success "Logged in to OpenShift"

CLUSTER_DOMAIN=$(get_cluster_domain)
if [ -z "$CLUSTER_DOMAIN" ]; then
    print_error "Could not determine cluster domain"
    exit 1
fi
print_success "Cluster domain: $CLUSTER_DOMAIN"

# Find model if not specified
if [ -z "$MODEL_NAME" ]; then
    print_step "Finding deployed models..."
    list_models
    echo ""
    
    SELECTED=$(select_model)
    if [ -z "$SELECTED" ]; then
        print_error "No model selected"
        exit 1
    fi
    parse_model "$SELECTED"
fi
print_success "Using model: $MODEL_NAMESPACE/$MODEL_NAME"

# Set namespace
if [ -z "$APP_NAMESPACE" ]; then
    read -p "Deploy app to namespace [$MODEL_NAMESPACE]: " APP_NAMESPACE
    APP_NAMESPACE=${APP_NAMESPACE:-$MODEL_NAMESPACE}
fi

# Create namespace if needed
if ! oc get project "$APP_NAMESPACE" &>/dev/null; then
    print_step "Creating namespace: $APP_NAMESPACE"
    oc new-project "$APP_NAMESPACE"
fi
oc project "$APP_NAMESPACE" >/dev/null
print_success "Using namespace: $APP_NAMESPACE"

# Export variables for envsubst
export APP_NAMESPACE
export MODEL_NAMESPACE
export MODEL_NAME
export MAAS_ENDPOINT="inference-gateway.${CLUSTER_DOMAIN}"

################################################################################
# Create Resources
################################################################################

print_header "Creating Application Resources"

# Create ConfigMap with app code
print_step "Creating ConfigMap with app code..."
oc create configmap maas-demo-code \
    --from-file=app.py="$SCRIPT_DIR/app.py" \
    --from-file=requirements.txt="$SCRIPT_DIR/requirements.txt" \
    -n "$APP_NAMESPACE" \
    --dry-run=client -o yaml | oc apply -f -
print_success "ConfigMap created"

# Create ServiceAccount
print_step "Creating ServiceAccount..."
apply_manifest "$MANIFESTS_DIR/serviceaccount.yaml" "$APP_NAMESPACE"
print_success "ServiceAccount created"

# Create RoleBinding in model namespace
print_step "Creating RoleBinding for model access..."
apply_manifest "$MANIFESTS_DIR/rolebinding.yaml" "$MODEL_NAMESPACE"
print_success "RoleBinding created"

# Generate token
print_step "Generating API token..."
TOKEN=$(generate_maas_token "maas-demo-app" "$APP_NAMESPACE" "24h")
if [ -z "$TOKEN" ]; then
    print_error "Failed to generate token"
    exit 1
fi
print_success "Token generated (valid for 24 hours)"

# Create Secret with token
print_step "Creating Secret with API token..."
oc create secret generic maas-demo-token \
    --from-literal=token="$TOKEN" \
    -n "$APP_NAMESPACE" \
    --dry-run=client -o yaml | oc apply -f -
print_success "Secret created"

# Generate tier tokens (if tier ServiceAccounts exist)
print_step "Generating tier tokens..."
FREE_TOKEN=""
PREMIUM_TOKEN=""
ENTERPRISE_TOKEN=""

# Check if tier ServiceAccounts exist and generate tokens
if oc get sa tier-free-sa -n "$APP_NAMESPACE" &>/dev/null; then
    FREE_TOKEN=$(oc create token tier-free-sa -n "$APP_NAMESPACE" --duration=24h --audience=https://kubernetes.default.svc 2>/dev/null || echo "")
fi
if oc get sa tier-premium-sa -n "$APP_NAMESPACE" &>/dev/null; then
    PREMIUM_TOKEN=$(oc create token tier-premium-sa -n "$APP_NAMESPACE" --duration=24h --audience=https://kubernetes.default.svc 2>/dev/null || echo "")
fi
if oc get sa tier-enterprise-sa -n "$APP_NAMESPACE" &>/dev/null; then
    ENTERPRISE_TOKEN=$(oc create token tier-enterprise-sa -n "$APP_NAMESPACE" --duration=24h --audience=https://kubernetes.default.svc 2>/dev/null || echo "")
fi

# Create tier tokens secret if any tier tokens were generated
if [ -n "$FREE_TOKEN" ] || [ -n "$PREMIUM_TOKEN" ] || [ -n "$ENTERPRISE_TOKEN" ]; then
    print_step "Creating tier tokens secret..."
    oc create secret generic maas-demo-tier-tokens \
        --from-literal=free="${FREE_TOKEN:-placeholder}" \
        --from-literal=premium="${PREMIUM_TOKEN:-placeholder}" \
        --from-literal=enterprise="${ENTERPRISE_TOKEN:-placeholder}" \
        -n "$APP_NAMESPACE" \
        --dry-run=client -o yaml | oc apply -f -
    print_success "Tier tokens secret created"
    
    # Report which tiers are available
    [ -n "$FREE_TOKEN" ] && print_info "  - Free tier token: ✓"
    [ -n "$PREMIUM_TOKEN" ] && print_info "  - Premium tier token: ✓"
    [ -n "$ENTERPRISE_TOKEN" ] && print_info "  - Enterprise tier token: ✓"
else
    print_warning "No tier ServiceAccounts found - tier switching will not work"
    print_info "Run './maas-toolkit.sh tiers' to create tier ServiceAccounts"
fi

# Create Deployment
print_step "Creating Deployment..."
apply_manifest "$MANIFESTS_DIR/deployment.yaml" "$APP_NAMESPACE"
print_success "Deployment created"

# Create Service
print_step "Creating Service..."
apply_manifest "$MANIFESTS_DIR/service.yaml" "$APP_NAMESPACE"
print_success "Service created"

# Create Route
print_step "Creating Route..."
apply_manifest "$MANIFESTS_DIR/route.yaml" "$APP_NAMESPACE"
print_success "Route created"

################################################################################
# Wait for Deployment
################################################################################

print_header "Waiting for Deployment"

wait_for_deployment "maas-demo" "$APP_NAMESPACE" 300

################################################################################
# Summary
################################################################################

APP_URL=$(oc get route maas-demo -n "$APP_NAMESPACE" -o jsonpath='{.spec.host}')

print_header "Deployment Complete!"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}MaaS Demo App Deployed Successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  App URL:    ${GREEN}https://${APP_URL}${NC}"
echo -e "  Namespace:  ${GREEN}${APP_NAMESPACE}${NC}"
echo -e "  Model:      ${GREEN}${MODEL_NAMESPACE}/${MODEL_NAME}${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}The app is pre-configured and ready to use!${NC}"
echo ""
echo -e "${YELLOW}Token expires in 24 hours. To refresh:${NC}"
echo "  $0 --delete -n $APP_NAMESPACE && $0 -n $APP_NAMESPACE -m $MODEL_NAMESPACE/$MODEL_NAME"
echo ""
echo -e "${GREEN}Open the app: https://${APP_URL}${NC}"
