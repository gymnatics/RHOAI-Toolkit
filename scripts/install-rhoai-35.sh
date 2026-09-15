#!/bin/bash
################################################################################
# RHOAI 3.5 Installation Script
# Installs Red Hat OpenShift AI 3.5 with all prerequisites
#
# Key changes from 3.4:
#   - OGX Operator replaces the Llama Stack Operator (DSC field: llamastackoperator -> ogx)
#     Component requirements: OGX Operator, Service Mesh 3.x, cert-manager, GPU nodes,
#     NFD, NVIDIA GPU Operator, S3-compatible storage. Responses API GA on OGX.
#   - MCP Lifecycle Operator is now a first-class DSC component (mcplifecycleoperator, TP)
#   - External OIDC authentication for MaaS is now GA
#   - EvalHub is GA (replaces/depreactes standalone LM-Eval, managed via TrustyAI)
#   - Flow control for llm-d is GA with BREAKING API changes vs the 3.4 TP:
#       API group: inference.networking.x-k8s.io -> llm-d.ai
#       Metrics prefix: inference_extension_ -> llm_d_epp_
#       saturationDetector moved under flowControl.saturationDetector
#   - Controlled (canary) deployment for llm-d GA; observability dashboards for llm-d
#     are now installed by default (ConfigMaps in OpenShift console)
#   - MaaS OpenAI-compatible body-based model routing to /v1/chat/completions
#   - Dashboard roleManagement flag is enabled by default
#   - RHCL 1.4.1+ required (1.4.0 is deprecated: auth failures/gateway instability)
#   - Service Mesh 3.4 required by RHCL 1.4
#   - KubeRay upgraded to 1.6.x
#   - OCP support widened to 4.19-4.22 (llm-d still requires 4.20+)
#   - Deprecated: FMS Guardrails Orchestrator (use NeMo Guardrails), LM-Eval (use EvalHub)
#   - Removed: RStudio Server workbench images, Kubeflow Training Operator v1 images
#
# MaaS TLS (unchanged from 3.4):
#   - Uses OpenShift service-ca for Authorino TLS (NOT cert-manager Certificate)
#   - Gateway requires annotations: opendatahub.io/managed, authorino-tls-bootstrap
#   - Tenant CR auto-created in models-as-a-service namespace
#   - MaaS CRDs: MaaSSubscription, MaaSAuthPolicy, MaaSModelRef, Tenant, ExternalModel
#
# Reference: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5
################################################################################

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source utilities
source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m'
}
source "$ROOT_DIR/lib/utils/common.sh" 2>/dev/null || true
source "$ROOT_DIR/lib/functions/redis-limitador.sh" 2>/dev/null || true
source "$ROOT_DIR/lib/functions/metallb.sh" 2>/dev/null || true
source "$ROOT_DIR/lib/functions/usage-logging.sh" 2>/dev/null || true
source "$ROOT_DIR/lib/functions/rhcl-install.sh" 2>/dev/null || true
source "$ROOT_DIR/lib/functions/install-common.sh" 2>/dev/null || true

# Default options
SKIP_PREREQUISITES=false
SKIP_RHCL=false
SKIP_MAAS=false
SKIP_NODE_SCALING=false
SKIP_MAAS_DB=false
ENABLE_LLMD=true
ENABLE_VLLM_MAAS=false
ENABLE_OBSERVABILITY=false
ENABLE_TP_FEATURES=false
ENABLE_USAGE_LOGGING=false
DEPLOY_GRAFANA=false
POSTGRES_CONNECTION=""
CLUSTER_DOMAIN=""
WAIT_TIMEOUT=600
RHOAI_CHANNEL=""

# Version identity, read by shared functions in install-common.sh
# (check_prerequisites' error/warning text, etc.) so they don't need
# per-version branching for cosmetic differences.
RHOAI_VERSION_LABEL="3.5"
RHOAI_MAX_VALIDATED_OCP="4.22"

# RHOAI 3.5: MaaS infrastructure namespace changed from redhat-ods-applications
# to redhat-ai-gateway-infra. This namespace hosts maas-api, maas-controller,
# maas-db-config secret, and (optionally) the POC PostgreSQL deployment.
# After DSC reconciliation you can discover it dynamically:
#   oc get maastenantconfig default-tenant -n models-as-a-service \
#     -o jsonpath='{.status.infraNamespace}'
MAAS_INFRA_NS="redhat-ai-gateway-infra"
SETUP_PIPELINES=false
PIPELINE_NAMESPACE=""
SKIP_ADMIN_USER=false
CREATE_ADMIN_USER=""
SETUP_USERS=false
NUM_USERS=5
ADMIN_GROUP="rhods-admins"
USER_GROUP="rhods-users"
USER_PASSWORD="openshift"

################################################################################
# Helper Functions
################################################################################

