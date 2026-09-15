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

print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
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

wait_for_operator() {
    local operator_name="$1"
    local namespace="$2"
    local timeout="${3:-$WAIT_TIMEOUT}"

    print_step "Waiting for $operator_name operator to be ready in $namespace..."

    local elapsed=0
    local interval=10
    local last_status=""

    while [ $elapsed -lt $timeout ]; do
        local csv_line=$(oc get csv -n "$namespace" 2>/dev/null | grep "$operator_name" | head -1)
        local status=$(echo "$csv_line" | awk '{print $NF}')
        local csv_name=$(echo "$csv_line" | awk '{print $1}')

        if [ "$status" = "Succeeded" ]; then
            print_success "$operator_name operator is ready ($csv_name)"
            return 0
        fi

        if [ -n "$status" ] && [ "$status" != "$last_status" ]; then
            echo "  $operator_name: $status ($csv_name) — ${elapsed}s elapsed"
            last_status="$status"
        elif [ -z "$csv_line" ] && [ $((elapsed % 30)) -eq 0 ] && [ $elapsed -gt 0 ]; then
            echo "  $operator_name: CSV not yet created in $namespace — ${elapsed}s elapsed"
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    print_error "$operator_name operator did not become ready within ${timeout}s"
    local final_csv=$(oc get csv -n "$namespace" 2>/dev/null | grep "$operator_name")
    [ -n "$final_csv" ] && print_info "  Last seen: $final_csv"
    return 1
}

wait_for_pod() {
    local label="$1"
    local namespace="$2"
    local timeout="${3:-300}"

    print_step "Waiting for pods with label $label..."

    local elapsed=0
    local interval=5

    while [ $elapsed -lt $timeout ]; do
        local ready=$(oc get pods -n "$namespace" -l "$label" -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null | grep -c "true" || echo "0")
        local total=$(oc get pods -n "$namespace" -l "$label" --no-headers 2>/dev/null | wc -l | tr -d ' ')

        if [ "$total" -gt 0 ] && [ "$ready" -eq "$total" ]; then
            print_success "Pods are ready"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    print_warning "Pods may not be fully ready"
    return 0
}

get_cluster_domain() {
    if [ -z "$CLUSTER_DOMAIN" ]; then
        CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null | sed 's/^apps\.//')
        if [ -z "$CLUSTER_DOMAIN" ]; then
            print_error "Could not detect cluster domain. Please specify with --domain"
            exit 1
        fi
    fi
    export CLUSTER_DOMAIN
    print_info "Cluster domain: $CLUSTER_DOMAIN"
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

check_prerequisites() {
    print_step "Checking prerequisites..."

    if ! command -v oc &> /dev/null; then
        print_error "oc CLI not found. Please install OpenShift CLI."
        exit 1
    fi

    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift cluster. Please run 'oc login' first."
        exit 1
    fi

    if ! oc auth can-i create clusterrole &> /dev/null; then
        print_error "You need cluster-admin privileges to install RHOAI."
        exit 1
    fi

    local ocp_version=$(oc version -o json 2>/dev/null | jq -r '.openshiftVersion' | cut -d. -f1,2)
    print_info "OpenShift version: $ocp_version"

    if [[ "$ocp_version" < "4.19" ]]; then
        print_error "RHOAI 3.5 requires OpenShift 4.19 or later. Current: $ocp_version"
        exit 1
    fi

    if [[ "$ocp_version" > "4.22" ]]; then
        print_warning "RHOAI 3.5 is validated up to OCP 4.22. Current: $ocp_version (proceeding anyway)"
    fi

    if [ "$ENABLE_LLMD" = true ] && [[ "$ocp_version" < "4.20" ]]; then
        print_warning "Distributed inference with llm-d requires OCP 4.20+. Current: $ocp_version"
        print_warning "llm-d will be installed but multi-node inference may not work correctly."
    fi

    print_success "Prerequisites check passed"
}

################################################################################
# Admin User Creation
################################################################################

# wait_for_api_server() now lives in lib/functions/rhcl-install.sh (shared with
# install-rhoai-34.sh and scripts/setup-maas.sh).

# Retry a command up to N times with API server recovery between attempts
retry_with_api_wait() {
    local max_retries=${1:-3}
    shift
    local attempt=1
    while [ $attempt -le $max_retries ]; do
        if "$@" 2>/dev/null; then
            return 0
        fi
        print_warning "Command failed (attempt $attempt/$max_retries), waiting for API server..."
        wait_for_api_server 60
        attempt=$((attempt + 1))
    done
    print_error "Command failed after $max_retries attempts: $*"
    return 1
}

