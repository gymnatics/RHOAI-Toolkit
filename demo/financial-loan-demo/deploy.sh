#!/bin/bash
################################################################################
# Deploy Micro Financial Loan Demo
################################################################################
# Clones cbtham/micro-financial-loan and deploys:
#   - Namespace with MinIO for model storage
#   - Web application (Flask + React) with auto-detected model endpoints
#
# The web app needs two models (deployed separately via RHOAI dashboard):
#   - scikit-learn classifier (trained from predictive-model-development.ipynb)
#   - LLM for explanations (shared model via MaaS or InferenceService)
#
# Usage:
#   ./deploy.sh                         # Deploy to financial-loan-demo namespace
#   ./deploy.sh -n my-namespace          # Custom namespace
#   ./deploy.sh --llm-url URL            # Specify LLM endpoint
#   ./deploy.sh --skip-webapp            # Infra only, no web app build
#   ./deploy.sh --delete                 # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"
source "$ROOT_DIR/lib/functions/external-repos.sh"
source "$ROOT_DIR/lib/functions/notebook-env.sh"
source "$ROOT_DIR/lib/functions/storage-backend.sh"

NAMESPACE="financial-loan-demo"
# Positional namespace still works (./deploy.sh my-ns); a leading flag (e.g. --delete) is not a namespace
[[ -n "${1:-}" && "${1:-}" != -* ]] && NAMESPACE="$1"
LLM_URL=""
DELETE_MODE=false
SKIP_WEBAPP=false
DEPLOY_MODEL_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --llm-url) LLM_URL="$2"; shift 2 ;;
        --skip-webapp) SKIP_WEBAPP=true; shift ;;
        --deploy-model) DEPLOY_MODEL_ONLY=true; shift ;;
        --delete) DELETE_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [-n namespace] [--llm-url URL] [--skip-webapp] [--deploy-model] [--delete]"
            echo "  --deploy-model  only (re)deploy the predictive model microloan-sklearn (run after the"
            echo "                  predictive-model-development notebook has uploaded s3://models/microloan/model.joblib)"
            exit 0
            ;;
        *) shift ;;
    esac
done

print_header "Micro Financial Loan Demo"

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing financial loan demo..."
    oc delete namespace microloan-web-app --ignore-not-found 2>/dev/null
    oc delete namespace "$NAMESPACE" --ignore-not-found 2>/dev/null
    # Clean up BuildConfig/ImageStream if they were in the workbench namespace
    oc delete bc microloan-webapp -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete is microloan-webapp -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    print_success "Financial loan demo removed"
    exit 0
fi

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

# --- Clone the repo ---
clone_or_update_repo "micro-financial-loan"
REPO_PATH=$(get_repo_path "micro-financial-loan")

# --- Predictive model: MLServer runtime + microloan-sklearn InferenceService ---
# The notebook saves a scikit-learn pipeline (model.joblib); RHOAI's MLServer runtime serves it with the v2
# protocol the web app uses (output predict_proba). Without this the web app silently falls back to a
# local/mock prediction.
ensure_predictive_runtime() {
    if oc get servingruntime mlserver-runtime -n "$NAMESPACE" &>/dev/null; then
        return 0
    fi
    if oc get template mlserver-runtime-template -n redhat-ods-applications &>/dev/null; then
        print_step "Installing RHOAI MLServer ServingRuntime (sklearn/xgboost/lightgbm, CPU)..."
        oc process mlserver-runtime-template -n redhat-ods-applications | oc apply -n "$NAMESPACE" -f - >/dev/null && \
            print_success "MLServer ServingRuntime installed (mlserver-runtime)"
    elif [ -f "$REPO_PATH/serving-runtimes/mlserver-kserve.yaml" ]; then
        print_step "RHOAI MLServer template not found -- installing upstream MLServer runtime..."
        oc apply -n "$NAMESPACE" -f "$REPO_PATH/serving-runtimes/mlserver-kserve.yaml" >/dev/null
    else
        print_warning "No MLServer runtime available: add one from the dashboard (Settings > Serving runtimes)"
        return 1
    fi
}

