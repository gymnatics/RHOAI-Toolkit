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
#   ./scripts/setup-maas.sh                      # full setup, auto-detects version
#   ./scripts/setup-maas.sh --from-phase 3       # resume from a specific phase (3.4+ only)
#   ./scripts/setup-maas.sh --diagnose           # run scripts/diagnose-maas.sh after setup
#   ./scripts/setup-maas.sh --enable-redis       # + Redis for Limitador persistence
#   ./scripts/setup-maas.sh --enable-observability  # + DSCI monitoring (metrics/tracing)
#
# Phases (RHOAI 3.4+):
#   1. RHCL operator + Kuadrant + Authorino TLS + User Workload Monitoring (required,
#      matches the BU MaaS guide's Phase 2 -- Prometheus needs UWM to scrape
#      MaaS/Kuadrant metrics)
#   2. GatewayClass + Gateway + gateway-resources ConfigMap + namespace labels + AUTH_SERVICE_TIMEOUT
#   3. PostgreSQL platform (lib/manifests/maas/platform/) + secrets
#   4. Enable MaaS in DataScienceCluster (version-branched DSC field) + dashboard flags
#      [optional] Redis for Limitador persistence (--enable-redis)
#      [optional] DSCI monitoring metrics/tracing (--enable-observability)
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
source "$ROOT_DIR/lib/functions/metallb.sh" 2>/dev/null || true
source "$ROOT_DIR/lib/functions/usage-logging.sh" 2>/dev/null || true
source "$ROOT_DIR/lib/functions/rhcl-install.sh" 2>/dev/null || true

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

CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-}"
FROM_PHASE=1
TO_PHASE=5
RUN_DIAGNOSE=false
ENABLE_REDIS=false
ENABLE_OBSERVABILITY=false
ENABLE_USAGE_LOGGING=false
CALLED_FROM_INSTALLER=false
POSTGRES_CONNECTION="${POSTGRES_CONNECTION:-}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --from-phase) FROM_PHASE="$2"; shift 2 ;;
        --to-phase) TO_PHASE="$2"; shift 2 ;;
        --called-from-installer) CALLED_FROM_INSTALLER=true; shift ;;
        --rhoai-version)
            # Explicit version override for the pre-RHOAI installer call (phases
            # 1-2 run before the DataScienceCluster exists, so detect_rhoai_version's
            # cluster-state detection has nothing to inspect yet). install-rhoai-34.sh
            # and install-rhoai-35.sh already know their own target version.
            case "$2" in
                3.5|3.5.x) RHOAI_VERSION="3.5.x"; RHOAI_MAJOR_VERSION="3"; RHOAI_MINOR_VERSION="5" ;;
                3.4|3.4.x) RHOAI_VERSION="3.4.x"; RHOAI_MAJOR_VERSION="3"; RHOAI_MINOR_VERSION="4" ;;
                *) echo "Unsupported --rhoai-version: $2 (expected 3.4 or 3.5)"; exit 1 ;;
            esac
            shift 2
            ;;
        --diagnose) RUN_DIAGNOSE=true; shift ;;
        --enable-redis) ENABLE_REDIS=true; shift ;;
        --enable-observability) ENABLE_OBSERVABILITY=true; shift ;;
        --enable-usage-logging) ENABLE_USAGE_LOGGING=true; shift ;;
        --postgres-connection) POSTGRES_CONNECTION="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--from-phase N] [--to-phase N] [--diagnose] [--enable-redis] [--enable-observability] [--enable-usage-logging] [--postgres-connection URL]"
            echo "  --from-phase N          Resume from phase N (1-5, RHOAI 3.4+ only)"
            echo "  --to-phase N            Stop after phase N (1-5, RHOAI 3.4+ only, default 5)"
            echo "  --called-from-installer Internal flag used by install-rhoai-34.sh/install-rhoai-35.sh"
            echo "                          to delegate MaaS setup to this script. Skips prerequisite"
            echo "                          checks and final usage banner (caller handles both); reuses"
            echo "                          CLUSTER_DOMAIN/RHOAI_VERSION env vars if already exported."
            echo "  --rhoai-version X.Y     Explicit RHOAI version (3.4 or 3.5) -- used by the installers'"
            echo "                          pre-RHOAI call (phases 1-2), before RHOAI/DSC exist on the"
            echo "                          cluster for auto-detection to inspect."
            echo "  --diagnose              Run scripts/diagnose-maas.sh after setup"
            echo "  --enable-redis          Deploy Redis for Limitador rate-limit counter"
            echo "                          persistence (survives Limitador pod restarts)"
            echo "  --enable-observability  Configure DSCI monitoring (metrics + tracing)."
            echo "                          Requires Tempo/OpenTelemetry/COO operators --"
            echo "                          use scripts/install-rhoai-35.sh for the full"
            echo "                          observability stack (Perses dashboards, Grafana)."
            echo "  --enable-usage-logging  Enable log-based MaaS usage dashboards (RHOAI 3.5+"
            echo "                          only -- Loki Operator + MinIO/S3 + LokiStack, for"
            echo "                          per-request token/user tracking)."
            echo "  --postgres-connection URL  Use an existing PostgreSQL instance instead of"
            echo "                          deploying the POC PostgreSQL (phase 3)."
            exit 0
            ;;
        *) shift ;;
    esac