recover_router_if_crashlooping() {
    local router_status
    router_status=$(oc get pods -n openshift-ingress -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default \
        -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)

    if [ "$router_status" = "CrashLoopBackOff" ]; then
        print_warning "Router pod is in CrashLoopBackOff (caused by API server restart)"
        print_step "Deleting stuck router pod to reset backoff..."
        oc delete pod -n openshift-ingress \
            -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default \
            --wait=false 2>/dev/null || true
        sleep 10
        local new_status
        new_status=$(oc get pods -n openshift-ingress \
            -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default \
            -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
        if [ "$new_status" = "Running" ]; then
            print_success "Router pod recovered"
        else
            print_info "Router pod restarting (status: $new_status) — it should recover shortly"
        fi
    fi
}

create_admin_user() {
    local admin_user="admin"
    local admin_pass='R3dh4t1!'

    # Check if admin user already exists in htpasswd
    local admin_exists=false
    if oc get secret htpasswd-secret -n openshift-config &>/dev/null; then
        if oc get secret htpasswd-secret -n openshift-config \
            -o jsonpath='{.data.htpasswd}' 2>/dev/null | base64 -d 2>/dev/null | grep -q "^${admin_user}:"; then
            admin_exists=true
        fi
    fi

    if [ "$admin_exists" = true ]; then
        print_info "Admin user '$admin_user' already exists — skipping creation"
        # Ensure group membership is correct even if user already exists
        if ! oc get group "$ADMIN_GROUP" &>/dev/null 2>&1; then
            oc adm groups new "$ADMIN_GROUP" 2>/dev/null || true
        fi
        oc adm groups add-users "$ADMIN_GROUP" "$admin_user" 2>/dev/null || true
        return 0
    fi

    print_step "Creating OAuth admin user '$admin_user'..."

    if ! command -v htpasswd &>/dev/null; then
        print_error "htpasswd CLI not found. Install httpd-tools (RHEL) or apache2-utils (Debian)."
        return 1
    fi

    # Pull existing htpasswd data (preserve other users)
    local htpasswd_tmp
    htpasswd_tmp=$(mktemp)

    if oc get secret htpasswd-secret -n openshift-config &>/dev/null; then
        oc get secret htpasswd-secret -n openshift-config \
            -o jsonpath='{.data.htpasswd}' | base64 -d > "$htpasswd_tmp" 2>/dev/null || true
    fi

    htpasswd -bB "$htpasswd_tmp" "$admin_user" "$admin_pass"
    print_success "User '$admin_user' added to htpasswd"

    # Update secret
    oc create secret generic htpasswd-secret \
        --from-file=htpasswd="$htpasswd_tmp" \
        -n openshift-config --dry-run=client -o yaml | oc apply -f -
    rm -f "$htpasswd_tmp"

    # Ensure htpasswd identity provider is configured
    local has_htpasswd
    has_htpasswd=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[?(@.name=="htpasswd")].name}' 2>/dev/null || true)
    if [ -z "$has_htpasswd" ]; then
        print_step "Adding htpasswd identity provider to OAuth..."
        oc patch oauth cluster --type=json -p '[{
            "op": "add",
            "path": "/spec/identityProviders/-",
            "value": {
                "name": "htpasswd",
                "type": "HTPasswd",
                "mappingMethod": "claim",
                "htpasswd": {
                    "fileData": {
                        "name": "htpasswd-secret"
                    }
                }
            }
        }]' 2>/dev/null || {
            oc patch oauth cluster --type=merge -p '{
                "spec": {
                    "identityProviders": [{
                        "name": "htpasswd",
                        "type": "HTPasswd",
                        "mappingMethod": "claim",
                        "htpasswd": {
                            "fileData": {
                                "name": "htpasswd-secret"
                            }
                        }
                    }]
                }
            }' 2>/dev/null
        }
        print_success "htpasswd identity provider configured"
    else
        print_info "htpasswd identity provider already configured"
    fi

    # Grant cluster-admin
    oc adm policy add-cluster-role-to-user cluster-admin "$admin_user" 2>/dev/null || true
    print_success "cluster-admin granted to '$admin_user'"

    # Create rhods-admins group and add admin
    if ! oc get group "$ADMIN_GROUP" &>/dev/null 2>&1; then
        oc adm groups new "$ADMIN_GROUP" 2>/dev/null || true
    fi
    oc adm groups add-users "$ADMIN_GROUP" "$admin_user" 2>/dev/null || true
    print_info "User '$admin_user' added to group '$ADMIN_GROUP'"

    # Don't switch sessions — continue using kube:admin for stability
    # The OAuth config change triggers an API server rollout; avoid disruption
    # by staying on the current session. User can log in as 'admin' later.
    print_success "Admin user created. Continuing installation as $(oc whoami)"
    print_info "Log in as '$admin_user' after installation: oc login -u $admin_user -p '$admin_pass'"
    echo ""

    # Wait briefly for the OAuth rollout to settle, then recover router if needed
    print_step "Waiting for API server to stabilize after OAuth change..."
    sleep 10
    wait_for_api_server 90
    recover_router_if_crashlooping
    print_success "Cluster stable — continuing installation"
}

scale_cluster_nodes() {
    print_step "Checking and scaling cluster nodes..."

    local worker_ms=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[?(@.spec.template.metadata.labels.machine\.openshift\.io/cluster-api-machine-role=="worker")].metadata.name}' 2>/dev/null | awk '{print $1}')

    if [ -z "$worker_ms" ]; then
        print_warning "No worker machineset found, skipping node scaling"
        return 0
    fi

    local current_replicas=$(oc get machineset "$worker_ms" -n openshift-machine-api -o jsonpath='{.spec.replicas}' 2>/dev/null)
    print_info "Worker machineset: $worker_ms (current replicas: $current_replicas)"

    if [ "$current_replicas" -lt 2 ]; then
        print_step "Scaling worker nodes to 2..."
        oc scale machineset "$worker_ms" -n openshift-machine-api --replicas=2
        print_success "Worker machineset scaled to 2 replicas"
    else
        print_info "Worker nodes already at $current_replicas replicas"
    fi

    local gpu_ms=$(oc get machineset -n openshift-machine-api -o name 2>/dev/null | grep -i gpu | head -1)

    if [ -n "$gpu_ms" ]; then
        print_info "GPU machineset already exists: $gpu_ms"
        local gpu_replicas=$(oc get "$gpu_ms" -n openshift-machine-api -o jsonpath='{.spec.replicas}' 2>/dev/null)
        if [ "$gpu_replicas" -eq 0 ]; then
            print_step "Scaling GPU machineset to 1..."
            oc scale "$gpu_ms" -n openshift-machine-api --replicas=1
            print_success "GPU machineset scaled to 1 replica"
        fi
    else
        print_step "Creating GPU machineset..."
        if [ -f "$ROOT_DIR/scripts/create-gpu-machineset.sh" ]; then
            local az=$(oc get machineset "$worker_ms" -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.placement.availabilityZone}' 2>/dev/null)
            "$ROOT_DIR/scripts/create-gpu-machineset.sh" --instance-type g6e.xlarge --az "$az" --replicas 1 --apply
            print_success "GPU machineset created and scaled to 1 replica"
        else
            print_warning "GPU machineset script not found, skipping GPU node creation"
        fi
    fi

    print_info "Nodes are scaling in the background. Installation will continue."
    print_info "Check node status with: oc get nodes"
}