deploy_predictive_model() {
    local name="${SKLEARN_MODEL_NAME:-microloan-sklearn}" s3_ep
    ensure_predictive_runtime || return 1
    s3_ep="$(get_storage_endpoint "$NAMESPACE")"
    if ! oc run s3-check-model --rm -i --restart=Never --quiet \
            --image=docker.io/amazon/aws-cli:latest -n "$NAMESPACE" \
            --env="AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY:-admin}" --env="AWS_SECRET_ACCESS_KEY=${S3_SECRET_KEY:-admin123}" \
            --env="AWS_DEFAULT_REGION=us-east-1" \
            -- s3 ls "s3://models/microloan/model.joblib" --endpoint-url "$s3_ep" 2>/dev/null | grep -q model.joblib; then
        print_info "Predictive model not trained yet: run notebooks/predictive-model-development.ipynb in the"
        print_info "model-training workbench, then: $0 -n $NAMESPACE --deploy-model"
        return 0
    fi
    print_step "Deploying predictive model $name (MLServer, s3://models/microloan/model.joblib)..."
    export NAMESPACE SKLEARN_MODEL_NAME="$name" S3_CONNECTION="aws-connection-minio"
    envsubst '${NAMESPACE} ${SKLEARN_MODEL_NAME} ${S3_CONNECTION}' \
        < "$SCRIPT_DIR/manifests/predictive-inferenceservice.yaml.tmpl" | oc apply -f -
    if oc wait --for=condition=Ready "inferenceservice/$name" -n "$NAMESPACE" --timeout=300s >/dev/null 2>&1; then
        local url
        url=$(oc get inferenceservice "$name" -n "$NAMESPACE" -o jsonpath='{.status.url}')
        print_success "Predictive model Ready: $url"
        if oc get configmap webapp-config -n "$NAMESPACE" &>/dev/null && [ -n "$url" ]; then
            oc patch configmap webapp-config -n "$NAMESPACE" --type=merge \
                -p "{\"data\":{\"SKLEARN_API_URL\":\"${url}/v2/models/${name}/infer\"}}" >/dev/null
            oc rollout restart deployment/microloan-webapp -n "$NAMESPACE" >/dev/null 2>&1 && \
                print_success "Web app pointed at ${url}/v2/models/${name}/infer and restarted"
        fi
    else
        print_warning "Predictive model not Ready after 300s: oc describe isvc $name -n $NAMESPACE"
    fi
}

if [ "$DEPLOY_MODEL_ONLY" = true ]; then
    deploy_predictive_model
    exit $?
fi


# --- Workbench namespace + MinIO ---
ensure_namespace "$NAMESPACE"
oc label namespace "$NAMESPACE" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true

print_step "Setting up S3 storage for model storage (${S3_BACKEND:-seaweedfs})..."
detect_or_select_storage_backend "$NAMESPACE"
deploy_storage_backend "$NAMESPACE"
wait_for_storage "$NAMESPACE"

# Create S3 buckets
create_storage_bucket "$NAMESPACE" "models"
create_storage_bucket "$NAMESPACE" "datasets"

# Data connection for RHOAI dashboard
S3_EP="$(get_storage_endpoint "$NAMESPACE")"
DATA_CONNECTION_NAME=aws-connection-minio DATA_CONNECTION_COMPAT=false \
    create_data_connection "$NAMESPACE" models "$NAMESPACE" "S3 - Models & Datasets" >/dev/null 2>&1 || true

# --- Upload training dataset to S3 (backend-agnostic: SeaweedFS/Ceph RGW/MinIO) ---
# NOTE: this previously checked a $MINIO_POD variable + `mc` commands that no
# longer get set anywhere in this script after the SeaweedFS migration --
# that made this entire block permanently dead code (silently skipped even
# with a valid Kaggle token). Fixed to use a generic aws-cli one-shot pod via
# get_storage_endpoint(), same pattern as automl-demo/autorag-demo.
DATA_EXISTS=false
if oc run s3-check-dataset --rm -i --restart=Never -n "$NAMESPACE" \
    --image=docker.io/amazon/aws-cli:latest \
    --env="AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY:-admin}" \
    --env="AWS_SECRET_ACCESS_KEY=${S3_SECRET_KEY:-admin123}" \
    --env="AWS_DEFAULT_REGION=us-east-1" \
    -- s3 ls "s3://datasets/microloan-dataset/application_train.csv" --endpoint-url "$S3_EP" \
    2>/dev/null | grep -q application_train.csv; then
    DATA_EXISTS=true
    print_info "Training dataset already in S3"
