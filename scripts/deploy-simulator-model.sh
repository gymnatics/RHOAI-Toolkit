#!/bin/bash
################################################################################
# Deploy CPU-only Simulator Model for MaaS Platform Validation
################################################################################
# Deploys a lightweight simulator (no GPU) to validate the full MaaS stack:
#   - LLMInferenceService (inference workload)
#   - MaaSModelRef (gateway registration)
#   - MaaSAuthPolicy (access control)
#   - MaaSSubscription (rate limiting tiers)
#
# Usage:
#   ./deploy-simulator-model.sh                  # Deploy to 'llm' namespace
#   ./deploy-simulator-model.sh -n my-namespace  # Custom namespace
#   ./deploy-simulator-model.sh --delete         # Remove simulator
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
}

print_step() { echo -e "${CYAN}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

MODEL_NAMESPACE="llm"
DELETE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) MODEL_NAMESPACE="$2"; shift 2 ;;
        --delete) DELETE_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [-n namespace] [--delete]"
            echo ""
            echo "Deploys a CPU-only simulator model to validate MaaS platform."
            echo "No GPU required. Starts in ~30 seconds."
            exit 0
            ;;
        *) shift ;;
    esac
done

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

MANIFESTS_DIR="$ROOT_DIR/lib/manifests/maas/simulator"

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing simulator model..."
    export MODEL_NAMESPACE
    for f in "$MANIFESTS_DIR"/maas-subscription-*.yaml "$MANIFESTS_DIR"/maas-auth-policy.yaml; do
        envsubst '${MODEL_NAMESPACE}' < "$f" | oc delete --ignore-not-found -f - 2>/dev/null
    done
    envsubst '${MODEL_NAMESPACE}' < "$MANIFESTS_DIR/maas-model-ref.yaml" | oc delete --ignore-not-found -f - 2>/dev/null
    envsubst '${MODEL_NAMESPACE}' < "$MANIFESTS_DIR/llminferenceservice.yaml" | oc delete --ignore-not-found -f - 2>/dev/null
    print_success "Simulator model removed"
    exit 0
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          Deploy MaaS Simulator Model (CPU-only)                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_step "Creating namespace '$MODEL_NAMESPACE'..."
oc create namespace "$MODEL_NAMESPACE" 2>/dev/null || true
oc label namespace "$MODEL_NAMESPACE" opendatahub.io/generated-namespace=true --overwrite 2>/dev/null || true

export MODEL_NAMESPACE

print_step "Deploying LLMInferenceService (simulator)..."
envsubst '${MODEL_NAMESPACE}' < "$MANIFESTS_DIR/llminferenceservice.yaml" | oc apply -f -

print_step "Registering model with MaaS (MaaSModelRef)..."
envsubst '${MODEL_NAMESPACE}' < "$MANIFESTS_DIR/maas-model-ref.yaml" | oc apply -f -

print_step "Applying access policy (MaaSAuthPolicy)..."
envsubst '${MODEL_NAMESPACE}' < "$MANIFESTS_DIR/maas-auth-policy.yaml" | oc apply -f -

print_step "Applying rate limit subscriptions..."
envsubst '${MODEL_NAMESPACE}' < "$MANIFESTS_DIR/maas-subscription-free.yaml" | oc apply -f -
envsubst '${MODEL_NAMESPACE}' < "$MANIFESTS_DIR/maas-subscription-premium.yaml" | oc apply -f -

print_step "Waiting for simulator to be ready..."
local_elapsed=0
while [ $local_elapsed -lt 120 ]; do
    ready=$(oc get llminferenceservice simulator -n "$MODEL_NAMESPACE" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
    if [ "$ready" = "True" ]; then
        print_success "Simulator model is Ready"
        break
    fi
    sleep 5
    local_elapsed=$((local_elapsed + 5))
done

if [ "$ready" != "True" ]; then
    print_info "Simulator not ready yet — check: oc get llminferenceservice -n $MODEL_NAMESPACE"
fi

echo ""
print_success "Simulator model deployed"
echo ""
print_info "Verify:"
echo "  oc get llminferenceservice -n $MODEL_NAMESPACE"
echo "  oc get maasmodelref -n $MODEL_NAMESPACE"
echo "  oc get maassubscription -n models-as-a-service"
echo ""

CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
if [ -n "$CLUSTER_DOMAIN" ]; then
    print_info "Test inference:"
    echo "  MAAS_URL=\"https://maas.${CLUSTER_DOMAIN}\""
    echo "  API_KEY=\$(curl -sk -X POST \"\${MAAS_URL}/maas-api/v1/api-keys\" \\"
    echo "    -H \"Authorization: Bearer \$(oc whoami -t)\" \\"
    echo "    -H \"Content-Type: application/json\" \\"
    echo "    -d '{\"name\":\"test\",\"subscription\":\"simulator-free\",\"expiresIn\":\"1h\"}' | jq -r '.key')"
    echo "  curl -sk \"\${MAAS_URL}/${MODEL_NAMESPACE}/simulator/v1/chat/completions\" \\"
    echo "    -H \"Authorization: Bearer \${API_KEY}\" \\"
    echo "    -H \"Content-Type: application/json\" \\"
    echo "    -d '{\"model\":\"facebook/opt-125m\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}'"
fi
