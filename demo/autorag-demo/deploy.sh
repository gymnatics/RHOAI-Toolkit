#!/bin/bash
################################################################################
# Deploy AutoRAG Demo
################################################################################
# Sets up infrastructure for AutoRAG (Technology Preview):
#   - MinIO for document storage and pipeline artifacts
#   - Milvus vector database (remote -- required by AutoRAG)
#   - Pipeline Server (DSPA) for Kubeflow Pipelines
#   - S3 data connection and sample documents
#   - Activates Llama Stack Operator if not already enabled
#
# AutoRAG itself is a dashboard-native feature -- after infrastructure is ready,
# use the RHOAI dashboard: Develop and train > AutoRAG
#
# Prerequisites:
#   - Llama Stack Operator activated (llamastackoperator: Managed in DSC)
#   - Llama Stack instance with foundation + embedding models
#   - Gen AI Studio enabled in dashboard
#
# Usage:
#   ./deploy.sh                    # Deploy to autorag-demo namespace
#   ./deploy.sh -n my-namespace    # Custom namespace
#   ./deploy.sh --delete           # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"
source "$ROOT_DIR/lib/functions/notebook-env.sh"

NAMESPACE="${1:-autorag-demo}"
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

print_header "AutoRAG Demo (Technology Preview)"

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing AutoRAG infrastructure from $NAMESPACE..."
    oc delete llamastackdistribution autorag-llamastack -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    export NAMESPACE
    envsubst < "$SCRIPT_DIR/manifests/llamastack-postgresql.yaml" | oc delete -f - --ignore-not-found 2>/dev/null
    oc delete secret llama-stack-secret milvus-connection-secret -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete datasciencepipelineapplication pipelines-definition -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    envsubst < "$SCRIPT_DIR/manifests/milvus.yaml" | oc delete -f - --ignore-not-found 2>/dev/null
    envsubst < "$SCRIPT_DIR/manifests/minio.yaml" | oc delete -f - --ignore-not-found 2>/dev/null
    print_success "AutoRAG infrastructure removed from $NAMESPACE"
    exit 0
fi

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

# --- Step 0: Verify prerequisites ---
print_step "Checking prerequisites..."

# Check Llama Stack Operator
LLAMASTACK_STATE=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.llamastackoperator.managementState}' 2>/dev/null)
if [ "$LLAMASTACK_STATE" != "Managed" ]; then
    print_warning "Llama Stack Operator is not enabled (current: ${LLAMASTACK_STATE:-not set})"
    print_info "Activating Llama Stack Operator in DSC..."
    oc patch datasciencecluster default-dsc --type=merge \
        -p '{"spec":{"components":{"llamastackoperator":{"managementState":"Managed"}}}}' 2>/dev/null || \
        print_warning "Could not patch DSC -- enable llamastackoperator manually"
fi

# Check AI Pipelines
if ! oc get crd datasciencepipelinesapplications.datasciencepipelinesapplications.opendatahub.io &>/dev/null 2>&1; then
    print_error "DSPA CRD not found. Ensure 'aipipelines: Managed' in your DataScienceCluster."
    exit 1
fi

ensure_namespace "$NAMESPACE"
oc label namespace "$NAMESPACE" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true

# Enable AutoRAG in dashboard
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
    --type=merge -p '{"spec":{"dashboardConfig":{"autorag":true}}}' 2>/dev/null || true

# --- Step 1: MinIO for document storage + pipeline artifacts ---
print_step "Deploying MinIO for document storage..."
if oc get deployment minio -n "$NAMESPACE" &>/dev/null; then
    print_info "MinIO already deployed in $NAMESPACE"
else
    export NAMESPACE
    envsubst < "$SCRIPT_DIR/manifests/minio.yaml" | oc apply -f -
    oc rollout status deployment/minio -n "$NAMESPACE" --timeout=120s 2>/dev/null || true
fi

