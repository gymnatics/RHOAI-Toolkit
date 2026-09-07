#!/bin/bash
################################################################################
# Deploy University Safeguard Demo
################################################################################
# Deploys NeMo Guardrails (RHOAI 3.5) in front of a chat model, with:
#   - Presidio PII redaction on input + PII block on output (built-in)
#   - Generic regex/keyword detection on input (built-in)
#   - granite-guardian-hap-38m HAP (hate/abuse/profanity) classifier, deployed
#     as its own CPU-only InferenceService and called directly from a custom
#     Colang flow + Python action on both input and output, generating a
#     structured log entry ("hap_alert") on every detection
#
# The main (chat) model defaults to an EXTERNAL LiteMaaS/LiteLLM-proxied
# endpoint (not deployed on this cluster) — pass --model-url/--model-name to
# point at a different OpenAI-compatible endpoint instead (e.g. an in-cluster
# LLMInferenceService's internal service URL).
#
# IMPORTANT: This is a technical PoC demo. HAP alerting is currently log-only
# (oc logs) — see actions.py in manifests/nemo-guardrails-config.yaml for the
# integration point to wire a real notification channel (webhook/email/Slack).
#
# Usage:
#   ./deploy.sh                              # Deploy into acme-university-demo
#   ./deploy.sh -n my-namespace              # Custom namespace
#   ./deploy.sh --model-api-key sk-...       # Skip the interactive key prompt
#   ./deploy.sh --delete                     # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"
source "$ROOT_DIR/lib/utils/os-compat.sh"

# NEMO_MANIFESTS_DIR override must happen BEFORE sourcing nemo-guardrails.sh so
# setup_nemo_guardrails_auth / wait_for_nemo_guardrails / verify_nemo_guardrails
# pick up this demo's SA/RBAC manifests instead of demo/nemo-guardrails-demo's.
export NEMO_MANIFESTS_DIR="$SCRIPT_DIR/manifests"
source "$ROOT_DIR/lib/functions/nemo-guardrails.sh"
source "$ROOT_DIR/lib/functions/university-safeguard.sh"

NAMESPACE="acme-university-demo"
GUARDRAILS_NAME="university-safeguard"
DELETE_MODE=false
# Defaults: external LiteMaaS/LiteLLM-proxied model (not deployed on this
# cluster). Override with --model-url/--model-name to point at a different
# OpenAI-compatible endpoint, e.g. an in-cluster LLMInferenceService.
MAIN_MODEL_URL="https://maas-rhdp.apps.maas.redhatworkshops.io/v1"
MAIN_MODEL_NAME="qwen36-35b-a3b"
MAIN_MODEL_API_KEY="${MAIN_MODEL_API_KEY:-}"

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --name) GUARDRAILS_NAME="$2"; shift 2 ;;
        --model-url) MAIN_MODEL_URL="$2"; shift 2 ;;
        --model-name) MAIN_MODEL_NAME="$2"; shift 2 ;;
        --model-api-key) MAIN_MODEL_API_KEY="$2"; shift 2 ;;
        --delete) DELETE_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [-n namespace] [--name NAME] [--model-url URL] [--model-name NAME] [--model-api-key KEY] [--delete]"
            exit 0
            ;;
        *) shift ;;
    esac
done

print_header "University Safeguard Demo (NeMo Guardrails + HAP Alerting)"

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing University Safeguard demo from $NAMESPACE..."
    oc delete nemoguardrails "$GUARDRAILS_NAME" -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete configmap "${GUARDRAILS_NAME}-config" -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete inferenceservice hap-detector -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete servingruntime guardrails-detector-huggingface-runtime -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete secret api-token-secret -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete secret "${GUARDRAILS_NAME}-model-key" -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete rolebinding nemo-guardrails-service-account-view -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete serviceaccount nemo-guardrails-service-account -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    print_success "University Safeguard demo removed (namespace not deleted)"
    exit 0
fi

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

if ! oc get crd nemoguardrails.trustyai.opendatahub.io &>/dev/null; then
    print_error "NemoGuardrails CRD not found. Ensure TrustyAI is enabled in your DataScienceCluster."
    exit 1
fi

ensure_namespace "$NAMESPACE"

print_info "Main model: $MAIN_MODEL_NAME ($MAIN_MODEL_URL)"

# The main model's API key is a real credential -- never hardcoded in this
# script or committed to git. Accept it via --model-api-key / MAIN_MODEL_API_KEY,
# reuse it from the existing Secret on redeploys, or prompt for it (hidden
# input) if neither is available. config.yaml needs the literal value (not
# just a secret reference) on every apply, so we always resolve it here.
if [ -z "$MAIN_MODEL_API_KEY" ]; then
    existing_key_b64=$(oc get secret "${GUARDRAILS_NAME}-model-key" -n "$NAMESPACE" -o jsonpath='{.data.api-key}' 2>/dev/null)
    if [ -n "$existing_key_b64" ]; then
        MAIN_MODEL_API_KEY=$(base64_decode "$existing_key_b64")
        print_info "Reusing main model API key from existing secret '${GUARDRAILS_NAME}-model-key'"
    else
        read -rsp "Enter API key for main model ($MAIN_MODEL_NAME @ $MAIN_MODEL_URL): " MAIN_MODEL_API_KEY
        echo ""
    fi
fi
if [ -z "$MAIN_MODEL_API_KEY" ]; then
    print_error "Main model API key is required (pass --model-api-key or set MAIN_MODEL_API_KEY)."
    exit 1
fi

HAP_DETECTOR_URL="http://hap-detector-predictor.${NAMESPACE}.svc.cluster.local"

deploy_hap_detector "$NAMESPACE"
wait_for_hap_detector "$NAMESPACE"

setup_nemo_guardrails_auth "$NAMESPACE"
ensure_main_model_api_key_secret "$NAMESPACE" "$GUARDRAILS_NAME" "$MAIN_MODEL_API_KEY"
deploy_university_guardrails_config "$NAMESPACE" "$GUARDRAILS_NAME" "$MAIN_MODEL_URL" "$MAIN_MODEL_NAME" "$HAP_DETECTOR_URL" "$MAIN_MODEL_API_KEY"
wait_for_nemo_guardrails "$NAMESPACE" "$GUARDRAILS_NAME"

echo ""
verify_nemo_guardrails "$NAMESPACE" "$GUARDRAILS_NAME"

echo ""
print_warning "Reminder: HAP alert logging is currently log-only (oc logs). See README.md for how to wire a real notification channel."

read -rp "Run automated tests (safe/PII/HAP)? (Y/n): " run_tests
run_tests="${run_tests:-Y}"
if [[ "$run_tests" =~ ^[Yy]$ ]]; then
    test_university_safeguard "$NAMESPACE" "$GUARDRAILS_NAME"
fi

echo ""
print_success "University Safeguard demo ready"
