#!/bin/bash
################################################################################
# Deploy LMEval Demo
################################################################################
# Sets up infrastructure for LLM evaluation benchmarks with MLflow tracking.
# Supports English benchmarks (MMLU, ARC, HellaSwag, etc.) via LMEvalJob CRs,
# Korean benchmarks (KMMLU, CLIcK, KoBEST, HAE-RAE) via EvalHub lab, and
# EvalHub (Technology Preview) for centralized evaluation orchestration.
#
# EvalHub is deployed via the official TrustyAI Operator EvalHub CR.
# Supports providers: lm-evaluation-harness, garak, guidellm, lighteval
# Dashboard UI: Develop and train > Evaluations
#
# Usage:
#   ./deploy.sh                    # Deploy to lmeval-demo namespace
#   ./deploy.sh -n my-namespace    # Custom namespace
#   ./deploy.sh --delete           # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"
source "$ROOT_DIR/lib/functions/external-repos.sh"

NAMESPACE="lmeval-demo"
# Positional namespace still works (./deploy.sh my-ns); a leading flag (e.g. --delete) is not a namespace
[[ -n "${1:-}" && "${1:-}" != -* ]] && NAMESPACE="$1"
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

print_header "LMEval Demo"

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing LMEval infrastructure from $NAMESPACE..."
    oc delete rolebinding evalhub-central-mlflow-access evalhub-central-jobs-writer evalhub-central-job-config -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    print_info "Note: EvalHub CR in redhat-ods-applications is shared -- not deleting it"
    export NAMESPACE MLFLOW_TRACKING_URI="placeholder"
    envsubst < "$SCRIPT_DIR/manifests/lmeval-rbac.yaml" | oc delete -f - --ignore-not-found 2>/dev/null
    oc delete lmevaljob --all -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    print_success "LMEval infrastructure removed"
    exit 0
fi

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

# Check TrustyAI is available (required for both LMEvalJob CRs and EvalHub CR)
if ! oc get crd lmevaljobs.trustyai.opendatahub.io &>/dev/null; then
    print_warning "LMEvalJob CRD not found. Ensure TrustyAI is enabled in your DataScienceCluster."
fi

EVALHUB_CRD_AVAILABLE=false
if oc get crd evalhubs.trustyai.opendatahub.io &>/dev/null 2>&1; then
    EVALHUB_CRD_AVAILABLE=true
fi

clone_or_update_repo "lmeval-builder-lab"
REPO_PATH=$(get_repo_path "lmeval-builder-lab")

ensure_namespace "$NAMESPACE"
oc label namespace "$NAMESPACE" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true
# Register as EvalHub tenant (per RHOAI 3.5 docs Section 2.28). The tenant
# label triggers TrustyAI Operator to provision job SA, RBAC, and service-ca.
# The generated-namespace label passes the default-deny NetworkPolicy in
# redhat-ods-applications so job sidecars can callback to EvalHub on :8443.
oc label namespace "$NAMESPACE" evalhub.trustyai.opendatahub.io/tenant= --overwrite 2>/dev/null || true
oc label namespace "$NAMESPACE" opendatahub.io/generated-namespace=true --overwrite 2>/dev/null || true

# Enable observability dashboard for EvalHub metrics
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
    --type=merge -p '{"spec":{"dashboardConfig":{"observabilityDashboard":true}}}' 2>/dev/null || true

print_step "Deploying LMEval RBAC..."
export NAMESPACE
envsubst < "$SCRIPT_DIR/manifests/lmeval-rbac.yaml" | oc apply -f -

print_step "Deploying EvalHub service (TrustyAI Operator CR)..."
EVALHUB_NAMESPACE="redhat-ods-applications"
# MLflow is started with --static-prefix=/mlflow, so all API paths live under
# /mlflow/. Without this prefix, EvalHub's /version probe 404s and workspace
# negotiation fails (MLflow returns "Workspace context is required").
export MLFLOW_TRACKING_URI="https://mlflow.${EVALHUB_NAMESPACE}.svc:8443/mlflow"

