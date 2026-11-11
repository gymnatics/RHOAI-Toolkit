#!/bin/bash
################################################################################
# Deploy Open WebUI
################################################################################
# Deploys Open WebUI chat interface connected to RHOAI model endpoints.
# Auto-detects a chat model endpoint (vLLM InferenceService, else LLMInferenceService;
# embedding/predictive models are skipped).
#
# Usage:
#   ./deploy.sh                         # Auto-detect model endpoint
#   ./deploy.sh -n open-webui           # Custom namespace
#   ./deploy.sh --model-url URL         # Specify model endpoint
#   ./deploy.sh --delete                # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"
source "$ROOT_DIR/lib/functions/notebook-env.sh"

NAMESPACE="open-webui"
MODEL_URL=""
DELETE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --model-url) MODEL_URL="$2"; shift 2 ;;
        --delete) DELETE_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [-n namespace] [--model-url URL] [--delete]"
            exit 0
            ;;
        *) shift ;;
    esac
done

print_header "Open WebUI Deployment"

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing Open WebUI from $NAMESPACE..."
    export NAMESPACE MODEL_URL="placeholder" MODEL_TLS_VERIFY=True
    envsubst '${NAMESPACE} ${MODEL_URL} ${MODEL_TLS_VERIFY}' < "$SCRIPT_DIR/manifests/open-webui.yaml" | oc delete -f - --ignore-not-found 2>/dev/null
    print_success "Open WebUI removed"
    exit 0
fi

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

if [ -z "$MODEL_URL" ]; then
    print_step "Auto-detecting model endpoint..."

    CLUSTER_DOMAIN=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)

    # inference-gateway.<domain> is the RHOAI 3.3 (Tech Preview) MaaS gateway; 3.4+ MaaS needs an API key
    MAAS_GATEWAY="https://inference-gateway.${CLUSTER_DOMAIN}"
    if [[ "$(oc get csv -n redhat-ods-operator -o jsonpath='{.items[?(@.spec.displayName=="Red Hat OpenShift AI")].spec.version}' 2>/dev/null)" == 3.3* ]] && curl -sk --connect-timeout 3 "$MAAS_GATEWAY/v1/models" &>/dev/null; then
        MODEL_URL="${MAAS_GATEWAY}/v1"
        print_success "Detected MaaS gateway: $MODEL_URL"
    else
        # Chat model only: detect_direct_llm_endpoint skips sklearn/onnx/embedding/guardrails models
        # and falls back to an LLMInferenceService's workload Service (no MaaS auth needed)
        if detect_direct_llm_endpoint "$NAMESPACE" && [ -n "$DIRECT_BASE_URL" ]; then
            MODEL_URL="$DIRECT_BASE_URL"
            print_success "Detected chat model: $DIRECT_MODEL_NAME in $DIRECT_MODEL_NS ($MODEL_URL)"
        else
            MODEL_URL="http://localhost:8080/v1"
            print_warning "No chat model detected. Set --model-url or configure after deployment."
        fi
    fi
fi

MODEL_TLS_VERIFY=True
if [[ "$MODEL_URL" == https://*.svc[:/]* ]]; then
    MODEL_TLS_VERIFY=False
    print_info "In-cluster https endpoint (service-CA certificate): TLS verification off for model calls"
fi

ensure_namespace "$NAMESPACE"

export NAMESPACE MODEL_URL MODEL_TLS_VERIFY
envsubst '${NAMESPACE} ${MODEL_URL} ${MODEL_TLS_VERIFY}' < "$SCRIPT_DIR/manifests/open-webui.yaml" | oc apply -f -
# ConfigMap changes are read only at startup (ENABLE_PERSISTENT_CONFIG=False)
oc rollout restart deployment/open-webui -n "$NAMESPACE" >/dev/null 2>&1 || true

print_step "Waiting for Open WebUI deployment..."
oc rollout status deployment/open-webui -n "$NAMESPACE" --timeout=120s 2>/dev/null || true

WEBUI_URL="https://$(oc get route open-webui -n "$NAMESPACE" -o jsonpath='{.status.ingress[0].host}' 2>/dev/null)"
echo ""
print_success "Open WebUI deployed"
print_info "URL: $WEBUI_URL"
print_info "Model endpoint: $MODEL_URL"
