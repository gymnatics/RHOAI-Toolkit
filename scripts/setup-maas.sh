#!/bin/bash

################################################################################
# Setup Model as a Service (MaaS) for RHOAI
################################################################################
# This script sets up MaaS infrastructure with version-aware configuration:
# - RHOAI 3.4+: Phased setup using lib/manifests/{rhcl,maas/platform}/ manifests
#   (this script only orchestrates -- see .cursor/rules/manifests-source-of-truth.mdc)
# - RHOAI 3.3: Legacy integrated tier-based MaaS (Technology Preview)
# - RHOAI 3.2 and earlier: Legacy kustomize-based setup
#
# Prerequisites:
# - RHOAI installed
# - oc CLI configured and logged in
#
# Usage:
#   ./scripts/setup-maas.sh                  # full setup, auto-detects version
#   ./scripts/setup-maas.sh --from-phase 3   # resume from a specific phase (3.4+ only)
#   ./scripts/setup-maas.sh --diagnose       # run scripts/diagnose-maas.sh after setup
#
# Phases (RHOAI 3.4+):
#   1. RHCL operator + Kuadrant + Authorino TLS
#   2. GatewayClass + Gateway + gateway-resources ConfigMap + namespace labels + AUTH_SERVICE_TIMEOUT
#   3. PostgreSQL platform (lib/manifests/maas/platform/) + secrets
#   4. Enable MaaS in DataScienceCluster (version-branched DSC field) + dashboard flags
#   5. Verify
################################################################################

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m'
}
source "$ROOT_DIR/lib/utils/rhoai-version.sh" 2>/dev/null || true
source "$ROOT_DIR/lib/functions/redis-limitador.sh" 2>/dev/null || true

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() { echo -e "${YELLOW}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

CLUSTER_DOMAIN=""
FROM_PHASE=1
RUN_DIAGNOSE=false
ENABLE_REDIS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --from-phase) FROM_PHASE="$2"; shift 2 ;;
        --diagnose) RUN_DIAGNOSE=true; shift ;;
        --enable-redis) ENABLE_REDIS=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--from-phase N] [--diagnose] [--enable-redis]"
            echo "  --from-phase N   Resume from phase N (1-5, RHOAI 3.4+ only)"
            echo "  --diagnose       Run scripts/diagnose-maas.sh after setup"
            echo "  --enable-redis   Deploy Redis for Limitador rate-limit counter"
            echo "                   persistence (survives Limitador pod restarts)"
            exit 0
            ;;
        *) shift ;;
    esac
done

################################################################################
# Service Mesh InstallPlan Approval
################################################################################