done

################################################################################
# Prerequisites Check (Common)
################################################################################

check_common_prerequisites() {
    if [ "$CALLED_FROM_INSTALLER" = true ]; then
        # Caller (install-rhoai-34.sh / install-rhoai-35.sh) already verified oc
        # login and RHOAI installation, and typically exports CLUSTER_DOMAIN before
        # calling this script. detect_rhoai_version() is a no-op if RHOAI_VERSION
        # is already set (also commonly pre-exported by the caller).
        detect_rhoai_version
        if [ -z "$CLUSTER_DOMAIN" ]; then
            CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null | sed 's/^apps\.//')
        fi
        return 0
    fi

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
    CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null | sed 's/^apps\.//')
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

# Phase 1: RHCL operator + Kuadrant + Istio + Authorino TLS
phase1_rhcl() {
    print_header "Phase 1: RHCL Operator + Kuadrant + Istio + Authorino TLS"

    if [ "$HAS_RHCL" = true ] && [ "$HAS_KUADRANT" = true ]; then
        print_success "RHCL + Kuadrant already installed and Ready -- skipping"
        return 0
    fi

    # Service Mesh 3 (Sail) is an OLM dependency of RHCL, and Kuadrant needs a
    # working Istio/Gateway-API stack to become Ready. install_servicemesh_operator
    # and setup_istio_for_kuadrant (lib/functions/rhcl-install.sh) also carry a
    # fix for a real OCP 4.20 bug: the ingress operator ships an EOL ISTIO_VERSION
    # that Service Mesh 3.4.0+ no longer supports, which breaks GatewayClass
    # reconciliation for the gateways created in phase2_gateway.
    if [ "$HAS_RHCL" != true ]; then
        install_servicemesh_operator
    fi

    if [ "$HAS_RHCL" != true ]; then
        print_step "Installing RHCL operator..."
        if is_rhoai_35_or_higher; then
            oc apply -f "$ROOT_DIR/lib/manifests/rhcl/rhcl-operator-35.yaml"
        else
            oc apply -f "$ROOT_DIR/lib/manifests/rhcl/rhcl-operator-34.yaml"
        fi

        # Auto-approve RHCL InstallPlan (OLM may set Manual even with Automatic
        # when dependency operators like Authorino/DNS/Limitador are being
        # upgraded; the 3.4 manifest also pins Manual explicitly to avoid the
        # broken 1.4.0 release).
        print_step "Waiting for RHCL InstallPlan..."
        local ip_wait=0
        while [ $ip_wait -lt 60 ]; do
            oc get subscription rhcl-operator -n openshift-operators \
                -o jsonpath='{.status.installPlanRef.name}' 2>/dev/null | grep -q . && break
            sleep 5
            ip_wait=$((ip_wait + 5))
        done
        approve_rhcl_installplans

        print_step "Waiting for RHCL operator CSV to succeed (this may take a few minutes)..."
        local elapsed=0
        until oc get csv -n openshift-operators 2>/dev/null | grep -q "rhcl-operator.*Succeeded"; do
            if [ $elapsed -ge 300 ]; then
                print_warning "Timeout waiting for RHCL CSV -- continuing anyway"
                break
            fi
            approve_rhcl_installplans 2>/dev/null || true
            sleep 10
            elapsed=$((elapsed + 10))
        done
        print_success "RHCL operator installed"

        print_step "Verifying RHCL component operators (Authorino, DNS, Limitador)..."
        local comp_elapsed=0
        while [ $comp_elapsed -lt 120 ]; do
            local all_found=true
            for component in "authorino" "dns" "limitador"; do
                oc get csv -n openshift-operators 2>/dev/null | grep -qi "$component.*Succeeded" || all_found=false
            done
            [ "$all_found" = true ] && break
            sleep 10
            comp_elapsed=$((comp_elapsed + 10))
        done
        for component in "authorino" "dns" "limitador"; do
            if oc get csv -n openshift-operators 2>/dev/null | grep -qi "$component.*Succeeded"; then
                print_success "  $component operator ready"
            else
                print_info "  $component operator not yet ready (may take a moment)"
            fi
        done
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

        setup_istio_for_kuadrant
        restart_kuadrant_operator
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

    print_step "Waiting for Authorino deployment to be Available..."
    oc wait --for=condition=Available deployment/authorino -n kuadrant-system --timeout=300s 2>/dev/null || \
        print_warning "Authorino deployment not yet Available -- continuing anyway"

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
# User Workload Monitoring -- REQUIRED per the BU MaaS guide's Phase 2 (not just
# recommended): Prometheus needs UWM enabled to scrape MaaS/Kuadrant metrics from
# user namespaces. Without it, Kuadrant's `observability.enable: true` (set on the
# Kuadrant CR in phase1_rhcl) has nothing to feed. Idempotent -- safe to re-run.
enable_user_workload_monitoring() {
    print_step "Enabling User Workload Monitoring (required for MaaS/Kuadrant metrics)..."

    if oc get deployment prometheus-operator -n openshift-user-workload-monitoring &>/dev/null; then
        print_success "User Workload Monitoring already enabled"
        return 0
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/monitoring/cluster-monitoring-config.yaml"

    print_step "Waiting for User Workload Monitoring stack to start..."
    oc wait --for=condition=Available deployment/prometheus-operator \
        -n openshift-user-workload-monitoring --timeout=300s 2>/dev/null || \
        print_warning "Timeout waiting for prometheus-operator -- it may still be starting"

    print_success "User Workload Monitoring enabled"
}

# DSCI monitoring (metrics + tracing) -- optional (BU guide Phase 7). Triggers the
# RHOAI operator's observability cascade (MonitoringStack, ThanosQuerier, Perses,
# tracing). Requires the Tempo/OpenTelemetry/COO operators to actually reconcile --
# use scripts/install-rhoai-35.sh --enable-observability for those plus Perses
# dashboards. This function only sets the DSCI field; it does not install operators.
configure_dsci_monitoring() {
    print_step "Configuring DSCI monitoring (metrics + tracing)..."

    local dsci_metrics
    dsci_metrics=$(oc get dsci default-dsci -o jsonpath='{.spec.monitoring.metrics.replicas}' 2>/dev/null)
    if [ -n "$dsci_metrics" ] && [ "$dsci_metrics" != "null" ]; then
        print_info "DSCI monitoring already configured (replicas=$dsci_metrics)"
        return 0
    fi

    oc patch dsci default-dsci --type=merge -p '{
        "spec": {
            "monitoring": {
                "namespace": "redhat-ods-monitoring",
                "metrics": {
                    "replicas": 1,
                    "storage": {
                        "size": "5Gi",
                        "retention": "90d"
                    }
                },
                "traces": {
                    "sampleRatio": "0.1",
                    "storage": {
                        "backend": "pv",
                        "retention": "2160h"
                    }
                }
            }
        }
    }' 2>/dev/null && print_success "DSCI monitoring configured" || \
        print_warning "Could not configure DSCI monitoring"

    oc wait --for=jsonpath='{.status.phase}'=Ready dsci/default-dsci --timeout=120s 2>/dev/null || true
}

