#!/bin/bash
################################################################################
# Set Up External OIDC Authentication for MaaS (Keycloak demo IdP)
################################################################################
# By default, MaaS authenticates users via OpenShift tokens (TokenReview).
# This script deploys a demo Keycloak instance and configures MaaS to also
# accept OIDC tokens, so users can authenticate with corporate-style credentials.
#
# If you already have an external OIDC provider (Okta, Azure AD, etc.), skip
# the Keycloak deployment and go straight to --configure-only with your own
# --client-id and --issuer-url.
#
# Usage:
#   ./scripts/setup-maas-oidc.sh                          # full setup (Keycloak + MaaS config)
#   ./scripts/setup-maas-oidc.sh --configure-only \
#       --client-id my-client --issuer-url https://idp.example.com/realms/x
#   ./scripts/setup-maas-oidc.sh --cleanup
#   ./scripts/setup-maas-oidc.sh --test
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

OIDC_DIR="$ROOT_DIR/lib/manifests/maas/oidc"
CONFIGURE_ONLY=false
CLEANUP=false
TEST_ONLY=false
CLIENT_ID="maas-oidc"
ISSUER_URL=""
TTL=300

usage() {
    echo "Usage: $0 [--configure-only --client-id <id> --issuer-url <url>] [--cleanup] [--test]"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --configure-only) CONFIGURE_ONLY=true; shift ;;
        --client-id) CLIENT_ID="$2"; shift 2 ;;
        --issuer-url) ISSUER_URL="$2"; shift 2 ;;
        --ttl) TTL="$2"; shift 2 ;;
        --cleanup) CLEANUP=true; shift ;;
        --test) TEST_ONLY=true; shift ;;
        -h|--help) usage ;;
        *) print_error "Unknown option: $1"; usage ;;
    esac
done

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

detect_rhoai_version 2>/dev/null || true
IS_35=false
is_rhoai_35_or_higher 2>/dev/null && IS_35=true

################################################################################
# Cleanup
################################################################################

if [ "$CLEANUP" = true ]; then
    print_step "Removing OIDC configuration and Keycloak..."
    if [ "$IS_35" = true ]; then
        oc patch aitenants.maas.opendatahub.io models-as-a-service -n ai-tenants \
            --type json -p '[{"op":"remove","path":"/spec/oidc"}]' 2>/dev/null || true
    else
        oc patch tenants.maas.opendatahub.io default-tenant -n models-as-a-service \
            --type json -p '[{"op":"remove","path":"/spec/externalOIDC"}]' 2>/dev/null || true
    fi
    oc delete -k "$OIDC_DIR/maas-oidc" --ignore-not-found 2>/dev/null || true
    oc delete namespace maas-keycloak --ignore-not-found 2>/dev/null || true
    print_success "OIDC configuration and Keycloak removed"
    print_info "MaaS falls back to default OpenShift TokenReview authentication."
    exit 0
fi

################################################################################
# Deploy Keycloak (skipped if --configure-only)
################################################################################