approve_servicemesh_installplans() {
    print_step "Checking for pending Service Mesh InstallPlans..."

    local pending_ips
    pending_ips=$(oc get installplan -n openshift-operators -o json 2>/dev/null | \
        python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('items', []):
    approved = item.get('spec', {}).get('approved', True)
    names = [n for n in item.get('spec', {}).get('clusterServiceVersionNames', []) if 'servicemesh' in n.lower() or 'istio' in n.lower()]
    if not approved and names:
        print(item['metadata']['name'])
" 2>/dev/null)

    if [ -n "$pending_ips" ]; then
        while IFS= read -r ip; do
            [ -z "$ip" ] && continue
            print_step "Approving Service Mesh InstallPlan: $ip"
            oc patch installplan "$ip" -n openshift-operators --type=merge -p '{"spec":{"approved":true}}'
        done <<< "$pending_ips"
        print_success "Service Mesh InstallPlans approved"
        sleep 15
    else
        print_success "No pending Service Mesh InstallPlans found"
    fi
}

################################################################################
# Prerequisites Check (Common)
################################################################################

check_common_prerequisites() {
    print_header "Checking Prerequisites"

    if ! command -v oc &> /dev/null; then
        print_error "oc command not found. Please install OpenShift CLI."
        exit 1
    fi
    print_success "oc CLI found"

    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift. Please run 'oc login' first."
        exit 1
    fi
    print_success "Logged in to OpenShift: $(oc whoami --show-server)"

    if ! oc get datasciencecluster default-dsc &>/dev/null; then
        print_error "RHOAI not found. Please install RHOAI first."
        exit 1
    fi
    print_success "RHOAI installation detected"

    detect_rhoai_version
    CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
    if [ -z "$CLUSTER_DOMAIN" ]; then
        print_error "Failed to get cluster domain"
        exit 1
    fi
    print_info "Cluster domain: $CLUSTER_DOMAIN"
}

################################################################################
# RHOAI 3.4+ Phased MaaS Setup (properly branched for 3.4 vs 3.5)
################################################################################
# This is the primary, actively-maintained path. Manifests referenced here are
# the source of truth (lib/manifests/rhcl/, lib/manifests/maas/platform/) -- this
# function only orchestrates version detection, ordering, and status gates.
################################################################################

# Idempotent state detection: sets HAS_* variables used to decide which phases to skip.
detect_maas_state() {
    HAS_RHCL=false
    HAS_KUADRANT=false
    HAS_GATEWAY=false
    HAS_POSTGRES=false
    HAS_MAAS_ENABLED=false

    oc get csv -A 2>/dev/null | grep -q "rhcl-operator.*Succeeded" && HAS_RHCL=true
    oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True && HAS_KUADRANT=true
    oc get gateway maas-default-gateway -n openshift-ingress -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null | grep -q True && HAS_GATEWAY=true

    local infra_ns
    infra_ns=$(get_maas_infra_namespace 2>/dev/null || echo "redhat-ods-applications")
    oc get secret maas-db-config -n "$infra_ns" &>/dev/null && HAS_POSTGRES=true

    if is_rhoai_35_or_higher; then
        local state
        state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.aigateway.modelsAsAService.managementState}' 2>/dev/null)
        [ "$state" = "Managed" ] && HAS_MAAS_ENABLED=true
    else
        local state
        state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.kserve.modelsAsService.managementState}' 2>/dev/null)
        [ "$state" = "Managed" ] && HAS_MAAS_ENABLED=true
    fi

    # IMPORTANT: this function is called as a bare statement (not inside a
    # condition), so its own return status must always be 0. Without this,
    # a false `[ "$state" = "Managed" ]` comparison above would make the
    # function return non-zero, which triggers `set -e` at the call site.
    return 0
}