fi

if [ "$DATA_EXISTS" = false ]; then
    echo ""
    print_step "Training dataset (Home Credit Default Risk) not found in S3."
    echo ""
    echo "  The notebook requires application_train.csv (~158 MB) from Kaggle."
    echo "  Before proceeding, you must:"
    echo "    1. Have a Kaggle account (https://www.kaggle.com)"
    echo "    2. Accept the competition rules at:"
    echo "       https://www.kaggle.com/c/home-credit-default-risk/rules"
    echo "    3. Create an API token at: https://www.kaggle.com/settings"
    echo ""
    read -rp "Enter your Kaggle API token (or press Enter to skip): " KAGGLE_TOKEN
    if [ -n "$KAGGLE_TOKEN" ]; then
        print_step "Downloading dataset from Kaggle..."
        TMPDIR=$(mktemp -d)
        export KAGGLE_API_TOKEN="$KAGGLE_TOKEN"
        if command -v kaggle &>/dev/null || pip3 install -q kaggle 2>/dev/null; then
            if kaggle competitions download -c home-credit-default-risk -f application_train.csv -p "$TMPDIR" 2>&1; then
                if [ -f "$TMPDIR/application_train.csv.zip" ]; then
                    unzip -o "$TMPDIR/application_train.csv.zip" -d "$TMPDIR" 2>/dev/null
                fi
                if [ -f "$TMPDIR/application_train.csv" ]; then
                    print_step "Uploading to S3 (this may take a minute)..."
                    oc run s3-upload-dataset --rm -i --restart=Never -n "$NAMESPACE" \
                        --image=docker.io/amazon/aws-cli:latest \
                        --env="AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY:-admin}" \
                        --env="AWS_SECRET_ACCESS_KEY=${S3_SECRET_KEY:-admin123}" \
                        --env="AWS_DEFAULT_REGION=us-east-1" \
                        -- s3 cp - "s3://datasets/microloan-dataset/application_train.csv" --endpoint-url "$S3_EP" \
                        < "$TMPDIR/application_train.csv" 2>/dev/null \
                    && print_success "Training dataset uploaded to S3" \
                    || print_warning "Upload failed -- upload manually from the workbench"
                fi
            else
                print_warning "Download failed -- make sure you accepted the competition rules"
            fi
        else
            print_warning "Could not install kaggle CLI"
        fi
        rm -rf "$TMPDIR"
        unset KAGGLE_API_TOKEN
    else
        print_info "Skipped -- you can download the dataset later from the workbench notebook"
    fi
fi

# --- Predictive ServingRuntime (CPU): RHOAI MLServer ---
ensure_predictive_runtime || true

# --- Detect model endpoints ---
CLUSTER_DOMAIN=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)

if [ -z "$LLM_URL" ]; then
    print_step "Auto-detecting LLM endpoint..."

    # Prefer direct (non-MaaS) vLLM endpoint — simpler, no gateway auth needed
    detect_direct_llm_endpoint || true
    if [ -n "$DIRECT_MODEL_NAME" ]; then
        LLM_URL="${DIRECT_BASE_URL%/v1}/v1/chat/completions"
        LLM_ISVC="$DIRECT_MODEL_NAME"
        print_success "Detected direct vLLM: $DIRECT_MODEL_NAME (ns: $DIRECT_MODEL_NS)"
    else
        # Fallback: the RHOAI 3.3 (Tech Preview) MaaS gateway -- not present on 3.4+
        MAAS_GATEWAY="https://inference-gateway.${CLUSTER_DOMAIN}"
        if [[ "$(oc get csv -n redhat-ods-operator -o jsonpath='{.items[?(@.spec.displayName=="Red Hat OpenShift AI")].spec.version}' 2>/dev/null)" == 3.3* ]] && curl -sk --connect-timeout 3 "$MAAS_GATEWAY/v1/models" -H "Authorization: Bearer $(oc create token default -n "$NAMESPACE" --duration=1m 2>/dev/null)" 2>/dev/null | grep -q "data"; then
            LLM_URL="${MAAS_GATEWAY}/v1/chat/completions"
            print_success "Detected MaaS gateway"
        else
            # Last resort: detect LLMInferenceService internal endpoint
            detect_llm_endpoint || true
            if [ -n "$LLM_MODEL_NAME" ]; then
                LLM_URL="${LLM_BASE_URL%/v1}/v1/chat/completions"
                LLM_ISVC="$LLM_MODEL_NAME"
                print_success "Detected LLM: $LLM_MODEL_NAME (ns: $LLM_MODEL_NS)"
            else
                LLM_URL="https://inference-gateway.${CLUSTER_DOMAIN}/v1/chat/completions"
                print_warning "No LLM model detected -- deploy a GenAI model first"
            fi
        fi
    fi
