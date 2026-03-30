#!/bin/bash
################################################################################
# Add Custom Serving Runtime to RHOAI
#
# Adds a custom vLLM serving runtime for newer model support (e.g., Qwen3.5)
#
# Usage:
#   ./add-serving-runtime.sh                    # Interactive mode
#   ./add-serving-runtime.sh --vllm-version v0.18.0 --name vllm-community
#   ./add-serving-runtime.sh --preset qwen3.5   # Use preset for Qwen3.5 support
#
# Presets:
#   qwen3.5  - vLLM v0.18.0 (supports Qwen3.5 models)
#   latest   - Latest vLLM release
#
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source utilities
if [ -f "$BASE_DIR/lib/utils/colors.sh" ]; then
    source "$BASE_DIR/lib/utils/colors.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

print_step() { echo -e "${YELLOW}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

# Defaults
VLLM_VERSION=""
RUNTIME_NAME=""
DISPLAY_NAME=""
PRESET=""
SHM_SIZE="12Gi"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --vllm-version)
            VLLM_VERSION="$2"
            shift 2
            ;;
        --name)
            RUNTIME_NAME="$2"
            shift 2
            ;;
        --display-name)
            DISPLAY_NAME="$2"
            shift 2
            ;;
        --preset)
            PRESET="$2"
            shift 2
            ;;
        --shm-size)
            SHM_SIZE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --vllm-version VERSION  vLLM version (e.g., v0.18.0)"
            echo "  --name NAME             Runtime name (e.g., vllm-community)"
            echo "  --display-name NAME     Display name in UI"
            echo "  --preset PRESET         Use preset (qwen3.5, latest)"
            echo "  --shm-size SIZE         Shared memory size (default: 12Gi)"
            echo "  -h, --help              Show this help"
            echo ""
            echo "Presets:"
            echo "  qwen3.5  - vLLM v0.18.0 for Qwen3.5 support"
            echo "  latest   - Latest vLLM version"
            echo ""
            echo "Examples:"
            echo "  $0 --preset qwen3.5"
            echo "  $0 --vllm-version v0.18.0 --name my-vllm"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check oc login
if ! oc whoami &>/dev/null; then
    print_error "Not logged into OpenShift. Run 'oc login' first."
    exit 1
fi

# Handle presets
if [ -n "$PRESET" ]; then
    case "$PRESET" in
        qwen3.5)
            VLLM_VERSION="v0.18.0"
            RUNTIME_NAME="vllm-community-v0.18"
            DISPLAY_NAME="vLLM Community v0.18 (Qwen3.5)"
            ;;
        latest)
            VLLM_VERSION="latest"
            RUNTIME_NAME="vllm-community-latest"
            DISPLAY_NAME="vLLM Community (Latest)"
            ;;
        *)
            print_error "Unknown preset: $PRESET"
            echo "Available presets: qwen3.5, latest"
            exit 1
            ;;
    esac
    print_info "Using preset: $PRESET"
fi

# Interactive mode if no version specified
if [ -z "$VLLM_VERSION" ]; then
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           Add Custom vLLM Serving Runtime                      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo "Select a preset or enter custom version:"
    echo ""
    echo "  1) Qwen3.5 support (vLLM v0.18.0)"
    echo "  2) Latest vLLM"
    echo "  3) Custom version"
    echo ""
    read -p "Enter choice [1-3]: " choice
    
    case $choice in
        1)
            VLLM_VERSION="v0.18.0"
            RUNTIME_NAME="vllm-community-v0.18"
            DISPLAY_NAME="vLLM Community v0.18 (Qwen3.5)"
            ;;
        2)
            VLLM_VERSION="latest"
            RUNTIME_NAME="vllm-community-latest"
            DISPLAY_NAME="vLLM Community (Latest)"
            ;;
        3)
            read -p "Enter vLLM version (e.g., v0.18.0): " VLLM_VERSION
            read -p "Enter runtime name [vllm-custom]: " RUNTIME_NAME
            RUNTIME_NAME=${RUNTIME_NAME:-vllm-custom}
            read -p "Enter display name [vLLM Custom]: " DISPLAY_NAME
            DISPLAY_NAME=${DISPLAY_NAME:-vLLM Custom}
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
fi

# Set defaults if not provided
RUNTIME_NAME=${RUNTIME_NAME:-vllm-community}
DISPLAY_NAME=${DISPLAY_NAME:-vLLM Community $VLLM_VERSION}

echo ""
print_step "Creating ServingRuntime: $RUNTIME_NAME"
print_info "vLLM Version: $VLLM_VERSION"
print_info "Display Name: $DISPLAY_NAME"
print_info "Image: vllm/vllm-openai:$VLLM_VERSION"
echo ""

# Check if runtime already exists
if oc get servingruntime "$RUNTIME_NAME" -n redhat-ods-applications &>/dev/null; then
    print_info "ServingRuntime '$RUNTIME_NAME' already exists"
    read -p "Replace it? (y/N): " replace
    if [[ ! "$replace" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    oc delete servingruntime "$RUNTIME_NAME" -n redhat-ods-applications
fi

# Create the ServingRuntime
cat <<EOF | oc apply -n redhat-ods-applications -f -
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: ${RUNTIME_NAME}
  annotations:
    opendatahub.io/apiProtocol: REST
    opendatahub.io/recommended-accelerators: '["nvidia.com/gpu"]'
    openshift.io/display-name: "${DISPLAY_NAME}"
  labels:
    opendatahub.io/dashboard: "true"
spec:
  annotations:
    prometheus.io/path: /metrics
    prometheus.io/port: "8080"
  containers:
    - name: kserve-container
      image: vllm/vllm-openai:${VLLM_VERSION}
      args:
        - --model
        - /mnt/models
        - --port
        - "8080"
      env:
        - name: HF_HOME
          value: /tmp/hf_home
      ports:
        - containerPort: 8080
          protocol: TCP
      volumeMounts:
        - name: shm
          mountPath: /dev/shm
  multiModel: false
  supportedModelFormats:
    - autoSelect: true
      name: vLLM
      priority: 1
  volumes:
    - name: shm
      emptyDir:
        medium: Memory
        sizeLimit: ${SHM_SIZE}
EOF

echo ""
print_success "ServingRuntime '$RUNTIME_NAME' created!"
echo ""
print_info "You can now select '${DISPLAY_NAME}' when deploying models in the RHOAI dashboard."
echo ""