# Phase 1: RHCL operator + Kuadrant + Authorino TLS
phase1_rhcl() {
    print_header "Phase 1: RHCL Operator + Kuadrant + Authorino TLS"

    if [ "$HAS_RHCL" = true ] && [ "$HAS_KUADRANT" = true ]; then
        print_success "RHCL + Kuadrant already installed and Ready -- skipping"
        return 0
    fi

    approve_servicemesh_installplans

    if [ "$HAS_RHCL" != true ]; then
        print_step "Installing RHCL operator..."
        if is_rhoai_35_or_higher; then
            oc apply -f "$ROOT_DIR/lib/manifests/rhcl/rhcl-operator-35.yaml"
        else
            oc apply -f "$ROOT_DIR/lib/manifests/rhcl/rhcl-operator-34.yaml"
            # 3.4 manifest pins Manual approval to avoid the broken 1.4.0 release -- auto-approve the initial plan.
            sleep 15
            local ip
            ip=$(oc get installplan -n openshift-operators -o json 2>/dev/null | \
                python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('items', []):
    if any('rhcl-operator' in n for n in item.get('spec', {}).get('clusterServiceVersionNames', [])):
        print(item['metadata']['name']); break
" 2>/dev/null)
            [ -n "$ip" ] && oc patch installplan "$ip" -n openshift-operators --type=merge -p '{"spec":{"approved":true}}' 2>/dev/null || true
        fi

        print_step "Waiting for RHCL operator CSV to succeed (this may take a few minutes)..."
        local elapsed=0
        until oc get csv -n openshift-operators 2>/dev/null | grep -q "rhcl-operator.*Succeeded"; do
            if [ $elapsed -ge 300 ]; then
                print_warning "Timeout waiting for RHCL CSV -- continuing anyway"
                break
            fi
            sleep 10
            elapsed=$((elapsed + 10))
        done
        print_success "RHCL operator installed"
    fi

    # Preventive fix (BU Issue 7): default 200ms AUTH_SERVICE_TIMEOUT causes HTTP
    # 500/503 under concurrent load. Set 2s proactively rather than reactively.
    print_step "Setting AUTH_SERVICE_TIMEOUT=2s on RHCL subscription (prevents BU Issue 7)..."
    oc patch subscription rhcl-operator -n openshift-operators --type=merge \
        -p '{"spec":{"config":{"env":[{"name":"AUTH_SERVICE_TIMEOUT","value":"2s"}]}}}' 2>/dev/null || true

    if [ "$HAS_KUADRANT" != true ]; then
        print_step "Creating kuadrant-system namespace and Kuadrant instance..."
        oc create namespace kuadrant-system 2>/dev/null || true
        oc apply -f "$ROOT_DIR/lib/manifests/rhcl/kuadrant-instance.yaml"

        print_step "Waiting for Kuadrant to become Ready..."
        local elapsed=0
        until oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; do
            if [ $elapsed -ge 180 ]; then
                print_warning "Timeout waiting for Kuadrant Ready -- checking for Istio race condition..."
                oc delete pod -n openshift-operators -l control-plane=controller-manager 2>/dev/null || true
                sleep 20
            fi
            sleep 10
            elapsed=$((elapsed + 10))
            [ $elapsed -ge 300 ] && { print_warning "Kuadrant still not Ready -- continuing anyway"; break; }
        done
        print_success "Kuadrant is Ready"
    fi

    print_step "Configuring Authorino TLS (service-ca method)..."
    oc annotate service authorino-authorino-authorization -n kuadrant-system \
        service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert --overwrite 2>/dev/null || true

    local cert_wait=0
    while [ $cert_wait -lt 60 ]; do
        oc get secret authorino-server-cert -n kuadrant-system &>/dev/null && break
        sleep 5
        cert_wait=$((cert_wait + 5))
    done

    oc apply -f "$ROOT_DIR/lib/manifests/rhcl/authorino-tls.yaml"
    oc -n kuadrant-system set env deployment/authorino \
        SSL_CERT_FILE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt \
        REQUESTS_CA_BUNDLE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt 2>/dev/null || true

    print_success "Phase 1 complete: RHCL + Kuadrant + Authorino TLS"
}

# Apply the gateway-resources ConfigMap (2Gi memory override, prevents BU
# Issue 5/6 OOM). On OCP < 4.22 behind a corporate proxy, the Gateway
# controller does not propagate cluster-wide proxy settings into the gateway
# pod (OCPBUGS-77457) -- use the proxy-aware variant instead so ExternalModel
# provider calls and WASM plugin image pulls can reach the internet.
apply_gateway_resources_configmap() {
    local ocp_version http_proxy_val https_proxy_val no_proxy_val

    ocp_version=$(oc get clusterversion version -o jsonpath='{.status.desired.version}' 2>/dev/null)
    http_proxy_val=$(oc get proxy/cluster -o jsonpath='{.spec.httpProxy}' 2>/dev/null)

    # Only relevant on OCP < 4.22 with a cluster-wide proxy configured.
    local major minor
    major=$(echo "$ocp_version" | cut -d. -f1)
    minor=$(echo "$ocp_version" | cut -d. -f2)

    if [ -n "$http_proxy_val" ] && [ -n "$major" ] && [ -n "$minor" ] && \
       { [ "$major" -lt 4 ] || { [ "$major" -eq 4 ] && [ "$minor" -lt 22 ]; }; }; then
        print_step "Detected OCP $ocp_version behind a corporate proxy -- applying proxy-aware gateway-resources ConfigMap..."
        https_proxy_val=$(oc get proxy/cluster -o jsonpath='{.spec.httpsProxy}' 2>/dev/null)
        no_proxy_val=$(oc get proxy/cluster -o jsonpath='{.spec.noProxy}' 2>/dev/null)
        export HTTP_PROXY="$http_proxy_val" HTTPS_PROXY="$https_proxy_val" NO_PROXY="$no_proxy_val"
        envsubst '${HTTP_PROXY} ${HTTPS_PROXY} ${NO_PROXY}' \
            < "$ROOT_DIR/lib/manifests/rhcl/gateway-resources-proxy.yaml.tmpl" | oc apply -f -
        unset HTTP_PROXY HTTPS_PROXY NO_PROXY
        print_success "Proxy-aware gateway-resources ConfigMap applied (OCPBUGS-77457 workaround)"
    else
        print_step "Applying gateway-resources ConfigMap (2Gi memory, prevents BU Issue 5/6 OOM)..."
        oc apply -f "$ROOT_DIR/lib/manifests/rhcl/gateway-resources.yaml"
    fi
}

# Phase 2: GatewayClass + Gateway + gateway-resources ConfigMap + namespace labels
phase2_gateway() {
    print_header "Phase 2: Gateway + Namespace Labels"

    if [ "$HAS_GATEWAY" = true ]; then
        print_success "Gateway already Programmed -- checking namespace labels only"
    else
        print_step "Creating GatewayClass..."
        oc apply -f "$ROOT_DIR/lib/manifests/rhcl/gatewayclass-gateway-controller.yaml"

        apply_gateway_resources_configmap

        print_step "Creating MaaS Gateway..."
        local cert_name
        cert_name=$(oc get ingresscontroller default -n openshift-ingress-operator \
            -o jsonpath='{.spec.defaultCertificate.name}' 2>/dev/null)
        cert_name="${cert_name:-router-certs-default}"
        export CLUSTER_DOMAIN CERT_NAME="$cert_name"
        envsubst '${CLUSTER_DOMAIN} ${CERT_NAME}' \
            < "$ROOT_DIR/lib/manifests/rhcl/gateway-maas.yaml" | oc apply -f -

        print_step "Waiting for Gateway to be Programmed..."
        local elapsed=0
        until oc get gateway maas-default-gateway -n openshift-ingress \
            -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null | grep -q True; do
            if [ $elapsed -ge 180 ]; then
                print_warning "Timeout waiting for Gateway Programmed -- continuing anyway"
                break
            fi
            sleep 10
            elapsed=$((elapsed + 10))
        done
        print_success "Gateway created"
    fi

    # REQUIRED (not just preventive): lib/manifests/rhcl/gateway-maas.yaml uses
    # `from: Selector` to restrict route binding to labeled namespaces (BU Issue 3
    # hardening, matches the BU MaaS guide). Without this label, HTTPRoutes in
    # these namespaces -- including maas-api's own route -- are rejected with
    # "namespace is not allowed by the parent".
    print_step "Labeling namespaces for gateway access (required for Selector-based routing)..."
    local infra_ns
    infra_ns=$(get_maas_infra_namespace 2>/dev/null || echo "redhat-ods-applications")
    for ns in redhat-ods-applications "$infra_ns" models-as-a-service; do
        oc get namespace "$ns" &>/dev/null && \
            oc label namespace "$ns" maas.opendatahub.io/gateway-access=true --overwrite 2>/dev/null || true
    done

    print_success "Phase 2 complete: Gateway + namespace labels"
}

# Phase 3: PostgreSQL platform (version-aware namespace)
phase3_postgres() {
    print_header "Phase 3: MaaS Platform (PostgreSQL)"

    local infra_ns
    infra_ns=$(get_maas_infra_namespace 2>/dev/null || echo "redhat-ods-applications")

    if [ "$HAS_POSTGRES" = true ]; then
        print_success "maas-db-config secret already exists in $infra_ns -- skipping"
        return 0
    fi

    print_step "Ensuring infrastructure namespace '$infra_ns' exists..."
    oc create namespace "$infra_ns" 2>/dev/null || true

    print_step "Deploying PostgreSQL platform manifests..."
    oc apply -n "$infra_ns" -f "$ROOT_DIR/lib/manifests/maas/platform/postgres-pvc.yaml"
    oc apply -n "$infra_ns" -f "$ROOT_DIR/lib/manifests/maas/platform/postgres-service.yaml"

    local pg_user="maas" pg_db="maas"
    local pg_password
    pg_password=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)
    local pg_image="registry.redhat.io/rhel9/postgresql-16:latest"

    export PG_IMAGE="$pg_image" PG_USER="$pg_user" PG_PASSWORD="$pg_password" PG_DB="$pg_db"
    envsubst '${PG_IMAGE} ${PG_USER} ${PG_PASSWORD} ${PG_DB}' \
        < "$ROOT_DIR/lib/manifests/maas/platform/postgres-deployment.yaml" | oc apply -n "$infra_ns" -f -
    unset PG_PASSWORD

    print_step "Waiting for PostgreSQL to be ready..."
    oc rollout status deployment/postgres -n "$infra_ns" --timeout=120s 2>/dev/null || true

    local encoded_password
    encoded_password=$(printf '%s' "$pg_password" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
    local db_url="postgresql://${pg_user}:${encoded_password}@postgres.${infra_ns}.svc.cluster.local:5432/${pg_db}?sslmode=disable"

    print_step "Creating maas-db-config secret in $infra_ns..."
    printf '%s' "$db_url" | oc create secret generic maas-db-config \
        --from-file=DB_CONNECTION_URL=/dev/stdin --dry-run=client -o yaml | \
        oc apply -n "$infra_ns" -f -

    oc create secret generic postgres-creds \
        --from-literal=user="$pg_user" --from-literal=password="$pg_password" --from-literal=database="$pg_db" \
        -n "$infra_ns" --dry-run=client -o yaml | oc apply -n "$infra_ns" -f -

    print_success "Phase 3 complete: PostgreSQL deployed in $infra_ns"
}

# Phase 4: Enable MaaS in DSC (version-branched) + dashboard flags
phase4_dsc() {
    print_header "Phase 4: Enable MaaS in DataScienceCluster"

    if [ "$HAS_MAAS_ENABLED" = true ]; then
        print_success "MaaS already enabled in DataScienceCluster -- skipping"
    elif is_rhoai_35_or_higher; then
        print_step "Enabling aigateway.modelsAsAService (RHOAI 3.5+ path)..."
        oc patch datasciencecluster default-dsc --type=merge -p '{
            "spec": { "components": { "aigateway": { "managementState": "Managed",
                "modelsAsAService": { "managementState": "Managed" } } } }
        }'
        print_success "aigateway.modelsAsAService enabled"
    else
        print_step "Enabling kserve.modelsAsService (RHOAI 3.4 path)..."
        oc patch datasciencecluster default-dsc --type=merge -p '{
            "spec": { "components": { "kserve": {
                "modelsAsService": { "managementState": "Managed" } } } }
        }'
        print_success "kserve.modelsAsService enabled"
    fi

    print_step "Waiting for DataScienceCluster to reconcile..."
    sleep 30

    print_step "Setting dashboard flags..."
    if is_rhoai_35_or_higher; then
        # maasAuthPolicies is REMOVED in 3.5 -- the admission webhook rejects it.
        oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
            --type=merge -p '{"spec":{"dashboardConfig":{"modelAsService":true,"genAiStudio":true}}}' 2>/dev/null || \
            print_warning "Could not patch dashboard config"
    else
        oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
            --type=merge -p '{"spec":{"dashboardConfig":{"modelAsService":true,"genAiStudio":true,"maasAuthPolicies":true}}}' 2>/dev/null || \
            print_warning "Could not patch dashboard config"
    fi
    print_success "Phase 4 complete: MaaS enabled + dashboard flags set"
}