fi

# OpenAI "model" field = served id (LLMInferenceService spec.model.name), not the resource name
if [ -n "${LLM_ISVC:-}" ] && [ -n "${LLM_MODEL_NS:-${DIRECT_MODEL_NS:-}}" ]; then
    LLM_MODEL_NAME=$(resolve_served_model_id "$LLM_ISVC" "${LLM_MODEL_NS:-$DIRECT_MODEL_NS}")
fi

# --- Detect predictive model endpoint ---
SKLEARN_MODEL_NAME=""
SKLEARN_MODEL_NS=""
# Look for a predictive InferenceService in this namespace first, then any namespace
while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    sk_ns=$(echo "$line" | awk '{print $1}')
    sk_name=$(echo "$line" | awk '{print $2}')
    sk_fmt=$(oc get inferenceservice "$sk_name" -n "$sk_ns" -o jsonpath='{.spec.predictor.model.modelFormat.name}' 2>/dev/null || true)
    if echo "$sk_fmt" | grep -qi -E 'sklearn|xgboost|lightgbm|onnx'; then
        SKLEARN_MODEL_NAME="$sk_name"
        SKLEARN_MODEL_NS="$sk_ns"
        break
    fi
done < <(oc get inferenceservice -n "$NAMESPACE" --no-headers 2>/dev/null || true; oc get inferenceservice -A --no-headers 2>/dev/null || true) || true

if [ -n "$SKLEARN_MODEL_NAME" ]; then
    SKLEARN_API_URL="https://${SKLEARN_MODEL_NAME}-${SKLEARN_MODEL_NS}.${CLUSTER_DOMAIN}/v2/models/${SKLEARN_MODEL_NAME}/infer"
    print_success "Detected predictive model: $SKLEARN_MODEL_NAME (ns: $SKLEARN_MODEL_NS)"
else
    SKLEARN_MODEL_NAME="microloan-sklearn"
    SKLEARN_API_URL="https://${SKLEARN_MODEL_NAME}-${NAMESPACE}.${CLUSTER_DOMAIN}/v2/models/${SKLEARN_MODEL_NAME}/infer"
    print_info "No predictive model deployed yet -- using default name: $SKLEARN_MODEL_NAME"
fi

# --- Generate demo-config.env for vendored notebooks ---
# NOTE: previously hardcoded MINIO_SVC=http://minio.$NAMESPACE.svc:9000 +
# minio/minio123 creds here too (same class of bug as the inject_notebook_env
# call below) -- this is a second, independent place notebooks can pick up
# config from (the printed "copy the ConfigMap to a .env file" instructions),
# so it needs the same S3_EP/S3_ACCESS_KEY/S3_SECRET_KEY fix.
CONFIG_ENV_CONTENT="# Auto-generated by deploy.sh -- $(date -u +%Y-%m-%dT%H:%M:%SZ)
S3_ENDPOINT=${S3_EP}
AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY:-admin}
AWS_SECRET_ACCESS_KEY=${S3_SECRET_KEY:-admin123}
S3_BUCKET_DATA=datasets
S3_BUCKET_MODELS=models
NAMESPACE=${NAMESPACE}
SKLEARN_API_URL=${SKLEARN_API_URL}
LLM_URL=${LLM_URL}
HF_MODEL_ID=${HF_MODEL_ID:-RedHatAI/Qwen3-8B-FP8-dynamic}
LLM_MODEL_NAME=${LLM_MODEL_NAME:-${LLM_ISVC:-qwen3-4b}}
"

oc create configmap demo-config-env \
    --from-literal=".env=${CONFIG_ENV_CONTENT}" \
    -n "$NAMESPACE" --dry-run=client -o yaml | oc apply -f - 2>/dev/null && \
    print_success "ConfigMap demo-config-env created (mount as /opt/app-root/src/.env in workbench)" || true