# Create buckets and upload sample docs
print_step "Creating S3 buckets and uploading sample documents..."
MINIO_POD=$(oc get pod -l app=minio -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$MINIO_POD" ]; then
    oc exec "$MINIO_POD" -n "$NAMESPACE" -- sh -c '
        mc alias set local http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} 2>/dev/null
        mc mb --ignore-existing local/pipeline-artifacts 2>/dev/null
        mc mb --ignore-existing local/autorag-docs 2>/dev/null
    ' 2>/dev/null || print_warning "Could not create buckets -- MinIO may still be starting"

    for doc in "$SCRIPT_DIR/sample-data/docs"/*; do
        if [ -f "$doc" ]; then
            BASENAME=$(basename "$doc")
            oc exec -i "$MINIO_POD" -n "$NAMESPACE" -- sh -c "cat > /tmp/$BASENAME" \
                < "$doc" 2>/dev/null
            oc exec "$MINIO_POD" -n "$NAMESPACE" -- sh -c \
                "mc cp /tmp/$BASENAME local/autorag-docs/$BASENAME 2>/dev/null" 2>/dev/null || true
        fi
    done

    # Upload test data for AutoRAG evaluation
    if [ -f "$SCRIPT_DIR/sample-data/test-data.json" ]; then
        oc exec -i "$MINIO_POD" -n "$NAMESPACE" -- sh -c "cat > /tmp/test-data.json" \
            < "$SCRIPT_DIR/sample-data/test-data.json" 2>/dev/null
        oc exec "$MINIO_POD" -n "$NAMESPACE" -- sh -c \
            "mc cp /tmp/test-data.json local/autorag-docs/test-data.json 2>/dev/null" 2>/dev/null || true
    fi
    print_success "Sample documents and test data uploaded to s3://autorag-docs/"
else
    print_warning "MinIO pod not found yet -- upload documents after MinIO is ready"
fi

# --- Step 2: S3 data connection ---
print_step "Creating S3 data connection for AutoRAG documents..."
oc apply -n "$NAMESPACE" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: aws-connection-autorag-docs
  namespace: $NAMESPACE
  labels:
    opendatahub.io/dashboard: "true"
    opendatahub.io/managed: "true"
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: "AutoRAG Documents"
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: minio
  AWS_SECRET_ACCESS_KEY: minio123
  AWS_DEFAULT_REGION: us-east-1
  AWS_S3_BUCKET: autorag-docs
  AWS_S3_ENDPOINT: http://minio.${NAMESPACE}.svc.cluster.local:9000
EOF

# --- Step 3: Milvus vector database ---
print_step "Deploying Milvus vector database..."
if oc get deployment milvus-standalone -n "$NAMESPACE" &>/dev/null; then
    print_info "Milvus already deployed in $NAMESPACE"
else
    export NAMESPACE
    envsubst < "$SCRIPT_DIR/manifests/milvus.yaml" | oc apply -f -
    print_info "Milvus deploying (takes 1-2 minutes for readiness)..."
    oc rollout status deployment/milvus-standalone -n "$NAMESPACE" --timeout=180s 2>/dev/null || \
        print_warning "Milvus not ready yet -- check: oc get pods -l app=milvus -n $NAMESPACE"
fi

MILVUS_ENDPOINT="milvus.${NAMESPACE}.svc.cluster.local:19530"

# --- Step 4: Pipeline Server (DSPA) ---
print_step "Deploying Pipeline Server (DSPA)..."
if oc get datasciencepipelinesapplication pipelines-definition -n "$NAMESPACE" &>/dev/null 2>&1; then
    print_info "Pipeline server already exists in $NAMESPACE"
else
    export NAMESPACE
    envsubst < "$SCRIPT_DIR/manifests/pipeline-server.yaml" | oc apply -f -
    print_info "Pipeline server deploying (takes 1-2 minutes)..."
fi

# --- Step 5: PostgreSQL for LlamaStack metadata ---
print_step "Deploying PostgreSQL for LlamaStack metadata store..."
if oc get deployment llamastack-postgres -n "$NAMESPACE" &>/dev/null; then
    print_info "LlamaStack PostgreSQL already deployed in $NAMESPACE"
else
    export NAMESPACE
    envsubst < "$SCRIPT_DIR/manifests/llamastack-postgresql.yaml" | oc apply -f -
    oc rollout status deployment/llamastack-postgres -n "$NAMESPACE" --timeout=120s 2>/dev/null || \
        print_warning "PostgreSQL not ready yet -- check: oc get pods -l app=llamastack-postgres -n $NAMESPACE"
fi

# --- Step 6: LlamaStack (auto-configured with direct vLLM + embedding endpoints) ---
print_step "Deploying LlamaStack..."

# Detect direct vLLM LLM endpoint (standard InferenceService, not MaaS)
if detect_direct_llm_endpoint; then
    print_info "Found direct vLLM LLM: $DIRECT_MODEL_NAME (ns: $DIRECT_MODEL_NS)"
else
    print_warning "No direct vLLM LLM endpoint found -- LlamaStack will need manual VLLM_URL configuration"
fi

# Detect embedding model in this namespace
EMBEDDING_ISVC=""
while IFS= read -r isvc_name; do
    [ -z "$isvc_name" ] && continue
    if echo "$isvc_name" | grep -qi -E 'bge|e5-|embed|nomic-embed'; then
        EMBEDDING_ISVC="$isvc_name"
        break
    fi
done < <(oc get inferenceservice -n "$NAMESPACE" --no-headers -o custom-columns='NAME:.metadata.name' 2>/dev/null || true)

EMBED_SVC="" EMBED_PORT=""
if [ -n "$EMBEDDING_ISVC" ]; then
    EMBED_SVC=$(oc get svc -n "$NAMESPACE" -l "serving.kserve.io/inferenceservice=${EMBEDDING_ISVC}" \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    EMBED_SVC="${EMBED_SVC:-${EMBEDDING_ISVC}-predictor}"
    EMBED_PORT=$(oc get svc "$EMBED_SVC" -n "$NAMESPACE" \
        -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "80")
    print_info "Found embedding model: $EMBEDDING_ISVC"
else
    print_warning "No embedding model found in $NAMESPACE -- deploy one (e.g. bge-m3) before running AutoRAG"
fi

# Set envsubst variables for LlamaStack manifest
export INFERENCE_MODEL="${DIRECT_MODEL_NAME:-}"
export VLLM_URL="${DIRECT_BASE_URL:-}"
export VLLM_TLS_VERIFY="false"
export VLLM_API_TOKEN=""
export EMBEDDING_MODEL="${EMBEDDING_ISVC:-bge-m3}"
export EMBEDDING_PROVIDER_MODEL_ID="${EMBEDDING_ISVC:-bge-m3}"
if [ -n "$EMBEDDING_ISVC" ]; then
    export VLLM_EMBEDDING_URL="http://${EMBED_SVC}.${NAMESPACE}.svc.cluster.local:${EMBED_PORT}/v1"
else
    export VLLM_EMBEDDING_URL=""
fi
export VLLM_EMBEDDING_API_TOKEN=""
export VLLM_EMBEDDING_TLS_VERIFY="false"
export VLLM_EMBEDDING_MAX_TOKENS="8192"
export MILVUS_ENDPOINT
export MILVUS_TOKEN=""

envsubst < "$SCRIPT_DIR/manifests/llamastack.yaml" | oc apply -f -
print_info "LlamaStack deploying (takes 1-2 minutes)..."

# Wait briefly for LlamaStack pod to start
sleep 5
oc rollout status deployment/autorag-llamastack -n "$NAMESPACE" --timeout=180s 2>/dev/null || \
    print_warning "LlamaStack not ready yet -- check: oc get pods -l app.kubernetes.io/name=autorag-llamastack -n $NAMESPACE"

LLAMASTACK_URL="http://autorag-llamastack-service.${NAMESPACE}.svc.cluster.local:8321"

echo ""
print_success "AutoRAG Demo infrastructure deployed"
print_info "Namespace: $NAMESPACE"
print_info "Milvus endpoint: $MILVUS_ENDPOINT"
if [ -n "${DIRECT_MODEL_NAME:-}" ]; then
    print_info "LLM (direct vLLM): $DIRECT_MODEL_NAME → $VLLM_URL"
fi
if [ -n "${EMBEDDING_ISVC:-}" ]; then
    print_info "Embedding: $EMBEDDING_ISVC → $VLLM_EMBEDDING_URL"
fi
print_info "LlamaStack: $LLAMASTACK_URL"
echo ""
echo "  Remaining manual steps:"
echo ""
echo "  1. CREATE LLAMA STACK CONNECTION IN PROJECT:"
echo "     - Dashboard > $NAMESPACE > Connections"
echo "     - Add connection: Llama Stack"
echo "       Base URL: $LLAMASTACK_URL"
echo "       API Key: (leave empty or use any value)"
echo ""
echo "  2. RUN AUTORAG:"
echo "     - Dashboard > Develop and train > AutoRAG"
echo "     - Click 'Create run'"
echo "     - S3 Connection: 'AutoRAG Documents'"
echo "     - Llama Stack Connection: (created in step 1)"
echo "     - Select optimization metric (e.g. Answer correctness)"
echo "     - Upload test data: sample-data/test-data.json"
echo "     - Click 'Create run'"
echo ""
echo "  3. EVALUATE AND USE:"
echo "     - Review RAG patterns on the leaderboard"
echo "     - Save indexing and inference notebooks"
echo "     - Run notebooks in a workbench"
echo ""
echo "  Sample data provided:"
echo "    Documents: sample-data/docs/ (uploaded to s3://autorag-docs/)"
echo "    Test data: sample-data/test-data.json (upload via dashboard)"
echo ""
