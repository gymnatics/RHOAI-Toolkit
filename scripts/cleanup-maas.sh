#!/bin/bash
################################################################################
# Cleanup MaaS and Its Dependencies (Reverse-Order Teardown)
################################################################################
# Modeled on the BU MaaS Guide's cleanup-maas.sh. Reverses scripts/setup-maas.sh
# in reverse phase order, checking whether each resource exists before deleting.
#
# Usage:
#   ./scripts/cleanup-maas.sh                # prompts for confirmation
#   ./scripts/cleanup-maas.sh --yes           # skip confirmation
#   ./scripts/cleanup-maas.sh --dry-run       # preview only, no deletions
#   ./scripts/cleanup-maas.sh --keep-operators  # keep RHCL/cert-manager/LWS/RHOAI installed
#   ./scripts/cleanup-maas.sh --from-phase 3    # start from a specific phase (1-6)
#
# Phases (reverse order):
#   1. Models              - LLMInferenceService, MaaSModelRef/AuthPolicy/Subscription, llm namespace
#   2. External Models     - ExternalProvider/ExternalModel, provider secrets, external-models namespace
#   3. OIDC                - Keycloak, AITenant/Tenant OIDC config, OIDC group subscriptions
#   4. MaaS Platform        - PostgreSQL, maas-db-config/postgres-creds secrets
#   5. Platform Config      - Gateway, GatewayClass, Kuadrant CR
#   6. Operators            - RHCL, (optionally kept)
#
# NOTE: Does NOT remove: pre-existing namespaces (openshift-operators, etc.),
# GPU operators, CRDs left behind by OLM, or the RHOAI/DSC install itself.
################################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
}
source "$ROOT_DIR/lib/utils/rhoai-version.sh" 2>/dev/null || true

print_step() { echo -e "${CYAN}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

DRY_RUN=false
YES=false
KEEP_OPERATORS=false
FROM_PHASE=1

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --yes) YES=true; shift ;;
        --keep-operators) KEEP_OPERATORS=true; shift ;;
        --from-phase) FROM_PHASE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--yes] [--keep-operators] [--from-phase N]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

run() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}[dry-run]${NC} $*"
    else
        "$@" 2>/dev/null || true
    fi
}

if ! oc whoami &>/dev/null; then
    echo "Not logged in to OpenShift. Run: oc login <cluster-url>" >&2
    exit 1
fi

detect_rhoai_version 2>/dev/null || true
INFRA_NS=$(get_maas_infra_namespace 2>/dev/null || echo "redhat-ods-applications")

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  MaaS Cleanup / Teardown                                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
print_info "RHOAI version: ${RHOAI_VERSION:-unknown} | maas-api namespace: $INFRA_NS"
[ "$DRY_RUN" = true ] && print_warning "DRY RUN -- no resources will actually be deleted"

if [ "$YES" != true ] && [ "$DRY_RUN" != true ]; then
    echo ""
    read -p "This will remove MaaS models, platform, and (optionally) operators. Continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

################################################################################
# Phase 1: Models
################################################################################
if [ "$FROM_PHASE" -le 1 ]; then
    print_step "[1/6] Removing models and MaaS governance..."
    run oc delete maassubscription --all -n models-as-a-service --ignore-not-found
    run oc delete maasauthpolicy --all -n models-as-a-service --ignore-not-found
    run oc delete maasmodelref --all -n llm --ignore-not-found
    run oc delete llminferenceservice --all -n llm --ignore-not-found
    run oc delete namespace llm --ignore-not-found
    print_success "Phase 1 complete: models removed"
fi

################################################################################
# Phase 2: External Models
################################################################################
if [ "$FROM_PHASE" -le 2 ]; then
    print_step "[2/6] Removing external models..."
    run oc delete maassubscription -l "app!=" -n models-as-a-service --ignore-not-found 2>/dev/null
    for provider in openai gemini bedrock; do
        run oc delete -k "$ROOT_DIR/lib/manifests/maas/external-models/$provider/maas" --ignore-not-found
        run oc delete -k "$ROOT_DIR/lib/manifests/maas/external-models/$provider/model" --ignore-not-found
        run oc delete -f "$ROOT_DIR/lib/manifests/maas/external-models/$provider/model/external-model-34.yaml" --ignore-not-found
        run oc delete secret "${provider}-api-key" -n external-models --ignore-not-found
    done
    run oc delete namespace external-models --ignore-not-found
    print_success "Phase 2 complete: external models removed"
fi