# --- Deploy web application (vendored) ---
WEBAPP_DIR="$SCRIPT_DIR/web-application"
if [ "$SKIP_WEBAPP" = false ] && [ -d "$WEBAPP_DIR" ]; then
    print_step "Deploying web application in $NAMESPACE..."

    # Auto-detect LLM model name (reuse detected endpoint name)
    LLM_MODEL_NAME="${LLM_MODEL_NAME:-}"
    if [ -z "$LLM_MODEL_NAME" ]; then
        if [ -n "${LLM_ISVC:-}" ]; then
            LLM_MODEL_NAME="$LLM_ISVC"
        elif [ -n "${DIRECT_MODEL_NAME:-}" ]; then
            LLM_MODEL_NAME="$DIRECT_MODEL_NAME"
        elif [ -n "${LLM_MODEL_NAME:-}" ]; then
            LLM_MODEL_NAME="$LLM_MODEL_NAME"
        else
            LLM_MODEL_NAME=$(oc get llmisvc -A --no-headers 2>/dev/null | awk '{print $2}' | head -1)
            [ -z "$LLM_MODEL_NAME" ] && LLM_MODEL_NAME="qwen3-4b"
        fi
    fi
    # The chat API needs the served id (LLMInferenceService spec.model.name), not the resource name
    if [ -n "${LLM_MODEL_NS:-${DIRECT_MODEL_NS:-}}" ]; then
        LLM_MODEL_NAME=$(resolve_served_model_id "$LLM_MODEL_NAME" "${LLM_MODEL_NS:-$DIRECT_MODEL_NS}")
    fi
    print_info "LLM model name for web app: $LLM_MODEL_NAME"

    # Patch the deployment.yaml namespace and apply
    sed "s/microloan-web-app/$NAMESPACE/g" "$WEBAPP_DIR/deployment.yaml" | oc apply -n "$NAMESPACE" -f -

    # ConfigMap with auto-detected endpoints + model name
    export NAMESPACE SKLEARN_API_URL LLM_URL LLM_MODEL_NAME
    envsubst '${NAMESPACE} ${SKLEARN_API_URL} ${LLM_URL} ${LLM_MODEL_NAME}' \
        < "$SCRIPT_DIR/manifests/webapp-config.yaml.tmpl" | oc apply -n "$NAMESPACE" -f -

    # Build the container image from vendored source
    print_step "Building web app container image (this takes 1-2 minutes)..."
    oc start-build microloan-webapp --from-dir="$WEBAPP_DIR" -n "$NAMESPACE" --follow 2>/dev/null || \
        print_warning "Build failed or already running -- check: oc get builds -n $NAMESPACE"

    # Restart to pick up the patched ConfigMap
    oc rollout restart deployment/microloan-webapp -n "$NAMESPACE" 2>/dev/null || true
    oc rollout status deployment/microloan-webapp -n "$NAMESPACE" --timeout=120s 2>/dev/null || true

    WEBAPP_URL="https://$(oc get route microloan-webapp -n "$NAMESPACE" -o jsonpath='{.status.ingress[0].host}' 2>/dev/null)"
    print_success "Web app deployed: $WEBAPP_URL"
else
    WEBAPP_URL="(skipped)"
    if [ "$SKIP_WEBAPP" = true ]; then
        print_info "Web app deployment skipped (--skip-webapp)"
    fi
fi

echo ""
print_success "Financial Loan Demo deployed"

# --- Predictive model (only if the notebook already uploaded it; otherwise prints how to) ---
deploy_predictive_model || true

# --- Create workbench + clone repo (GPU workbench with PyTorch image) ---
source "$ROOT_DIR/lib/functions/workbench.sh"
ensure_workbench "$NAMESPACE" "model-training" "$(workbench_image pytorch)" "2" "4" "12Gi" "12Gi" "1" "20Gi" "Model Training"