if [ "$EVALHUB_CRD_AVAILABLE" = true ]; then
    if oc get evalhub evalhub -n "$EVALHUB_NAMESPACE" &>/dev/null; then
        print_info "EvalHub CR already exists in $EVALHUB_NAMESPACE"
    else
        print_info "Deploying EvalHub CR in $EVALHUB_NAMESPACE (required for dashboard UI)"
        NAMESPACE="$EVALHUB_NAMESPACE" envsubst < "$SCRIPT_DIR/manifests/evalhub.yaml" | oc apply -f -
        print_info "EvalHub CR applied -- TrustyAI Operator will reconcile the deployment"
        print_info "Waiting for EvalHub to become Ready..."
        for i in $(seq 1 30); do
            PHASE=$(oc get evalhub evalhub -n "$EVALHUB_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
            if [ "$PHASE" = "Ready" ]; then
                print_success "EvalHub is Ready"
                break
            fi
            sleep 5
        done
    fi

    # Grant the central EvalHub SA access to this project's MLflow workspace
    print_info "Granting EvalHub access to MLflow workspace in $NAMESPACE..."
    export NAMESPACE EVALHUB_NAMESPACE
    envsubst '${NAMESPACE} ${EVALHUB_NAMESPACE}' < "$SCRIPT_DIR/manifests/evalhub-central-rbac.yaml.tmpl" | oc apply -f -

    # Create the SA that EvalHub uses to run eval jobs in this namespace
    oc create sa evalhub-${EVALHUB_NAMESPACE}-job -n "$NAMESPACE" 2>/dev/null || true
    oc adm policy add-role-to-user edit "system:serviceaccount:${NAMESPACE}:evalhub-${EVALHUB_NAMESPACE}-job" -n "$NAMESPACE" 2>/dev/null || true

    # Create the service-ca ConfigMap that EvalHub job pods mount for TLS.
    # Without this, job pods get stuck in Init:0/1 with:
    #   MountVolume.SetUp failed for volume "evalhub-service-ca": configmap not found
    # The annotation tells OpenShift to inject the cluster CA bundle.
    oc apply -f - <<EOCM 2>/dev/null || true
apiVersion: v1
kind: ConfigMap
metadata:
  name: evalhub-service-ca
  namespace: ${NAMESPACE}
  annotations:
    service.beta.openshift.io/inject-cabundle: "true"
data: {}
EOCM

    # Grant job SA access to MLflow experiments (required for results to appear in MLflow UI)
    envsubst '${NAMESPACE} ${EVALHUB_NAMESPACE}' < "$SCRIPT_DIR/manifests/evalhub-job-mlflow-rbac.yaml.tmpl" | oc apply -f -

    # Grant evalhub-service SA permission to submit evaluations via SDK
    envsubst '${NAMESPACE} ${EVALHUB_NAMESPACE}' < "$SCRIPT_DIR/manifests/evalhub-evaluations-writer-rbac.yaml.tmpl" | oc apply -f -

    EVALHUB_URL="https://$(oc get routes -l app=eval-hub -n "$EVALHUB_NAMESPACE" -o jsonpath='{.items[0].spec.host}' 2>/dev/null)"
    if [ -z "$EVALHUB_URL" ] || [ "$EVALHUB_URL" = "https://" ]; then
        EVALHUB_URL="(deploying -- check: oc get pods -l app=eval-hub -n $EVALHUB_NAMESPACE)"
    fi
else
    print_warning "EvalHub CRD not available. Ensure TrustyAI is Managed in your DSC."
    print_info "EvalHub requires RHOAI 3.4+ with trustyai.managementState: Managed"
    EVALHUB_URL="(not deployed -- EvalHub CRD not available)"
fi

# --- Deploy HTTP InferenceService for EvalHub benchmarks ---
# EvalHub job sidecars expect an HTTP model endpoint (not HTTPS/service-ca).
# LLMInferenceService wraps vLLM in TLS which the sidecar can't verify.
# A standard InferenceService with RawDeployment gives HTTP on port 80.
print_step "Deploying HTTP model endpoint for EvalHub benchmarks..."
if ! oc get inferenceservice qwen3-8b-eval -n llm &>/dev/null; then
    # Ensure vLLM ServingRuntime exists
    if ! oc get servingruntime vllm-rhaiis -n llm &>/dev/null; then
        if oc get servingruntime vllm-rhaiis -n redhat-ods-applications &>/dev/null; then
            oc get servingruntime vllm-rhaiis -n redhat-ods-applications -o json \
                | jq '.metadata.namespace = "llm" | del(.metadata.uid, .metadata.resourceVersion, .metadata.creationTimestamp, .metadata.managedFields)' \
                | oc apply -f - 2>/dev/null
        else
            "$ROOT_DIR/scripts/add-serving-runtime.sh" --preset vllm-redhat 2>/dev/null || true
            oc get servingruntime vllm-rhaiis -n redhat-ods-applications -o json \
                | jq '.metadata.namespace = "llm" | del(.metadata.uid, .metadata.resourceVersion, .metadata.creationTimestamp, .metadata.managedFields)' \
                | oc apply -f - 2>/dev/null || true
        fi
    fi
    oc apply -f "$SCRIPT_DIR/manifests/eval-inferenceservice.yaml" 2>/dev/null
    print_info "qwen3-8b-eval InferenceService deploying (HTTP endpoint for EvalHub)"
    print_info "Model URL: http://qwen3-8b-eval-predictor.llm.svc.cluster.local/v1"
else
    print_info "qwen3-8b-eval InferenceService already exists"
fi

# --- Generate demo-config.env for vendored notebooks ---
CLUSTER_DOMAIN=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
EVALHUB_SVC="https://evalhub.redhat-ods-applications.svc:8443"

FIRST_MODEL=""
FIRST_MODEL_URL=""
FIRST_ISVC=$(oc get inferenceservice -n "$NAMESPACE" --no-headers 2>/dev/null | head -1)
if [ -n "$FIRST_ISVC" ]; then
    FIRST_MODEL=$(echo "$FIRST_ISVC" | awk '{print $1}')
    FIRST_MODEL_URL="https://${FIRST_MODEL}-predictor.${NAMESPACE}.svc.cluster.local:8443/v1"
fi

CONFIG_ENV_CONTENT="# Auto-generated by deploy.sh -- $(date -u +%Y-%m-%dT%H:%M:%SZ)
NAMESPACE=${NAMESPACE}
MODEL_NAME=${FIRST_MODEL}
BASE_URL=${FIRST_MODEL_URL}
EVALHUB_URL=${EVALHUB_SVC}
"

oc create configmap demo-config-env \
    --from-literal=".env=${CONFIG_ENV_CONTENT}" \
    -n "$NAMESPACE" --dry-run=client -o yaml | oc apply -f - 2>/dev/null && \
    print_success "ConfigMap demo-config-env created (mount as .env in workbench)" || true

# --- Pipeline Server (DSPA) + compile KFP pipeline ---
# Wraps the same submit -> poll -> MLflow flow used in the notebooks as a
# repeatable Kubeflow Pipeline (see pipeline-kfp.py).
print_step "Setting up Pipeline Server for KFP benchmark runs..."
if [ -f "$ROOT_DIR/lib/functions/rhoai.sh" ]; then
    source "$ROOT_DIR/lib/functions/rhoai.sh" 2>/dev/null || true
fi
if type setup_pipeline_server &>/dev/null; then
    setup_pipeline_server "$NAMESPACE" 2>/dev/null || true
else
    print_info "Pipeline Server can be created from RHOAI Dashboard > Data Science Pipelines"
fi

print_step "KFP pipeline (lmeval-benchmark-run)..."
if command -v python3 &>/dev/null && python3 -c "import kfp" 2>/dev/null; then
    (cd "$SCRIPT_DIR" && python3 pipeline-kfp.py)
    print_success "Pipeline compiled to lmeval-pipeline.yaml"
    print_info "Upload via: RHOAI Dashboard > Pipelines > Import"
else
    print_info "KFP SDK not installed locally. Compile inside the workbench:"
    echo "    pip install kfp"
    echo "    python pipeline-kfp.py"
fi

echo ""
print_success "LMEval Demo infrastructure deployed"
print_info "Namespace: $NAMESPACE"
print_info "EvalHub: $EVALHUB_URL"
echo ""
echo "  EVALHUB (Technology Preview):"
echo "    Dashboard UI: Develop and train > Evaluations"
echo "    SDK: pip install 'eval-hub-sdk[client]'"
echo "    CLI: pip install 'eval-hub-sdk[cli]'"
echo "    Providers: lm-evaluation-harness, garak, guidellm, lighteval"
echo ""
echo "  ⚠ Tokenizer mismatch (common UI issue):"
echo "    The 'Model or agent name' field is used as BOTH the served model name"
echo "    and the HuggingFace tokenizer ID. For Red Hat AI models these differ:"
echo "      Served name: redhataiqwen3-8b-fp8-dynamic"
echo "      Tokenizer:   RedHatAI/Qwen3-8B-FP8-dynamic"
echo "    Fix: use served name in the model field, check 'Add additional arguments'"
echo "    and add: tokenizer=RedHatAI/Qwen3-8B-FP8-dynamic"
echo ""
echo "  Vendored notebooks (run in workbench):"
echo "    1. The 'model-benchmarking' workbench + RHOAI-Toolkit clone are"
echo "       created automatically below. If it wasn't Running in time, run:"
echo "         ./scripts/clone-toolkit-in-workbenches.sh -n $NAMESPACE"
echo "    2. Open demo/lmeval-demo/notebooks/"
echo "         guidellm-benchmark.ipynb  -- GuideLLM performance benchmark"
echo "         korean-mcq-benchmark.ipynb -- Korean multiple-choice evaluation"
echo "    3. Config is auto-detected. To override, copy the ConfigMap:"
echo "       oc get cm demo-config-env -n $NAMESPACE -o jsonpath='{.data.\.env}' > .env"
echo ""
echo "  English benchmarks (run from CLI):"
echo "    ./run-benchmark.sh --list              # See available benchmarks"
echo "    ./run-benchmark.sh mmlu                # Run MMLU"
echo "    ./run-benchmark.sh reasoning           # ARC + HellaSwag + Winogrande"
echo "    ./run-benchmark.sh all-english          # Run all English benchmarks"
echo "    ./run-benchmark.sh --status            # Check job progress"
echo ""
echo "  For the full Korean lab workshop, also clone the upstream repo:"
echo "    git clone https://github.com/hyogrin/rhoai-lmeval-builder-lab.git"
echo ""
echo "  All results tracked in MLflow via EvalHub"
echo ""
echo "  Run as a Data Science Pipeline (KFP):"
echo "    1. lmeval-pipeline.yaml compiled above -- upload via"
echo "       RHOAI Dashboard > Pipelines > Import pipeline"
echo "    2. Create a run, filling in parameters (get auth_token with):"
echo "         oc get secret lmeval-sa-token -n $NAMESPACE -o jsonpath='{.data.token}' | base64 -d"
echo "       required: evalhub_url, tenant=$NAMESPACE, auth_token, model_name,"
echo "                 model_url, benchmark_id, provider_id, tokenizer"
echo "    3. Results appear in both the KFP run's Metrics tab and MLflow"
echo "    See README.md 'Run as a Data Science Pipeline' for full details."
echo ""

# --- Create workbench + clone repo ---
source "$ROOT_DIR/lib/functions/workbench.sh"
ensure_workbench "$NAMESPACE" "model-benchmarking"

# --- Inject notebook environment variables into workbench ---
# EVALHUB_AUTH_TOKEN is now auto-generated from lmeval-sa by inject_notebook_env
# itself (see lib/functions/notebook-env.sh) -- lmeval-sa is bound to
# trustyai-operator-lmevaljob-editor-role via lmeval-rbac.yaml above, unlike
# the workbench's own default SA which has no EvalHub-related RBAC.
source "$ROOT_DIR/lib/functions/notebook-env.sh"

# Resolve MODEL_SERVED_NAME (HuggingFace model ID) and HF_MODEL_ID for the
# EvalHub SDK notebooks. inject_notebook_env auto-detects MODEL_NAME (k8s
# resource name, e.g. "qwen3-8b") but the EvalHub SDK needs the served model
# name (e.g. "RedHatAI/Qwen3-8B-FP8-dynamic") which is the spec.model.name
# from the LLMInferenceService (or spec.predictor.model.modelFormat.name for
# InferenceService). These often differ from the k8s resource name.
detect_llm_endpoint "$NAMESPACE" || true
detect_direct_llm_endpoint "$NAMESPACE" || true
HF_MODEL_ID=""
MODEL_SERVED_NAME=""
if [ -n "${LLM_MODEL_NAME:-}" ]; then
    # LLMInferenceService: spec.model.name is the HF model ID
    HF_MODEL_ID=$(oc get llminferenceservice "${LLM_MODEL_NAME}" -n "${LLM_MODEL_NS}" \
        -o jsonpath='{.spec.model.name}' 2>/dev/null || true)
    if [ -z "$HF_MODEL_ID" ]; then
        # InferenceService fallback
        HF_MODEL_ID=$(oc get inferenceservice "${LLM_MODEL_NAME}" -n "${LLM_MODEL_NS}" \
            -o jsonpath='{.metadata.annotations.serving\.kserve\.io/deploymentMode}' 2>/dev/null || true)
    fi
    MODEL_SERVED_NAME="${HF_MODEL_ID:-${LLM_MODEL_NAME}}"
fi

# DIRECT_ROUTE_URL: LLMInferenceService models on RHOAI 3.5 have no external
# route (only the MaaS gateway). The EvalHub lm_evaluation_harness provider
# runs inside the cluster, so the internal workload service URL works fine.
# Fall back to it when DIRECT_ROUTE_URL is unset.
if [ -z "${DIRECT_ROUTE_URL:-}" ] && [ -n "${DIRECT_BASE_URL:-}" ]; then
    DIRECT_ROUTE_URL="${DIRECT_BASE_URL}"
fi

# EvalHub URL: prefer the external route over the internal service. The
# internal service (port 8443) is blocked by NetworkPolicy to workbench pods
# in other namespaces; the external route goes through the OpenShift router
# and works from any namespace.
EVALHUB_NAMESPACE="redhat-ods-applications"
EVALHUB_EXTERNAL=""
EVALHUB_EXTERNAL=$(oc get route -l app=eval-hub -n "$EVALHUB_NAMESPACE" \
    -o jsonpath='{.items[0].spec.host}' 2>/dev/null || true)
if [ -n "$EVALHUB_EXTERNAL" ]; then
    EVALHUB_OVERRIDE="https://${EVALHUB_EXTERNAL}"
else
    EVALHUB_OVERRIDE="https://evalhub.${EVALHUB_NAMESPACE}.svc:8443"
fi

inject_notebook_env "$NAMESPACE" \
    "MLFLOW_TRACKING_URI=https://mlflow.${EVALHUB_NAMESPACE}.svc:8443" \
    "LIMIT=5" \
    "MODEL_SERVED_NAME=${MODEL_SERVED_NAME}" \
    "HF_MODEL_ID=${HF_MODEL_ID}" \
    "MODEL_ID=${HF_MODEL_ID}" \
    "DIRECT_ROUTE_URL=${DIRECT_ROUTE_URL}" \
    "EVALHUB_URL=${EVALHUB_OVERRIDE}"
print_success "notebook-env ConfigMap created (auto-injected into workbenches)"

# --- Retry the repo clone in case the workbench wasn't Running yet when
# ensure_workbench's wait_for_workbench call ran above -- cheap no-op
# otherwise (already cloned, or still not Running).
clone_if_missing "$NAMESPACE" "model-benchmarking"
