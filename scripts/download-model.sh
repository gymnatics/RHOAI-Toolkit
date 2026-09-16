#!/bin/bash
################################################################################
# Download Model from HuggingFace
#
# Downloads models from HuggingFace to S3 (MinIO) or PVC storage.
# For S3 mode, requires MinIO to be set up first (see setup-model-storage.sh).
#
# Usage:
#   ./download-model.sh <mode> <model> [model2] [model3] ...
#
# Modes:
#   s3  - Download to S3 (via MinIO)
#   pvc - Download to PVC only (for direct PVC model serving)
#
# Examples:
#   ./download-model.sh s3 Qwen/Qwen3-8B-Instruct
#   ./download-model.sh pvc meta-llama/Llama-3-8B-Instruct
#   HF_TOKEN=hf_xxx ./download-model.sh s3 meta-llama/Llama-3-8B-Instruct
#   NAMESPACE=my-project MINIO_NAMESPACE=model-storage ./download-model.sh s3 Qwen/Qwen3-8B
#
# Environment Variables:
#   HF_TOKEN         - HuggingFace token for gated models (optional)
#   NAMESPACE        - Namespace where job runs and data connection exists (default: model-storage)
#   MINIO_NAMESPACE  - Namespace where MinIO is deployed (default: model-storage)
#   BUCKET_NAME      - S3 bucket name (default: models)
#
# Prerequisites:
#   For S3 mode, run setup-model-storage.sh first:
#     ./scripts/setup-model-storage.sh
################################################################################

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source utilities if available
if [ -f "$BASE_DIR/lib/utils/colors.sh" ]; then
    source "$BASE_DIR/lib/utils/colors.sh"
else
    # Fallback colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    print_step() { echo -e "${YELLOW}▶ $1${NC}"; }
    print_success() { echo -e "${GREEN}✓ $1${NC}"; }
    print_error() { echo -e "${RED}✗ $1${NC}"; }
    print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
fi

# Configuration
NAMESPACE="${NAMESPACE:-model-storage}"
MINIO_NAMESPACE="${MINIO_NAMESPACE:-model-storage}"
BUCKET_NAME="${BUCKET_NAME:-models}"
JOB_NAME="download-models"
MODE="${1:-}"
shift 2>/dev/null || true
MODEL_LIST="$@"

# Validate arguments
if [ -z "$MODE" ] || [ -z "$MODEL_LIST" ]; then
    echo "Usage: $0 <s3|pvc> <model1> [model2] [model3] ..."
    echo ""
    echo "Modes:"
    echo "  s3  - Download to S3 (MinIO) - requires setup-model-storage.sh first"
    echo "  pvc - Download to PVC only"
    echo ""
    echo "Examples:"
    echo "  $0 s3 Qwen/Qwen3-8B-Instruct"
    echo "  $0 pvc meta-llama/Llama-3-8B-Instruct"
    echo "  HF_TOKEN=hf_xxx $0 s3 meta-llama/Llama-3-8B-Instruct"
    echo ""
    echo "Environment Variables:"
    echo "  HF_TOKEN         - HuggingFace token for gated models"
    echo "  NAMESPACE        - Target namespace (default: model-storage)"
    echo "  MINIO_NAMESPACE  - MinIO namespace (default: model-storage)"
    echo "  BUCKET_NAME      - S3 bucket name (default: models)"
    echo ""
    echo "Prerequisites for S3 mode:"
    echo "  ./scripts/setup-model-storage.sh"
    exit 1
fi

# Validate mode
if [ "$MODE" != "s3" ] && [ "$MODE" != "pvc" ]; then
    print_error "Invalid mode: $MODE (must be 's3' or 'pvc')"
    exit 1
fi

# For S3 mode, verify MinIO exists
if [ "$MODE" = "s3" ]; then
    if ! oc get deployment minio -n "$MINIO_NAMESPACE" &>/dev/null; then
        print_error "MinIO not found in namespace '$MINIO_NAMESPACE'"
        echo ""
        echo "Please run setup-model-storage.sh first:"
        echo "  ./scripts/setup-model-storage.sh -n $MINIO_NAMESPACE"
        exit 1
    fi
    
    # Check for data connection secret
    if ! oc get secret aws-connection-my-storage -n "$NAMESPACE" &>/dev/null && \
       ! oc get secret aws-connection-minio -n "$NAMESPACE" &>/dev/null; then
        print_error "No data connection secret found in namespace '$NAMESPACE'"
        echo ""
        echo "Please run setup-model-storage.sh with --data-connection-ns:"
        echo "  ./scripts/setup-model-storage.sh -n $MINIO_NAMESPACE --data-connection-ns $NAMESPACE"
        exit 1
    fi
    
    # Determine which secret to use
    if oc get secret aws-connection-my-storage -n "$NAMESPACE" &>/dev/null; then
        DATA_CONNECTION_SECRET="aws-connection-my-storage"
    else
        DATA_CONNECTION_SECRET="aws-connection-minio"
    fi
