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
    
    cat <<EOF | oc create -n ${NAMESPACE} -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
spec:
  template:
    metadata:
      name: ${JOB_NAME}
    spec:
      containers:
      - name: download
        image: registry.redhat.io/ubi9/python-312
        command: ["/bin/bash", "-c"]
        args:
          - |
            set -e
            
            # Install AWS CLI
            echo "Installing AWS CLI..."
            curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip -q awscliv2.zip
            mkdir -p aws-cli bin
            ./aws/install -i \$PWD/aws-cli -b \$PWD/bin
            
            # Configure AWS CLI alias with endpoint
            # AWS CLI needs --endpoint-url for MinIO
            S3_ENDPOINT="\${AWS_S3_ENDPOINT:-${MINIO_URL}}"
            echo "Using S3 endpoint: \$S3_ENDPOINT"
            
            # Create wrapper function for aws s3 commands
            s3() {
              bin/aws --endpoint-url "\$S3_ENDPOINT" s3 "\$@"
            }
            
            # Wait for MinIO
            echo "Waiting for MinIO at ${MINIO_URL}..."
            until curl --silent --head --fail ${MINIO_URL}/minio/health/live; do
                echo "  MinIO not ready, retrying..."
                sleep 5
            done
            echo "MinIO is ready!"
            
            # Create bucket if needed
            if ! s3 ls s3://${BUCKET_NAME} 2>/dev/null; then
              echo "Creating bucket '${BUCKET_NAME}'..."
              s3 mb s3://${BUCKET_NAME}
            fi
            
            # Install huggingface_hub
            echo "Installing huggingface_hub..."
            pip3 install -q --upgrade huggingface_hub
            
            # Add pip bin to PATH
            export PATH="\$PATH:/opt/app-root/src/.local/bin"
            
            # Download function
            download_model() {
              local repo="\$1"
              local local_dir="/tmp/models/\$repo"
              local s3_path="s3://${BUCKET_NAME}/\$repo/"
              
              # Check if already in S3
              if s3 ls "\$s3_path" >/dev/null 2>&1; then
                echo "Model '\$repo' already exists in S3. Skipping."
                return 0
              fi
              
              echo "Downloading \$repo from HuggingFace..."
              mkdir -p "\$local_dir"
              python3 -c "from huggingface_hub import snapshot_download; snapshot_download('\$repo', local_dir='\$local_dir')" || exit 1
              rm -rf "\$local_dir/.cache"
              
              echo "Syncing to S3..."
              s3 sync "\$local_dir" "\$s3_path"
              
              # Cleanup local copy to save space
              rm -rf "\$local_dir"
              
              echo "✓ \$repo downloaded and synced to s3://${BUCKET_NAME}/\$repo/"
            }
            
            # Download each model
            for model in ${MODEL_LIST}; do
              download_model "\$model"
            done
            
            echo ""
            echo "All downloads complete!"
            echo "Models available at: s3://${BUCKET_NAME}/<model-name>/"
        env:
          - name: HF_TOKEN
            value: "${HF_TOKEN:-}"
        envFrom: 
          - secretRef:
              name: ${DATA_CONNECTION_SECRET}
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 2
            memory: 16Gi
      restartPolicy: Never
  backoffLimit: 3
EOF

else
    print_step "Creating PVC download job..."
    
    # Check if PVC exists
    if ! oc get pvc models-pvc -n "$NAMESPACE" &>/dev/null; then
        print_info "Creating models-pvc (200Gi)..."
        cat <<EOF | oc apply -n ${NAMESPACE} -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: models-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 200Gi
EOF
    fi
    
    cat <<EOF | oc create -n ${NAMESPACE} -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
spec:
  template:
    metadata:
      name: ${JOB_NAME}
    spec:
      volumes:
        - name: models-storage
          persistentVolumeClaim:
            claimName: models-pvc
      containers:
      - name: download
        image: registry.redhat.io/ubi9/python-312
        command: ["/bin/bash", "-c"]
        args:
          - |
            set -e
            
            pip3 install -q --upgrade huggingface_hub
            
            for model in ${MODEL_LIST}; do
              local_dir="/mnt/models/\$model"
              
              if [ -d "\$local_dir" ] && [ "\$(ls -A \$local_dir 2>/dev/null)" ]; then
                echo "Model '\$model' already exists. Skipping."
                continue
              fi
              
              echo "Downloading \$model from HuggingFace..."
              mkdir -p "\$local_dir"
              huggingface-cli download "\$model" --local-dir "\$local_dir"
              rm -rf "\$local_dir/.cache"
              echo "✓ \$model downloaded to /mnt/models/\$model"
            done
            
            echo ""
            echo "All downloads complete!"
            echo "Models available at PVC path: /mnt/models/<model-name>/"
        env:
          - name: HF_TOKEN
            value: "${HF_TOKEN:-}"
        volumeMounts:
          - name: models-storage
            mountPath: "/mnt/models"
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 2
            memory: 16Gi
      restartPolicy: Never
  backoffLimit: 3
EOF
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