################################################################################
# Phase 3: External OIDC
################################################################################
if [ "$FROM_PHASE" -le 3 ]; then
    print_step "[3/6] Removing External OIDC configuration..."
    if is_rhoai_35_or_higher 2>/dev/null; then
        run oc patch aitenants.maas.opendatahub.io models-as-a-service -n ai-tenants \
            --type json -p '[{"op":"remove","path":"/spec/oidc"}]'
    else
        run oc patch tenants.maas.opendatahub.io default-tenant -n models-as-a-service \
            --type json -p '[{"op":"remove","path":"/spec/externalOIDC"}]'
    fi
    run oc delete -k "$ROOT_DIR/lib/manifests/maas/oidc/maas-oidc" --ignore-not-found
    run oc delete namespace maas-keycloak --ignore-not-found
    print_success "Phase 3 complete: OIDC configuration removed"
fi

################################################################################
# Phase 4: MaaS Platform (PostgreSQL)
################################################################################
if [ "$FROM_PHASE" -le 4 ]; then
    print_step "[4/6] Removing PostgreSQL platform..."
    run oc delete deployment postgres -n "$INFRA_NS" --ignore-not-found
    run oc delete service postgres -n "$INFRA_NS" --ignore-not-found
    run oc delete pvc postgres-data -n "$INFRA_NS" --ignore-not-found
    run oc delete secret postgres-creds maas-db-config -n "$INFRA_NS" --ignore-not-found
    # Legacy 3.4-style location, in case it differs from the resolved infra namespace
    run oc delete secret maas-db-config -n redhat-ods-applications --ignore-not-found

    # RHOAI 3.5+: the cluster-scoped Config/default object carries a
    # maas.opendatahub.io/default-aitenant-bootstrapped annotation once a
    # default AITenant/MaasTenantConfig has ever been bootstrapped. Because
    # it's cluster-scoped, it survives any namespace-scoped teardown above and
    # tells the maas-controller on the next install "an admin already
    # bootstrapped and intentionally removed the default tenant -- respect the
    # zero-tenant state" (per upstream opendatahub-io/models-as-a-service
    # docs), which blocks auto-bootstrap on a fresh reinstall. Delete it here
    # so a teardown+reinstall cycle via this toolkit doesn't hit that trap.
    if oc get crd configs.maas.opendatahub.io &>/dev/null; then
        run oc delete configs.maas.opendatahub.io default --ignore-not-found
    fi
    print_success "Phase 4 complete: PostgreSQL removed"
fi

################################################################################
# Phase 5: Platform Configuration (Gateway, Kuadrant)
################################################################################
if [ "$FROM_PHASE" -le 5 ]; then
    print_step "[5/6] Removing Gateway and Kuadrant..."
    run oc delete route maas-default-gateway-https -n openshift-ingress --ignore-not-found
    run oc delete gateway maas-default-gateway -n openshift-ingress --ignore-not-found
    run oc delete gateway openshift-ai-inference -n openshift-ingress --ignore-not-found
    run oc delete configmap maas-gateway-options -n openshift-ingress --ignore-not-found
    run oc delete gatewayclass openshift-gateway-controller --ignore-not-found
    run oc delete gatewayclass openshift-ai-inference --ignore-not-found
    run oc delete kuadrant kuadrant -n kuadrant-system --ignore-not-found
    run oc delete namespace kuadrant-system --ignore-not-found
    print_success "Phase 5 complete: Gateway and Kuadrant removed"
fi

################################################################################
# Phase 6: Operators
################################################################################
if [ "$FROM_PHASE" -le 6 ]; then
    if [ "$KEEP_OPERATORS" = true ]; then
        print_info "[6/6] Skipping operator removal (--keep-operators)"
    else
        print_step "[6/6] Removing RHCL operator..."
        run oc delete subscription rhcl-operator -n openshift-operators --ignore-not-found
        csv_name=$(oc get csv -n openshift-operators --no-headers 2>/dev/null | grep rhcl-operator | awk '{print $1}')
        [ -n "$csv_name" ] && run oc delete csv "$csv_name" -n openshift-operators --ignore-not-found
        print_success "Phase 6 complete: RHCL operator removed"
        print_warning "cert-manager, LWS, and RHOAI itself are NOT removed by this script"
        print_info "(they may be used by other components) -- see scripts/cleanup-all.sh for full teardown"
    fi
fi

echo ""
if [ "$DRY_RUN" = true ]; then
    print_info "Dry run complete. Re-run without --dry-run to apply."
else
    print_success "MaaS cleanup complete."
    print_info "To reinstall: ./scripts/setup-maas.sh"
fi
