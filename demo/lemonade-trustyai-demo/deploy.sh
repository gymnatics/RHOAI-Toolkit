#!/usr/bin/env bash
################################################################################
# Deploy Lemonade Stand Assistant (TrustyAI / FMS Orchestr8 Edition)
################################################################################
# Vendors and deploys the upstream rh-ai-quickstart/lemonade-stand-assistant
# Helm chart as-is (all images are pre-built on quay.io -- no local builds).
#
# Unlike demo/lemonade-stand-demo/ (NeMo Guardrails edition), this deploys:
#   - Llama 3.2 3B Instruct (vLLM InferenceService, GPU) -- or your own endpoint
#   - IBM HAP Detector (Granite Guardian) -- KServe InferenceService, CPU
#   - Prompt Injection Detector (DeBERTa v3) -- KServe InferenceService, CPU
#   - Lingua Language Detector -- plain Deployment, CPU
#   - MinIO (vendors + serves the two HF detector models)
#   - TrustyAI GuardrailsOrchestrator (FMS Orchestr8) wiring model + detectors
#   - lemonade-stand FastAPI chat app + Route
#   - shiny-dashboard (R Shiny) metrics dashboard + Route
#
# Usage:
#   ./deploy.sh                                  # Deploy own Llama 3.2 3B (GPU required)
#   ./deploy.sh -n my-namespace
#   ./deploy.sh --model-name my-model --model-endpoint my-maas-host --model-port 443 --model-api-key sk-xxx
#   ./deploy.sh --set detectors.hap.useGpu=true   # Pass through extra --set flags to helm
#   ./deploy.sh --delete
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"
source "$ROOT_DIR/lib/functions/external-repos.sh"

NAMESPACE="lemonade-trustyai-demo"
MODEL_NAME=""
MODEL_ENDPOINT=""
MODEL_PORT=""
MODEL_API_KEY=""
DELETE_MODE=false
EXTRA_HELM_ARGS=()

usage() {
    cat <<EOF
Usage: $0 [options]

  -n, --namespace NAME       Target namespace (default: $NAMESPACE)
  --model-name NAME          Use an existing model instead of deploying Llama 3.2 3B
  --model-endpoint HOST      Existing model hostname (no https://, no trailing /)
  --model-port PORT          Existing model port (default: 443)
  --model-api-key KEY        API key for the existing model endpoint
  --set KEY=VALUE            Extra Helm --set (repeatable), e.g. --set detectors.hap.useGpu=true
  --delete                   Uninstall and remove the namespace
  -h, --help                 Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --model-name) MODEL_NAME="$2"; shift 2 ;;
        --model-endpoint) MODEL_ENDPOINT="$2"; shift 2 ;;
        --model-port) MODEL_PORT="$2"; shift 2 ;;
        --model-api-key) MODEL_API_KEY="$2"; shift 2 ;;
        --set) EXTRA_HELM_ARGS+=(--set "$2"); shift 2 ;;
        --delete) DELETE_MODE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) print_warning "Unknown option: $1"; shift ;;
    esac
done

print_header "Lemonade Stand Assistant (TrustyAI / FMS Orchestr8 Edition)"

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing Lemonade Stand Assistant (TrustyAI edition) from $NAMESPACE..."
    if command -v helm &>/dev/null && helm status lemonade-stand-assistant -n "$NAMESPACE" &>/dev/null; then
        helm uninstall lemonade-stand-assistant -n "$NAMESPACE"
    fi
    oc delete namespace "$NAMESPACE" --ignore-not-found
    print_success "Removed"
    exit 0
fi

if ! command -v helm &>/dev/null; then
    print_error "helm CLI not found. Install Helm 3: https://helm.sh/docs/intro/install/"
    exit 1
fi

