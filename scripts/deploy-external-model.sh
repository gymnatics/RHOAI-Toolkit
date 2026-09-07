#!/bin/bash
################################################################################
# Deploy a MaaS External Model (OpenAI, Gemini, or Bedrock)
################################################################################
# Orchestration script for lib/manifests/maas/external-models/{provider}/.
# Manifests are the source of truth (see .cursor/rules/manifests-source-of-truth.mdc).
# This script handles: namespace setup, provider API key secret creation
# (imperative -- never committed to manifests), and version-aware CRD selection
# (ExternalProvider is RHOAI 3.5+ only; 3.4 uses a standalone ExternalModel).
#
# Usage:
#   ./scripts/deploy-external-model.sh --provider openai --api-key "$OPENAI_API_KEY"
#   ./scripts/deploy-external-model.sh --provider gemini --api-key "$GEMINI_API_KEY"
#   ./scripts/deploy-external-model.sh --provider bedrock --api-key "$BEDROCK_API_KEY"
#   ./scripts/deploy-external-model.sh --provider openai --delete
#
# NOTE: Gemini is broken on RHOAI 3.4 (RHOAIENG-68592) -- the BBR provider
# hardcodes /v1/chat/completions and Gemini requires /v1beta/openai/chat/completions.
# This script will warn and refuse to deploy Gemini on 3.4 unless --force is passed.
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
}
source "$ROOT_DIR/lib/utils/rhoai-version.sh" 2>/dev/null || true

print_step() { echo -e "${CYAN}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

PROVIDER=""
API_KEY=""
DELETE_MODE=false
FORCE=false
VALID_PROVIDERS=(openai gemini bedrock)

usage() {
    echo "Usage: $0 --provider <openai|gemini|bedrock> --api-key <key> [--force]"
    echo "       $0 --provider <name> --delete"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --provider) PROVIDER="$2"; shift 2 ;;
        --api-key) API_KEY="$2"; shift 2 ;;
        --delete) DELETE_MODE=true; shift ;;
        --force) FORCE=true; shift ;;
        -h|--help) usage ;;
        *) print_error "Unknown option: $1"; usage ;;
    esac
done

if [[ ! " ${VALID_PROVIDERS[*]} " =~ " ${PROVIDER} " ]]; then
    print_error "Unknown or missing --provider (expected: openai, gemini, bedrock)"
    usage
fi

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

MANIFEST_DIR="$ROOT_DIR/lib/manifests/maas/external-models/$PROVIDER"
NS_MANIFEST="$ROOT_DIR/lib/manifests/maas/external-models/namespace.yaml"

detect_rhoai_version 2>/dev/null || true
IS_35=false
is_rhoai_35_or_higher 2>/dev/null && IS_35=true

SECRET_NAME="${PROVIDER}-api-key"
if [ "$IS_35" = true ]; then
    MANAGED_LABEL="inference.llm-d.ai/ipp-managed=true"
else
    MANAGED_LABEL="inference.networking.k8s.io/bbr-managed=true"
fi

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing external model provider '$PROVIDER'..."
    oc delete -k "$MANIFEST_DIR/maas" --ignore-not-found 2>/dev/null || true
    if [ "$IS_35" = true ]; then
        oc delete -k "$MANIFEST_DIR/model" --ignore-not-found 2>/dev/null || true
    else
        oc delete -f "$MANIFEST_DIR/model/external-model-34.yaml" --ignore-not-found 2>/dev/null || true
    fi
    oc delete secret "$SECRET_NAME" -n external-models --ignore-not-found 2>/dev/null || true
    print_success "External model provider '$PROVIDER' removed"
    exit 0
fi

if [ "$PROVIDER" = "gemini" ] && [ "$IS_35" != true ] && [ "$FORCE" != true ]; then
    print_error "Gemini is broken on RHOAI 3.4 (RHOAIENG-68592): the BBR provider"
    print_error "hardcodes /v1/chat/completions but Gemini requires"
    print_error "/v1beta/openai/chat/completions. No workaround exists on 3.4."
    print_error "Upgrade to RHOAI 3.5+, or pass --force to deploy anyway (will fail with HTTP 404)."
    exit 1
fi

if [ -z "$API_KEY" ]; then
    print_error "--api-key is required"
    usage
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Deploy External Model Provider: $PROVIDER"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_step "Ensuring 'external-models' namespace exists..."
oc apply -f "$NS_MANIFEST"
print_success "Namespace ready"

print_step "Creating credential secret '$SECRET_NAME' (imperative -- not committed to manifests)..."
oc create secret generic "$SECRET_NAME" \
    --from-literal=api-key="$API_KEY" \
    -n external-models \
    --dry-run=client -o yaml | oc apply -f -
oc label secret "$SECRET_NAME" -n external-models "$MANAGED_LABEL" --overwrite
print_success "Secret created and labeled ($MANAGED_LABEL)"

print_step "Applying ExternalProvider/ExternalModel manifests..."
if [ "$IS_35" = true ]; then
    oc apply -k "$MANIFEST_DIR/model"
else
    oc apply -f "$MANIFEST_DIR/model/external-model-34.yaml"
fi
print_success "Model manifests applied"

print_step "Applying MaaS governance (MaaSModelRef, AuthPolicy, Subscription)..."
oc apply -k "$MANIFEST_DIR/maas"
print_success "MaaS governance applied"

echo ""
print_step "Waiting for MaaSModelRef to reach Ready..."
elapsed=0
model_name=$(basename "$(grep -l "kind: MaaSModelRef" "$MANIFEST_DIR/maas"/*.yaml)" 2>/dev/null)
ref_name=$(grep -A2 "kind: MaaSModelRef" -r "$MANIFEST_DIR/maas" | grep "name:" | head -1 | awk '{print $2}')
while [ $elapsed -lt 60 ]; do
    phase=$(oc get maasmodelref "$ref_name" -n external-models -o jsonpath='{.status.phase}' 2>/dev/null || true)
    [ "$phase" = "Ready" ] && break
    sleep 5
    elapsed=$((elapsed + 5))
done

if [ "$phase" = "Ready" ]; then
    print_success "MaaSModelRef '$ref_name' is Ready"
else
    print_warning "MaaSModelRef not Ready yet -- check: oc get maasmodelref $ref_name -n external-models"
fi

CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
echo ""
print_info "Test inference:"
echo "  MAAS_GW=\"https://maas.${CLUSTER_DOMAIN}\""
echo "  API_KEY=\$(curl -sk -X POST \"\${MAAS_GW}/maas-api/v1/api-keys\" \\"
echo "    -H \"Authorization: Bearer \$(oc whoami -t)\" \\"
echo "    -d '{\"name\":\"test\",\"subscription\":\"${ref_name}-free\",\"expiresIn\":\"1h\"}' | jq -r '.key')"
