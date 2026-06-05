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

NAMESPACE="${1:-financial-loan-demo}"
LLM_URL=""
DELETE_MODE=false
SKIP_WEBAPP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --llm-url) LLM_URL="$2"; shift 2 ;;
        --skip-webapp) SKIP_WEBAPP=true; shift ;;
        --delete) DELETE_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [-n namespace] [--llm-url URL] [--skip-webapp] [--delete]"
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

# --- Workbench namespace + MinIO ---
ensure_namespace "$NAMESPACE"
oc label namespace "$NAMESPACE" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true

print_step "Setting up MinIO for model storage..."
if oc get deployment minio -n "$NAMESPACE" &>/dev/null; then
    print_info "MinIO already deployed in $NAMESPACE"
else
    if [ -f "$ROOT_DIR/lib/manifests/storage/minio.yaml" ]; then
        export NAMESPACE
        envsubst < "$ROOT_DIR/lib/manifests/storage/minio.yaml" | oc apply -n "$NAMESPACE" -f - 2>/dev/null || \
            print_warning "MinIO setup failed -- set up storage manually"
        oc rollout status deployment/minio -n "$NAMESPACE" --timeout=120s 2>/dev/null || true
    else
        print_warning "MinIO manifest not found -- set up storage manually"
    fi
fi

# Create S3 buckets and data connection
MINIO_POD=$(oc get pod -l app.kubernetes.io/name=minio -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$MINIO_POD" ]; then
    oc exec "$MINIO_POD" -n "$NAMESPACE" -- sh -c '
        mc alias set local http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} 2>/dev/null
        mc mb --ignore-existing local/models 2>/dev/null
        mc mb --ignore-existing local/datasets 2>/dev/null
    ' &>/dev/null || true
fi

# Data connection for RHOAI dashboard
oc apply -n "$NAMESPACE" -f - <<DCEOF 2>/dev/null || true
apiVersion: v1
kind: Secret
metadata:
  name: aws-connection-minio
  labels:
    opendatahub.io/dashboard: "true"
    opendatahub.io/managed: "true"
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: "MinIO - Models & Datasets"
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: minio
  AWS_SECRET_ACCESS_KEY: minio123
  AWS_DEFAULT_REGION: us-east-1
  AWS_S3_BUCKET: models
  AWS_S3_ENDPOINT: http://minio.${NAMESPACE}.svc.cluster.local:9000
DCEOF

# --- Upload training dataset to MinIO ---
DATA_EXISTS=false
if [ -n "$MINIO_POD" ]; then
    if oc exec "$MINIO_POD" -n "$NAMESPACE" -- sh -c \
        'mc alias set local http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} 2>/dev/null && mc stat local/datasets/microloan-dataset/application_train.csv 2>/dev/null' &>/dev/null; then
        DATA_EXISTS=true
        print_info "Training dataset already in MinIO"
    fi
fi

if [ "$DATA_EXISTS" = false ] && [ -n "$MINIO_POD" ]; then
    echo ""
    print_step "Training dataset (Home Credit Default Risk) not found in MinIO."
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
                    print_step "Uploading to MinIO (this may take a minute)..."
                    oc exec -i "$MINIO_POD" -n "$NAMESPACE" -- sh -c 'cat > /tmp/application_train.csv' \
                        < "$TMPDIR/application_train.csv" 2>/dev/null
                    oc exec "$MINIO_POD" -n "$NAMESPACE" -- sh -c '
                        mc alias set local http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} 2>/dev/null
                        mc cp /tmp/application_train.csv local/datasets/microloan-dataset/application_train.csv 2>/dev/null
                        rm /tmp/application_train.csv
                    ' 2>/dev/null && print_success "Training dataset uploaded to MinIO" || \
                        print_warning "Upload failed -- upload manually from the workbench"
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

# --- Check for predictive ServingRuntime (CPU) ---
PREDICTIVE_RUNTIME_EXISTS=$(oc get servingruntime -A -o jsonpath='{range .items[*]}{.spec.supportedModelFormats[*].name}{" "}{end}' 2>/dev/null)
if echo "$PREDICTIVE_RUNTIME_EXISTS" | grep -qi -E 'sklearn|xgboost|lightgbm'; then
    print_info "Predictive ServingRuntime available (supports sklearn/xgboost)"
else
    print_step "No predictive ServingRuntime found -- installing XGBServer..."
    if [ -f "$REPO_PATH/serving-runtimes/xgbserver-kserve.yaml" ]; then
        oc apply -n "$NAMESPACE" -f "$REPO_PATH/serving-runtimes/xgbserver-kserve.yaml" 2>/dev/null && \
            print_success "XGBoost ServingRuntime installed (CPU, no GPU required)" || \
            print_warning "Failed to install -- import ServingRuntime manually from dashboard"
    else
        print_warning "Install MLServer or XGBServer from the RHOAI dashboard (Settings > Serving runtimes)"
    fi
fi

# --- Detect model endpoints ---
CLUSTER_DOMAIN=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)

