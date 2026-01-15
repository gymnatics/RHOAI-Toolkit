#!/bin/bash
################################################################################
# Download Model from HuggingFace
#
# Downloads models from HuggingFace to S3 or PVC storage.
#
# Usage:
#   ./download-model.sh <mode> <model> [model2] [model3] ...
#
# Modes:
#   s3  - Download to S3 (via MinIO) and PVC
#   pvc - Download to PVC only
#
# Examples:
#   ./download-model.sh s3 Qwen/Qwen3-8B-Instruct
#   ./download-model.sh pvc meta-llama/Llama-3-8B-Instruct
#   HF_TOKEN=hf_xxx ./download-model.sh s3 meta-llama/Llama-3-8B-Instruct
#
# Environment Variables:
#   HF_TOKEN   - HuggingFace token for gated models (optional)
#   NAMESPACE  - Target namespace (default: demo)
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
NAMESPACE="${NAMESPACE:-demo}"
JOB_NAME="download-models"
MODE="${1:-}"
shift 2>/dev/null || true
MODEL_LIST="$@"

# Validate arguments
if [ -z "$MODE" ] || [ -z "$MODEL_LIST" ]; then
    echo "Usage: $0 <s3|pvc> <model1> [model2] [model3] ..."
    echo ""
    echo "Examples:"
    echo "  $0 s3 Qwen/Qwen3-8B-Instruct"
    echo "  $0 pvc meta-llama/Llama-3-8B-Instruct"
    echo "  HF_TOKEN=hf_xxx $0 s3 meta-llama/Llama-3-8B-Instruct"
    echo ""
    echo "Environment Variables:"
    echo "  HF_TOKEN   - HuggingFace token for gated models"
    echo "  NAMESPACE  - Target namespace (default: demo)"
    exit 1
fi

# Validate mode
if [ "$MODE" != "s3" ] && [ "$MODE" != "pvc" ]; then
    print_error "Invalid mode: $MODE (must be 's3' or 'pvc')"
    exit 1
fi

# Set job name based on mode
JOB_NAME="${JOB_NAME}-${MODE}"

print_step "Downloading models to $MODE storage"
print_info "Models: $MODEL_LIST"
print_info "Namespace: $NAMESPACE"
echo ""

# Cleanup old job
oc delete job/${JOB_NAME} -n ${NAMESPACE} --ignore-not-found 2>/dev/null

# Create job based on mode
if [ "$MODE" = "s3" ]; then
    print_step "Creating S3 download job..."
    
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
            
            # Install AWS CLI
            echo "Installing AWS CLI..."
            curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip -q awscliv2.zip
            mkdir -p aws-cli bin
            ./aws/install -i \$PWD/aws-cli -b \$PWD/bin
            
            # Wait for MinIO
            echo "Waiting for MinIO..."
            until curl --silent --head --fail http://minio:9000/minio/health/live; do
                sleep 5
            done
            
            # Create bucket if needed
            if ! bin/aws s3 ls s3://models 2>/dev/null; then
              echo "Creating models bucket..."
              bin/aws s3 mb s3://models
            fi
            
            # Install huggingface_hub
            pip3 install -q --upgrade huggingface_hub
            
            # Download function
            download_model() {
              local repo="\$1"
              local local_dir="/mnt/models/\$repo"
              local s3_path="s3://models/\$repo/"
              
              # Check if already in S3
              if bin/aws s3 ls "\$s3_path" >/dev/null 2>&1; then
                echo "Model '\$repo' already exists in S3. Skipping."
                return 0
              fi
              
              echo "Downloading \$repo..."
              mkdir -p "\$local_dir"
              hf download "\$repo" --local-dir "\$local_dir" || exit 1
              rm -rf "\$local_dir/.cache"
              
              echo "Syncing to S3..."
              bin/aws s3 sync "\$local_dir" "\$s3_path"
              echo "✓ \$repo downloaded and synced"
            }
            
            # Download each model
            for model in ${MODEL_LIST}; do
              download_model "\$model"
            done
            
            echo "All downloads complete!"
        env:
          - name: HF_TOKEN
            value: "${HF_TOKEN:-}"
        envFrom: 
          - secretRef:
              name: aws-connection-my-storage
        volumeMounts:
          - name: models-storage
            mountPath: "/mnt/models"
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 2
            memory: 8Gi
      restartPolicy: Never
  backoffLimit: 3
EOF

else
    print_step "Creating PVC download job..."
    
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
              
              echo "Downloading \$model..."
              mkdir -p "\$local_dir"
              hf download "\$model" --local-dir "\$local_dir"
              rm -rf "\$local_dir/.cache"
              echo "✓ \$model downloaded"
            done
            
            echo "All downloads complete!"
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
            memory: 8Gi
      restartPolicy: Never
  backoffLimit: 3
EOF
fi

print_step "Waiting for job to complete..."

# Wait for job completion
while true; do
    STATUS=$(oc get job ${JOB_NAME} -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "")
    FAILED=$(oc get job ${JOB_NAME} -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || echo "")
    
    if [ "$STATUS" = "True" ]; then
        print_success "Download complete!"
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
    
    echo "  Job still running..."
    sleep 10
done
