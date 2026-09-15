#!/bin/bash
################################################################################
# RHOAI 3.4 Installation Script
# Installs Red Hat OpenShift AI 3.4 with all prerequisites
#
# Key changes from 3.3:
#   - MaaS core GA (subscriptions replace tiers, API keys, llm-d)
#     Sub-features still TP: vLLM runtime, external OIDC, observability, external egress
#   - NeMo Guardrails now GA
#   - MLflow Operator officially a managed DSC component
#   - New Tech Preview: AutoML, AutoRAG, vLLM on MaaS, EvalHub
#   - llm-d enhancements: Prometheus metrics, simplified scheduler config
#   - MLServer ServingRuntime now GA
#   - OCI-compliant storage for model registry
#   - Workbench images default to Red Hat Python index
#
# MaaS TLS changes (3.4):
#   - Uses OpenShift service-ca for Authorino TLS (NOT cert-manager Certificate)
#   - Gateway requires annotations: opendatahub.io/managed, authorino-tls-bootstrap
#   - Dashboard flags: maasAuthPolicies, observabilityDashboard (new)
#   - Tenant CR auto-created in models-as-a-service namespace
#   - MaaS CRDs: MaaSSubscription, MaaSAuthPolicy, MaaSModelRef, Tenant, ExternalModel
#
# Reference: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4
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
DEPLOY_GRAFANA=false
POSTGRES_CONNECTION=""
CLUSTER_DOMAIN=""
WAIT_TIMEOUT=600
RHOAI_CHANNEL=""

# Version identity, read by shared functions in install-common.sh
# (check_prerequisites' error/warning text, etc.) so they don't need
# per-version branching for cosmetic differences.
RHOAI_VERSION_LABEL="3.4"
RHOAI_MAX_VALIDATED_OCP=""   # unset on 3.4: no known upper bound was documented

# RHOAI 3.4: MaaS infrastructure (maas-api, maas-controller, maas-db-config
# secret, optional POC PostgreSQL) lives in redhat-ods-applications. (3.5+
# moves this to redhat-ai-gateway-infra -- see install-rhoai-35.sh.) Kept as
# a variable, not hardcoded, so shared functions in install-common.sh that
# reference $MAAS_INFRA_NS work unmodified across both installers.
MAAS_INFRA_NS="redhat-ods-applications"
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
    echo -e "${MAGENTA}║          RHOAI 3.4 Installation Script                         ║${NC}"
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
    echo "  --deploy-grafana      Deploy standalone Grafana with GPU/vLLM dashboards"
    echo "  --postgres-connection <url>  External PostgreSQL for MaaS (skips POC DB deployment)"
    echo "                         Format: postgresql://user:pass@host:5432/db?sslmode=require"
    echo "  --skip-maas-db         Skip MaaS PostgreSQL setup entirely"
    echo "  --skip-admin-user      Skip creating the htpasswd admin user"
    echo "  --channel <channel>    RHOAI channel (e.g., fast-3.x, stable-3.4). If not specified, will prompt."
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
    echo "  $0 --channel stable-3.4"
    echo "  $0 --channel stable-3.4 --enable-vllm-maas"
    echo "  $0 --channel stable-3.4 --enable-observability"
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
    echo "  • stable-X.Y : Specific version streams (e.g., stable-3.4)"
    echo "  • stable     : Production-ready releases"
    echo ""

    local default_idx=1
    for i in "${!channel_map[@]}"; do
        if [ "${channel_map[$i]}" = "fast-3.x" ]; then
            default_idx=$((i + 1))
            break
        elif [ "${channel_map[$i]}" = "$default_channel" ]; then
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

# wait_for_api_server() now lives in lib/functions/rhcl-install.sh (shared
# with install-rhoai-35.sh and scripts/setup-maas.sh).
# Retry a command up to N times with API server recovery between attempts

# install_servicemesh_operator(), approve_servicemesh_installplans(),
# approve_rhcl_installplans(), setup_istio_for_kuadrant(), and
# restart_kuadrant_operator() now live in lib/functions/rhcl-install.sh
# (shared with install-rhoai-35.sh and scripts/setup-maas.sh's phase1_rhcl).
#
# install_rhcl_operator(), setup_maas_database(), and configure_maas_tls()
# have been removed: this installer now delegates RHCL + Kuadrant + Istio +
# Gateway + PostgreSQL + Authorino TLS setup to
# "$ROOT_DIR/scripts/setup-maas.sh --called-from-installer --rhoai-version 3.4"
# (phases 1-2 pre-RHOAI, phases 3-5 post-RHOAI) -- see main() below.