# Phase 5: Verify
phase5_verify() {
    print_header "Phase 5: Verify"

    local infra_ns
    infra_ns=$(get_maas_infra_namespace 2>/dev/null || echo "redhat-ods-applications")

    print_step "Waiting for maas-api deployment in $infra_ns..."
    local elapsed=0
    until oc get deployment maas-api -n "$infra_ns" &>/dev/null; do
        [ $elapsed -ge 120 ] && { print_warning "maas-api deployment not found yet -- may still be starting"; break; }
        sleep 10
        elapsed=$((elapsed + 10))
    done
    oc rollout status deployment/maas-api -n "$infra_ns" --timeout=120s 2>/dev/null || \
        print_warning "maas-api not rolled out yet"

    print_step "Checking MaaS health endpoint..."
    local health
    health=$(curl -sk "https://maas.${CLUSTER_DOMAIN}/maas-api/health" 2>/dev/null)
    if echo "$health" | grep -q "healthy"; then
        print_success "MaaS API health: $health"
    else
        print_warning "MaaS API health check inconclusive: ${health:-no response}"
    fi

    print_success "Phase 5 complete: verification done"

    if [ "$RUN_DIAGNOSE" = true ]; then
        print_step "Running full diagnostic (scripts/diagnose-maas.sh)..."
        bash "$SCRIPT_DIR/diagnose-maas.sh" || true
    fi
}

