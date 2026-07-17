#!/bin/bash
################################################################################
# Deploy Open WebUI
################################################################################
# Deploys Open WebUI chat interface connected to RHOAI model endpoints.
# Auto-detects MaaS gateway or InferenceService endpoints.
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
    export NAMESPACE MODEL_URL="placeholder"
    envsubst < "$SCRIPT_DIR/manifests/open-webui.yaml" | oc delete -f - --ignore-not-found 2>/dev/null
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

    MAAS_GATEWAY="https://inference-gateway.${CLUSTER_DOMAIN}"
    if curl -sk --connect-timeout 3 "$MAAS_GATEWAY/v1/models" &>/dev/null; then
        MODEL_URL="${MAAS_GATEWAY}/v1"
        print_success "Detected MaaS gateway: $MODEL_URL"
    else
        FIRST_ISVC=$(oc get inferenceservice -A --no-headers 2>/dev/null | head -1)
        if [ -n "$FIRST_ISVC" ]; then
            local_ns=$(echo "$FIRST_ISVC" | awk '{print $1}')
            local_name=$(echo "$FIRST_ISVC" | awk '{print $2}')
            MODEL_URL="https://${local_name}-predictor.${local_ns}.svc:8080/v1"
            print_success "Detected InferenceService: $local_name in $local_ns"
        else
            MODEL_URL="http://localhost:8080/v1"
            print_warning "No model endpoint detected. Set --model-url or configure after deployment."
        fi
    fi
fi

ensure_namespace "$NAMESPACE"

export NAMESPACE MODEL_URL
envsubst < "$SCRIPT_DIR/manifests/open-webui.yaml" | oc apply -f -

print_step "Waiting for Open WebUI deployment..."
oc rollout status deployment/open-webui -n "$NAMESPACE" --timeout=120s 2>/dev/null || true

WEBUI_URL="https://$(oc get route open-webui -n "$NAMESPACE" -o jsonpath='{.status.ingress[0].host}' 2>/dev/null)"
echo ""
print_success "Open WebUI deployed"
print_info "URL: $WEBUI_URL"
print_info "Model endpoint: $MODEL_URL"
