#!/bin/bash
################################################################################
# Serve Model - Quick CLI
#
# Thin wrapper around lib/functions/model-deployment.sh for rapid deployment.
# Calls _deploy_model_execute() directly with preset or custom parameters.
#
# Usage:
#   ./serve-model.sh                                    # Interactive menu
#   ./serve-model.sh <mode> <name> <model_path> [args]  # CLI mode
#
# Modes: s3, pvc, oci, hf
#
# Environment Variables:
#   NAMESPACE        Target namespace (default: demo)
#   RUNTIME          Runtime: vllm (default), vllm-gemma4, vllm-omni
#   HF_TOKEN         HuggingFace token (required for gated models)
#   HF_TOKEN_SECRET  K8s secret name for HF token (default: hf-token)
#
# Examples:
#   ./serve-model.sh                                           # Interactive
#   ./serve-model.sh oci qwen3-4b oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b
#   ./serve-model.sh s3 qwen3-8b Qwen/Qwen3-8B-Instruct
#   ./serve-model.sh hf gemma4-e2b google/gemma-4-E2B-it  # Apache 2.0, no token needed
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source utilities
source "$BASE_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'
    print_step() { echo -e "${YELLOW}▶ $1${NC}"; }
    print_success() { echo -e "${GREEN}✓ $1${NC}"; }
    print_error() { echo -e "${RED}✗ $1${NC}"; }
    print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
    print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
    print_header() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }
}

# Source model deployment library
source "$BASE_DIR/lib/functions/model-deployment.sh"

# Configuration
NAMESPACE="${NAMESPACE:-demo}"
RUNTIME="${RUNTIME:-vllm}"
HF_TOKEN="${HF_TOKEN:-}"
HF_TOKEN_SECRET="${HF_TOKEN_SECRET:-hf-token}"

################################################################################
# Deploy helper: prepare namespace, show summary, execute, wait & test
################################################################################
_do_deploy() {
    local runtime="$1" name="$2" uri="$3" ns="$4"
    local gpu="$5" cpu="$6" mem="$7" vllm_args="$8"

    # Ensure namespace
    oc get ns "$ns" &>/dev/null || oc new-project "$ns" 2>/dev/null || oc create namespace "$ns" 2>/dev/null || true

    # HF token secret
    if [ -n "$HF_TOKEN" ] && [[ "$uri" == hf://* ]]; then
        ensure_hf_token_secret "$ns" "$HF_TOKEN_SECRET" "$HF_TOKEN"
    fi

    # Auth disabled for quick deploy (no-auth)
    local auth_annotation="security.opendatahub.io/enable-auth: 'false'"

    # Summary
    echo ""
    print_header "Deployment Summary"
    printf "  %-12s %s\n" "Runtime:" "$runtime"
    printf "  %-12s %s\n" "Model:" "$name"
    printf "  %-12s %s\n" "URI:" "$uri"
    printf "  %-12s %s\n" "Namespace:" "$ns"
    printf "  %-12s %s\n" "Resources:" "${gpu} GPU, ${cpu} CPU, ${mem} Memory"
    [ -n "$vllm_args" ] && printf "  %-12s %s\n" "vLLM Args:" "$vllm_args"
    echo ""

    # Deploy
    _deploy_model_execute "$runtime" "$name" "$uri" "$ns" \
        "$gpu" "$cpu" "$mem" "$vllm_args" \
        "$auth_annotation" "false" "" "" "redhat-ods-applications"

    # Wait and test
    wait_and_test_model "$name" "$ns" 600 true
}

################################################################################
# Interactive menu (no arguments)
################################################################################
if [ -z "$1" ]; then
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    Deploy Model - Quick Start                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} Gemma 4 E2B (google/gemma-4-E2B-it) ${GREEN}[1 GPU, 5B params]${NC}"
    echo "    Multimodal, tool-calling, FP8 KV cache, Apache 2.0 (no HF token needed)"
    echo ""
    echo -e "${YELLOW}2)${NC} Qwen2.5-Coder-7B (OCI ModelCar)"
    echo "    vLLM runtime, tool-calling (hermes), 1 GPU"
    echo ""
    echo -e "${YELLOW}3)${NC} Qwen3-4B (OCI ModelCar) ${GREEN}[Recommended for demos]${NC}"
    echo "    vLLM runtime, tool-calling (hermes), 1 GPU"
    echo ""
    echo -e "${YELLOW}4)${NC} Custom model (S3 / PVC / OCI / HuggingFace)"
    echo ""
    echo -e "${YELLOW}5)${NC} Full interactive wizard"
    echo "    Detailed runtime / resource / auth configuration"
    echo ""
    read -p "Select [1-5]: " choice

    case "$choice" in
        1)
            read -p "Namespace [${NAMESPACE}]: " ns_input
            NAMESPACE="${ns_input:-$NAMESPACE}"
            _do_deploy "vllm-gemma4" "gemma4-e2b" "google/gemma-4-E2B-it" "$NAMESPACE" \
                "1" "8" "32Gi" "--enable-auto-tool-choice --tool-call-parser=gemma4 --kv-cache-dtype=fp8"
            ;;
        2)
            read -p "Namespace [${NAMESPACE}]: " ns_input
            NAMESPACE="${ns_input:-$NAMESPACE}"
            _do_deploy "vllm" "qwen25-coder-7b" \
                "oci://registry.redhat.io/rhelai1/modelcar-qwen2.5-coder-7b-instruct:1.5" "$NAMESPACE" \
                "1" "8" "32Gi" "--enable-auto-tool-choice --tool-call-parser=hermes"
            ;;
        3)
            read -p "Namespace [${NAMESPACE}]: " ns_input
            NAMESPACE="${ns_input:-$NAMESPACE}"
            _do_deploy "vllm" "qwen3-4b" \
                "oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b" "$NAMESPACE" \
                "1" "4" "16Gi" "--enable-auto-tool-choice --tool-call-parser=hermes"
            ;;
        4)
            echo ""
            echo -e "${BLUE}Storage type:${NC}"
            echo "  1) OCI    e.g. oci://registry.redhat.io/..."
            echo "  2) S3     e.g. Qwen/Qwen3-8B-Instruct"
            echo "  3) PVC    e.g. meta-llama/Llama-3-8B-Instruct"
            echo "  4) HF     e.g. google/gemma-4-E2B-it"
            read -p "Select [1-4]: " st

            uri=""
            case "$st" in
                1) read -p "OCI URI: " uri ;;
                2) read -p "S3 path: " p; uri="s3://$p" ;;
                3) read -p "PVC name [models-pvc]: " pn; pn="${pn:-models-pvc}"
                   read -p "Path in PVC: " pp; uri="pvc://$pn/$pp" ;;
                4) read -p "HF model ID: " hf; uri="hf://$hf"
                   if [ -z "$HF_TOKEN" ]; then
                       read -sp "HF Token (required for gated models): " HF_TOKEN; echo ""
                   fi ;;
                *) print_error "Invalid choice"; exit 1 ;;
            esac

            read -p "Model name: " custom_name
            read -p "Namespace [${NAMESPACE}]: " ns_input
            NAMESPACE="${ns_input:-$NAMESPACE}"
            read -p "Extra vLLM args (optional): " extra_args

            _do_deploy "$RUNTIME" "$custom_name" "$uri" "$NAMESPACE" \
                "1" "4" "16Gi" "$extra_args"
            ;;
        5)
            deploy_model_interactive
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    exit 0
fi