setup_maas_34_plus() {
    print_header "Setting up MaaS for RHOAI $(is_rhoai_35_or_higher && echo '3.5+' || echo '3.4')"
    detect_maas_state

    [ "$FROM_PHASE" -le 1 ] && phase1_rhcl
    [ "$FROM_PHASE" -le 2 ] && phase2_gateway
    [ "$FROM_PHASE" -le 3 ] && phase3_postgres
    [ "$FROM_PHASE" -le 4 ] && phase4_dsc

    if [ "$ENABLE_REDIS" = true ]; then
        setup_redis_limitador
    fi

    [ "$FROM_PHASE" -le 5 ] && phase5_verify

    display_usage_instructions_34_plus
}

display_usage_instructions_34_plus() {
    print_header "MaaS Setup Complete!"

    local infra_ns
    infra_ns=$(get_maas_infra_namespace 2>/dev/null || echo "redhat-ods-applications")

    echo -e "${GREEN}✓ Model as a Service (MaaS) has been enabled!${NC}"
    echo ""
    echo "MaaS endpoint:        https://maas.${CLUSTER_DOMAIN}"
    echo "maas-api namespace:   $infra_ns"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Deploy a model:      ./scripts/deploy-maas-model.sh --model auto"
    echo "  2. Verify end-to-end:   ./scripts/verify-maas.sh"
    echo "  3. Diagnose issues:     ./scripts/diagnose-maas.sh --fix"
    echo ""
}