print_banner() {
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║          RHOAI 3.5 Installation Script                         ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --skip-prerequisites    Skip installing NFD, GPU, Kueue, cert-manager operators"
    echo "  --skip-rhcl            Skip RHCL/Kuadrant installation (no MaaS/llm-d auth)"
    echo "  --skip-maas            Skip MaaS configuration"
    echo "  --skip-node-scaling    Skip automatic worker/GPU node scaling"
    echo "  --no-llmd              Don't configure llm-d Gateway"
    echo "  --enable-vllm-maas     Enable vLLM runtime for MaaS (Technology Preview)"
    echo "  --enable-observability Enable MaaS observability dashboard (Technology Preview)"
    echo "  --enable-tp-features  Enable ALL Technology Preview dashboard features"
    echo "                         (AutoML, AutoRAG, Guardrails, Observability, Tracing, etc.)"
    echo "  --deploy-grafana      Deploy standalone Grafana with GPU/vLLM dashboards"
    echo "  --enable-usage-logging Enable log-based MaaS usage dashboards (Loki Operator +"
    echo "                         MinIO/S3 + LokiStack; per-request token/user tracking)"
    echo "  --postgres-connection <url>  External PostgreSQL for MaaS (skips POC DB deployment)"
    echo "                         Format: postgresql://user:pass@host:5432/db?sslmode=require"
    echo "  --skip-maas-db         Skip MaaS PostgreSQL setup entirely"
    echo "  --skip-admin-user      Skip creating the htpasswd admin user"
    echo "  --channel <channel>    RHOAI channel (e.g., fast-3.x, stable-3.5, eus-3.5). If not specified, will prompt."
    echo "  --domain <domain>      Cluster domain (e.g., cluster.example.com)"
    echo "  --timeout <seconds>    Wait timeout for operators (default: 600)"
    echo ""
    echo "AI Pipelines:"
    echo "  --setup-pipelines      Deploy a pipeline server (DSPA) with built-in MinIO + MariaDB"
    echo "  --pipeline-namespace <ns>  Namespace for pipeline server (default: prompts interactively)"
    echo ""
    echo "User Management:"
    echo "  --setup-users          Create demo users (user1..userN) with htpasswd + groups"
    echo "  --num-users <N>        Number of demo users to create (default: 5, implies --setup-users)"
    echo "  --admin-group <name>   Admin group name (default: rhods-admins). user1 goes here."
    echo "  --user-group <name>    Regular user group name (default: rhods-users). user2+ go here."
    echo "  --user-password <pw>   Password for all demo users (default: openshift)"
    echo ""
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --domain cluster.example.com"
    echo "  $0 --channel stable-3.5"
    echo "  $0 --channel stable-3.5 --enable-vllm-maas"
    echo "  $0 --channel stable-3.5 --enable-observability"
    echo "  $0 --postgres-connection 'postgresql://maas:secret@rds.example.com:5432/maas?sslmode=require'"
    echo "  $0 --setup-users --num-users 10 --user-password 'demo123'"
}

################################################################################
# RHOAI Channel Selection
################################################################################

