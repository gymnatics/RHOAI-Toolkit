#!/bin/bash
################################################################################
# Serve Model via KServe
#
# Deploys a model for serving using vLLM runtime with S3, PVC, or OCI storage.
#
# Usage:
#   ./serve-model.sh <mode> <name> <model_path> [extra_vllm_args]
#
# Modes:
#   s3  - Model stored in S3 (MinIO)
#   pvc - Model stored in PVC
#   oci - Model from OCI registry (ModelCar)
#
# Examples:
#   ./serve-model.sh s3 qwen3-8b Qwen/Qwen3-8B-Instruct
#   ./serve-model.sh pvc llama-3-8b meta-llama/Llama-3-8B-Instruct
#   ./serve-model.sh oci qwen3-8b-fp8 oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b:1.5
#   ./serve-model.sh s3 qwen3-8b Qwen/Qwen3-8B-Instruct "--max-model-len 8192 --enable-auto-tool-choice"
#
# Environment Variables:
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
MODE="${1:-s3}"
NAME="${2:-}"
MODEL_PATH="${3:-}"
EXTRA_VLLM_ARGS="${4:-}"

# Validate arguments
if [ -z "$NAME" ] || [ -z "$MODEL_PATH" ]; then
    echo "Usage: $0 <mode> <name> <model_path> [extra_vllm_args]"
    echo ""
    echo "Modes: s3, pvc, oci"
    echo ""
    echo "Examples:"
    echo "  $0 s3 qwen3-8b Qwen/Qwen3-8B-Instruct"
    echo "  $0 pvc llama-3-8b meta-llama/Llama-3-8B-Instruct"
    echo "  $0 oci qwen3-8b-fp8 oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b:1.5"
    echo "  $0 s3 qwen3-8b Qwen/Qwen3-8B-Instruct \"--max-model-len 8192\""
    exit 1
fi

# Kubernetes-safe name (lowercase, alphanumeric, hyphens)
k8s_safe_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//' | sed 's/-$//'
}

NAME=$(k8s_safe_name "$NAME")

# Remove leading slash from model path
MODEL_PATH="${MODEL_PATH#/}"

# Build vLLM args array for YAML
VLLM_ARGS=""
if [ -n "$EXTRA_VLLM_ARGS" ]; then
    for arg in $EXTRA_VLLM_ARGS; do
        VLLM_ARGS="${VLLM_ARGS}        - '$arg'
"
    done
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    Deploying Model                             ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
printf "%-15s | %s\n" "Name" "$NAME"
printf "%-15s | %s\n" "Storage Mode" "$MODE"
printf "%-15s | %s\n" "Model Path" "$MODEL_PATH"
printf "%-15s | %s\n" "Namespace" "$NAMESPACE"
if [ -n "$EXTRA_VLLM_ARGS" ]; then
    printf "%-15s | %s\n" "Extra Args" "$EXTRA_VLLM_ARGS"
fi
echo ""

# Clean up existing resources
print_step "Cleaning up existing resources..."
oc delete isvc/$NAME -n ${NAMESPACE} --ignore-not-found 2>/dev/null || true
oc delete servingruntime/$NAME -n ${NAMESPACE} --ignore-not-found 2>/dev/null || true

# Create ServingRuntime
print_step "Creating ServingRuntime..."
cat <<EOF | oc apply -n ${NAMESPACE} -f -
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  annotations:
    opendatahub.io/accelerator-name: ''
    opendatahub.io/apiProtocol: REST
    opendatahub.io/serving-runtime-scope: global
    opendatahub.io/recommended-accelerators: '["nvidia.com/gpu"]'
    openshift.io/display-name: ${NAME}
  name: ${NAME}
  labels:
    opendatahub.io/dashboard: 'true'
spec:
  annotations:
    prometheus.io/path: /metrics
    prometheus.io/port: '8080'
  containers:
    - args:
        - '--port=8080'
        - '--model=/mnt/models'
        - '--served-model-name={{.Name}}'
      command:
        - python
        - '-m'
        - vllm.entrypoints.openai.api_server
      env:
        - name: HF_HOME
          value: /tmp/hf_home
      image: 'registry.redhat.io/rhaiis/vllm-cuda-rhel9:3.2.5'
      name: kserve-container
      ports:
        - containerPort: 8080
          protocol: TCP
      volumeMounts:
        - mountPath: /dev/shm
          name: shm
  multiModel: false
  supportedModelFormats:
    - autoSelect: true
      name: vLLM
  volumes:
    - emptyDir:
        medium: Memory
        sizeLimit: 2Gi
      name: shm
EOF

# Create InferenceService based on mode
print_step "Creating InferenceService ($MODE mode)..."