################################################################################
# RHOAI 3.3 Integrated (Legacy Tech Preview) MaaS Setup
################################################################################

setup_maas_33() {
    print_header "Setting up MaaS for RHOAI 3.3 (Tech Preview, tier-based)"

    echo -e "${CYAN}RHOAI 3.3 uses integrated MaaS via the DataScienceCluster.${NC}"
    echo ""

    approve_servicemesh_installplans
    install_rhcl_operator_33
    enable_maas_in_dsc_33
    create_inference_gateway_33
    enable_dashboard_maas_features_33
    restart_controllers_33
    display_usage_instructions_33
}

install_rhcl_operator_33() {
    print_header "Step 1: Installing RHCL (Kuadrant) Operator"

    if oc get namespace kuadrant-system &>/dev/null; then
        print_success "kuadrant-system namespace already exists"
    else
        oc create namespace kuadrant-system
    fi

    if oc get csv -n kuadrant-system 2>/dev/null | grep -q "rhcl-operator"; then
        print_success "RHCL Operator already installed"
    else
        oc apply -f "$ROOT_DIR/lib/manifests/rhcl/rhcl-operator.yaml" 2>/dev/null || cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: kuadrant-system
  namespace: kuadrant-system
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhcl-operator
  namespace: kuadrant-system
spec:
  channel: stable
  installPlanApproval: Automatic
  name: rhcl-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
        print_step "Waiting for RHCL operator to be ready..."
        local elapsed=0
        until oc get crd kuadrants.kuadrant.io &>/dev/null; do
            [ $elapsed -ge 300 ] && { print_error "Timeout waiting for RHCL operator CRDs"; return 1; }
            sleep 10
            elapsed=$((elapsed + 10))
        done
        print_success "RHCL Operator is ready"
    fi

    if oc get kuadrant kuadrant -n kuadrant-system &>/dev/null; then
        print_success "Kuadrant instance already exists"
    else
        oc apply -f "$ROOT_DIR/lib/manifests/rhcl/kuadrant-instance.yaml"
        print_step "Waiting for Authorino service..."
        local auth_elapsed=0
        until oc get svc/authorino-authorino-authorization -n kuadrant-system &>/dev/null; do
            [ $auth_elapsed -ge 120 ] && { print_warning "Timeout waiting for Authorino service"; break; }
            sleep 10
            auth_elapsed=$((auth_elapsed + 10))
        done
    fi

    print_step "Creating Authorino TLS certificate (cert-manager, 3.3 method)..."
    if ! oc get secret authorino-server-cert -n kuadrant-system &>/dev/null; then
        cat <<'CERTEOF' | oc apply -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: authorino-selfsigned
  namespace: kuadrant-system
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: authorino-server-cert
  namespace: kuadrant-system
spec:
  secretName: authorino-server-cert
  isCA: false
  duration: 8760h
  renewBefore: 720h
  issuerRef:
    name: authorino-selfsigned
    kind: Issuer
  commonName: authorino-authorino
  dnsNames:
    - authorino-authorino
    - authorino-authorino.kuadrant-system
    - authorino-authorino.kuadrant-system.svc
    - authorino-authorino.kuadrant-system.svc.cluster.local
  usages:
    - server auth
CERTEOF
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/rhcl/authorino-tls.yaml"
    oc annotate svc/authorino-authorino-authorization \
        service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
        -n kuadrant-system --overwrite 2>/dev/null || true

    print_success "RHCL + Authorino TLS configured"
}