# --- Inject notebook environment variables into workbench ---
source "$ROOT_DIR/lib/functions/notebook-env.sh"
# NOTE: previously hardcoded S3_ENDPOINT=${S3_ENDPOINT} (an unset variable --
# this script uses $S3_EP, set above from get_storage_endpoint()) and the
# literal MinIO default credentials minio/minio123. Both silently pointed
# every notebook at the old MinIO endpoint even after the SeaweedFS backend
# was deployed and the aws-connection-minio data-connection Secret was
# correctly updated -- confirmed live on cluster-sclg6 2026-09-28: the Secret
# had the new seaweedfs-s3:8333 endpoint while notebook-env still had
# minio:9000/minio/minio123. Fixed to use the same S3_EP/S3_ACCESS_KEY/
# S3_SECRET_KEY variables the data-connection Secret above uses.
# Resolve Model Registry URL for notebooks that register models.
# Port 8080 is the REST API (no auth); port 8443 is the kube-rbac-proxy
# endpoint (requires SA auth). Notebooks use requests.get() without auth,
# so port 8080 is the correct default.
REGISTRY_NS="rhoai-model-registries"
REGISTRY_NAME="model-registry"
if oc get svc "$REGISTRY_NAME" -n "$REGISTRY_NS" &>/dev/null; then
    MODEL_REGISTRY_URL="http://${REGISTRY_NAME}.${REGISTRY_NS}.svc:8080"
else
    MODEL_REGISTRY_URL=""
fi

inject_notebook_env "$NAMESPACE" \
    "S3_ENDPOINT=${S3_EP}" \
    "AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY:-admin}" \
    "AWS_SECRET_ACCESS_KEY=${S3_SECRET_KEY:-admin123}" \
    "S3_BUCKET_DATA=datasets" \
    "S3_BUCKET_MODELS=models" \
    "HF_MODEL_ID=${HF_MODEL_ID:-RedHatAI/Qwen3-8B-FP8-dynamic}" \
    "FINETUNE_MODEL_ID=Qwen/Qwen3-4B-Instruct-2507" \
    "LLM_URL=${LLM_URL}" \
    "MODEL_REGISTRY_URL=${MODEL_REGISTRY_URL}"
# NOTE: do NOT also pass SKLEARN_API_URL here -- inject_notebook_env already
# calls detect_predictive_endpoint internally and adds SKLEARN_MODEL_NAME +
# SKLEARN_API_URL to the ConfigMap automatically when a predictive model is
# found. Passing it again as an extra arg produced a duplicate
# `--from-literal=SKLEARN_API_URL=...` in the same `oc create configmap`
# invocation, which fails client-side with "cannot add key ..., another key
# by that name already exists" (confirmed 2026-09-21 on cluster-sclg6).
print_success "notebook-env ConfigMap created (auto-injected into workbenches)"

# --- Retry the repo clone now that the rest of the demo has finished
# deploying -- model-training is a GPU workbench, so ensure_workbench's
# earlier wait_for_workbench call may have timed out waiting for a GPU node
# to provision. By now (after web app + notebook-env steps), it's had extra
# time and is often Running. Cheap no-op if already cloned or still Pending.
clone_if_missing "$NAMESPACE" "model-training"

echo ""
echo "  Components:"
echo "    Workbench namespace: $NAMESPACE (create workbench from RHOAI dashboard)"
echo "    Web app:             $WEBAPP_URL"
echo "    Repo:                $REPO_PATH"
echo ""
echo "  Model endpoints:"
echo "    SKLEARN: $SKLEARN_API_URL"
echo "    LLM:     $LLM_URL"
echo ""
echo "  Notebooks (run in workbench):"
echo "    1. RHOAI-Toolkit is auto-cloned into the workbench. If the GPU node was"
echo "       still provisioning during deploy, run once it's Running:"
echo "         ./scripts/clone-toolkit-in-workbenches.sh -n $NAMESPACE"
echo "    2. Open demo/financial-loan-demo/notebooks/"
echo "         predictive-model-development.ipynb -- train scikit-learn classifier"
echo "         llm-model-fine-tuning.ipynb -- fine-tune LLM (optional)"
echo "    3. Config is auto-detected. To override, copy the ConfigMap to a .env file:"
echo "         oc get cm demo-config-env -n $NAMESPACE -o jsonpath='{.data.\.env}' > .env"
echo ""
echo "  The web app is live but needs the scikit-learn model deployed to work fully."
echo "  Train the model in the notebook, serve it via RHOAI dashboard, then refresh."
echo ""
echo "  Original notebooks: https://github.com/cbtham/micro-financial-loan"
echo ""
