#!/bin/bash
################################################################################
# Check MaaS Security Configuration (RHOAI 3.3+ integrated MaaS)
################################################################################
# Checks for LLMInferenceService/InferenceService models that are exposed
# through the MaaS gateway (maas-default-gateway) but have NO corresponding
# MaaSAuthPolicy -- meaning they are reachable via the gateway with no access
# control governance. This is the current (3.3+) integrated MaaS security
# model; it replaces the old legacy `maas-api` namespace + `enable-auth`
# annotation checks from the pre-3.3 kustomize-based setup, which no longer
# apply once MaaS moved to DSC-integrated subscription CRDs.
#
# See also: scripts/diagnose-maas.sh, which covers the BU guide's 10
# documented post-upgrade MaaS issues (gateway namespace labels, OOM, rate
# limiting defaults, etc.) -- a different, complementary set of checks.
#
# Usage: ./scripts/check-maas-security.sh
################################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
}
source "$ROOT_DIR/lib/utils/rhoai-version.sh" 2>/dev/null || true

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

print_header "MaaS Security Configuration Check"

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift"
    echo "Please login first: oc login <cluster-url>"
    exit 1
fi
print_success "Connected to: $(oc whoami --show-server)"
echo ""

detect_rhoai_version 2>/dev/null || true
if ! is_rhoai_33_or_higher 2>/dev/null; then
    print_warning "This check targets RHOAI 3.3+ integrated MaaS (subscription CRDs)."
    print_info "Detected version: ${RHOAI_VERSION:-unknown}. For legacy (<=3.2) MaaS, this"
    print_info "check does not apply -- the legacy kustomize deployment had no equivalent"
    print_info "governance CRDs to audit."
    exit 0
fi

if ! oc get gateway maas-default-gateway -n openshift-ingress &>/dev/null; then
    print_warning "MaaS gateway (maas-default-gateway) not found. Run: ./scripts/setup-maas.sh"
    exit 0
fi
print_success "MaaS gateway found"
echo ""

print_header "Checking Model Governance"

total_models=0
governed_models=0
ungoverned_models=0

# All namespaces with an LLMInferenceService or InferenceService that has a
# MaaSModelRef pointing at it are considered "MaaS-exposed" models.
model_refs=$(oc get maasmodelref -A -o json 2>/dev/null | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit()
for item in data.get('items', []):
    ns = item['metadata']['namespace']
    name = item['metadata']['name']
    ref = item.get('spec', {}).get('modelRef', {})
    ref_name = ref.get('name', name)
    ref_kind = ref.get('kind', 'LLMInferenceService')
    print(f'{ns}|{name}|{ref_name}|{ref_kind}')
" 2>/dev/null)

if [ -z "$model_refs" ]; then
    print_info "No MaaSModelRef resources found. No models are currently exposed via MaaS."
else
    while IFS='|' read -r ns modelref_name ref_name ref_kind; do
        [ -z "$ns" ] && continue
        total_models=$((total_models + 1))

        # Does a MaaSAuthPolicy exist that references this model?
        has_policy=$(oc get maasauthpolicy -n models-as-a-service -o json 2>/dev/null | \
            python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit()
for item in data.get('items', []):
    for ref in item.get('spec', {}).get('modelRefs', []):
        if ref.get('name') == '$ref_name' and ref.get('namespace') == '$ns':
            print(item['metadata']['name'])
            sys.exit()
" 2>/dev/null)

        has_subscription=$(oc get maassubscription -n models-as-a-service -o json 2>/dev/null | \
            python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit()
for item in data.get('items', []):
    for ref in item.get('spec', {}).get('modelRefs', []):
        if ref.get('name') == '$ref_name' and ref.get('namespace') == '$ns':
            print(item['metadata']['name'])
            sys.exit()
" 2>/dev/null)

        if [ -n "$has_policy" ] && [ -n "$has_subscription" ]; then
            print_success "GOVERNED: $ns/$ref_name ($ref_kind)"
            echo "   MaaSAuthPolicy: $has_policy | MaaSSubscription: $has_subscription"
            governed_models=$((governed_models + 1))
        else
            print_error "UNGOVERNED: $ns/$ref_name ($ref_kind)"
            [ -z "$has_policy" ] && echo "   Missing: MaaSAuthPolicy (no access control -- reachable by anyone through the gateway)"
            [ -z "$has_subscription" ] && echo "   Missing: MaaSSubscription (no rate limiting)"
            echo ""
            echo -e "   ${YELLOW}Fix:${NC} deploy governance with scripts/deploy-maas-model.sh, or manually:"
            echo "   oc apply -f - <<EOF"
            echo "   apiVersion: maas.opendatahub.io/v1alpha1"
            echo "   kind: MaaSAuthPolicy"
            echo "   metadata: {name: ${ref_name}-access, namespace: models-as-a-service}"
            echo "   spec: {modelRefs: [{name: ${ref_name}, namespace: ${ns}}], subjects: {groups: [{name: system:authenticated}]}}"
            echo "   EOF"
            ungoverned_models=$((ungoverned_models + 1))
        fi
        echo ""
    done <<< "$model_refs"
fi

print_header "Security Check Summary"
echo "Total MaaS-exposed models: $total_models"
echo -e "Governed:                   ${GREEN}$governed_models${NC}"
echo -e "Ungoverned:                 ${RED}$ungoverned_models${NC}"
echo ""

if [ "$ungoverned_models" -eq 0 ] && [ "$total_models" -gt 0 ]; then
    print_success "All MaaS-exposed models have both AuthPolicy and Subscription governance."
elif [ "$ungoverned_models" -gt 0 ]; then
    print_error "Found $ungoverned_models ungoverned model(s)."
    print_warning "Models with a MaaSModelRef but no MaaSAuthPolicy are reachable through the"
    print_warning "gateway's HTTPRoute with NO access control -- effectively public."
fi

print_header "Additional Recommendations"
echo "1. Run ./scripts/diagnose-maas.sh --fix for known post-upgrade issue checks"
echo "   (gateway namespace labels, OOM prevention, rate limit defaults, etc.)"
echo "2. Use ./scripts/deploy-maas-model.sh for new models -- it always creates"
echo "   MaaSAuthPolicy + MaaSSubscription alongside the LLMInferenceService."
echo "3. Regularly audit: ./scripts/check-maas-security.sh"
echo ""

[ "$ungoverned_models" -gt 0 ] && exit 1
exit 0