# configure_maas_rate_limiting() has been removed: Redis-for-Limitador setup
# (lib/functions/redis-limitador.sh) is now always requested via the
# `--enable-redis` flag on setup-maas.sh's post-RHOAI call in main() below,
# instead of a separate wrapper function.

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
              kubernetes.io/metadata.name: openshift-operators
      ports:
        - port: 8080
          protocol: TCP
  policyTypes:
    - Ingress
EOF

    # RHOAI 3.4 doesn't ship a DSC-managed Monitoring component that auto-creates
    # its own default PersesDatasource, so this toolkit's "monitoring-prometheus-datasource"
    # is normally the only default in play here. However, if this script is ever
    # run against a cluster that already has a native "cluster-prometheus-datasource"
    # (e.g. a later RHOAI upgrade, or a mixed 3.4/3.5 environment), skip creating
    # our own — Perses only allows ONE default datasource per kind, and having two
    # causes the loser to be rejected by the Perses API (400 error) and stay
    # permanently Degraded, breaking the dashboard's Observe & monitor page with
    # "No datasource found for kind 'PrometheusDatasource'".
    if oc get persesdatasource cluster-prometheus-datasource -n "$mon_ns" &>/dev/null; then
        print_info "A 'cluster-prometheus-datasource' already exists — skipping toolkit's duplicate datasource to avoid a default-datasource conflict"
    else
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

    oc apply -f "$ROOT_DIR/lib/manifests/rhoai/datasciencecluster-v3-34.yaml"

    print_step "Waiting for DataScienceCluster core components..."
    local elapsed=0
    local timeout=300

    while [ $elapsed -lt $timeout ]; do
        local phase=$(oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}' 2>/dev/null)
        if [ "$phase" = "Ready" ]; then
            print_success "DataScienceCluster is fully ready"
            return 0
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
            return 0
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
        echo -n "."
    done

    echo ""
    print_warning "DataScienceCluster may not be fully ready yet (MaaS/Kueue configured in later steps)"
}

enable_dashboard_features() {
    print_step "Enabling dashboard features..."

    local elapsed=0
    while [ $elapsed -lt 120 ]; do
        if oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; then
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    # Build dashboard config with all 3.4 MaaS flags
    # Required flags per https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/govern_llm_access_with_models-as-a-service:
    #   modelAsService: true          - core MaaS functionality
    #   genAiStudio: true             - MaaS user-facing features in dashboard
    #   maasAuthPolicies: true        - MaaS admin features (subscriptions, auth policies)
    #   vLLMDeploymentOnMaaS: true    - Required for "Publish as MaaS" to appear in deploy wizard
    #                                   (without it, dashboard hides the non-legacy deployment path)
    # Developer Preview flags:
    #   mcpCatalog: true              - MCP Catalog under AI Hub (requires MCP Lifecycle Operator)
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
                "maasAuthPolicies": true,
                "vLLMDeploymentOnMaaS": true,
                "disableLMEval": false,
                "mcpCatalog": true
            }
        }
    }'

    if [ "$ENABLE_VLLM_MAAS" = true ]; then
        patch_json='{
            "spec": {
                "dashboardConfig": {
                    "disableModelRegistry": false,
                    "disableModelCatalog": false,
                    "disableKServeMetrics": false,
                    "genAiStudio": true,
                    "modelAsService": true,
                    "maasAuthPolicies": true,
                    "disableLMEval": false,
                    "vLLMDeploymentOnMaaS": true,
                    "mcpCatalog": true
                }
            }
        }'
        print_info "Enabling vLLM runtime for MaaS (Technology Preview)"
    fi

    if [ "$ENABLE_OBSERVABILITY" = true ]; then
        patch_json='{
            "spec": {
                "dashboardConfig": {
                    "disableModelRegistry": false,
                    "disableModelCatalog": false,
                    "disableKServeMetrics": false,
                    "genAiStudio": true,
                    "modelAsService": true,
                    "maasAuthPolicies": true,
                    "observabilityDashboard": true,
                    "disableLMEval": false,
                    "mcpCatalog": true
                }
            }
        }'
        print_info "Enabling MaaS observability dashboard (Technology Preview)"
    fi

    oc patch odhdashboardconfig odh-dashboard-config \
        -n redhat-ods-applications \
        --type=merge \
        -p "$patch_json" 2>/dev/null || print_warning "Could not patch dashboard config yet"

    print_success "Dashboard features enabled (including maasAuthPolicies)"
}