enable_maas_in_dsc_33() {
    print_header "Step 2: Enabling MaaS in DataScienceCluster"

    local current_state
    current_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.kserve.modelsAsService.managementState}' 2>/dev/null)

    if [ "$current_state" = "Managed" ]; then
        print_success "MaaS already enabled in DataScienceCluster"
    else
        oc patch datasciencecluster default-dsc --type=merge -p '{
            "spec": { "components": { "kserve": {
                "modelsAsService": { "managementState": "Managed" } } } }
        }'
        print_success "MaaS enabled in DataScienceCluster"
        sleep 30
    fi
}

create_inference_gateway_33() {
    print_header "Step 3: Creating Inference Gateway"

    if oc get gatewayclass openshift-ai-inference &>/dev/null; then
        print_success "GatewayClass 'openshift-ai-inference' already exists"
    else
        oc apply -f "$ROOT_DIR/lib/manifests/rhcl/gatewayclass-ai-inference.yaml" 2>/dev/null || cat <<EOF | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-ai-inference
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
    fi

    local gateway_hostname="inference-gateway.${CLUSTER_DOMAIN}"
    if oc get gateway openshift-ai-inference -n openshift-ingress &>/dev/null; then
        print_success "Gateway 'openshift-ai-inference' already exists"
    else
        cat <<EOF | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/rev: openshift-gateway
  name: openshift-ai-inference
  namespace: openshift-ingress
spec:
  gatewayClassName: openshift-ai-inference
  listeners:
    - allowedRoutes:
        namespaces:
          from: All
      hostname: ${gateway_hostname}
      name: https
      port: 443
      protocol: HTTPS
      tls:
        certificateRefs:
          - group: ''
            kind: Secret
            name: default-gateway-tls
        mode: Terminate
EOF
        print_success "Gateway 'openshift-ai-inference' created"
    fi
}

