#!/bin/bash
################################################################################
# Deploy NeMo Guardrails Demo
################################################################################
# Deploys NeMo Guardrails (RHOAI 3.4) with built-in detectors.
# Optionally connects to a deployed model for LLM self-check rails.
#
# Usage:
#   ./deploy.sh                              # Basic (no LLM)
#   ./deploy.sh -n my-project                # Custom namespace
#   ./deploy.sh --selfcheck                  # With LLM self-check
#   ./deploy.sh --delete                     # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"
source "$ROOT_DIR/lib/functions/nemo-guardrails.sh"

NAMESPACE="${1:-nemo-guardrails-demo}"
GUARDRAILS_NAME="nemo-quickstart"
MODE="basic"
DELETE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --name) GUARDRAILS_NAME="$2"; shift 2 ;;
        --selfcheck) MODE="selfcheck"; shift ;;
        --delete) DELETE_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [-n namespace] [--name NAME] [--selfcheck] [--delete]"
            exit 0
            ;;
        *) shift ;;
    esac
done

print_header "NeMo Guardrails Demo (RHOAI 3.4)"

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

MODEL_URL=""
MODEL_NAME=""
if [ "$MODE" = "selfcheck" ]; then
    print_step "Self-check mode: need a deployed model endpoint"
    echo ""
    echo "  Available InferenceServices:"
    oc get inferenceservice -A --no-headers 2>/dev/null | awk '{printf "  %-30s %s\n", $2, $1}'
    echo ""
    read -rp "Model namespace: " model_ns
    read -rp "Model name: " model_isvc

    MODEL_URL="https://${model_isvc}-predictor.${model_ns}.svc:8080/v1"
    MODEL_NAME="$model_isvc"
    echo ""
    print_info "Using model: $MODEL_URL ($MODEL_NAME)"
fi

setup_nemo_guardrails_auth "$NAMESPACE"
deploy_nemo_guardrails "$NAMESPACE" "$GUARDRAILS_NAME" "$MODE" "$MODEL_URL" "$MODEL_NAME"
wait_for_nemo_guardrails "$NAMESPACE" "$GUARDRAILS_NAME"

echo ""
verify_nemo_guardrails "$NAMESPACE" "$GUARDRAILS_NAME"

read -rp "Run automated tests? (Y/n): " run_tests
run_tests="${run_tests:-Y}"
if [[ "$run_tests" =~ ^[Yy]$ ]]; then
    test_nemo_guardrails "$NAMESPACE" "$GUARDRAILS_NAME"
fi

echo ""
print_success "NeMo Guardrails demo ready"
