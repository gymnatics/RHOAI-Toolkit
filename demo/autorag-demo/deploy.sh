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
    oc delete datasciencepipelineapplication pipelines-definition -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    export NAMESPACE
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
    print_success "Sample documents uploaded to s3://autorag-docs/"
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

echo ""
print_success "AutoRAG Demo infrastructure deployed"
print_info "Namespace: $NAMESPACE"
print_info "Milvus endpoint: $MILVUS_ENDPOINT"
echo ""
echo "  AutoRAG is a dashboard UI feature. Before using it, complete these manual steps:"
echo ""
echo "  1. SET UP LLAMA STACK INSTANCE:"
echo "     - Dashboard > Applications > Enabled"
echo "     - Find Llama Stack and create an instance"
echo "     - Configure with your deployed models:"
echo "       Foundation model: (your vLLM-served model)"
echo "       Embedding model: BAAI/bge-m3 (recommended)"
echo ""
echo "  2. REGISTER MILVUS WITH LLAMA STACK:"
echo "     - In Llama Stack settings, add vector database:"
echo "       Type: Milvus (remote)"
echo "       Endpoint: $MILVUS_ENDPOINT"
echo ""
echo "  3. CREATE LLAMA STACK CONNECTION IN PROJECT:"
echo "     - Dashboard > $NAMESPACE > Connections"
echo "     - Add connection: Llama Stack"
echo "       Base URL: (your Llama Stack instance URL)"
echo "       API Key: (your Llama Stack API key)"
echo ""
echo "  4. RUN AUTORAG:"
echo "     - Dashboard > Develop and train > AutoRAG"
echo "     - Click 'Create run'"
echo "     - S3 Connection: 'AutoRAG Documents'"
echo "     - Llama Stack Connection: (created in step 3)"
echo "     - Select optimization metric (e.g. Answer correctness)"
echo "     - Upload test data: sample-data/test-data.json"
echo "     - Click 'Create run'"
echo ""
echo "  5. EVALUATE AND USE:"
echo "     - Review RAG patterns on the leaderboard"
echo "     - Save indexing and inference notebooks"
echo "     - Run notebooks in a workbench"
echo ""
echo "  Sample data provided:"
echo "    Documents: sample-data/docs/ (uploaded to s3://autorag-docs/)"
echo "    Test data: sample-data/test-data.json (upload via dashboard)"
echo ""