enable_dashboard_maas_features_33() {
    print_header "Step 4: Enabling Dashboard MaaS Features"
    oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge -p '{
        "spec": { "dashboardConfig": {
            "disableModelRegistry": false, "disableModelCatalog": false,
            "disableKServeMetrics": false, "genAiStudio": true,
            "modelAsService": true, "disableLMEval": false
        } }
    }' 2>/dev/null || print_warning "Could not patch dashboard config"
    print_success "Dashboard features enabled"
}

restart_controllers_33() {
    print_header "Step 5: Restarting Controllers"
    oc delete pod -n redhat-ods-applications -l app=odh-model-controller --ignore-not-found=true
    oc delete pod -n redhat-ods-applications -l control-plane=kserve-controller-manager --ignore-not-found=true
    sleep 10
    print_success "Controllers restarted"
}

display_usage_instructions_33() {
    print_header "MaaS Setup Complete! (RHOAI 3.3)"
    echo "MaaS endpoint:     https://maas.${CLUSTER_DOMAIN}"
    echo "Inference Gateway: https://inference-gateway.${CLUSTER_DOMAIN}"
    echo ""
    echo "Deploy a model: RHOAI Dashboard -> Models -> Deploy Model -> llm-d runtime"
    echo "  Check 'Enable Model as a Service' + 'Require authentication'"
}

################################################################################
# RHOAI 3.2 and Earlier - Legacy MaaS Setup
################################################################################

setup_maas_legacy() {
    print_header "Setting up MaaS for RHOAI 3.2 and Earlier (Legacy)"

    if ! command -v kustomize &> /dev/null; then
        print_error "kustomize not found. Install with: brew install kustomize"
        exit 1
    fi

    local maas_enabled
    maas_enabled=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications -o jsonpath='{.spec.dashboardConfig.modelAsService}' 2>/dev/null)
    if [ "$maas_enabled" != "true" ]; then
        oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
            --type=merge -p '{"spec": {"dashboardConfig": {"modelAsService": true, "genAiStudio": true}}}' 2>/dev/null || true
    fi

    oc create namespace maas-api 2>/dev/null || true
    export CLUSTER_DOMAIN
    oc apply --server-side=true \
        -f <(kustomize build "https://github.com/opendatahub-io/maas-billing.git/deployment/overlays/openshift?ref=main" | \
             envsubst '$CLUSTER_DOMAIN')

    print_step "Waiting for MaaS API pods..."
    sleep 10
    oc wait --for=condition=ready pod -l app=maas-api -n maas-api --timeout=300s || true

    print_success "Legacy MaaS infrastructure deployed"
    echo "MaaS URL: https://maas.${CLUSTER_DOMAIN}/maas-api/v1/..."
}

################################################################################
# Main execution
################################################################################

main() {
    print_header "Model as a Service (MaaS) Setup"

    check_common_prerequisites

    echo ""
    if is_rhoai_34_or_higher; then
        setup_maas_34_plus
    elif is_rhoai_33_or_higher; then
        setup_maas_33
    else
        setup_maas_legacy
    fi
}

main