# --- Ensure TrustyAI component is enabled (required for GuardrailsOrchestrator) ---
print_step "Checking TrustyAI component state..."
TRUSTYAI_STATE=$(oc get dsc default-dsc -o jsonpath='{.spec.components.trustyai.managementState}' 2>/dev/null || echo "")
if [ "$TRUSTYAI_STATE" != "Managed" ]; then
    print_step "Enabling TrustyAI component in the DataScienceCluster..."
    oc patch dsc default-dsc --type=merge -p '{"spec":{"components":{"trustyai":{"managementState":"Managed"}}}}'
    print_step "Waiting for TrustyAI operator to become ready..."
    elapsed=0
    while [ $elapsed -lt 180 ]; do
        state=$(oc get trustyai default-trustyai -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [ "$state" = "Ready" ]; then
            print_success "TrustyAI component ready"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    if ! oc get crd guardrailsorchestrators.trustyai.opendatahub.io &>/dev/null; then
        print_warning "GuardrailsOrchestrator CRD not yet visible -- it may take another minute to register"
        sleep 15
    fi
else
    print_success "TrustyAI component already Managed"
fi

if ! oc get crd guardrailsorchestrators.trustyai.opendatahub.io &>/dev/null; then
    print_error "GuardrailsOrchestrator CRD still not found. Check: oc get trustyai default-trustyai -o yaml"
    exit 1
fi

# --- Clone the upstream repo (vendored chart, used as-is) ---
clone_or_update_repo "lemonade-stand-assistant"
REPO_PATH=$(get_repo_path "lemonade-stand-assistant")

# --- Namespace ---
ensure_namespace "$NAMESPACE"
oc label namespace "$NAMESPACE" opendatahub.io/dashboard=true --overwrite &>/dev/null || true

# --- Build Helm args ---
HELM_ARGS=(upgrade --install lemonade-stand-assistant "$REPO_PATH/chart" -n "$NAMESPACE" --create-namespace --timeout 15m --wait=false)

if [ -n "$MODEL_NAME" ] || [ -n "$MODEL_ENDPOINT" ]; then
    print_info "Using existing model endpoint (skipping on-cluster Llama 3.2 3B deploy)"
    [ -n "$MODEL_NAME" ] && HELM_ARGS+=(--set "model.name=$MODEL_NAME")
    [ -n "$MODEL_ENDPOINT" ] && HELM_ARGS+=(--set "model.endpoint=$MODEL_ENDPOINT")
    HELM_ARGS+=(--set "model.port=${MODEL_PORT:-443}")
    [ -n "$MODEL_API_KEY" ] && HELM_ARGS+=(--set "model.api_key=$MODEL_API_KEY")
else
    print_info "Deploying default model: Llama 3.2 3B Instruct (requires 1 GPU)"
fi

if [ "${#EXTRA_HELM_ARGS[@]}" -gt 0 ]; then
    HELM_ARGS+=("${EXTRA_HELM_ARGS[@]}")
fi

print_step "Installing Helm chart (namespace: $NAMESPACE)..."
helm "${HELM_ARGS[@]}"
print_success "Helm release applied"

# --- Workaround for upstream chart bug ---
# fms-orchestr8-config-nlp hardcodes the *container* ports (8000 for the HAP/
# prompt-injection detector runtimes, 8080 for the model) as the port to reach
# each KServe Service by. But KServe RawDeployment always exposes ClusterIP
# Services on port 80 (mapping to the container's targetPort) -- so those
# hardcoded ports go nowhere and every chat/detection request hangs for 60s
# before failing with a Connect timeout. Patch the ConfigMap to use port 80
# for the two detector InferenceServices (and the model, if we deployed it).
print_step "Applying upstream config fix (KServe Service port 80, not container port)..."
sleep 5  # let KServe finish creating the Services before we read them
HAP_SVC_PORT=$(oc get svc guardrails-detector-ibm-hap-predictor -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "80")
PI_SVC_PORT=$(oc get svc prompt-injection-detector-predictor -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "80")
if [ -n "$MODEL_NAME" ] || [ -n "$MODEL_ENDPOINT" ]; then
    MODEL_SVC_HOST="${MODEL_ENDPOINT:-llama-32-predictor}"
    MODEL_SVC_PORT="${MODEL_PORT:-443}"
else
    MODEL_SVC_HOST="llama-32-predictor"
    MODEL_SVC_PORT=$(oc get svc llama-32-predictor -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "80")
fi

oc get cm fms-orchestr8-config-nlp -n "$NAMESPACE" -o json | \
    python3 -c "
import json, sys
cm = json.load(sys.stdin)
import re
cfg = cm['data']['config.yaml']
cfg = re.sub(r'(hostname: ${MODEL_SVC_HOST}\n\s*port: )\d+', r'\g<1>${MODEL_SVC_PORT}', cfg)
cfg = re.sub(r'(hostname: guardrails-detector-ibm-hap-predictor\n\s*port: )\d+', r'\g<1>${HAP_SVC_PORT}', cfg)
cfg = re.sub(r'(hostname: prompt-injection-detector-predictor\n\s*port: )\d+', r'\g<1>${PI_SVC_PORT}', cfg)
cm['data']['config.yaml'] = cfg
json.dump(cm, sys.stdout)
" | oc apply -f - &>/dev/null && print_success "Config fixed (model port $MODEL_SVC_PORT, HAP port $HAP_SVC_PORT, prompt-injection port $PI_SVC_PORT)" || \
    print_warning "Could not auto-patch fms-orchestr8-config-nlp -- see README known issues"

oc rollout restart deployment/guardrails-orchestrator -n "$NAMESPACE" &>/dev/null || true

# --- Wait for key workloads ---
print_step "Waiting for MinIO (detector model download) to be ready..."
oc rollout status deployment/minio-storage-guardrail-detectors -n "$NAMESPACE" --timeout=300s 2>/dev/null || \
    print_warning "MinIO not ready yet -- detector InferenceServices may still be pulling models"

print_step "Waiting for guardrails-orchestrator to pick up the config fix..."
if ! oc rollout status deployment/guardrails-orchestrator -n "$NAMESPACE" --timeout=90s 2>/dev/null; then
    print_warning "Orchestrator rollout slow -- likely waiting for CPU on a busy cluster."
    print_info "If it stays Pending, free up capacity with: oc delete pod -l app=guardrails-orchestrator,pod-template-hash!=\$(oc get rs -n $NAMESPACE -l app=guardrails-orchestrator --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.labels.pod-template-hash}') -n $NAMESPACE"
fi

print_step "Waiting for lemonade-stand app to be ready..."
oc rollout status deployment/lemonade-stand -n "$NAMESPACE" --timeout=300s 2>/dev/null || \
    print_warning "lemonade-stand app not ready yet -- check: oc get pods -n $NAMESPACE"

print_step "Waiting for shiny-dashboard to be ready..."
oc rollout status deployment/shiny-dashboard -n "$NAMESPACE" --timeout=180s 2>/dev/null || \
    print_warning "shiny-dashboard not ready yet -- check: oc get pods -n $NAMESPACE"

# --- Print access info ---
APP_ROUTE=$(oc get route lemonade-stand -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
DASHBOARD_ROUTE=$(oc get route shiny-dashboard -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

echo ""
print_success "Lemonade Stand Assistant (TrustyAI edition) deployed to namespace: $NAMESPACE"
echo ""
[ -n "$APP_ROUTE" ] && print_info "Chat app:        https://$APP_ROUTE"
[ -n "$DASHBOARD_ROUTE" ] && print_info "Shiny dashboard: https://$DASHBOARD_ROUTE"
echo ""
print_info "Check status:"
echo "    oc get pods -n $NAMESPACE"
echo "    oc get inferenceservice -n $NAMESPACE"
echo "    oc get guardrailsorchestrator -n $NAMESPACE"
echo ""
print_info "This is separate from demo/lemonade-stand-demo/ (NeMo Guardrails edition)."
print_info "Original upstream: https://github.com/rh-ai-quickstart/lemonade-stand-assistant"