if [ "$MODE" = "s3" ]; then
    cat <<EOF | oc apply -n ${NAMESPACE} -f -
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  annotations:
    opendatahub.io/hardware-profile-name: nvidia-gpu
    opendatahub.io/hardware-profile-namespace: redhat-ods-applications
    openshift.io/display-name: ${NAME}
    serving.kserve.io/deploymentMode: RawDeployment
    opendatahub.io/model-type: generative
  name: ${NAME}
  labels:
    networking.kserve.io/visibility: exposed
    opendatahub.io/dashboard: 'true'
    opendatahub.io/genai-asset: "true"
spec:
  predictor:
    automountServiceAccountToken: false
    maxReplicas: 1
    minReplicas: 1
    model:
      args:
        - '--max-model-len'
        - '4096'
${VLLM_ARGS}
      modelFormat:
        name: vLLM
      name: ''
      resources:
        limits:
          cpu: '4'
          memory: 32Gi
          nvidia.com/gpu: '1'
        requests:
          cpu: '2'
          memory: 8Gi
          nvidia.com/gpu: '1'
      runtime: ${NAME}
      storage:
        key: aws-connection-my-storage
        path: ${MODEL_PATH}
EOF

elif [ "$MODE" = "pvc" ]; then
    cat <<EOF | oc apply -n ${NAMESPACE} -f -
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  annotations:
    opendatahub.io/hardware-profile-name: nvidia-gpu
    opendatahub.io/hardware-profile-namespace: redhat-ods-applications
    openshift.io/display-name: ${NAME}
    serving.kserve.io/deploymentMode: RawDeployment
    opendatahub.io/model-type: generative
  name: ${NAME}
  labels:
    networking.kserve.io/visibility: exposed
    opendatahub.io/dashboard: 'true'
    opendatahub.io/genai-asset: "true"
spec:
  predictor:
    automountServiceAccountToken: false
    maxReplicas: 1
    minReplicas: 1
    model:
      args:
        - '--max-model-len'
        - '4096'
${VLLM_ARGS}
      modelFormat:
        name: vLLM
      name: ''
      resources:
        limits:
          cpu: '4'
          memory: 32Gi
          nvidia.com/gpu: '1'
        requests:
          cpu: '2'
          memory: 8Gi
          nvidia.com/gpu: '1'
      runtime: ${NAME}
      storageUri: "pvc://models-pvc/${MODEL_PATH}"
EOF

elif [ "$MODE" = "oci" ]; then
    cat <<EOF | oc apply -n ${NAMESPACE} -f -
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  annotations:
    opendatahub.io/hardware-profile-name: nvidia-gpu
    opendatahub.io/hardware-profile-namespace: redhat-ods-applications
    openshift.io/display-name: ${NAME}
    serving.kserve.io/deploymentMode: RawDeployment
    opendatahub.io/model-type: generative
  name: ${NAME}
  labels:
    networking.kserve.io/visibility: exposed
    opendatahub.io/dashboard: 'true'
    opendatahub.io/genai-asset: "true"
spec:
  predictor:
    automountServiceAccountToken: false
    maxReplicas: 1
    minReplicas: 1
    model:
      args:
        - '--max-model-len'
        - '4096'
${VLLM_ARGS}
      modelFormat:
        name: vLLM
      name: ''
      resources:
        limits:
          cpu: '4'
          memory: 32Gi
          nvidia.com/gpu: '1'
        requests:
          cpu: '2'
          memory: 8Gi
          nvidia.com/gpu: '1'
      runtime: ${NAME}
      storageUri: "${MODEL_PATH}"
EOF

else
    print_error "Invalid mode: $MODE (must be 's3', 'pvc', or 'oci')"
    exit 1
fi

print_success "InferenceService created"
echo ""

# Wait for deployment
print_step "Waiting for model to be ready..."
echo "  This may take several minutes for large models..."

if oc wait --for=condition=Ready isvc/${NAME} -n ${NAMESPACE} --timeout=600s 2>/dev/null; then
    print_success "Model is ready!"
    echo ""
    
    # Get URL
    URL=$(oc get isvc ${NAME} -n ${NAMESPACE} -o jsonpath='{.status.url}' 2>/dev/null || echo "")
    if [ -n "$URL" ]; then
        echo -e "${GREEN}Model URL: ${URL}${NC}"
        echo ""
        echo "Test with:"
        echo "  curl -s ${URL}/v1/models | jq"
        echo ""
        echo "Chat completion:"
        echo "  curl -X POST ${URL}/v1/chat/completions \\"
        echo "    -H 'Content-Type: application/json' \\"
        echo "    -d '{\"model\": \"${NAME}\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'"
    fi
else
    print_error "Model deployment timed out or failed"
    echo ""
    echo "Check status with:"
    echo "  oc get isvc ${NAME} -n ${NAMESPACE}"
    echo "  oc describe isvc ${NAME} -n ${NAMESPACE}"
    echo "  oc logs -l serving.kserve.io/inferenceservice=${NAME} -n ${NAMESPACE}"
    exit 1
fi
