#!/bin/bash
################################################################################
# Deploy a MaaS Model via Kustomize (GPU auto-detection, HF Xet workaround)
################################################################################
# Orchestration script for lib/manifests/maas/models/{model}/. Manifests are the
# source of truth (see .cursor/rules/manifests-source-of-truth.mdc) -- this script
# only handles namespace setup, GPU auto-detection, envsubst for templated
# manifests, and post-deploy readiness checks / known-issue workarounds.
#
# Models:
#   simulator              CPU-only, no GPU required (~30s startup)
#   simulator-disconnected CPU-only, air-gapped variant (oci:// URI)
#   granite-tiny-gpu       ~1B params, ~8 GiB VRAM
#   gemma                  Gemma 2 9B IT FP8, ~12 GiB VRAM
#   gpt-oss-20b            ~16+ GiB VRAM
#   auto                   Auto-detect based on available GPU VRAM
#
# Usage:
#   ./scripts/deploy-maas-model.sh --model simulator
#   ./scripts/deploy-maas-model.sh --model auto
#   ./scripts/deploy-maas-model.sh --model gemma -n my-namespace
#   ./scripts/deploy-maas-model.sh --model simulator --delete
#
# Two valid paths to deploy the SAME manifests:
#   1. This script (handles namespace, GPU detection, workarounds)
#   2. Direct:  oc apply -k lib/manifests/maas/models/simulator/
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
}
source "$ROOT_DIR/lib/utils/os-compat.sh" 2>/dev/null || true

print_step() { echo -e "${CYAN}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

MODEL="auto"
MODEL_NAMESPACE="llm"
DELETE_MODE=false
DISCONNECTED_REGISTRY=""
VALID_MODELS=(simulator simulator-disconnected granite-tiny-gpu gemma gpt-oss-20b)

usage() {
    echo "Usage: $0 --model <name> [-n namespace] [--delete] [--disconnected-registry <host>]"
    echo ""
    echo "Models: simulator | simulator-disconnected | granite-tiny-gpu | gemma | gpt-oss-20b | auto"
    echo ""
    echo "  --model auto   Auto-detects based on GPU VRAM on cluster nodes:"
    echo "                   no GPU        -> simulator"
    echo "                   >= 40960 MiB  -> gpt-oss-20b"
    echo "                   >= 16384 MiB  -> gemma"
    echo "                   else (has GPU) -> granite-tiny-gpu"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --model) MODEL="$2"; shift 2 ;;
        -n|--namespace) MODEL_NAMESPACE="$2"; shift 2 ;;
        --delete) DELETE_MODE=true; shift ;;
        --disconnected-registry) DISCONNECTED_REGISTRY="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) print_error "Unknown option: $1"; usage ;;
    esac
done

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

if ! command -v kustomize &>/dev/null && ! oc kustomize --help &>/dev/null 2>&1; then
    print_error "kustomize not found and 'oc kustomize' unavailable."
    exit 1
fi

# Rewrite the default 'llm' namespace to a custom namespace across all YAML files
# in a directory tree. This covers both kustomize `namespace:` transformers (in
# kustomization.yaml) and explicit `metadata.namespace: llm` / `namespace: llm`
# fields in the maas/ CRs. NOTE: must use a while-read loop, not `find -exec
# sed_inplace`, because `find -exec` execs the command by name and cannot see
# bash functions even when exported with `export -f`.
rewrite_namespace_in_dir() {
    local dir="$1"
    local new_ns="$2"
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        sed_inplace "s/namespace: llm$/namespace: ${new_ns}/" "$f"
    done < <(find "$dir" -name '*.yaml')
}

################################################################################
# GPU Auto-Detection
################################################################################

# Query the maximum GPU memory (MiB) advertised by any node, via the NVIDIA
# GPU Feature Discovery labels. Echoes 0 if no GPU nodes are found.
detect_max_gpu_memory_mib() {
    oc get nodes -o jsonpath='{range .items[*]}{.metadata.labels.nvidia\.com/gpu\.memory}{"\n"}{end}' 2>/dev/null \
        | grep -E '^[0-9]+$' | sort -rn | head -1 || echo "0"
}