phase2_gateway() {
    print_header "Phase 2: Gateway + Namespace Labels"

    # Non-cloud platforms (BareMetal, OpenStack, None/SNO) have no cloud LB
    # controller to provision the Gateway's LoadBalancer Service external IP --
    # without MetalLB, the Gateway never reaches Programmed=True. No-op on cloud.
    setup_metallb_if_needed

    if [ "$HAS_GATEWAY" = true ]; then
        print_success "Gateway already Programmed -- checking namespace labels only"
    else
        print_step "Creating GatewayClass..."
        oc apply -f "$ROOT_DIR/lib/manifests/rhcl/gatewayclass-gateway-controller.yaml"

        apply_gateway_resources_configmap

        print_step "Creating MaaS Gateway..."
        local cert_name
        # Prefer a dedicated "default-gateway-tls" secret if one already exists
        # (e.g. created by install-rhoai-34.sh/install-rhoai-35.sh's
        # create_gateway_tls_secret() before delegating here) -- it's shared with
        # the non-MaaS openshift-ai-inference gateway. Otherwise fall back to
        # whatever certificate the IngressController is already using.
        if oc get secret default-gateway-tls -n openshift-ingress &>/dev/null; then
            cert_name="default-gateway-tls"
        else
            cert_name=$(oc get ingresscontroller default -n openshift-ingress-operator \
                -o jsonpath='{.spec.defaultCertificate.name}' 2>/dev/null)
            cert_name="${cert_name:-router-certs-default}"
        fi
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

    # Bridge *.apps.<cluster> wildcard DNS (OpenShift Router) to the gateway's own
    # LoadBalancer Service. Required on non-cloud platforms; harmless/idempotent
    # elsewhere -- confirmed working this way on live AWS test clusters.
    if ! oc get route maas-default-gateway-passthrough -n openshift-ingress &>/dev/null; then
        print_step "Creating passthrough route for maas-default-gateway..."
        local svc_name
        svc_name=$(oc get svc -n openshift-ingress -l "gateway.networking.k8s.io/gateway-name=maas-default-gateway" \
            -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        if [ -n "$svc_name" ]; then
            export ROUTE_NAME="maas-default-gateway-passthrough"
            export HOSTNAME="maas.apps.${CLUSTER_DOMAIN}"
            export SERVICE_NAME="$svc_name"
            envsubst '${ROUTE_NAME} ${HOSTNAME} ${SERVICE_NAME}' \
                < "$ROOT_DIR/lib/manifests/rhcl/gateway-passthrough-route.yaml" | oc apply -f -
            print_success "Passthrough route created"
        else
            print_warning "No service found for maas-default-gateway yet -- skipping passthrough route (retry later)"
        fi
    else
        print_success "Passthrough route already exists"
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

    # If the caller (or user) provided an existing PostgreSQL connection string,
    # use it directly instead of deploying the POC PostgreSQL below.
    if [ -n "$POSTGRES_CONNECTION" ]; then
        print_step "Creating maas-db-config secret from provided connection string..."
        printf '%s' "$POSTGRES_CONNECTION" | oc create secret generic maas-db-config \
            --from-file=DB_CONNECTION_URL=/dev/stdin --dry-run=client -o yaml | \
            oc label --local -f - app=maas-api --dry-run=client -o yaml | \
            oc apply -n "$infra_ns" -f -
        print_success "Phase 3 complete: maas-db-config created from provided connection string"
        return 0
    fi

    print_step "Deploying PostgreSQL platform manifests..."
    oc apply -n "$infra_ns" -f "$ROOT_DIR/lib/manifests/maas/platform/postgres-pvc.yaml"
    oc apply -n "$infra_ns" -f "$ROOT_DIR/lib/manifests/maas/platform/postgres-service.yaml"

    local pg_user="maas" pg_db="maas"
    local pg_password
    pg_password=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)

    # Resolve PostgreSQL image from the RHOAI operator CSV (fallback to default)
    local pg_image
    pg_image=$(oc get csv -l 'olm.copiedFrom=redhat-ods-operator' \
        -o jsonpath='{.items[0].spec.relatedImages[?(@.name=="postgresql_16_image")].image}' 2>/dev/null) || true
    if [ -z "$pg_image" ]; then
        pg_image="registry.redhat.io/rhel9/postgresql-16:latest"
    fi

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
        oc label --local -f - app=maas-api --dry-run=client -o yaml | \
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
# Phase 5: Verify (version-aware; this is the single source of truth for MaaS
# post-install verification -- previously duplicated as install-rhoai-35.sh's
# verify_maas_deployment() [3.5-specific: ModelsAsAServiceReady/MaasTenantConfig/
# redhat-ai-gateway-infra] and install-rhoai-34.sh's verify_maas_deployment()
# [3.4-specific: ModelsAsServiceReady/Tenant/redhat-ods-applications]).
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

    if is_rhoai_35_or_higher; then
        # RHOAI 3.5: Check ModelsAsAServiceReady DSC condition (note: "AsA" not "As")
        local maas_ready maas_msg
        maas_ready=$(oc get datasciencecluster default-dsc \
            -o jsonpath='{.status.conditions[?(@.type=="ModelsAsAServiceReady")].status}' 2>/dev/null)
        maas_msg=$(oc get datasciencecluster default-dsc \
            -o jsonpath='{.status.conditions[?(@.type=="ModelsAsAServiceReady")].message}' 2>/dev/null)
        if [ "$maas_ready" = "True" ]; then
            print_success "ModelsAsAServiceReady is True"
        elif [ -n "$maas_ready" ]; then
            print_warning "ModelsAsAServiceReady is $maas_ready"
            [ -n "$maas_msg" ] && print_info "  Message: $maas_msg"
        else
            print_info "ModelsAsAServiceReady condition not found yet (controller may still be starting)"
        fi

        local maas_crds
        maas_crds=$(oc get crd 2>/dev/null | grep -c "maas.opendatahub.io" || echo "0")
        if [ "$maas_crds" -ge 5 ]; then
            print_success "MaaS CRDs installed ($maas_crds found)"
        else
            print_warning "MaaS CRDs not fully installed yet ($maas_crds found, expected 5+)"
        fi

        local tenant_ready
        tenant_ready=$(oc get maastenantconfig default-tenant -n models-as-a-service \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$tenant_ready" = "True" ]; then
            print_success "MaasTenantConfig 'default-tenant' is Ready"
        elif [ -n "$tenant_ready" ]; then
            local tenant_msg
            tenant_msg=$(oc get maastenantconfig default-tenant -n models-as-a-service \
                -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
            print_warning "MaasTenantConfig not ready yet: $tenant_msg"
        else
            print_info "MaasTenantConfig not found yet (it will be auto-created by the MaaS controller)"
        fi

        local telemetry_enabled
        telemetry_enabled=$(oc get maastenantconfig default-tenant -n models-as-a-service \
            -o jsonpath='{.spec.telemetry.enabled}' 2>/dev/null)
        if [ "$telemetry_enabled" = "true" ]; then
            print_success "MaaS telemetry is enabled"
        else
            print_info "MaaS telemetry not enabled (optional -- see configure_maas_telemetry in the installers)"
        fi
    else
        # RHOAI 3.4: Tenant CRD (not MaasTenantConfig), fewer CRDs expected
        local maas_crds
        maas_crds=$(oc get crd 2>/dev/null | grep -c "maas.opendatahub.io" || echo "0")
        if [ "$maas_crds" -ge 3 ]; then
            print_success "MaaS CRDs installed ($maas_crds found)"
        else
            print_warning "MaaS CRDs not fully installed yet ($maas_crds found, expected 3+)"
        fi

        local tenant_ready
        tenant_ready=$(oc get tenant default-tenant -n models-as-a-service \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$tenant_ready" = "True" ]; then
            print_success "MaaS Tenant 'default-tenant' is Ready"
        elif [ -n "$tenant_ready" ]; then
            local tenant_msg
            tenant_msg=$(oc get tenant default-tenant -n models-as-a-service \
                -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
            print_warning "MaaS Tenant not ready yet: $tenant_msg"
        else
            print_info "MaaS Tenant not found yet (it will be auto-created by the MaaS controller)"
        fi
    fi

    print_step "Checking maas-db-config secret in $infra_ns..."
    if oc get secret maas-db-config -n "$infra_ns" &>/dev/null; then
        local has_url
        has_url=$(oc get secret maas-db-config -n "$infra_ns" -o jsonpath='{.data.DB_CONNECTION_URL}' 2>/dev/null)
        if [ -n "$has_url" ]; then
            print_success "maas-db-config secret exists with DB_CONNECTION_URL in $infra_ns"
        else
            print_warning "maas-db-config secret exists but may be missing DB_CONNECTION_URL key"
        fi
    else
        print_warning "maas-db-config secret NOT found in $infra_ns -- MaaS Tenant will show Degraded"
    fi

    print_step "Checking MaaS deployments..."
    for deploy_spec in "maas-api:$infra_ns" "maas-controller:redhat-ods-applications" "ai-gateway-operator:redhat-ods-applications"; do
        local deploy="${deploy_spec%%:*}"
        local ns="${deploy_spec##*:}"
        if oc get deployment "$deploy" -n "$ns" &>/dev/null; then
            local ready
            ready=$(oc get deployment "$deploy" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            if [ "${ready:-0}" -gt 0 ]; then
                print_success "  $deploy ($ns): running ($ready replicas ready)"
            else
                print_warning "  $deploy ($ns): exists but has no ready replicas"
            fi
        else
            print_info "  $deploy not found in $ns (may still be starting or not applicable on this version)"
        fi
    done

    local uwm
    uwm=$(oc get configmap cluster-monitoring-config -n openshift-monitoring \
        -o jsonpath='{.data.config\.yaml}' 2>/dev/null | grep -c "enableUserWorkload: true" || echo "0")
    if [ "$uwm" -gt 0 ]; then
        print_success "User Workload Monitoring is enabled"
    else
        print_warning "User Workload Monitoring may not be enabled - MaaS requires it"
    fi

    local gw_exists
    gw_exists=$(oc get gateway maas-default-gateway -n openshift-ingress &>/dev/null && echo "yes" || echo "no")
    if [ "$gw_exists" = "yes" ]; then
        local gw_managed gw_tls
        gw_managed=$(oc get gateway maas-default-gateway -n openshift-ingress \
            -o jsonpath='{.metadata.annotations.opendatahub\.io/managed}' 2>/dev/null)
        gw_tls=$(oc get gateway maas-default-gateway -n openshift-ingress \
            -o jsonpath='{.metadata.annotations.security\.opendatahub\.io/authorino-tls-bootstrap}' 2>/dev/null)
        if [ "$gw_managed" = "false" ] && [ "$gw_tls" = "true" ]; then
            print_success "maas-default-gateway has correct annotations"
        else
            print_warning "maas-default-gateway missing required annotations"
        fi
    else
        print_warning "maas-default-gateway not found"
    fi

    print_step "Checking auto-created gateway policies..."
    local auth_policies
    auth_policies=$(oc get authpolicy -n openshift-ingress --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "${auth_policies:-0}" -gt 0 ]; then
        print_success "  AuthPolicy in openshift-ingress: $auth_policies found"
    else
        print_info "  No AuthPolicy found yet (maas-controller may still be reconciling)"
    fi
    if oc get tokenratelimitpolicy -n openshift-ingress --no-headers &>/dev/null 2>&1; then
        local trl_count
        trl_count=$(oc get tokenratelimitpolicy -n openshift-ingress --no-headers 2>/dev/null | wc -l | tr -d ' ')
        print_success "  TokenRateLimitPolicy in openshift-ingress: $trl_count found"
    else
        print_info "  No TokenRateLimitPolicy found yet (maas-controller may still be reconciling)"
    fi

    local auth_tls
    auth_tls=$(oc get authorino authorino -n kuadrant-system -o jsonpath='{.spec.listener.tls.enabled}' 2>/dev/null)
    if [ "$auth_tls" = "true" ]; then
        print_success "Authorino TLS listener is enabled"
    else
        print_warning "Authorino TLS listener not enabled"
    fi

    print_step "Checking MaaS health endpoint..."
    local health
    health=$(curl -sk "https://maas.apps.${CLUSTER_DOMAIN}/maas-api/health" 2>/dev/null)
    if echo "$health" | grep -q "healthy"; then
        print_success "MaaS API health: $health"
    else
        print_warning "MaaS API health check inconclusive: ${health:-no response}"

        # Restart the maas-default-gateway pod to clear stale WASM shim state.
        # During initial install the maas-api may crash-loop while waiting for the
        # database and other dependencies. The gateway's Kuadrant WASM shim caches
        # gRPC connection state from those failed attempts, causing persistent 500
        # "Internal Server Error." responses on authenticated /maas-api/* and
        # /v1/api-keys/* calls. Restarting the gateway after maas-api has
        # stabilized clears the stale state.
        print_step "Restarting maas-default-gateway to clear stale WASM shim state..."
        if oc delete pod -n openshift-ingress \
            -l gateway.networking.k8s.io/gateway-name=maas-default-gateway \
            --wait=false 2>/dev/null; then
            sleep 10
            local gw_elapsed=0
            while [ $gw_elapsed -lt 60 ]; do
                if oc get pods -n openshift-ingress \
                    -l gateway.networking.k8s.io/gateway-name=maas-default-gateway \
                    --no-headers 2>/dev/null | grep -q "1/1.*Running"; then
                    print_success "maas-default-gateway pod restarted"
                    break
                fi
                sleep 5
                gw_elapsed=$((gw_elapsed + 5))
            done
            sleep 5
            local post_health
            post_health=$(curl -sk "https://maas.apps.${CLUSTER_DOMAIN}/maas-api/health" 2>/dev/null)
            if echo "$post_health" | grep -q "healthy"; then
                print_success "MaaS API healthy after gateway restart: $post_health"
            else
                print_info "MaaS API not yet healthy after restart -- may need a few more seconds"
            fi
        else
            print_info "No maas-default-gateway pods to restart (gateway may not be deployed yet)"
        fi
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

    [ "$FROM_PHASE" -le 1 ] && [ "$TO_PHASE" -ge 1 ] && phase1_rhcl
    [ "$FROM_PHASE" -le 1 ] && [ "$TO_PHASE" -ge 1 ] && enable_user_workload_monitoring
    [ "$FROM_PHASE" -le 2 ] && [ "$TO_PHASE" -ge 2 ] && phase2_gateway
    [ "$FROM_PHASE" -le 3 ] && [ "$TO_PHASE" -ge 3 ] && phase3_postgres
    [ "$FROM_PHASE" -le 4 ] && [ "$TO_PHASE" -ge 4 ] && phase4_dsc

    if [ "$FROM_PHASE" -le 4 ] && [ "$TO_PHASE" -ge 4 ]; then
        if [ "$ENABLE_REDIS" = true ]; then
            setup_redis_limitador
        fi

        if [ "$ENABLE_OBSERVABILITY" = true ]; then
            configure_dsci_monitoring
        fi

        if [ "$ENABLE_USAGE_LOGGING" = true ]; then
            setup_maas_usage_logging
        fi
    fi

    [ "$FROM_PHASE" -le 5 ] && [ "$TO_PHASE" -ge 5 ] && phase5_verify

    if [ "$CALLED_FROM_INSTALLER" != true ]; then
        display_usage_instructions_34_plus
    fi
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