################################################################################
# CLI argument mode (backward compatible)
#   ./serve-model.sh <mode> <name> <model_path> [extra_vllm_args]
################################################################################
MODE="$1"
NAME="${2:-}"
MODEL_PATH="${3:-}"
EXTRA_VLLM_ARGS="${4:-}"

if [ -z "$NAME" ] || [ -z "$MODEL_PATH" ]; then
    echo "Usage: $0 <mode> <name> <model_path> [extra_vllm_args]"
    echo ""
    echo "Modes: s3, pvc, oci, hf"
    echo ""
    echo "Presets (no arguments):"
    echo "  $0                  # Interactive menu"
    echo ""
    echo "Examples:"
    echo "  $0 oci qwen3-4b oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b"
    echo "  $0 s3 qwen3-8b Qwen/Qwen3-8B-Instruct"
    echo "  $0 pvc llama-3-8b meta-llama/Llama-3-8B-Instruct"
    echo "  $0 hf gemma4-e2b google/gemma-4-E2B-it"
    echo ""
    echo "Environment: NAMESPACE=$NAMESPACE  RUNTIME=$RUNTIME  HF_TOKEN  HF_TOKEN_SECRET"
    exit 1
fi

# Build URI based on mode
case "$MODE" in
    s3)  uri="s3://${MODEL_PATH}" ;;
    pvc) uri="pvc://models-pvc/${MODEL_PATH}" ;;
    oci) uri="${MODEL_PATH}" ;;
    hf)  uri="hf://${MODEL_PATH}" ;;
    *)   print_error "Invalid mode: $MODE (use s3, pvc, oci, hf)"; exit 1 ;;
esac

_do_deploy "$RUNTIME" "$NAME" "$uri" "$NAMESPACE" "1" "4" "16Gi" "$EXTRA_VLLM_ARGS"
