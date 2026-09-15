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
source "$ROOT_DIR/demo/lib/rhoai-detect.sh"

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

# Detect RHOAI version + MaaS endpoint (maas.<cluster> on 3.4+ -- this demo
# targets subscription-based MaaS, which does not exist on 3.3-).
detect_rhoai_version
if ! is_rhoai_34_or_higher; then
    print_error "This demo requires RHOAI 3.4+ (MaaSSubscription/sk-oai-* API keys)."
    echo "  Detected: RHOAI $RHOAI_VERSION"
    echo "  For RHOAI 3.3, tier-based rate limiting is not covered by this demo."
    exit 1
fi

if ! get_maas_endpoint >/dev/null; then
    print_error "MaaS endpoint not found -- is MaaS enabled in the DataScienceCluster?"
    echo "  Run: ../../scripts/setup-maas.sh"
    exit 1
fi
MAAS_ENDPOINT_URL="https://${MAAS_ENDPOINT}"

print_step "Checking for MaaS models..."
MODELS=$(oc get llminferenceservice -A --no-headers 2>/dev/null)
if [ -n "$MODELS" ]; then
    print_success "Available models:"
    echo "$MODELS" | awk '{printf "    %-30s %s\n", $2, $1}'
    FIRST_MODEL_NS=$(echo "$MODELS" | head -1 | awk '{print $1}')
    FIRST_MODEL_NAME=$(echo "$MODELS" | head -1 | awk '{print $2}')
else
    print_warning "No models found. Deploy one first: ../../scripts/deploy-maas-model.sh --model simulator"
    FIRST_MODEL_NS=""
    FIRST_MODEL_NAME=""
fi

# Resolve the exact model id to send in the request body. This must be the
# LLMInferenceService's spec.model.name (e.g. "facebook/opt-125m"), which is
# often different from the k8s resource name (e.g. "simulator") -- sending
# the bare resource name returns a 404 "model does not exist" regardless of
# routing mode. get_maas_model_id resolves this via `oc` and formats it
# correctly for the active MAAS_ROUTING mode (default: per-model URL routing,
# confirmed working on RHOAI 3.5.0 GA; export MAAS_ROUTING=body to opt into
# the 3.5+ single shared endpoint instead).
MODEL_ID=""
if [ -n "$FIRST_MODEL_NAME" ]; then
    MODEL_ID=$(get_maas_model_id "$FIRST_MODEL_NS" "$FIRST_MODEL_NAME")
fi

echo ""
print_success "MaaS Rate Limiting Demo namespace ready"
print_info "Namespace: $NAMESPACE"
print_info "RHOAI Version: $RHOAI_VERSION (routing: $([ "$MAAS_ROUTING" = "body" ] && echo "body-based" || echo "per-model URL"))"

# --- Create workbench + clone repo ---
source "$ROOT_DIR/lib/functions/workbench.sh"
ensure_workbench "$NAMESPACE" "rate-limit-testing"

# --- Inject notebook environment variables into workbench ---
# NOTE: inject_notebook_env auto-detects the first LLMInferenceService cluster-wide
# (same `oc get llminferenceservice -A | head -1` query used above for
# FIRST_MODEL_NAME/FIRST_MODEL_NS) and already adds MODEL_NAME/MODEL_NAMESPACE
# itself -- do NOT pass those as extra args here or `oc create configmap` fails
# with "another key by that name already exists".
source "$ROOT_DIR/lib/functions/notebook-env.sh"
inject_notebook_env "$NAMESPACE" \
    "MAAS_ENDPOINT=${MAAS_ENDPOINT_URL}" \
    "MODEL_ID=${MODEL_ID}" \
    "MAAS_ROUTING=${MAAS_ROUTING}"
print_success "notebook-env ConfigMap created (auto-injected into workbenches)"

echo ""
echo "  Next steps:"
echo "  1. Create a workbench in RHOAI dashboard for namespace: $NAMESPACE"
echo "  2. In the workbench terminal, clone and navigate to the notebook:"
echo "     git clone https://github.com/gymnatics/RHOAI-Toolkit.git"
echo "     cd RHOAI-Toolkit/demo/maas-ratelimit-demo"
echo "     # Open maas-ratelimit-test.ipynb"
echo ""
echo "  3. Generate an API key:"
echo "     RHOAI Dashboard > Gen AI Studio > API Keys > Create API key"
echo "     (must be scoped to a MaaSSubscription for '${FIRST_MODEL_NAME:-<model>}')"
echo ""
echo "  4. In the notebook, set (or leave blank to auto-pick up the injected env):"
echo "     API_KEY = \"sk-oai-your-key-here\""
echo "     MODEL_ID = \"${MODEL_ID:-<see /v1/models>}\""
echo "     MAAS_ENDPOINT = \"${MAAS_ENDPOINT_URL}\""
echo ""
if [ "$MAAS_ROUTING" = "body" ]; then
    echo "  Routing: body-based (opt-in) -- single endpoint \${MAAS_ENDPOINT}/v1/chat/completions,"
    echo "  model id goes in the request body (\"model\": \"${MODEL_ID}\")."
else
    echo "  Routing: per-model URL (default) -- \${MAAS_ENDPOINT}/${FIRST_MODEL_NS}/${FIRST_MODEL_NAME}/v1/chat/completions"
    if is_rhoai_35_or_higher; then
        echo "  (body-based routing also available on 3.5+: export MAAS_ROUTING=body before deploying)"
    fi
fi
echo ""
echo "  The notebook tests:"
echo "  - API key authentication"
echo "  - Token rate limit enforcement (HTTP 429)"
echo "  - Burst vs sustained load patterns"
echo "  - Multi-subscription comparison"
echo ""