if [ "$CONFIGURE_ONLY" = false ] && [ "$TEST_ONLY" = false ]; then
    print_step "Installing RHBK (Keycloak) operator..."
    oc apply -k "$OIDC_DIR/keycloak/operator"

    print_step "Waiting for RHBK operator CSV to succeed (this may take a few minutes)..."
    elapsed=0
    while [ $elapsed -lt 300 ]; do
        phase=$(oc get csv -n maas-keycloak -o jsonpath='{.items[?(@.spec.displayName=="Red Hat build of Keycloak")].status.phase}' 2>/dev/null)
        [ "$phase" = "Succeeded" ] && break
        sleep 10
        elapsed=$((elapsed + 10))
    done
    [ "$phase" = "Succeeded" ] && print_success "RHBK operator ready" || print_warning "RHBK operator not confirmed ready -- continuing anyway"

    print_step "Creating Keycloak DB secret..."
    KC_DB_PASSWORD=$(openssl rand -base64 16 | tr -d '=+/')
    oc create secret generic keycloak-db-secret -n maas-keycloak \
        --from-literal=username=keycloak \
        --from-literal=password="$KC_DB_PASSWORD" \
        --dry-run=client -o yaml | oc apply -f -

    print_step "Deploying Keycloak instance + realm import..."
    oc apply -k "$OIDC_DIR/keycloak/instance"

    print_step "Waiting for Keycloak PostgreSQL..."
    oc rollout status deployment/keycloak-pgsql -n maas-keycloak --timeout=120s || true

    print_step "Waiting for Keycloak instance to be Ready (this may take a few minutes)..."
    elapsed=0
    while [ $elapsed -lt 300 ]; do
        ready=$(oc get keycloak keycloak -n maas-keycloak -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        [ "$ready" = "True" ] && break
        sleep 10
        elapsed=$((elapsed + 10))
    done
    [ "$ready" = "True" ] && print_success "Keycloak is Ready" || print_warning "Keycloak not confirmed Ready -- check: oc get keycloak keycloak -n maas-keycloak"

    KEYCLOAK_HOST=$(oc get route keycloak -n maas-keycloak -o jsonpath='{.spec.host}' 2>/dev/null)
    ISSUER_URL="https://${KEYCLOAK_HOST}/realms/maas"
    print_success "Keycloak issuer URL: $ISSUER_URL"
fi

if [ -z "$ISSUER_URL" ]; then
    print_error "--issuer-url is required when using --configure-only"
    usage
fi

################################################################################
# Configure MaaS Tenant for External OIDC
################################################################################

if [ "$TEST_ONLY" = false ]; then
    print_step "Configuring MaaS tenant for external OIDC (client=$CLIENT_ID)..."
    if [ "$IS_35" = true ]; then
        oc patch aitenants.maas.opendatahub.io models-as-a-service -n ai-tenants \
            --type merge \
            -p "{\"spec\":{\"oidc\":{\"clientId\":\"${CLIENT_ID}\",\"issuerUrl\":\"${ISSUER_URL}\",\"ttl\":${TTL}}}}"
        print_success "AITenant patched (spec.oidc)"
    else
        oc patch tenants.maas.opendatahub.io default-tenant -n models-as-a-service \
            --type merge \
            -p "{\"spec\":{\"externalOIDC\":{\"clientId\":\"${CLIENT_ID}\",\"issuerUrl\":\"${ISSUER_URL}\"}}}"
        print_success "Tenant patched (spec.externalOIDC)"
    fi

    print_step "Applying OIDC group subscriptions and auth policies..."
    oc apply -k "$OIDC_DIR/maas-oidc"
    print_success "OIDC group governance applied (data-scientists, ml-engineers)"
fi

################################################################################
# Test
################################################################################

CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)

if [ "$CONFIGURE_ONLY" = false ]; then
    echo ""
    print_step "Testing OIDC flow with demo user 'maas-user'..."
    TOKEN=$(curl -sSk -X POST "${ISSUER_URL}/protocol/openid-connect/token" \
        -d "grant_type=password" \
        -d "client_id=${CLIENT_ID}" \
        -d "username=maas-user" \
        -d "password=maas-user" \
        -d "scope=openid groups" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)

    if [ -n "$TOKEN" ]; then
        print_success "Obtained OIDC token for maas-user"
        RESP=$(curl -sSk -w '\n%{http_code}' \
            -H "Authorization: Bearer ${TOKEN}" \
            "https://maas.${CLUSTER_DOMAIN}/maas-api/v1/models" 2>/dev/null)
        CODE=$(echo "$RESP" | tail -1)
        if [ "$CODE" = "200" ]; then
            print_success "MaaS API accepted OIDC token (HTTP 200)"
        else
            print_warning "MaaS API returned HTTP $CODE for OIDC token -- check tenant OIDC config"
        fi
    else
        print_warning "Could not obtain OIDC token -- Keycloak may still be initializing"
    fi
fi

echo ""
print_info "Manual verification:"
echo "  KEYCLOAK_ISSUER=\"$ISSUER_URL\""
echo "  TOKEN=\$(curl -sSk -X POST \"\${KEYCLOAK_ISSUER}/protocol/openid-connect/token\" \\"
echo "    -d grant_type=password -d client_id=$CLIENT_ID \\"
echo "    -d username=maas-user -d password=maas-user -d 'scope=openid groups' | jq -r .access_token)"
echo "  curl -sSk -H \"Authorization: Bearer \$TOKEN\" https://maas.${CLUSTER_DOMAIN}/maas-api/v1/models"
