#!/usr/bin/env bash
# Deploy Lemonade Stand Chat (NeMo Guardrails Edition)
# Builds the app image on-cluster and deploys with NeMo Guardrails endpoint.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$REPO_ROOT/lib/utils/colors.sh"
source "$REPO_ROOT/lib/utils/common.sh"

NAMESPACE="${NAMESPACE:-nemo-guardrails-demo}"
GUARDRAILS_NAMESPACE="${GUARDRAILS_NAMESPACE:-nemo-guardrails-demo}"
GUARDRAILS_NAME="${GUARDRAILS_NAME:-nemo-quickstart}"

print_header "Lemonade Stand Chat (NeMo Guardrails Edition)"

# --- Detect NeMo Guardrails endpoint ---
print_step "Detecting NeMo Guardrails endpoint..."

GUARDRAILS_ROUTE=$(oc get route "$GUARDRAILS_NAME" -n "$GUARDRAILS_NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || true)
if [[ -z "$GUARDRAILS_ROUTE" ]]; then
    print_error "NeMo Guardrails route not found in namespace $GUARDRAILS_NAMESPACE"
    print_error "Deploy NeMo Guardrails first: ./demo/nemo-guardrails-demo/deploy.sh --selfcheck"
    exit 1
fi

export GUARDRAILS_URL="https://${GUARDRAILS_ROUTE}/v1/chat/completions"
print_success "NeMo Guardrails URL: $GUARDRAILS_URL"

# --- Detect model name ---
MODEL_NAME=$(oc get configmap "${GUARDRAILS_NAME}-config" -n "$GUARDRAILS_NAMESPACE" -o jsonpath='{.data.config\.yaml}' 2>/dev/null | grep 'model_name:' | awk '{print $2}' | tr -d '"' || echo "")
if [[ -z "$MODEL_NAME" ]]; then
    MODEL_NAME="qwen3-8b-fp8-dynamic-no-maas"
fi
export MODEL_NAME
print_info "Model: $MODEL_NAME"

# --- Get API key from guardrails namespace ---
GUARDRAILS_API_KEY=$(oc get secret api-token-secret -n "$GUARDRAILS_NAMESPACE" -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || echo "")
export GUARDRAILS_API_KEY

# --- Create namespace and build image ---
oc get namespace "$NAMESPACE" &>/dev/null || oc new-project "$NAMESPACE" --display-name="Lemonade Stand Demo" >/dev/null
print_success "Namespace: $NAMESPACE"

print_step "Building app image on cluster..."
oc new-build --name=lemonade-stand --binary --strategy=docker \
    --to="lemonade-stand:latest" -n "$NAMESPACE" 2>/dev/null || true

oc start-build lemonade-stand --from-dir="$SCRIPT_DIR/app" -n "$NAMESPACE" --follow --wait

# Get the internal image reference
APP_IMAGE=$(oc get imagestream lemonade-stand -n "$NAMESPACE" -o jsonpath='{.status.dockerImageRepository}'):latest
export APP_IMAGE
print_success "Image built: $APP_IMAGE"

# --- Deploy ---
print_step "Deploying Lemonade Stand..."
envsubst < "$SCRIPT_DIR/manifests/lemonade-stand.yaml" | oc apply -f -

# Wait for rollout
oc rollout status deployment/lemonade-stand -n "$NAMESPACE" --timeout=120s

# --- Print access info ---
ROUTE=$(oc get route lemonade-stand -n "$NAMESPACE" -o jsonpath='{.spec.host}')
echo ""
print_success "Lemonade Stand deployed!"
print_info "URL: https://$ROUTE"
print_info "Metrics: https://$ROUTE/metrics"
print_info "Health: https://$ROUTE/health"
echo ""
print_info "The app talks to NeMo Guardrails at: $GUARDRAILS_URL"
print_info "Try asking about lemons, then try prompt injection to see guardrails in action."