install_nfd_operator() {
    print_step "Installing Node Feature Discovery (NFD) Operator..."

    if oc get csv -n openshift-nfd 2>/dev/null | grep -q nfd; then
        print_info "NFD Operator already installed"
        return 0
    fi

    oc create namespace openshift-nfd 2>/dev/null || true

    local og_count=$(oc get operatorgroup -n openshift-nfd -o name 2>/dev/null | wc -l | tr -d ' ')
    if [ "$og_count" -gt 0 ]; then
        print_info "Found $og_count existing OperatorGroup(s) in openshift-nfd namespace"
        oc delete operatorgroup --all -n openshift-nfd 2>/dev/null || true
        sleep 2
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/operators/nfd-operator.yaml"
    wait_for_operator "nfd" "openshift-nfd"

    print_step "Creating NFD instance..."
    oc apply -f "$ROOT_DIR/lib/manifests/operators/nfd-instance.yaml"

    print_success "NFD Operator installed"
}

install_gpu_operator() {
    print_step "Installing NVIDIA GPU Operator..."

    if oc get csv -n nvidia-gpu-operator 2>/dev/null | grep -q gpu-operator; then
        print_info "GPU Operator already installed"
        return 0
    fi

    oc create namespace nvidia-gpu-operator 2>/dev/null || true

    local og_count=$(oc get operatorgroup -n nvidia-gpu-operator -o name 2>/dev/null | wc -l | tr -d ' ')
    if [ "$og_count" -gt 0 ]; then
        print_info "Found $og_count existing OperatorGroup(s) in nvidia-gpu-operator namespace"
        oc delete operatorgroup --all -n nvidia-gpu-operator 2>/dev/null || true
        sleep 2
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/operators/gpu-operator.yaml"
    wait_for_operator "gpu-operator" "nvidia-gpu-operator"

    print_step "Creating ClusterPolicy..."
    oc apply -f "$ROOT_DIR/lib/manifests/operators/gpu-clusterpolicy.yaml"

    print_success "GPU Operator installed"
}

install_kueue_operator() {
    print_step "Installing Red Hat Build of Kueue Operator..."

    if oc get csv -n openshift-operators 2>/dev/null | grep -q kueue; then
        print_info "Kueue Operator already installed"
        return 0
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/operators/kueue-subscription.yaml"
    wait_for_operator "kueue" "openshift-operators"

    print_success "Kueue Operator installed"
}

install_certmanager_operator() {
    print_step "Installing cert-manager Operator..."

    if oc get csv -n cert-manager-operator 2>/dev/null | grep -q cert-manager; then
        print_info "cert-manager Operator already installed"
        return 0
    fi

    oc create namespace cert-manager-operator 2>/dev/null || true

    local og_count=$(oc get operatorgroup -n cert-manager-operator -o name 2>/dev/null | wc -l | tr -d ' ')
    if [ "$og_count" -gt 0 ]; then
        print_info "Found $og_count existing OperatorGroup(s) in cert-manager-operator namespace"
        oc delete operatorgroup --all -n cert-manager-operator 2>/dev/null || true
        sleep 2
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/operators/certmanager-operatorgroup.yaml"
    oc apply -f "$ROOT_DIR/lib/manifests/operators/certmanager-subscription.yaml"
    wait_for_operator "cert-manager" "cert-manager-operator"

    print_success "cert-manager Operator installed"
}

install_lws_operator() {
    print_step "Installing Leader Worker Set (LWS) Operator..."

    if oc get csv -n openshift-lws-operator 2>/dev/null | grep -q "leader-worker-set"; then
        print_info "LWS Operator already installed"
        return 0
    fi

    oc create namespace openshift-lws-operator 2>/dev/null || true

    local og_count=$(oc get operatorgroup -n openshift-lws-operator -o name 2>/dev/null | wc -l | tr -d ' ')
    if [ "$og_count" -gt 0 ]; then
        print_info "Found $og_count existing OperatorGroup(s) in openshift-lws-operator namespace"
        oc delete operatorgroup --all -n openshift-lws-operator 2>/dev/null || true
        sleep 2
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/operators/lws-operatorgroup.yaml"
    oc apply -f "$ROOT_DIR/lib/manifests/operators/lws-subscription.yaml"
    wait_for_operator "leader-worker-set" "openshift-lws-operator"

    oc apply -f "$ROOT_DIR/lib/manifests/operators/lws-operator-cr.yaml"

    print_success "LWS Operator installed"
}

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

enable_user_workload_monitoring() {
    print_step "Enabling User Workload Monitoring..."

    oc apply -f "$ROOT_DIR/lib/manifests/monitoring/cluster-monitoring-config.yaml"

    print_success "User Workload Monitoring enabled"
}

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

install_coo_operator() {
    print_step "Installing Cluster Observability Operator (COO)..."

    if oc get csv -n openshift-cluster-observability-operator 2>/dev/null | grep -q "cluster-observability-operator.*Succeeded"; then
        print_info "COO already installed"
        return 0
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/observability/coo-namespace.yaml"
    oc apply -f "$ROOT_DIR/lib/manifests/observability/coo-operatorgroup.yaml"
    oc apply -f "$ROOT_DIR/lib/manifests/observability/coo-subscription.yaml"

    print_step "Waiting for COO operator to be ready..."
    local elapsed=0
    while [ $elapsed -lt 180 ]; do
        if oc get csv -n openshift-cluster-observability-operator 2>/dev/null | grep -q "cluster-observability-operator.*Succeeded"; then
            print_success "COO operator installed (Perses CRDs available)"
            return 0
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done

    print_warning "COO operator not ready after 180s (may still be installing)"
}

