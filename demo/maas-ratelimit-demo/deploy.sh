#!/bin/bash
################################################################################
# Deploy MaaS Rate Limiting Demo
################################################################################
# Sets up namespace for testing MaaS API key auth and token rate limiting.
# Provides a notebook to upload into a workbench you create via the dashboard.
#
# Usage:
#   ./deploy.sh                         # Deploy to maas-ratelimit-demo namespace
#   ./deploy.sh -n my-namespace          # Custom namespace
#   ./deploy.sh --delete                 # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"

NAMESPACE="${1:-maas-ratelimit-demo}"
DELETE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --delete) DELETE_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [-n namespace] [--delete]"
            exit 0
            ;;
        *) shift ;;
    esac
done

print_header "MaaS Rate Limiting Demo"

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing namespace $NAMESPACE..."
    oc delete namespace "$NAMESPACE" --ignore-not-found 2>/dev/null
    print_success "MaaS rate limiting demo removed"
    exit 0
fi

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

ensure_namespace "$NAMESPACE"
oc label namespace "$NAMESPACE" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true

# Detect MaaS endpoint and models
CLUSTER_DOMAIN=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
MAAS_ENDPOINT="https://inference-gateway.${CLUSTER_DOMAIN}"

print_step "Checking for MaaS models..."
MODELS=$(oc get inferenceservice -A --no-headers 2>/dev/null)
if [ -n "$MODELS" ]; then
    print_success "Available models:"
    echo "$MODELS" | awk '{printf "    %-30s %s\n", $2, $1}'
    FIRST_MODEL_NS=$(echo "$MODELS" | head -1 | awk '{print $1}')
    FIRST_MODEL_NAME=$(echo "$MODELS" | head -1 | awk '{print $2}')
else
    print_warning "No models found. Deploy a model first."
    FIRST_MODEL_NS="admin-workshop"
    FIRST_MODEL_NAME="qwen3-32b"
fi

echo ""
print_success "MaaS Rate Limiting Demo namespace ready"
print_info "Namespace: $NAMESPACE"
echo ""
echo "  Next steps:"
echo "  1. Create a workbench in RHOAI dashboard for namespace: $NAMESPACE"
echo "  2. In the workbench terminal, clone and navigate to the notebook:"
echo "     git clone https://github.com/gymnatics/openshift-installation.git"
echo "     cd openshift-installation/demo/maas-ratelimit-demo"
echo "     # Open maas-ratelimit-test.ipynb"
echo ""
echo "  3. Generate an API key:"
echo "     RHOAI Dashboard > Gen AI Studio > API Keys > Create API key"
echo ""
echo "  4. In the notebook, set:"
echo "     API_KEY = \"sk-oai-your-key-here\""
echo "     MODEL_NAME = \"${FIRST_MODEL_NAME}\""
echo "     MODEL_NAMESPACE = \"${FIRST_MODEL_NS}\""
echo "     MAAS_ENDPOINT = \"${MAAS_ENDPOINT}\""
echo ""
echo "  The notebook tests:"
echo "  - API key authentication"
echo "  - Token rate limit enforcement (HTTP 429)"
echo "  - Burst vs sustained load patterns"
echo "  - Multi-subscription comparison"
echo ""