select_rhoai_channel() {
    print_step "Fetching available RHOAI channels from cluster..."

    local channels_raw=$(oc get packagemanifest rhods-operator -n openshift-marketplace \
        -o jsonpath='{.status.channels[*].name}' 2>/dev/null)

    if [ -z "$channels_raw" ]; then
        print_warning "Unable to fetch RHOAI channels from cluster"
        print_info "Using default channel: fast-3.x"
        RHOAI_CHANNEL="fast-3.x"
        return 0
    fi

    local default_channel=$(oc get packagemanifest rhods-operator -n openshift-marketplace \
        -o jsonpath='{.status.defaultChannel}' 2>/dev/null)

    local channels=()
    while IFS= read -r channel; do
        [ -n "$channel" ] && channels+=("$channel")
    done < <(echo "$channels_raw" | tr ' ' '\n' | sort -V)

    if [ ${#channels[@]} -eq 0 ]; then
        print_warning "No channels found, using default: fast-3.x"
        RHOAI_CHANNEL="fast-3.x"
        return 0
    fi

    echo ""
    echo -e "${CYAN}Available RHOAI Channels:${NC}"
    echo ""

    local stable_channels=()
    local fast_channels=()
    local other_channels=()

    for channel in "${channels[@]}"; do
        if [[ "$channel" == stable* ]]; then
            stable_channels+=("$channel")
        elif [[ "$channel" == fast* ]]; then
            fast_channels+=("$channel")
        else
            other_channels+=("$channel")
        fi
    done

    local idx=1
    local channel_map=()

    if [ ${#fast_channels[@]} -gt 0 ]; then
        echo -e "${MAGENTA}Fast Channels (Latest/Preview):${NC}"
        for channel in "${fast_channels[@]}"; do
            local marker=""
            [ "$channel" = "$default_channel" ] && marker=" ${GREEN}[default]${NC}"
            echo -e "  ${YELLOW}$idx)${NC} $channel$marker"
            channel_map+=("$channel")
            ((idx++))
        done
        echo ""
    fi

    if [ ${#stable_channels[@]} -gt 0 ]; then
        echo -e "${MAGENTA}Stable Channels:${NC}"
        for channel in "${stable_channels[@]}"; do
            local marker=""
            [ "$channel" = "$default_channel" ] && marker=" ${GREEN}[default]${NC}"
            echo -e "  ${YELLOW}$idx)${NC} $channel$marker"
            channel_map+=("$channel")
            ((idx++))
        done
        echo ""
    fi

    if [ ${#other_channels[@]} -gt 0 ]; then
        echo -e "${MAGENTA}Other Channels:${NC}"
        for channel in "${other_channels[@]}"; do
            local marker=""
            [ "$channel" = "$default_channel" ] && marker=" ${GREEN}[default]${NC}"
            echo -e "  ${YELLOW}$idx)${NC} $channel$marker"
            channel_map+=("$channel")
            ((idx++))
        done
        echo ""
    fi

    echo -e "${CYAN}Channel Types:${NC}"
    echo "  • fast-3.x   : RHOAI 3.x (latest features, GenAI, MaaS)"
    echo "  • stable-X.Y : Specific version streams (e.g., stable-3.5)"
    echo "  • stable     : Production-ready releases"
    echo ""

    local default_idx=1
    for i in "${!channel_map[@]}"; do
        if [ "${channel_map[$i]}" = "stable-3.5" ]; then
            default_idx=$((i + 1))
            break
        elif [ "${channel_map[$i]}" = "fast-3.x" ]; then
            default_idx=$((i + 1))
        elif [ "${channel_map[$i]}" = "$default_channel" ] && [ "$default_idx" -eq 1 ]; then
            default_idx=$((i + 1))
        fi
    done

    local max_idx=${#channel_map[@]}
    local choice=""

    while true; do
        read -p "Select channel (1-$max_idx) [default: $default_idx - ${channel_map[$((default_idx - 1))]}]: " choice
        choice=$(echo "$choice" | tr -d '[:space:]')

        if [ -z "$choice" ]; then
            choice=$default_idx
            break
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$max_idx" ]; then
            break
        else
            print_error "Invalid selection. Please enter a number between 1 and $max_idx"
        fi
    done

    RHOAI_CHANNEL="${channel_map[$((choice - 1))]}"
    print_success "Selected channel: $RHOAI_CHANNEL"
}

################################################################################
# Installation Functions
################################################################################

################################################################################
# Admin User Creation
################################################################################

# wait_for_api_server() now lives in lib/functions/rhcl-install.sh (shared with
# install-rhoai-34.sh and scripts/setup-maas.sh).

# Retry a command up to N times with API server recovery between attempts

# install_servicemesh_operator(), approve_servicemesh_installplans(),
# approve_rhcl_installplans(), setup_istio_for_kuadrant(), and
# restart_kuadrant_operator() now live in lib/functions/rhcl-install.sh
# (shared with install-rhoai-34.sh and scripts/setup-maas.sh's phase1_rhcl).
#
# install_rhcl_operator(), setup_maas_database(), and configure_maas_tls()
# have been removed: this installer now delegates RHCL + Kuadrant + Istio +
# Gateway + PostgreSQL + Authorino TLS setup to
# "$ROOT_DIR/scripts/setup-maas.sh --called-from-installer --rhoai-version 3.5"
# (phases 1-2 pre-RHOAI, phases 3-5 post-RHOAI) -- see main() below. This
# removes ~350 lines of logic that was previously duplicated (and drifting)
# between the two scripts; setup-maas.sh is now the single source of truth
# for MaaS setup logic (see .cursor/rules/manifests-source-of-truth.mdc).

################################################################################
# MaaS Telemetry Configuration
# Enable usage metrics capture on MaasTenantConfig (RHOAI 3.5+)
# Captures: group, model usage, organization, and user metrics
################################################################################

configure_maas_telemetry() {
    print_step "Enabling MaaS telemetry metrics..."

    # Wait for MaasTenantConfig to exist (created by maas-controller)
    local elapsed=0
    while [ $elapsed -lt 120 ]; do
        if oc get maastenantconfig default-tenant -n models-as-a-service &>/dev/null; then
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    if ! oc get maastenantconfig default-tenant -n models-as-a-service &>/dev/null; then
        print_warning "MaasTenantConfig not found — skipping telemetry configuration"
        return 0
    fi

    # Check if telemetry is already enabled
    local telemetry_enabled=$(oc get maastenantconfig default-tenant -n models-as-a-service \
        -o jsonpath='{.spec.telemetry.enabled}' 2>/dev/null)
    if [ "$telemetry_enabled" = "true" ]; then
        print_success "MaaS telemetry already enabled"
        return 0
    fi

    # Enable all telemetry capture flags
    if oc patch maastenantconfig default-tenant -n models-as-a-service --type=merge -p '{
        "spec": {
            "telemetry": {
                "enabled": true,
                "metrics": {
                    "captureGroup": true,
                    "captureModelUsage": true,
                    "captureOrganization": true,
                    "captureUser": true
                }
            }
        }
    }' 2>/dev/null; then
        print_success "MaaS telemetry enabled (group, model usage, organization, user metrics)"
    else
        print_warning "Could not enable MaaS telemetry — apply manually:"
        echo "  oc patch maastenantconfig default-tenant -n models-as-a-service --type=merge \\"
        echo "    -p '{\"spec\":{\"telemetry\":{\"enabled\":true,\"metrics\":{\"captureGroup\":true,\"captureModelUsage\":true,\"captureOrganization\":true,\"captureUser\":true}}}}'"
    fi
}

# configure_maas_rate_limiting() has been removed: Redis-for-Limitador setup
# (lib/functions/redis-limitador.sh) is now always requested via the
# `--enable-redis` flag on setup-maas.sh's post-RHOAI call in main() below,
# instead of a separate wrapper function.

install_tempo_operator() {
    print_step "Installing Tempo Operator (required for DSCI monitoring tracing)..."

    if oc get csv -n openshift-tempo-operator 2>/dev/null | grep -q "tempo-operator.*Succeeded"; then
        print_info "Tempo Operator already installed"
        return 0
    fi

    oc apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-tempo-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-tempo-operator
  namespace: openshift-tempo-operator
spec:
  upgradeStrategy: Default
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: tempo-product
  namespace: openshift-tempo-operator
spec:
  channel: stable
  installPlanApproval: Automatic
  name: tempo-product
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

    print_step "Waiting for Tempo Operator..."
    local elapsed=0
    while [ $elapsed -lt 180 ]; do
        if oc get csv -n openshift-tempo-operator 2>/dev/null | grep -q "tempo-operator.*Succeeded"; then
            print_success "Tempo Operator installed"
            return 0
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done

    print_warning "Tempo Operator not ready after 180s (may still be installing)"
}

install_opentelemetry_operator() {
    print_step "Installing OpenTelemetry Operator (required for DSCI monitoring)..."

    if oc get csv -n openshift-opentelemetry-operator 2>/dev/null | grep -q "opentelemetry-operator.*Succeeded"; then
        print_info "OpenTelemetry Operator already installed"
        return 0
    fi

    oc apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-opentelemetry-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-opentelemetry-operator
  namespace: openshift-opentelemetry-operator
spec:
  upgradeStrategy: Default
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: opentelemetry-product
  namespace: openshift-opentelemetry-operator
spec:
  channel: stable
  installPlanApproval: Automatic
  name: opentelemetry-product
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

    print_step "Waiting for OpenTelemetry Operator..."
    local elapsed=0
    while [ $elapsed -lt 180 ]; do
        if oc get csv -n openshift-opentelemetry-operator 2>/dev/null | grep -q "opentelemetry-operator.*Succeeded"; then
            print_success "OpenTelemetry Operator installed"
            return 0
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done

    print_warning "OpenTelemetry Operator not ready after 180s (may still be installing)"
}

setup_observability_perses() {
    local mon_ns="redhat-ods-monitoring"

    if ! oc get crd perses.perses.dev &>/dev/null 2>&1; then
        print_warning "Perses CRD not found — skipping Perses server setup"
        return 0
    fi

    if oc get pods -n "$mon_ns" -l app.kubernetes.io/managed-by=perses-operator --no-headers 2>/dev/null | grep -q Running; then
        print_info "Perses already running in $mon_ns [SKIP]"
    else
        print_step "Creating Perses server in $mon_ns..."

        oc create sa perses-sa -n "$mon_ns" 2>/dev/null || true
        oc create clusterrolebinding perses-sa-${mon_ns} \
            --clusterrole=system:openshift:scc:nonroot-v2 \
            --serviceaccount=${mon_ns}:perses-sa 2>/dev/null || true

        oc apply -f - <<EOF
apiVersion: perses.dev/v1alpha2
kind: Perses
metadata:
  name: data-science-perses
  namespace: ${mon_ns}
spec:
  serviceAccountName: perses-sa
  config:
    database:
      file:
        case_sensitive: false
        extension: yaml
        folder: /perses
    datasource:
      disable_local: false
      global:
        disable: false
      project:
        disable: false
    ephemeral_dashboard:
      enable: true
      cleanup_interval: 300s
  client:
    kubernetesAuth:
      enable: false
EOF

        print_step "Waiting for Perses pod..."
        local elapsed=0
        while [ $elapsed -lt 90 ]; do
            if oc get pods -n "$mon_ns" -l app.kubernetes.io/managed-by=perses-operator --no-headers 2>/dev/null | grep -q Running; then
                print_success "Perses server running in $mon_ns"
                break
            fi
            sleep 10
            elapsed=$((elapsed + 10))
        done
    fi

    # NetworkPolicy: allow perses-operator (in openshift-cluster-observability-operator)
    # to sync PersesDashboard and PersesDatasource CRs with the Perses server.
    # Also allow from openshift-operators (fallback) and redhat-ods-monitoring (self).
    # Without this, the operator gets "context deadline exceeded" and all dashboards
    # stay in PersesBackendError state — the RHOAI "Dashboard" menu item never appears.
    oc apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: perses-operator-access
  namespace: ${mon_ns}
  labels:
    app.kubernetes.io/managed-by: rhoai-toolkit
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/managed-by: perses-operator
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: openshift-cluster-observability-operator
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: openshift-operators
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ${mon_ns}
      ports:
        - port: 8080
          protocol: TCP
  policyTypes:
    - Ingress
EOF

    # Configure DSCI monitoring FIRST to trigger the operator's observability
    # cascade (MonitoringStack, ThanosQuerier, Perses datasources, tracing).
    # Without this, DSCI monitoring.metrics stays empty ({}) and the RHOAI
    # "Dashboard" menu item under "Observe & monitor" never appears. This must
    # run BEFORE the PersesDatasource fallback logic below, since RHOAI 3.5's
    # DSC-managed Monitoring component only auto-creates its own default
    # "cluster-prometheus-datasource" PersesDatasource once this is configured.
    # Reference: https://rh-aiservices-bu.github.io/rhoai-maas-guide/modules/main/07-observability.html
    local dsci_metrics
    dsci_metrics=$(oc get dsci default-dsci -o jsonpath='{.spec.monitoring.metrics.replicas}' 2>/dev/null)
    if [ -z "$dsci_metrics" ] || [ "$dsci_metrics" = "null" ]; then
        print_step "Configuring DSCI monitoring (metrics + tracing)..."
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
    else
        print_info "DSCI monitoring already configured (replicas=$dsci_metrics)"
    fi

    # RHOAI's Monitoring operator reconciles cluster-prometheus-datasource
    # asynchronously after DSCI is Ready — give it a short window to appear
    # before deciding whether the toolkit needs to create a fallback.
    print_step "Checking for RHOAI-native 'cluster-prometheus-datasource'..."
    local ds_elapsed=0
    while [ $ds_elapsed -lt 60 ]; do
        if oc get persesdatasource cluster-prometheus-datasource -n "$mon_ns" &>/dev/null; then
            break
        fi
        sleep 5
        ds_elapsed=$((ds_elapsed + 5))
    done

    # Perses only allows ONE default datasource per kind. If we also apply our
    # own default PersesDatasource ("monitoring-prometheus-datasource") when
    # RHOAI's native one already exists, whichever is created SECOND gets
    # rejected by the Perses API (400: "cannot be a default PrometheusDatasource
    # because there is already one defined") and stays permanently Degraded —
    # breaking the RHOAI dashboard's Observe & monitor page with
    # "No datasource found for kind 'PrometheusDatasource'".
    # Only fall back to creating our own if RHOAI's native one truly isn't
    # present (e.g. an older RHOAI 3.5.x build that doesn't auto-create it).
    if oc get persesdatasource cluster-prometheus-datasource -n "$mon_ns" &>/dev/null; then
        print_info "RHOAI-native 'cluster-prometheus-datasource' found — skipping toolkit's duplicate datasource to avoid a default-datasource conflict"
    else
        print_info "RHOAI-native datasource not found — falling back to toolkit-managed PersesDatasource"

        if ! oc get configmap prometheus-web-tls-ca -n "$mon_ns" &>/dev/null; then
            oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-web-tls-ca
  namespace: ${mon_ns}
  annotations:
    service.beta.openshift.io/inject-cabundle: "true"
data: {}
EOF
            print_info "Created service-ca ConfigMap for PersesDatasource"
        fi

        # Create the monitoring-prometheus-datasource-secret that the PersesDatasource
        # references for authenticating to Thanos Querier. Without this secret the
        # datasource stays Degraded and all dashboards fail to sync.
        if ! oc get secret monitoring-prometheus-datasource-secret -n "$mon_ns" &>/dev/null; then
            print_step "Creating Prometheus datasource secret for Perses..."
            local thanos_host
            thanos_host=$(oc get route thanos-querier -n openshift-monitoring -o jsonpath='{.spec.host}' 2>/dev/null)
            local ds_token
            ds_token=$(oc create token prometheus-k8s -n openshift-monitoring --duration=87600h 2>/dev/null)
            if [ -n "$ds_token" ] && [ -n "$thanos_host" ]; then
                oc create secret generic monitoring-prometheus-datasource-secret \
                    --from-literal=token="$ds_token" \
                    --from-literal=host="$thanos_host" \
                    -n "$mon_ns" 2>/dev/null && \
                    print_success "Prometheus datasource secret created" || \
                    print_warning "Could not create Prometheus datasource secret"
            else
                print_warning "Could not create Prometheus datasource secret — token or host unavailable"
            fi
        fi

        oc apply -f "$ROOT_DIR/lib/manifests/monitoring/persesdatasource-monitoring.yaml"
    fi

    print_success "Observability Perses setup complete"
}

create_datasciencecluster() {
    print_step "Creating DataScienceCluster..."

    # Apply DSCInitialization first (controls monitoring, trustedCABundle, applications namespace)
    if ! oc get dscinitialization default-dsci &>/dev/null; then
        print_step "Applying DSCInitialization..."
        oc apply -f "$ROOT_DIR/lib/manifests/rhoai/dscinitialization.yaml"
        oc wait --for=jsonpath='{.status.phase}'=Ready dscinitialization/default-dsci --timeout=120s 2>/dev/null || true
    fi

    if oc get datasciencecluster default-dsc &>/dev/null; then
        print_info "DataScienceCluster already exists"
        return 0
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/rhoai/datasciencecluster-v3-35.yaml"

    print_step "Waiting for DataScienceCluster core components..."
    local elapsed=0
    local timeout=300

    while [ $elapsed -lt $timeout ]; do
        local phase=$(oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}' 2>/dev/null)
        if [ "$phase" = "Ready" ]; then
            print_success "DataScienceCluster is fully ready"
            break
        fi
        
        # Check if core components are ready (MaaS/Kueue may need later config steps)
        local dashboard_ready=$(oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions[?(@.type=="DashboardReady")].status}' 2>/dev/null)
        local kserve_ready=$(oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions[?(@.type=="KserveReady")].status}' 2>/dev/null)
        
        if [ "$dashboard_ready" = "True" ] && [ "$kserve_ready" = "True" ]; then
            echo ""
            print_success "Core components ready (Dashboard, KServe)"
            local not_ready=$(oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
            if [ -n "$not_ready" ]; then
                print_info "Pending (will be configured in later steps): $not_ready"
            fi
            break
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
        echo -n "."
    done

    if [ $elapsed -ge $timeout ]; then
        echo ""
        print_warning "DataScienceCluster may not be fully ready yet (MaaS/Kueue configured in later steps)"
    fi

    # RHOAI 3.5: Wait for AIGatewayReady — the ai-gateway-operator + maas-controller
    # must be running before MaaS subscriptions and API keys work.
    # ModelsAsAServiceReady will remain False until gateway+DB+TLS are configured (later steps).
    print_step "Waiting for AIGatewayReady (AI Gateway / MaaS controller)..."
    if oc wait --for=jsonpath='{.status.conditions[?(@.type=="AIGatewayReady")].status}'=True \
        datasciencecluster/default-dsc --timeout=300s 2>/dev/null; then
        print_success "AIGatewayReady is True"
    else
        print_warning "AIGatewayReady did not become True within 300s"
        print_info "This may resolve after MaaS prerequisites (gateway, DB, TLS) are configured"
    fi
}

enable_dashboard_features() {
    print_step "Enabling dashboard features..."

    # Wait for the OdhDashboardConfig to be created by the operator
    print_step "Waiting for OdhDashboardConfig to be available..."
    local elapsed=0
    while [ $elapsed -lt 180 ]; do
        if oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; then
            print_success "OdhDashboardConfig is available"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        [ $((elapsed % 15)) -eq 0 ] && echo "  Waiting for OdhDashboardConfig... (${elapsed}s elapsed)"
    done

    if ! oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; then
        print_warning "OdhDashboardConfig not found after 180s — dashboard flags will not be applied"
        print_info "Apply manually later: oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications ..."
        return 1
    fi

    # Build dashboard config with all 3.5 MaaS flags
    # Required flags per https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.5/html/govern_llm_access_with_models-as-a-service:
    #   modelAsService: true          - core MaaS functionality
    #   genAiStudio: true             - MaaS user-facing features in dashboard
    #   vLLMDeploymentOnMaaS: true    - Required for "Publish as MaaS" to appear in deploy wizard
    #                                   (without it, dashboard hides the non-legacy deployment path)
    #   roleManagement: true          - Custom RBAC role creation UI for data science projects
    #                                   (enabled by default in 3.5, set explicitly for clarity)
    #   mcpCatalog: true              - MCP Catalog under AI Hub (requires MCP Lifecycle Operator)
    #
    # REMOVED in 3.5 (CEL validation rejects setting these):
    #   maasAuthPolicies              - no longer a settable flag, baked into MaaS GA
    #
    # Optional TP flags:
    #   observabilityDashboard: true  - MaaS usage monitoring dashboard (TP)
    local patch_json='{
        "spec": {
            "dashboardConfig": {
                "disableModelRegistry": false,
                "disableModelCatalog": false,
                "disableKServeMetrics": false,
                "genAiStudio": true,
                "modelAsService": true,
                "vLLMDeploymentOnMaaS": true,
                "disableLMEval": false,
                "mcpCatalog": true,
                "roleManagement": true
            }
        }
    }'

    if [ "$ENABLE_TP_FEATURES" = true ]; then
        patch_json='{
            "spec": {
                "dashboardConfig": {
                    "disableModelRegistry": false,
                    "disableModelCatalog": false,
                    "disableKServeMetrics": false,
                    "genAiStudio": true,
                    "modelAsService": true,
                    "vLLMDeploymentOnMaaS": true,
                    "disableLMEval": false,
                    "mcpCatalog": true,
                    "roleManagement": true,
                    "automl": true,
                    "autorag": true,
                    "observabilityDashboard": true,
                    "guardrails": true,
                    "connectionTest": true,
                    "featureStoreAdmin": true,
                    "promptManagement": true,
                    "toolCalling": true,
                    "externalModels": true,
                    "externalVectorStores": true,
                    "genAiTracing": true,
                    "llmdTemplates": true,
                    "llmGatewayField": true,
                    "mcpRegistry": true,
                    "deploymentWizardYAMLViewer": true,
                    "aiAssetCustomEndpoints": true,
                    "globalProjectPrompts": true
                }
            }
        }'
        print_info "Enabling ALL Technology Preview dashboard features"
    elif [ "$ENABLE_OBSERVABILITY" = true ]; then
        patch_json='{
            "spec": {
                "dashboardConfig": {
                    "disableModelRegistry": false,
                    "disableModelCatalog": false,
                    "disableKServeMetrics": false,
                    "genAiStudio": true,
                    "modelAsService": true,
                    "observabilityDashboard": true,
                    "disableLMEval": false,
                    "mcpCatalog": true,
                    "roleManagement": true
                }
            }
        }'
        print_info "Enabling MaaS observability dashboard (Technology Preview)"
    fi

    if oc patch odhdashboardconfig odh-dashboard-config \
        -n redhat-ods-applications \
        --type=merge \
        -p "$patch_json" 2>/dev/null; then

        # Verify the patch took effect
        local maas_flag=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
            -o jsonpath='{.spec.dashboardConfig.modelAsService}' 2>/dev/null)
        if [ "$maas_flag" = "true" ]; then
            print_success "Dashboard features enabled and verified"
        else
            print_warning "Dashboard patch applied but modelAsService not yet set — operator may reconcile"
        fi
    else
        print_warning "Could not patch dashboard config"
        print_info "Apply manually: oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge -p '$patch_json'"
    fi
}

install_mcp_lifecycle_operator() {
    # In RHOAI 3.5, the MCP Lifecycle Operator is a first-class DSC component
    # (spec.components.mcplifecycleoperator) and is automatically deployed by the
    # RHOAI meta-operator as part of create_datasciencecluster() — unlike 3.4, where
    # it had to be installed manually from kubernetes-sigs as a Developer Preview.
    # This function now just verifies the DSC-managed rollout instead of installing it.
    print_step "Verifying MCP Lifecycle Operator (DSC-managed component, Technology Preview)..."

    local mcp_state
    mcp_state=$(oc get datasciencecluster default-dsc \
        -o jsonpath='{.spec.components.mcplifecycleoperator.managementState}' 2>/dev/null)

    if [ "$mcp_state" != "Managed" ]; then
        print_warning "mcplifecycleoperator is not Managed in the DSC — MCP Catalog will not appear in AI Hub"
        return 1
    fi

    local elapsed=0
    while [ $elapsed -lt 120 ]; do
        if oc get crd mcpservers.mcp.x-k8s.io &>/dev/null; then
            print_success "MCP Lifecycle Operator CRDs are present"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    print_warning "MCP Lifecycle Operator CRDs not detected yet — check: oc get datasciencecluster default-dsc -o yaml"
}

# MCP Catalog prerequisites — the catalog creates MCPServer CRs but does NOT
# auto-create the ServiceAccount, RBAC, or config ConfigMap the server pod needs.
# Call this before deploying from the catalog in any namespace.

# apply_gateway_resources_configmap() has been removed: it's a MaaS-gateway
# concern (the ConfigMap is referenced via maas-default-gateway's
# infrastructure.parametersRef), so it now lives solely in setup-maas.sh's
# phase2_gateway.

# Creates ONLY the non-MaaS "openshift-ai-inference" Gateway, for direct
# model access outside MaaS governance (no auth/rate-limiting). The MaaS
# gateway (maas-default-gateway) is created by setup-maas.sh's phase2_gateway,
# called from main() before this function runs -- see
# .cursor/rules/manifests-source-of-truth.mdc and the sub-plan this refactor
# implements ("openshift-ai-inference gateway creation is NOT a MaaS concern").

################################################################################
# Monitoring Dashboards
################################################################################

# verify_maas_deployment() has been removed: this is now setup-maas.sh's
# phase5_verify() (single source of truth, called via --called-from-installer
# --from-phase 3 in main() below).

################################################################################
# User Management
################################################################################

print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          RHOAI 3.5 Installation Complete!                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # RHOAI dashboard URL is rh-ai (data-science-gateway auto-redirects) - unchanged from 3.4
    local dashboard_url=$(oc get route -n redhat-ods-applications -o jsonpath='{.items[?(@.metadata.name=="rh-ai")].spec.host}' 2>/dev/null)
    if [ -z "$dashboard_url" ]; then
        dashboard_url=$(oc get route -n redhat-ods-applications -o jsonpath='{.items[?(@.metadata.name=="data-science-gateway")].spec.host}' 2>/dev/null)
    fi
    if [ -z "$dashboard_url" ]; then
        dashboard_url="rh-ai.apps.${CLUSTER_DOMAIN}"
    fi

    echo -e "${CYAN}Dashboard URL:${NC} https://${dashboard_url}"
    echo -e "${CYAN}Current User:${NC} $(oc whoami 2>/dev/null)"

    local admin_in_htpasswd=false
    if oc get secret htpasswd-secret -n openshift-config &>/dev/null; then
        if oc get secret htpasswd-secret -n openshift-config \
            -o jsonpath='{.data.htpasswd}' 2>/dev/null | base64 -d 2>/dev/null | grep -q "^admin:"; then
            admin_in_htpasswd=true
        fi
    fi

    if [ "$admin_in_htpasswd" = true ]; then
        echo -e "${CYAN}Admin Login:${NC}  admin / R3dh4t1!"
        echo ""
        echo -e "${YELLOW}Post-install:${NC} Log in as 'admin' for MaaS API key generation:"
        echo "  oc login -u admin -p 'R3dh4t1!' $(oc whoami --show-server 2>/dev/null)"
        echo "  To remove kubeadmin, use the toolkit: ./rhoai-toolkit.sh → RHOAI Management → Day 2 Operations"
    else
        echo ""
        echo -e "${YELLOW}Post-install:${NC} No htpasswd admin user was created."
        echo "  To create one later: $0 (re-run and choose Y at the admin user prompt)"
        echo "  Or use: scripts/setup-users.sh to create demo users"
    fi

    if [ "$ENABLE_LLMD" = true ] && [ "$SKIP_RHCL" = false ]; then
        echo -e "${CYAN}MaaS Gateway:${NC} https://maas.apps.${CLUSTER_DOMAIN}"
        echo -e "${CYAN}Inference Gateway:${NC} https://inference-gateway.apps.${CLUSTER_DOMAIN}"
    fi

    echo ""
    echo -e "${GREEN}What's New in 3.5:${NC}"
    echo "  • OGX Operator replaces the Llama Stack Operator (DSC: ogx, was llamastackoperator)"
    echo "  • External OIDC authentication for MaaS is now GA"
    echo "  • EvalHub is GA (unified evaluation platform, replaces standalone LM-Eval)"
    echo "  • Flow control for llm-d is GA (BREAKING: API group is now llm-d.ai)"
    echo "  • Controlled (canary) deployment for llm-d is GA"
    echo "  • llm-d observability dashboards installed by default"
    echo "  • MaaS OpenAI-compatible body-based routing to /v1/chat/completions"
    echo "  • Dashboard roleManagement flag enabled by default (custom RBAC roles UI)"
    echo "  • RHCL 1.4.1+ required (1.4.0 is deprecated); Service Mesh 3.4 required"
    echo "  • KubeRay upgraded to 1.6.x"
    echo "  • Deprecated: FMS Guardrails Orchestrator (use NeMo Guardrails), LM-Eval (use EvalHub)"
    echo "  • Removed: RStudio Server workbench images, Kubeflow Training Operator v1 images"
    echo ""

    # Show PostgreSQL info
    if oc get secret maas-db-config -n "$MAAS_INFRA_NS" &>/dev/null; then
        if oc get deployment postgres -n "$MAAS_INFRA_NS" &>/dev/null; then
            echo -e "${YELLOW}PostgreSQL:${NC} POC instance in $MAAS_INFRA_NS (NOT for production)"
            echo "  For production: AWS RDS, Crunchy Operator, or Azure Database for PostgreSQL"
        else
            echo -e "${CYAN}PostgreSQL:${NC} External (maas-db-config secret exists)"
        fi
        echo ""
    fi

    echo -e "${YELLOW}MaaS Next Steps (subscription model):${NC}"
    echo "  1. Access dashboard > Settings > verify MaaS is active"
    echo "  2. Deploy a model and publish to MaaS (creates MaaSModelRef)"
    echo "  3. Create a MaaS Subscription (dashboard Settings > Subscriptions)"
    echo "  4. Create a MaaS Authorization Policy (dashboard Settings > Authorization Policies)"
    echo "  5. Generate API keys for users (dashboard or self-service)"
    echo "  6. Verify: oc get tenant default-tenant -n models-as-a-service"
    echo "  7. Verify: oc get maassubscriptions -n models-as-a-service"
    if [ "$ENABLE_VLLM_MAAS" = true ]; then
        echo "  • vLLM on MaaS is enabled (TP) - deploy models via MaaS with vLLM runtime"
    fi
    if [ "$ENABLE_TP_FEATURES" = true ]; then
        echo "  • ALL Technology Preview features enabled (AutoML, AutoRAG, Guardrails, Observability, etc.)"
    elif [ "$ENABLE_OBSERVABILITY" = true ]; then
        echo "  • MaaS observability dashboard is enabled (TP)"
    fi
    echo ""

    echo -e "${BLUE}Verification commands:${NC}"
    echo "  oc get datasciencecluster"
    echo "  oc get csv -n redhat-ods-operator"
    echo "  oc get hardwareprofiles -n redhat-ods-applications"
    echo "  oc get crd | grep maas.opendatahub.io"
    echo "  oc get tenant -n models-as-a-service"
    echo "  oc get gateway maas-default-gateway -n openshift-ingress"
    echo "  oc get authorino authorino -n kuadrant-system -o jsonpath='{.spec.listener.tls}'"
    echo ""
}

################################################################################
# Main
################################################################################

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-prerequisites)
                SKIP_PREREQUISITES=true
                shift
                ;;
            --skip-rhcl)
                SKIP_RHCL=true
                shift
                ;;
            --skip-node-scaling)
                SKIP_NODE_SCALING=true
                shift
                ;;
            --skip-maas)
                SKIP_MAAS=true
                shift
                ;;
            --no-llmd)
                ENABLE_LLMD=false
                shift
                ;;
            --enable-vllm-maas)
                ENABLE_VLLM_MAAS=true
                shift
                ;;
            --enable-observability)
                ENABLE_OBSERVABILITY=true
                shift
                ;;
            --enable-tp-features)
                ENABLE_TP_FEATURES=true
                ENABLE_OBSERVABILITY=true
                shift
                ;;
            --deploy-grafana)
                DEPLOY_GRAFANA=true
                shift
                ;;
            --enable-usage-logging)
                ENABLE_USAGE_LOGGING=true
                shift
                ;;
            --postgres-connection)
                POSTGRES_CONNECTION="$2"
                shift 2
                ;;
            --skip-maas-db)
                SKIP_MAAS_DB=true
                shift
                ;;
            --skip-admin-user)
                SKIP_ADMIN_USER=true
                shift
                ;;
            --channel)
                RHOAI_CHANNEL="$2"
                shift 2
                ;;
            --domain)
                CLUSTER_DOMAIN="$2"
                shift 2
                ;;
            --timeout)
                WAIT_TIMEOUT="$2"
                shift 2
                ;;
            --setup-pipelines)
                SETUP_PIPELINES=true
                shift
                ;;
            --pipeline-namespace)
                SETUP_PIPELINES=true
                PIPELINE_NAMESPACE="$2"
                shift 2
                ;;
            --setup-users)
                SETUP_USERS=true
                shift
                ;;
            --num-users)
                SETUP_USERS=true
                NUM_USERS="$2"
                shift 2
                ;;
            --admin-group)
                ADMIN_GROUP="$2"
                shift 2
                ;;
            --user-group)
                USER_GROUP="$2"
                shift 2
                ;;
            --user-password)
                USER_PASSWORD="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    print_banner
    check_prerequisites
    get_cluster_domain

    if [ "$SKIP_ADMIN_USER" = true ]; then
        print_info "Skipping admin user creation (--skip-admin-user)"
    elif [ "$CREATE_ADMIN_USER" = "yes" ]; then
        create_admin_user
    else
        echo ""
        echo -e "${CYAN}Would you like to create an htpasswd admin user?${NC}"
        echo -e "  This creates user ${YELLOW}'admin'${NC} with password ${YELLOW}'R3dh4t1!'${NC} and cluster-admin role."
        echo -e "  You can skip this if you already have an identity provider configured."
        echo ""
        read -p "Create admin user? (Y/n): " admin_choice
        admin_choice=${admin_choice:-Y}
        if [[ "$admin_choice" =~ ^[Yy]$ ]]; then
            create_admin_user
        else
            print_info "Skipping admin user creation"
        fi
    fi

    if [ "$SKIP_NODE_SCALING" = false ]; then
        scale_cluster_nodes
    else
        print_info "Skipping node scaling (--skip-node-scaling)"
    fi

    if [ "$SKIP_PREREQUISITES" = false ]; then
        install_nfd_operator
        install_gpu_operator
        install_kueue_operator
        install_certmanager_operator

        if [ "$ENABLE_LLMD" = true ]; then
            install_lws_operator
        fi
    fi

    if [ "$SKIP_RHCL" = false ] && [ "$SKIP_MAAS" = false ]; then
        # Ensure the shared gateway TLS secret exists before delegating gateway
        # creation to setup-maas.sh's phase2_gateway, which prefers it when present.
        create_gateway_tls_secret
        "$ROOT_DIR/scripts/setup-maas.sh" --called-from-installer --rhoai-version 3.5 --from-phase 1 --to-phase 2
        create_inference_gateway
    elif [ "$SKIP_RHCL" = false ]; then
        "$ROOT_DIR/scripts/setup-maas.sh" --called-from-installer --rhoai-version 3.5 --from-phase 1 --to-phase 1
    else
        print_info "Skipping RHCL/MaaS (--skip-rhcl or --skip-maas)"
    fi

    enable_user_workload_monitoring

    install_rhoai_operator
    create_datasciencecluster

    enable_dashboard_features
    install_mcp_lifecycle_operator
    create_hardware_profile
    create_mlflow_server

    # MaaS DB + DSC flags + verify - must run after RHCL and gateway are created.
    # DB secret must exist BEFORE modelsAsService becomes Managed (or restart maas-api after).
    # Delegates to setup-maas.sh (phases 3-5: PostgreSQL, DSC flags, verify) -- the
    # single source of truth for MaaS setup logic (manifests-source-of-truth.mdc).
    if [ "$SKIP_RHCL" = false ] && [ "$SKIP_MAAS" = false ]; then
        local maas_from_phase=3
        if [ "$SKIP_MAAS_DB" = true ]; then
            print_info "Skipping MaaS DB setup (--skip-maas-db)"
            maas_from_phase=4
        fi

        local maas_extra_flags=()
        [ "$ENABLE_OBSERVABILITY" = true ] && maas_extra_flags+=(--enable-observability)
        [ "$ENABLE_USAGE_LOGGING" = true ] && maas_extra_flags+=(--enable-usage-logging)
        [ -n "$POSTGRES_CONNECTION" ] && maas_extra_flags+=(--postgres-connection "$POSTGRES_CONNECTION")

        "$ROOT_DIR/scripts/setup-maas.sh" --called-from-installer --rhoai-version 3.5 \
            --from-phase "$maas_from_phase" --enable-redis "${maas_extra_flags[@]}"

        if [ "$SKIP_MAAS_DB" = true ] && ! oc get secret maas-db-config -n "$MAAS_INFRA_NS" &>/dev/null; then
            print_warning "maas-db-config secret not found in $MAAS_INFRA_NS — MaaS Tenant will show Degraded"
            print_info "Create it with: oc create secret generic maas-db-config \\"
            print_info "  --from-literal=DB_CONNECTION_URL='postgresql://user:pass@host:5432/db?sslmode=require' \\"
            print_info "  -n $MAAS_INFRA_NS"
        fi

        # Kept in the installer (not moved to setup-maas.sh) since it's gated on the
        # full observability stack this installer sets up below, matching
        # install-rhoai-34.sh's equivalent configure_gateway_telemetry gating.
        if [ "$ENABLE_OBSERVABILITY" = true ]; then
            configure_maas_telemetry
        fi
    fi

    # Observability stack — Tempo + OpenTelemetry + COO + UIPlugins + Perses
    # Tempo and OpenTelemetry are required by the DSCI Monitoring controller.
    # Without them, the DSCI cannot provision MonitoringStack/ThanosQuerier/tracing,
    # and the RHOAI "Dashboard" menu item never appears.
    install_tempo_operator
    install_opentelemetry_operator
    install_coo_operator
    setup_observability_uiplugins
    setup_observability_perses
    create_thanos_proxy_secret

    # Native Observe tab dashboards (zero-dependency, always deployed)
    deploy_observe_dashboards

    # Standalone Grafana instance (optional, controlled by --deploy-grafana)
    if [ "${DEPLOY_GRAFANA:-false}" = true ]; then
        deploy_grafana_monitoring
    fi

    # Gateway telemetry (MaaS usage metrics) is optional
    if [ "$ENABLE_OBSERVABILITY" = true ]; then
        configure_gateway_telemetry
    fi

    # Log-based MaaS usage dashboards (RHOAI 3.5+ only, optional -- Loki Operator
    # + MinIO/S3 + LokiStack). Provides per-request token consumption, user
    # attribution, and subscription tracking, distinct from the Prometheus-based
    # gateway telemetry above (which aggregates rather than tracking per-call).
    if [ "$ENABLE_USAGE_LOGGING" = true ]; then
        setup_maas_usage_logging
    fi

    if [ "$SETUP_PIPELINES" = true ]; then
        setup_pipeline_server "$PIPELINE_NAMESPACE"
    fi

    if [ "$SETUP_USERS" = true ]; then
        setup_demo_users "$NUM_USERS" "$ADMIN_GROUP" "$USER_GROUP" "$USER_PASSWORD"
    fi

    print_summary
}

# Only run main when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit 0
fi
