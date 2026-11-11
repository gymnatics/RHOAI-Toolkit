#!/bin/bash
################################################################################
# Deploy NeMo Guardrails Demo
################################################################################
# Deploys NeMo Guardrails (RHOAI 3.4+) with built-in detectors.
# Optionally connects to a deployed model for LLM self-check rails.
#
# Usage:
#   ./deploy.sh                              # Basic (no LLM)
#   ./deploy.sh -n my-project                # Custom namespace
#   ./deploy.sh --selfcheck                  # With LLM self-check (auto-detects the chat model)
#   ./deploy.sh --selfcheck --model-url URL --model-name SERVED_ID   # explicit model
#   ./deploy.sh --delete                     # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"
source "$ROOT_DIR/lib/functions/nemo-guardrails.sh"
source "$ROOT_DIR/lib/functions/notebook-env.sh"

NAMESPACE="nemo-guardrails-demo"
# Positional namespace still works (./deploy.sh my-ns); a leading flag (e.g. --delete) is not a namespace
[[ -n "${1:-}" && "${1:-}" != -* ]] && NAMESPACE="$1"
GUARDRAILS_NAME="nemo-quickstart"
MODE="basic"
DELETE_MODE=false
MODEL_URL=""
MODEL_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --name) GUARDRAILS_NAME="$2"; shift 2 ;;
        --selfcheck) MODE="selfcheck"; shift ;;
        --model-url) MODEL_URL="$2"; shift 2 ;;
        --model-name) MODEL_NAME="$2"; shift 2 ;;
        --delete) DELETE_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [-n namespace] [--name NAME] [--selfcheck [--model-url URL --model-name ID]] [--delete]"
            exit 0
            ;;
        *) shift ;;
    esac
done

print_header "NeMo Guardrails Demo (RHOAI 3.4+)"

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing NeMo Guardrails from $NAMESPACE..."
    oc delete nemoguardrails "$GUARDRAILS_NAME" -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete configmap "${GUARDRAILS_NAME}-config" -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete secret api-token-secret -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete rolebinding nemo-guardrails-service-account-view -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete serviceaccount nemo-guardrails-service-account -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    print_success "NeMo Guardrails removed"
    exit 0
fi

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

# Check TrustyAI is enabled
if ! oc get crd nemoguardrails.trustyai.opendatahub.io &>/dev/null; then
    print_error "NemoGuardrails CRD not found. Ensure TrustyAI is enabled in your DataScienceCluster."
    exit 1
fi

ensure_namespace "$NAMESPACE"

if [ "$MODE" = "selfcheck" ]; then
    if [ -z "$MODEL_URL" ]; then
        print_step "Self-check mode: detecting a chat model..."
        # Prefers a plain-http vLLM InferenceService (NeMo does not trust the service CA used by
        # LLMInferenceService https endpoints); skips embedding/predictive/guardrails models
        if ! detect_direct_llm_endpoint "$NAMESPACE" || [ -z "$DIRECT_BASE_URL" ]; then
            print_error "No chat model found. Deploy one, or pass --model-url URL --model-name SERVED_ID"
            exit 1
        fi
        MODEL_URL="$DIRECT_BASE_URL"
        MODEL_NAME="${MODEL_NAME:-$(resolve_served_model_id "$DIRECT_MODEL_NAME" "$DIRECT_MODEL_NS")}"
        [[ "$MODEL_URL" == https://* ]] && print_warning "Model endpoint is https ($MODEL_URL); NeMo may reject its service-CA certificate"
    fi
    if [ -z "$MODEL_NAME" ]; then
        print_error "--model-name SERVED_ID is required with --model-url (the id the model serves on /v1/models)"
        exit 1
    fi
    print_info "Using model: $MODEL_URL ($MODEL_NAME)"
fi

setup_nemo_guardrails_auth "$NAMESPACE"
deploy_nemo_guardrails "$NAMESPACE" "$GUARDRAILS_NAME" "$MODE" "$MODEL_URL" "$MODEL_NAME"
wait_for_nemo_guardrails "$NAMESPACE" "$GUARDRAILS_NAME"

echo ""
verify_nemo_guardrails "$NAMESPACE" "$GUARDRAILS_NAME"

run_tests=Y
[ -t 0 ] && { read -rp "Run automated tests? (Y/n): " run_tests; run_tests="${run_tests:-Y}"; }
if [[ "$run_tests" =~ ^[Yy]$ ]]; then
    test_nemo_guardrails "$NAMESPACE" "$GUARDRAILS_NAME"
fi

echo ""
print_success "NeMo Guardrails demo ready"