install_mcp_lifecycle_operator() {
    print_step "Installing MCP Lifecycle Operator (Developer Preview)..."

    if oc get crd mcpservers.mcp.x-k8s.io &>/dev/null; then
        print_success "MCP Lifecycle Operator already installed [SKIP]"
        return 0
    fi

    local MCP_OPERATOR_URL="https://github.com/kubernetes-sigs/mcp-lifecycle-operator/releases/latest/download/install.yaml"

    print_step "Deploying MCP Lifecycle Operator from kubernetes-sigs..."
    if kubectl apply -f "$MCP_OPERATOR_URL" &>/dev/null; then
        print_success "MCP Lifecycle Operator deployed"
    else
        print_warning "Could not install MCP Lifecycle Operator — MCP Catalog will not appear in AI Hub"
        return 1
    fi

    local elapsed=0
    while [ $elapsed -lt 120 ]; do
        if oc get pods -n mcp-lifecycle-operator-system 2>/dev/null | grep -q "1/1.*Running"; then
            print_success "MCP Lifecycle Operator is running"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    print_warning "MCP Lifecycle Operator not ready yet — check: oc get pods -n mcp-lifecycle-operator-system"
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
# .cursor/rules/manifests-source-of-truth.mdc.

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
    echo -e "${GREEN}║          RHOAI 3.4 Installation Complete!                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # RHOAI 3.4 dashboard URL changed to rh-ai (data-science-gateway auto-redirects)
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
    echo -e "${GREEN}What's New in 3.4:${NC}"
    echo "  • MaaS core platform now GA (subscriptions replace tiers, API keys, llm-d)"
    echo "    Sub-features still TP: vLLM runtime, external OIDC, observability, external model egress"
    echo "  • MaaS uses OpenShift service-ca for TLS (NOT cert-manager)"
    echo "  • NeMo Guardrails now Generally Available"
    echo "  • MLflow Operator is officially a managed DSC component"
    echo "  • AutoML and AutoRAG available as Technology Preview"
    echo "  • llm-d: Prometheus metrics, simplified scheduler config"
    echo "  • MLServer ServingRuntime now GA (scikit-learn, XGBoost, LightGBM, ONNX)"
    echo "  • OCI-compliant storage for Model Registry"
    echo ""

    # Show PostgreSQL info
    if oc get secret maas-db-config -n redhat-ods-applications &>/dev/null; then
        if oc get deployment postgres -n redhat-ods-applications &>/dev/null; then
            echo -e "${YELLOW}PostgreSQL:${NC} POC instance in redhat-ods-applications (NOT for production)"
            echo "  For production: AWS RDS, Crunchy Operator, or Azure Database for PostgreSQL"
        else
            echo -e "${CYAN}PostgreSQL:${NC} External (maas-db-config secret exists)"
        fi
        echo ""
    fi

    echo -e "${YELLOW}MaaS Next Steps (new subscription model in 3.4):${NC}"
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
    if [ "$ENABLE_OBSERVABILITY" = true ]; then
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
            --deploy-grafana)
                DEPLOY_GRAFANA=true
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
        "$ROOT_DIR/scripts/setup-maas.sh" --called-from-installer --rhoai-version 3.4 --from-phase 1 --to-phase 2
        create_inference_gateway
    elif [ "$SKIP_RHCL" = false ]; then
        "$ROOT_DIR/scripts/setup-maas.sh" --called-from-installer --rhoai-version 3.4 --from-phase 1 --to-phase 1
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

    # MaaS DB + DSC flags + verify (3.4) - must run after RHCL and gateway are created.
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
        [ -n "$POSTGRES_CONNECTION" ] && maas_extra_flags+=(--postgres-connection "$POSTGRES_CONNECTION")

        "$ROOT_DIR/scripts/setup-maas.sh" --called-from-installer --rhoai-version 3.4 \
            --from-phase "$maas_from_phase" --enable-redis "${maas_extra_flags[@]}"

        if [ "$SKIP_MAAS_DB" = true ] && ! oc get secret maas-db-config -n redhat-ods-applications &>/dev/null; then
            print_warning "maas-db-config secret not found — MaaS Tenant will show Degraded"
            print_info "Create it with: oc create secret generic maas-db-config \\"
            print_info "  --from-literal=DB_CONNECTION_URL='postgresql://user:pass@host:5432/db?sslmode=require' \\"
            print_info "  -n redhat-ods-applications"
        fi
    fi

    # Observability stack — COO + UIPlugins + Perses + Thanos proxy are always installed.
    # Without these the RHOAI "Observability dashboard" shows "Service Unavailable".
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