fi

# Set job name based on mode
JOB_NAME="${JOB_NAME}-${MODE}"

print_step "Downloading models to $MODE storage"
print_info "Models: $MODEL_LIST"
print_info "Namespace: $NAMESPACE"
if [ "$MODE" = "s3" ]; then
    print_info "MinIO Namespace: $MINIO_NAMESPACE"
    print_info "Bucket: $BUCKET_NAME"
    print_info "Data Connection: $DATA_CONNECTION_SECRET"
fi
echo ""

# Cleanup old job
oc delete job/${JOB_NAME} -n ${NAMESPACE} --ignore-not-found 2>/dev/null

# Create job based on mode
if [ "$MODE" = "s3" ]; then
    print_step "Creating S3 download job..."
    
    # MinIO service URL (cross-namespace)
    MINIO_URL="http://minio.${MINIO_NAMESPACE}.svc:9000"

    # Precompute the ${HF_TOKEN:-} default-value expansion into a plain
    # variable before envsubst -- envsubst only does literal ${VAR}
    # substitution, it doesn't support bash's ":-" default-value operator.
    HF_TOKEN_VALUE="${HF_TOKEN:-}"
    export JOB_NAME MINIO_URL BUCKET_NAME MODEL_LIST DATA_CONNECTION_SECRET HF_TOKEN_VALUE
    envsubst '${JOB_NAME} ${MINIO_URL} ${BUCKET_NAME} ${MODEL_LIST} ${DATA_CONNECTION_SECRET} ${HF_TOKEN_VALUE}' \
        < "$BASE_DIR/lib/manifests/download-model/download-job-s3.yaml.tmpl" | oc create -n ${NAMESPACE} -f -

else
    print_step "Creating PVC download job..."
    
    # Check if PVC exists
    if ! oc get pvc models-pvc -n "$NAMESPACE" &>/dev/null; then
        print_info "Creating models-pvc (200Gi)..."
        oc apply -n ${NAMESPACE} -f "$BASE_DIR/lib/manifests/download-model/models-pvc.yaml"
    fi

    HF_TOKEN_VALUE="${HF_TOKEN:-}"
    export JOB_NAME MODEL_LIST HF_TOKEN_VALUE
    envsubst '${JOB_NAME} ${MODEL_LIST} ${HF_TOKEN_VALUE}' \
        < "$BASE_DIR/lib/manifests/download-model/download-job-pvc.yaml.tmpl" | oc create -n ${NAMESPACE} -f -
fi

print_step "Waiting for job to complete (this may take a while for large models)..."
print_info "You can watch logs with: oc logs -f job/${JOB_NAME} -n ${NAMESPACE}"
echo ""

# Wait for job completion
ELAPSED=0
while true; do
    STATUS=$(oc get job ${JOB_NAME} -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "")
    FAILED=$(oc get job ${JOB_NAME} -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || echo "")
    
    if [ "$STATUS" = "True" ]; then
        echo ""
        print_success "Download complete!"
        
        # Show next steps
        echo ""
        if [ "$MODE" = "s3" ]; then
            echo -e "${CYAN}Models are now available in S3:${NC}"
            for model in ${MODEL_LIST}; do
                echo "  s3://${BUCKET_NAME}/${model}/"
            done
            echo ""
            echo -e "${CYAN}To deploy a model, use storageUri:${NC}"
            echo "  storageUri: s3://${BUCKET_NAME}/<model-name>/"
        else
            echo -e "${CYAN}Models are now available on PVC:${NC}"
            for model in ${MODEL_LIST}; do
                echo "  pvc://models-pvc/${model}/"
            done
        fi
        
        oc delete job/${JOB_NAME} -n ${NAMESPACE} --ignore-not-found 2>/dev/null
        exit 0
    fi
    
    if [ "$FAILED" = "True" ]; then
        print_error "Download failed!"
        echo ""
        echo "Check logs with:"
        echo "  oc logs job/${JOB_NAME} -n ${NAMESPACE}"
        exit 1
    fi
    
    # Show elapsed time every minute
    if [ $((ELAPSED % 60)) -eq 0 ] && [ $ELAPSED -gt 0 ]; then
        echo "  Still downloading... (${ELAPSED}s elapsed)"
    fi
    
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done