if [ -z "$LLM_URL" ]; then
    print_step "Auto-detecting LLM endpoint..."
    MAAS_GATEWAY="https://inference-gateway.${CLUSTER_DOMAIN}"
    if curl -sk --connect-timeout 3 "$MAAS_GATEWAY/v1/models" -H "Authorization: Bearer $(oc create token default -n "$NAMESPACE" --duration=1m 2>/dev/null)" 2>/dev/null | grep -q "data"; then
        LLM_URL="${MAAS_GATEWAY}/v1/chat/completions"
        print_success "Detected MaaS gateway"
    else
        # Prefer LLMInferenceService (GenAI), then vLLM InferenceService; skip predictive models
        LLM_ISVC=""
        LLM_ISVC_NS=""
        FIRST_LLMISVC=$(oc get llmisvc -A --no-headers 2>/dev/null | head -1)
        if [ -n "$FIRST_LLMISVC" ]; then
            LLM_ISVC_NS=$(echo "$FIRST_LLMISVC" | awk '{print $1}')
            LLM_ISVC=$(echo "$FIRST_LLMISVC" | awk '{print $2}')
        else
            # Look for vLLM-based InferenceService (skip sklearn/xgboost/lightgbm)
            while IFS= read -r line || [ -n "$line" ]; do
                [ -z "$line" ] && continue
                ns=$(echo "$line" | awk '{print $1}')
                name=$(echo "$line" | awk '{print $2}')
                fmt=$(oc get inferenceservice "$name" -n "$ns" -o jsonpath='{.spec.predictor.model.modelFormat.name}' 2>/dev/null || true)
                if echo "$fmt" | grep -qi -E 'sklearn|xgboost|lightgbm|onnx'; then
                    continue
                fi
                LLM_ISVC_NS="$ns"
                LLM_ISVC="$name"
                break
            done < <(oc get inferenceservice -A --no-headers 2>/dev/null || true) || true
        fi

        if [ -n "$LLM_ISVC" ]; then
            LLM_URL="https://${LLM_ISVC}-predictor.${LLM_ISVC_NS}.svc:8080/v1/chat/completions"
            print_success "Detected LLM: $LLM_ISVC (ns: $LLM_ISVC_NS)"
        else
            LLM_URL="https://inference-gateway.${CLUSTER_DOMAIN}/v1/chat/completions"
            print_warning "No LLM model detected -- deploy a GenAI model first"
        fi
    fi
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
    SKLEARN_API_URL="https://${SKLEARN_MODEL_NAME}-${SKLEARN_MODEL_NS}.apps.${CLUSTER_DOMAIN}/v2/models/${SKLEARN_MODEL_NAME}/infer"
    print_success "Detected predictive model: $SKLEARN_MODEL_NAME (ns: $SKLEARN_MODEL_NS)"
else
    SKLEARN_MODEL_NAME="microloan-sklearn"
    SKLEARN_API_URL="https://${SKLEARN_MODEL_NAME}-${NAMESPACE}.apps.${CLUSTER_DOMAIN}/v2/models/${SKLEARN_MODEL_NAME}/infer"
    print_info "No predictive model deployed yet -- using default name: $SKLEARN_MODEL_NAME"
fi

# --- Generate demo-config.env for vendored notebooks ---
MINIO_SVC="http://minio.${NAMESPACE}.svc:9000"
MINIO_ROUTE="https://minio-api-${NAMESPACE}.apps.${CLUSTER_DOMAIN}"
S3_ENDPOINT="${MINIO_SVC}"

CONFIG_ENV_CONTENT="# Auto-generated by deploy.sh -- $(date -u +%Y-%m-%dT%H:%M:%SZ)
S3_ENDPOINT=${S3_ENDPOINT}
AWS_ACCESS_KEY_ID=minio
AWS_SECRET_ACCESS_KEY=minio123
S3_BUCKET_DATA=datasets
S3_BUCKET_MODELS=models
NAMESPACE=${NAMESPACE}
SKLEARN_API_URL=${SKLEARN_API_URL}
LLM_URL=${LLM_URL}
HF_MODEL_ID=${HF_MODEL_ID:-Qwen/Qwen3-4B-Instruct-2507}
LLM_MODEL_NAME=${LLM_MODEL_NAME:-qwen3-4b}
"

oc create configmap demo-config-env \
    --from-literal=".env=${CONFIG_ENV_CONTENT}" \
    -n "$NAMESPACE" --dry-run=client -o yaml | oc apply -f - 2>/dev/null && \
    print_success "ConfigMap demo-config-env created (mount as /opt/app-root/src/.env in workbench)" || true

# --- Deploy web application (vendored) ---
WEBAPP_DIR="$SCRIPT_DIR/web-application"
if [ "$SKIP_WEBAPP" = false ] && [ -d "$WEBAPP_DIR" ]; then
    print_step "Deploying web application in $NAMESPACE..."

    # Auto-detect LLM model name (reuse the LLM_ISVC found during endpoint detection)
    LLM_MODEL_NAME="${LLM_MODEL_NAME:-}"
    if [ -z "$LLM_MODEL_NAME" ]; then
        if [ -n "${LLM_ISVC:-}" ]; then
            LLM_MODEL_NAME="$LLM_ISVC"
        else
            LLM_MODEL_NAME=$(oc get llmisvc -A --no-headers 2>/dev/null | awk '{print $2}' | head -1)
            [ -z "$LLM_MODEL_NAME" ] && LLM_MODEL_NAME="qwen3-4b"
        fi
        print_info "LLM model name for web app: $LLM_MODEL_NAME"
    fi

    # Patch the deployment.yaml namespace and apply
    sed "s/microloan-web-app/$NAMESPACE/g" "$WEBAPP_DIR/deployment.yaml" | oc apply -n "$NAMESPACE" -f -

    # ConfigMap with auto-detected endpoints + model name
    oc apply -n "$NAMESPACE" -f - <<PATCH
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: ${NAMESPACE}
data:
  SKLEARN_API_URL: "${SKLEARN_API_URL}"
  LLM_API_URL: "${LLM_URL}"
  LLM_MODEL_NAME: "${LLM_MODEL_NAME}"
  FLASK_ENV: "production"
  HOST: "0.0.0.0"
  PORT: "8080"
PATCH

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
echo "    1. Clone this repo in your workbench:"
echo "         git clone https://github.com/gymnatics/RHOAI-Toolkit.git"
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