auto_select_model() {
    local gpu_mem
    gpu_mem=$(detect_max_gpu_memory_mib)
    gpu_mem="${gpu_mem:-0}"

    if [ "$gpu_mem" -eq 0 ]; then
        print_info "No GPU detected on cluster nodes -> selecting 'simulator'"
        echo "simulator"
    elif [ "$gpu_mem" -ge 40960 ]; then
        print_info "GPU memory ${gpu_mem} MiB >= 40960 -> selecting 'gpt-oss-20b'"
        echo "gpt-oss-20b"
    elif [ "$gpu_mem" -ge 16384 ]; then
        print_info "GPU memory ${gpu_mem} MiB >= 16384 -> selecting 'gemma'"
        echo "gemma"
    else
        print_info "GPU memory ${gpu_mem} MiB (< 16384, but GPU present) -> selecting 'granite-tiny-gpu'"
        echo "granite-tiny-gpu"
    fi
}

if [ "$MODEL" = "auto" ]; then
    print_step "Auto-detecting model based on cluster GPU capacity..."
    MODEL=$(auto_select_model)
fi

if [[ ! " ${VALID_MODELS[*]} " =~ " ${MODEL} " ]]; then
    print_error "Unknown model: $MODEL"
    usage
fi

MANIFEST_DIR="$ROOT_DIR/lib/manifests/maas/models/$MODEL"
if [ ! -d "$MANIFEST_DIR" ]; then
    print_error "Manifest directory not found: $MANIFEST_DIR"
    exit 1
fi