setup_observability_uiplugins() {
    print_step "Setting up observability UIPlugins..."

    if ! oc get crd uiplugins.observability.openshift.io &>/dev/null 2>&1; then
        print_warning "UIPlugin CRD not found — COO may not be installed yet"
        return 0
    fi

    if oc get uiplugin dashboards &>/dev/null 2>&1; then
        local dash_avail
        dash_avail=$(oc get uiplugin dashboards -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$dash_avail" = "True" ]; then
            print_info "UIPlugin 'dashboards' already available [SKIP]"
        fi
    else
        oc apply -f - <<'EOF'
apiVersion: observability.openshift.io/v1alpha1
kind: UIPlugin
metadata:
  name: dashboards
spec:
  type: Dashboards
EOF
    fi

    oc apply -f - <<'EOF'
apiVersion: observability.openshift.io/v1alpha1
kind: UIPlugin
metadata:
  name: monitoring
spec:
  type: Monitoring
  monitoring:
    perses:
      enabled: true
EOF

    local elapsed=0
    while [ $elapsed -lt 60 ]; do
        local mon_avail
        mon_avail=$(oc get uiplugin monitoring -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$mon_avail" = "True" ]; then
            print_success "UIPlugins ready (dashboards + monitoring with Perses)"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    print_warning "UIPlugin 'monitoring' not yet Available — check: oc get uiplugin monitoring -o yaml"
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

create_thanos_proxy_secret() {
    local dash_ns="redhat-ods-applications"

    if ! oc get namespace "$dash_ns" &>/dev/null; then
        return 0
    fi

    # Always create the secret — it's harmless when observabilityDashboard is off,
    # and required immediately when someone enables it later via the menu.
    # Previously this was gated on observabilityDashboard=true, which caused the
    # secret to be missing when the flag was enabled post-install.
    print_step "Creating Thanos proxy secret for observability dashboard..."

    if oc get secret monitoring-thanos-proxy-secret -n "$dash_ns" &>/dev/null; then
        local existing_token thanos_host http_code
        existing_token=$(oc get secret monitoring-thanos-proxy-secret -n "$dash_ns" \
            -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
        thanos_host=$(oc get route thanos-querier -n openshift-monitoring \
            -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
        if [ -n "$existing_token" ] && [ -n "$thanos_host" ]; then
            http_code=$(curl -sk --connect-timeout 5 --max-time 10 -o /dev/null -w "%{http_code}" \
                -H "Authorization: Bearer ${existing_token}" \
                "https://${thanos_host}/api/v1/query?query=up" 2>/dev/null || echo "000")
            if [ "$http_code" -eq 200 ] 2>/dev/null; then
                print_success "Thanos proxy secret valid (HTTP 200)"
                return 0
            fi
        fi
        oc delete secret monitoring-thanos-proxy-secret -n "$dash_ns" &>/dev/null || true
    fi

    local new_token thanos_host
    new_token=$(oc create token rhods-dashboard -n "$dash_ns" --duration=87600h 2>/dev/null || echo "")
    thanos_host=$(oc get route thanos-querier -n openshift-monitoring \
        -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

    if [ -z "$new_token" ] || [ -z "$thanos_host" ]; then
        print_warning "Could not generate token or find Thanos route"
        return 0
    fi

    oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: monitoring-thanos-proxy-secret
  namespace: ${dash_ns}
  labels:
    app.kubernetes.io/part-of: rhods-dashboard
    opendatahub.io/dashboard: "true"
type: Opaque
stringData:
  token: "${new_token}"
  url: "https://${thanos_host}"
EOF

    print_success "Thanos proxy secret created (10-year token)"
}

configure_gateway_telemetry() {
    print_step "Configuring gateway telemetry for MaaS usage metrics..."

    oc apply -f "$ROOT_DIR/lib/manifests/observability/gateway-telemetry-policy.yaml" 2>/dev/null || \
        print_warning "TelemetryPolicy CRD not available (RHCL may need upgrade)"
    oc apply -f "$ROOT_DIR/lib/manifests/observability/istio-gateway-telemetry.yaml" 2>/dev/null || \
        print_warning "Istio Telemetry CRD not available"

    print_success "Gateway telemetry configured"
}

install_rhoai_operator() {
    print_step "Installing Red Hat OpenShift AI Operator..."

    oc create namespace redhat-ods-operator 2>/dev/null || true

    if oc get csv -n redhat-ods-operator 2>/dev/null | grep -q rhods; then
        print_info "RHOAI Operator already installed"
        return 0
    fi

    if [ -z "$RHOAI_CHANNEL" ]; then
        select_rhoai_channel
    else
        print_info "Using specified channel: $RHOAI_CHANNEL"
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/rhoai/rhoai-operatorgroup.yaml"

    print_step "Creating RHOAI subscription with channel: $RHOAI_CHANNEL"
    export RHOAI_CHANNEL
    envsubst '${RHOAI_CHANNEL}' < "$ROOT_DIR/lib/manifests/rhoai/rhoai-subscription.yaml" | oc apply -f -

    wait_for_operator "rhods" "redhat-ods-operator"

    print_success "RHOAI Operator installed (channel: $RHOAI_CHANNEL)"
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
setup_mcp_catalog_prerequisites() {
    local namespace="${1:?Namespace required}"

    print_step "Setting up MCP Catalog prerequisites in $namespace..."

    if ! oc get sa mcp-viewer -n "$namespace" &>/dev/null; then
        print_step "Creating mcp-viewer ServiceAccount..."
        oc create serviceaccount mcp-viewer -n "$namespace"
        oc create clusterrolebinding "mcp-viewer-${namespace}" \
            --clusterrole=view \
            --serviceaccount="${namespace}:mcp-viewer" 2>/dev/null || true
        print_success "mcp-viewer ServiceAccount + view ClusterRoleBinding created"
    else
        print_success "mcp-viewer ServiceAccount already exists [SKIP]"
    fi

    if ! oc get configmap openshift-mcp-server-config -n "$namespace" &>/dev/null; then
        print_step "Creating openshift-mcp-server-config ConfigMap..."
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: openshift-mcp-server-config
  namespace: $namespace
data:
  config.toml: |
    port = "8080"
    read_only = true
    stateless = true
    toolsets = ["core", "config", "openshift"]
EOF
        print_success "openshift-mcp-server-config ConfigMap created"
    else
        print_success "openshift-mcp-server-config ConfigMap already exists [SKIP]"
    fi
}

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
create_inference_gateway() {
    print_step "Creating openshift-ai-inference Gateway (direct model access, outside MaaS)..."

    get_cluster_domain

    print_step "Creating openshift-ai-inference gateway..."
    if ! oc get gatewayclass openshift-ai-inference &>/dev/null; then
        oc_apply_retry -f "$ROOT_DIR/lib/manifests/rhcl/gatewayclass-ai-inference.yaml"
    fi

    export CERT_NAME="default-gateway-tls"
    envsubst '${CLUSTER_DOMAIN} ${CERT_NAME}' < "$ROOT_DIR/lib/manifests/rhcl/gateway-inference.yaml" | oc_apply_retry

    # Create passthrough Routes so *.apps.<cluster> wildcard DNS reaches both
    # gateways (each gets its own LoadBalancer ELB, but *.apps.<cluster> DNS
    # points to the default OpenShift Router).
    create_gateway_passthrough_routes

    print_step "Waiting for GatewayClass and Gateway readiness..."
    oc wait --for=condition=Accepted gatewayclass/openshift-default --timeout=120s 2>/dev/null || \
        print_warning "openshift-default GatewayClass not yet Accepted"
    oc wait --for=condition=Programmed gateway/openshift-ai-inference -n openshift-ingress --timeout=120s 2>/dev/null || \
        print_warning "openshift-ai-inference gateway not yet Programmed"

    print_success "Gateways created"
    print_info "MaaS endpoint: https://maas.apps.${CLUSTER_DOMAIN}"
    print_info "Inference endpoint: https://inference-gateway.apps.${CLUSTER_DOMAIN}"
}

create_gateway_tls_secret() {
    if oc get secret default-gateway-tls -n openshift-ingress &>/dev/null; then
        print_success "default-gateway-tls secret already exists"
        return 0
    fi

    print_step "Creating default-gateway-tls secret for gateway HTTPS listeners..."

    # Strategy 0: If no ClusterIssuer exists, try to set up TLS automatically
    local issuer
    issuer=$(oc get clusterissuers -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -z "$issuer" ] && [ -f "$ROOT_DIR/scripts/setup-letsencrypt-tls.sh" ]; then
        print_info "No ClusterIssuer found. Running Let's Encrypt TLS setup..."
        "$ROOT_DIR/scripts/setup-letsencrypt-tls.sh" letsencrypt 2>/dev/null || \
            "$ROOT_DIR/scripts/setup-letsencrypt-tls.sh" selfsigned 2>/dev/null || true
        issuer=$(oc get clusterissuers -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    fi

    # Strategy 1: Use cert-manager Certificate CR if a ClusterIssuer exists
    if [ -n "$issuer" ]; then
        print_info "Found ClusterIssuer '$issuer' — creating Certificate CR..."
        export ISSUER_NAME="$issuer"
        envsubst '${CLUSTER_DOMAIN} ${ISSUER_NAME}' < "$ROOT_DIR/lib/manifests/rhcl/gateway-tls-certificate.yaml" | oc_apply_retry
        print_step "Waiting for cert-manager to generate TLS secret..."
        local wait=0
        while [ $wait -lt 120 ]; do
            if oc get secret default-gateway-tls -n openshift-ingress &>/dev/null; then
                print_success "default-gateway-tls created by cert-manager"
                return 0
            fi
            sleep 5
            wait=$((wait + 5))
        done
        print_warning "cert-manager did not create secret within 120s"
    fi

    # Strategy 2: Copy from existing wildcard cert (e.g. Let's Encrypt or router default)
    local wildcard_secrets=("apps-wildcard-tls" "cert-manager-ingress-cert" "router-certs-default")
    for src in "${wildcard_secrets[@]}"; do
        if oc get secret "$src" -n openshift-ingress &>/dev/null 2>&1; then
            local cert_cn
            cert_cn=$(oc get secret "$src" -n openshift-ingress -o jsonpath='{.data.tls\.crt}' 2>/dev/null \
                | base64 -d 2>/dev/null | openssl x509 -noout -subject 2>/dev/null || true)
            if echo "$cert_cn" | grep -q "${CLUSTER_DOMAIN}"; then
                print_info "Copying wildcard cert from '$src'..."
                local tmpdir_cert
                tmpdir_cert=$(mktemp -d)
                oc get secret "$src" -n openshift-ingress -o jsonpath='{.data.tls\.crt}' | base64 -d > "$tmpdir_cert/tls.crt"
                oc get secret "$src" -n openshift-ingress -o jsonpath='{.data.tls\.key}' | base64 -d > "$tmpdir_cert/tls.key"
                oc create secret tls default-gateway-tls \
                    --cert="$tmpdir_cert/tls.crt" --key="$tmpdir_cert/tls.key" \
                    -n openshift-ingress --dry-run=client -o yaml | \
                    oc label --local -f - app.kubernetes.io/managed-by=rhoai-toolkit --dry-run=client -o yaml | \
                    oc apply -f -
                rm -rf "$tmpdir_cert"
                print_success "default-gateway-tls created from '$src'"
                return 0
            fi
        fi
    done

    # Strategy 3: Check openshift-ingress-operator for router-ca
    if oc get secret router-ca -n openshift-ingress-operator &>/dev/null 2>&1; then
        print_info "Using OpenShift router-ca to generate self-signed gateway cert..."
        local ca_crt ca_key
        ca_crt=$(oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.crt}' | base64 -d)
        ca_key=$(oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.key}' | base64 -d)
        local tmpdir
        tmpdir=$(mktemp -d)
        echo "$ca_crt" > "$tmpdir/ca.crt"
        echo "$ca_key" > "$tmpdir/ca.key"
        openssl req -new -newkey rsa:2048 -nodes \
            -keyout "$tmpdir/tls.key" -out "$tmpdir/tls.csr" \
            -subj "/CN=*.apps.${CLUSTER_DOMAIN}" \
            -addext "subjectAltName=DNS:*.apps.${CLUSTER_DOMAIN},DNS:apps.${CLUSTER_DOMAIN}" 2>/dev/null
        openssl x509 -req -in "$tmpdir/tls.csr" -CA "$tmpdir/ca.crt" -CAkey "$tmpdir/ca.key" \
            -CAcreateserial -out "$tmpdir/tls.crt" -days 365 \
            -extfile <(printf "subjectAltName=DNS:*.apps.${CLUSTER_DOMAIN},DNS:apps.${CLUSTER_DOMAIN}") 2>/dev/null
        oc create secret tls default-gateway-tls \
            --cert="$tmpdir/tls.crt" --key="$tmpdir/tls.key" \
            -n openshift-ingress 2>/dev/null
        rm -rf "$tmpdir"
        print_success "default-gateway-tls created (signed by router-ca)"
        return 0
    fi

    print_error "Could not create default-gateway-tls — no cert-manager, wildcard cert, or router-ca found"
    print_info "Create it manually: oc create secret tls default-gateway-tls --cert=tls.crt --key=tls.key -n openshift-ingress"
    return 1
}

create_gateway_passthrough_routes() {
    # The *.apps.<cluster> wildcard DNS points to the default OpenShift Router,
    # but gateway pods get their own LoadBalancer. A passthrough Route bridges them.
    local gateways=("maas-default-gateway:maas" "openshift-ai-inference:inference-gateway")

    for entry in "${gateways[@]}"; do
        local gw_name="${entry%%:*}"
        local hostname_prefix="${entry##*:}"
        local route_name="${gw_name}-passthrough"
        local hostname="${hostname_prefix}.apps.${CLUSTER_DOMAIN}"

        if oc get route "$route_name" -n openshift-ingress &>/dev/null; then
            print_info "Passthrough route '$route_name' already exists"
            continue
        fi

        local svc_name
        svc_name=$(oc get svc -n openshift-ingress -l "gateway.networking.k8s.io/gateway-name=${gw_name}" \
            -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

        if [ -z "$svc_name" ]; then
            print_warning "No service found for gateway '$gw_name' — skipping passthrough route"
            continue
        fi

        print_step "Creating passthrough route: ${hostname} → ${svc_name}..."
        export ROUTE_NAME="$route_name"
        export HOSTNAME="$hostname"
        export SERVICE_NAME="$svc_name"
        envsubst '${ROUTE_NAME} ${HOSTNAME} ${SERVICE_NAME}' \
            < "$ROOT_DIR/lib/manifests/rhcl/gateway-passthrough-route.yaml" | oc_apply_retry
    done
    print_success "Gateway passthrough routes configured"
}

create_hardware_profile() {
    print_step "Creating default GPU hardware profile..."

    oc apply -f "$ROOT_DIR/lib/manifests/rhoai/hardware-profile-gpu.yaml"

    print_success "Hardware profile created"
}

################################################################################
# Monitoring Dashboards
################################################################################

deploy_observe_dashboards() {
    print_step "Deploying dashboards to OpenShift Observe tab..."

    local dashboard_dir="$ROOT_DIR/lib/manifests/dashboards"
    local namespace="openshift-config-managed"

    local cm_names="nvidia-dcgm-exporter-dashboard vllm-performance-dashboard vllm-advanced-dashboard"
    local cm_files="dcgm-exporter-dashboard.json vllm-performance-ocp.json vllm-advanced-ocp.json"

    local i=1
    for cm_name in $cm_names; do
        local file
        file=$(echo "$cm_files" | cut -d' ' -f"$i")
        i=$((i + 1))
        if [ ! -f "$dashboard_dir/$file" ]; then
            print_warning "Dashboard file not found: $dashboard_dir/$file"
            continue
        fi

        if oc get configmap "$cm_name" -n "$namespace" &>/dev/null; then
            print_info "Dashboard '$cm_name' already exists [SKIP]"
            continue
        fi

        oc create configmap "$cm_name" \
            -n "$namespace" \
            --from-file="$dashboard_dir/$file"

        oc label configmap "$cm_name" \
            -n "$namespace" \
            "console.openshift.io/dashboard=true" --overwrite

        oc label configmap "$cm_name" \
            -n "$namespace" \
            "console.openshift.io/odc-dashboard=true" --overwrite
    done

    print_success "Dashboards deployed -> Observe > Dashboards"
}

deploy_grafana_monitoring() {
    print_step "Deploying Grafana monitoring stack..."

    local grafana_ns="monitoring"
    oc create namespace "$grafana_ns" 2>/dev/null || true

    if oc get deployment grafana -n "$grafana_ns" &>/dev/null; then
        print_info "Grafana already deployed [SKIP]"
    else
        oc apply -f "$ROOT_DIR/lib/manifests/grafana/grafana-deployment.yaml" -n "$grafana_ns"
        print_step "Waiting for Grafana pod..."
        oc wait --for=condition=ready pod -l app=grafana -n "$grafana_ns" --timeout=120s 2>/dev/null || true
        print_success "Grafana deployed"
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/grafana/prometheus-token.yaml" 2>/dev/null || true

    local token=""
    local retries=0
    while [ $retries -lt 6 ] && [ -z "$token" ]; do
        token=$(oc get secret grafana-prometheus-token -n openshift-monitoring \
            -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null)
        [ -z "$token" ] && sleep 5 && retries=$((retries + 1))
    done

    if [ -z "$token" ]; then
        token=$(oc create token prometheus-k8s -n openshift-monitoring --duration=87600h 2>/dev/null || true)
    fi

    if [ -z "$token" ]; then
        print_warning "Could not get Prometheus token for Grafana datasource"
        return 0
    fi

    local grafana_route
    grafana_route=$(oc get route grafana -n "$grafana_ns" -o jsonpath='{.spec.host}' 2>/dev/null)

    if [ -n "$grafana_route" ]; then
        print_step "Configuring Prometheus datasource..."
        curl -sk -X POST "https://${grafana_route}/api/datasources" \
            -u admin:admin \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"Prometheus\",
                \"type\": \"prometheus\",
                \"url\": \"https://thanos-querier.openshift-monitoring.svc:9091\",
                \"access\": \"proxy\",
                \"isDefault\": true,
                \"jsonData\": {
                    \"httpHeaderName1\": \"Authorization\",
                    \"tlsSkipVerify\": true
                },
                \"secureJsonData\": {
                    \"httpHeaderValue1\": \"Bearer ${token}\"
                }
            }" &>/dev/null && print_success "Prometheus datasource configured" \
            || print_info "Datasource may already exist"

        for dashboard_file in "$ROOT_DIR"/lib/manifests/grafana/*-dashboard.json; do
            [ -f "$dashboard_file" ] || continue
            local dash_name
            dash_name=$(basename "$dashboard_file" .json)
            print_step "Importing dashboard: $dash_name..."
            local dash_json
            dash_json=$(cat "$dashboard_file")
            curl -sk -X POST "https://${grafana_route}/api/dashboards/db" \
                -u admin:admin \
                -H "Content-Type: application/json" \
                -d "{\"dashboard\": ${dash_json}, \"overwrite\": true}" &>/dev/null \
                && print_success "  Imported: $dash_name" \
                || print_warning "  Failed to import: $dash_name"
        done
    fi

    get_cluster_domain
    export CLUSTER_DOMAIN
    envsubst '${CLUSTER_DOMAIN}' < "$ROOT_DIR/lib/manifests/monitoring/consolelinks-grafana.yaml" | oc apply -f - 2>/dev/null || true
    envsubst '${CLUSTER_DOMAIN}' < "$ROOT_DIR/lib/manifests/monitoring/odhapplication-grafana.yaml" | oc apply -f - 2>/dev/null || true

    print_success "Grafana monitoring stack deployed"
    if [ -n "$grafana_route" ]; then
        print_info "Grafana URL: https://${grafana_route}"
        print_info "Dashboards: GPU Metrics (DCGM), vLLM Inference, vLLM Advanced"
    fi
}

create_mlflow_server() {
    print_step "Creating MLflow server instance..."

    if oc get mlflow mlflow &>/dev/null 2>&1; then
        local mlflow_ready=$(oc get mlflow mlflow -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$mlflow_ready" = "True" ]; then
            print_success "MLflow server already exists and is ready"
            return 0
        fi
        print_info "MLflow server exists but not yet ready"
        return 0
    fi

    if ! oc get crd mlflows.mlflow.opendatahub.io &>/dev/null 2>&1; then
        print_warning "MLflow CRD not found — MLflow operator may not be ready yet"
        print_info "You can create it later: oc apply -f <mlflow-cr.yaml>"
        return 0
    fi

    if oc get deployment postgres -n "$MAAS_INFRA_NS" &>/dev/null; then
        print_info "Using existing PostgreSQL (in $MAAS_INFRA_NS) for MLflow backend..."
        local pg_pod
        pg_pod=$(oc get pods -n "$MAAS_INFRA_NS" -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ -n "$pg_pod" ]; then
            oc exec "$pg_pod" -n "$MAAS_INFRA_NS" -- bash -c \
                'PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='"'"'mlflow'"'"'" | grep -q 1 || \
                 PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -c "CREATE DATABASE mlflow OWNER maas;"' 2>/dev/null || true
        fi

        local pg_url
        pg_url=$(oc get secret maas-db-config -n "$MAAS_INFRA_NS" \
            -o jsonpath='{.data.DB_CONNECTION_URL}' 2>/dev/null | base64 -d 2>/dev/null | sed 's|/maas|/mlflow|')

        if [ -n "$pg_url" ]; then
            oc create secret generic mlflow-db-credentials \
                --from-literal=database-url="$pg_url" \
                -n redhat-ods-applications \
                --dry-run=client -o yaml | oc apply -f - 2>/dev/null

            oc apply -f - <<'EOF'
apiVersion: mlflow.opendatahub.io/v1
kind: MLflow
metadata:
  name: mlflow
spec:
  replicas: 1
  backendStoreUriFrom:
    name: mlflow-db-credentials
    key: database-url
  serveArtifacts: true
  artifactsDestination: "file:///mlflow/artifacts"
  storage:
    size: 10Gi
EOF
            print_info "MLflow configured with PostgreSQL backend"
        else
            print_warning "Could not read PostgreSQL URL, falling back to SQLite"
            oc apply -f "$ROOT_DIR/lib/manifests/rhoai/mlflow-cr.yaml"
        fi
    else
        oc apply -f "$ROOT_DIR/lib/manifests/rhoai/mlflow-cr.yaml"
        print_info "MLflow configured with SQLite backend (PVC)"
    fi

    print_step "Waiting for MLflow server to be ready..."
    local wait=0
    while [ $wait -lt 180 ]; do
        local ready=$(oc get mlflow mlflow -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$ready" = "True" ]; then
            local url=$(oc get mlflow mlflow -o jsonpath='{.status.url}' 2>/dev/null)
            print_success "MLflow server is ready: ${url}"
            return 0
        fi
        sleep 10
        wait=$((wait + 10))
    done

    print_warning "MLflow server not ready yet (may still be starting) — check: oc get mlflow mlflow"
}

# verify_maas_deployment() has been removed: this is now setup-maas.sh's
# phase5_verify() (single source of truth, called via --called-from-installer
# --from-phase 3 in main() below).

################################################################################
# User Management
################################################################################

setup_demo_users() {
    local num_users="${1:-5}"
    local admin_group="${2:-rhods-admins}"
    local user_group="${3:-rhods-users}"
    local password="${4:-openshift}"

    print_step "Setting up ${num_users} demo users with groups '${admin_group}' and '${user_group}'..."

    # Ensure htpasswd is available
    if ! command -v htpasswd &>/dev/null; then
        if command -v python3 &>/dev/null; then
            _htpasswd_add() {
                local file="$1" user="$2" pass="$3"
                local hash
                hash=$(python3 -c "import bcrypt; print(bcrypt.hashpw('${pass}'.encode(), bcrypt.gensalt()).decode())" 2>/dev/null) || \
                hash=$(python3 -c "import passlib.hash; print(passlib.hash.bcrypt.hash('${pass}'))" 2>/dev/null) || \
                hash=$(openssl passwd -apr1 "${pass}" 2>/dev/null)
                echo "${user}:${hash}" >> "$file"
            }
        else
            print_error "htpasswd or python3 required for user creation"
            return 1
        fi
    fi

    local tmpdir
    tmpdir=$(mktemp -d)
    local htpasswd_file="${tmpdir}/htpasswd"
    touch "$htpasswd_file"

    # Collect existing htpasswd data if it exists
    if oc get secret htpasswd-secret -n openshift-config &>/dev/null 2>&1; then
        oc get secret htpasswd-secret -n openshift-config -o jsonpath='{.data.htpasswd}' 2>/dev/null \
            | base64 -d > "$htpasswd_file" 2>/dev/null || true
    fi

    local admin_users=""
    local regular_users=""

    for i in $(seq 1 "$num_users"); do
        local username="user${i}"
        if grep -q "^${username}:" "$htpasswd_file" 2>/dev/null; then
            print_info "User '${username}' already exists in htpasswd — skipping"
        else
            if command -v htpasswd &>/dev/null; then
                htpasswd -bB "$htpasswd_file" "$username" "$password" 2>/dev/null
            else
                _htpasswd_add "$htpasswd_file" "$username" "$password"
            fi
            print_info "Created user '${username}'"
        fi

        if [ "$i" -eq 1 ]; then
            admin_users="${username}"
        else
            regular_users="${regular_users:+${regular_users},}${username}"
        fi
    done

    # Create/update htpasswd secret
    oc create secret generic htpasswd-secret \
        --from-file=htpasswd="$htpasswd_file" \
        -n openshift-config --dry-run=client -o yaml | oc apply -f -

    # Ensure htpasswd identity provider is configured
    local has_htpasswd
    has_htpasswd=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[?(@.name=="htpasswd")].name}' 2>/dev/null || true)
    if [ -z "$has_htpasswd" ]; then
        print_step "Adding htpasswd identity provider to OAuth..."
        oc patch oauth cluster --type=json -p '[{
            "op": "add",
            "path": "/spec/identityProviders/-",
            "value": {
                "name": "htpasswd",
                "type": "HTPasswd",
                "mappingMethod": "claim",
                "htpasswd": {
                    "fileData": {
                        "name": "htpasswd-secret"
                    }
                }
            }
        }]' 2>/dev/null || {
            oc patch oauth cluster --type=merge -p '{
                "spec": {
                    "identityProviders": [{
                        "name": "htpasswd",
                        "type": "HTPasswd",
                        "mappingMethod": "claim",
                        "htpasswd": {
                            "fileData": {
                                "name": "htpasswd-secret"
                            }
                        }
                    }]
                }
            }' 2>/dev/null
        }
        print_info "OAuth will restart — users may take 1-2 minutes to become available"
    fi

    # Create groups
    for grp in "$admin_group" "$user_group"; do
        if ! oc get group "$grp" &>/dev/null 2>&1; then
            print_step "Creating group '${grp}'..."
            oc adm groups new "$grp" 2>/dev/null || true
        fi
    done

    # Add user1 to admin group, rest to user group
    if [ -n "$admin_users" ]; then
        print_step "Adding ${admin_users} to '${admin_group}' (admin)..."
        oc adm groups add-users "$admin_group" "$admin_users" 2>/dev/null || true
        # Give cluster-admin to admin users for RHOAI dashboard access
        oc adm policy add-cluster-role-to-user cluster-admin "$admin_users" 2>/dev/null || true
    fi

    if [ -n "$regular_users" ]; then
        local IFS=','
        for u in $regular_users; do
            oc adm groups add-users "$user_group" "$u" 2>/dev/null || true
        done
        unset IFS
        print_step "Added ${num_users-1} users to '${user_group}' (regular)"
    fi

    rm -rf "$tmpdir"

    print_success "Demo users created:"
    echo -e "  ${CYAN}Admin group (${admin_group}):${NC} ${admin_users}"
    echo -e "  ${CYAN}User group (${user_group}):${NC} ${regular_users}"
    echo -e "  ${CYAN}Password:${NC} ${password}"
    echo -e "  ${CYAN}Login:${NC} oc login -u user1 -p ${password}"
    echo ""
    echo -e "  ${YELLOW}Note:${NC} When creating MaaS Subscriptions, set owner group to '${admin_group}' or '${user_group}'"
    echo -e "  ${YELLOW}Note:${NC} Users may take 1-2 minutes to be available after OAuth restart"
}

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