################################################################################
# Delete Mode
################################################################################

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing model '$MODEL' from namespace '$MODEL_NAMESPACE'..."
    if [ "$MODEL_NAMESPACE" != "llm" ]; then
        TMP_DIR=$(mktemp -d)
        cp -r "$MANIFEST_DIR"/* "$TMP_DIR/"
        rewrite_namespace_in_dir "$TMP_DIR" "$MODEL_NAMESPACE"
        oc delete -k "$TMP_DIR" --ignore-not-found 2>/dev/null
        rm -rf "$TMP_DIR"
    else
        oc delete -k "$MANIFEST_DIR" --ignore-not-found 2>/dev/null
    fi
    print_success "Model '$MODEL' removed"
    exit 0
fi

################################################################################
# Deploy
################################################################################

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Deploy MaaS Model: $MODEL"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_step "Ensuring namespace '$MODEL_NAMESPACE' exists with required labels..."
oc create namespace "$MODEL_NAMESPACE" --dry-run=client -o yaml | oc apply -f - >/dev/null
oc label namespace "$MODEL_NAMESPACE" \
    opendatahub.io/generated-namespace=true \
    maas.opendatahub.io/gateway-access=true \
    opendatahub.io/dashboard=true \
    --overwrite >/dev/null
print_success "Namespace '$MODEL_NAMESPACE' ready (labeled for MaaS gateway + dashboard)"

# Build a working copy so we can safely: (a) rewrite the namespace if it's not
# the default 'llm', and (b) run envsubst for templated models (disconnected).
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
cp -r "$MANIFEST_DIR"/* "$TMP_DIR/"

if [ "$MODEL_NAMESPACE" != "llm" ]; then
    print_step "Rewriting manifest namespace: llm -> $MODEL_NAMESPACE"
    rewrite_namespace_in_dir "$TMP_DIR" "$MODEL_NAMESPACE"
fi

if [ "$MODEL" = "simulator-disconnected" ]; then
    if [ -z "$DISCONNECTED_REGISTRY" ]; then
        print_error "--disconnected-registry <host> is required for simulator-disconnected"
        exit 1
    fi
    print_step "Substituting DISCONNECTED_REGISTRY=$DISCONNECTED_REGISTRY..."
    export DISCONNECTED_REGISTRY
    for f in "$TMP_DIR/llm/model.yaml"; do
        envsubst '${DISCONNECTED_REGISTRY}' < "$f" > "${f}.rendered" && mv "${f}.rendered" "$f"
    done
fi

print_step "Applying manifests via kustomize..."
oc apply -k "$TMP_DIR"
print_success "Manifests applied"

################################################################################
# Readiness Wait + HuggingFace Xet Workaround
################################################################################
# HuggingFace has migrated model storage to the Xet protocol, which can cause
# the KServe storage-initializer init container to hang indefinitely when
# downloading hf:// URIs (affects 'simulator' only -- OCI modelcar models are
# unaffected). If the pod is stuck in Init for >120s, patch HF_HUB_DISABLE_XET=1
# on the init container to fall back to standard HTTP downloads.
################################################################################

apply_hf_xet_workaround_if_needed() {
    local ns="$1"
    local model="$2"
    local elapsed="$3"

    # Only relevant for hf:// URI models (simulator); OCI modelcar models are unaffected.
    if [ "$model" != "simulator" ]; then
        return 0
    fi
    if [ "$elapsed" -lt 120 ]; then
        return 0
    fi

    local deploy
    deploy=$(oc get deployment -n "$ns" -o name 2>/dev/null | grep -i "$model" | grep -i kserve | head -1)
    if [ -z "$deploy" ]; then
        return 0
    fi

    local phase
    phase=$(oc get pods -n "$ns" -l "serving.kserve.io/inferenceservice=$model" \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
    local init_ready
    init_ready=$(oc get pods -n "$ns" -l "serving.kserve.io/inferenceservice=$model" \
        -o jsonpath='{.items[0].status.initContainerStatuses[0].ready}' 2>/dev/null)

    if [ "$phase" = "Pending" ] || [ "$init_ready" = "false" ]; then
        print_warning "Init container stuck >120s (possible HuggingFace Xet download hang)"
        print_step "Applying HF_HUB_DISABLE_XET=1 workaround to $deploy..."
        oc patch "$deploy" -n "$ns" --type=json \
            -p '[{"op":"add","path":"/spec/template/spec/initContainers/0/env/-","value":{"name":"HF_HUB_DISABLE_XET","value":"1"}}]' \
            2>/dev/null && print_success "Workaround applied -- pod should complete init within ~30s" \
            || print_warning "Could not apply workaround automatically; see docs/TROUBLESHOOTING.md"
    fi
    return 0
}

print_step "Waiting for '$MODEL' to become Ready (this may take a while for GPU models)..."
elapsed=0
timeout=900
ready="False"
xet_patch_attempted=false
while [ $elapsed -lt $timeout ]; do
    ready=$(oc get llminferenceservice "$MODEL" -n "$MODEL_NAMESPACE" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
    if [ "$ready" = "True" ]; then
        print_success "Model '$MODEL' is Ready"
        break
    fi

    if [ "$xet_patch_attempted" = false ] && [ "$elapsed" -ge 120 ]; then
        # `|| true` guards against `set -e` exiting the script if this helper's
        # last internal comparison happens to be false (see detect_maas_state
        # in setup-maas.sh for the same class of bug and a fuller explanation).
        apply_hf_xet_workaround_if_needed "$MODEL_NAMESPACE" "$MODEL" "$elapsed" || true
        xet_patch_attempted=true
    fi

    sleep 10
    elapsed=$((elapsed + 10))
    echo -n "."
done
echo ""

if [ "$ready" != "True" ]; then
    print_warning "Model not Ready after ${timeout}s -- check manually:"
    echo "  oc get llminferenceservice $MODEL -n $MODEL_NAMESPACE"
    echo "  oc get pods -n $MODEL_NAMESPACE"
fi

echo ""
print_info "Verify:"
echo "  oc get llminferenceservice $MODEL -n $MODEL_NAMESPACE"
echo "  oc get maasmodelref $MODEL -n $MODEL_NAMESPACE"
echo "  oc get maassubscription -n models-as-a-service | grep $MODEL"

CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
if [ -n "$CLUSTER_DOMAIN" ]; then
    echo ""
    print_info "Test inference (see scripts/verify-maas.sh for a full E2E check):"
    echo "  MAAS_URL=\"https://maas.${CLUSTER_DOMAIN}\""
    echo "  API_KEY=\$(curl -sk -X POST \"\${MAAS_URL}/maas-api/v1/api-keys\" \\"
    echo "    -H \"Authorization: Bearer \$(oc whoami -t)\" \\"
    echo "    -H \"Content-Type: application/json\" \\"
    echo "    -d '{\"name\":\"test\",\"subscription\":\"${MODEL}-free\",\"expiresIn\":\"1h\"}' | jq -r '.key')"
fi
