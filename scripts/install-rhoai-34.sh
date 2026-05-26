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

# Default options
SKIP_PREREQUISITES=false
SKIP_RHCL=false
SKIP_MAAS=false
SKIP_NODE_SCALING=false
SKIP_MAAS_DB=false
ENABLE_LLMD=true
ENABLE_VLLM_MAAS=false
ENABLE_OBSERVABILITY=false
POSTGRES_CONNECTION=""
CLUSTER_DOMAIN=""
WAIT_TIMEOUT=600
RHOAI_CHANNEL=""
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
    echo "  --postgres-connection <url>  External PostgreSQL for MaaS (skips POC DB deployment)"
    echo "                         Format: postgresql://user:pass@host:5432/db?sslmode=require"
    echo "  --skip-maas-db         Skip MaaS PostgreSQL setup entirely"
    echo "  --channel <channel>    RHOAI channel (e.g., fast-3.x, stable-3.4). If not specified, will prompt."
    echo "  --domain <domain>      Cluster domain (e.g., cluster.example.com)"
    echo "  --timeout <seconds>    Wait timeout for operators (default: 600)"
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
        print_error "RHOAI 3.4 requires OpenShift 4.19 or later. Current: $ocp_version"
        exit 1
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

create_admin_user() {
    local admin_user="admin"
    local admin_pass='R3dh4t1!'

    print_step "Creating OAuth admin user '$admin_user'..."

    # Check if htpasswd CLI is available
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

    if grep -q "^${admin_user}:" "$htpasswd_tmp" 2>/dev/null; then
        print_info "User '$admin_user' already exists in htpasswd"
    else
        htpasswd -bB "$htpasswd_tmp" "$admin_user" "$admin_pass"
        print_success "User '$admin_user' added to htpasswd"
    fi

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

    # Wait for OAuth pods to restart so the new user becomes available
    print_step "Waiting for OAuth pods to restart..."
    local api_server
    api_server=$(oc whoami --show-server)

    local elapsed=0
    local timeout=120
    local interval=10

    # Give OAuth a moment to begin rolling out
    sleep 10
    elapsed=10

    while [ $elapsed -lt $timeout ]; do
        if oc login -u "$admin_user" -p "$admin_pass" "$api_server" --insecure-skip-tls-verify=true &>/dev/null; then
            print_success "Logged in as '$admin_user'"
            echo ""
            print_info "Session switched from kube:admin to $admin_user (cluster-admin)"
            print_info "All subsequent operations will run as '$admin_user'"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        echo "  Waiting for OAuth... (${elapsed}s/${timeout}s)"
    done

    print_warning "Could not log in as '$admin_user' within ${timeout}s"
    print_info "OAuth may still be restarting. Continuing as $(oc whoami)..."
    print_info "You can log in manually later: oc login -u $admin_user -p '$admin_pass' $api_server"
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

    oc apply -f - <<EOF
apiVersion: operator.openshift.io/v1
kind: LeaderWorkerSetOperator
metadata:
  name: cluster
  namespace: openshift-lws-operator
spec:
  managementState: Managed
  logLevel: Normal
  operatorLogLevel: Normal
EOF

    print_success "LWS Operator installed"
}

install_servicemesh_operator() {
    print_step "Installing OpenShift Service Mesh 3 Operator..."

    if oc get csv -n openshift-operators 2>/dev/null | grep -q "servicemeshoperator3.*Succeeded"; then
        print_info "Service Mesh 3 Operator already installed and ready"
    else
        if ! oc get subscription servicemeshoperator3 -n openshift-operators &>/dev/null; then
            oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: servicemeshoperator3
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Manual
  name: servicemeshoperator3
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
        fi

        print_step "Waiting for Service Mesh InstallPlan to be created..."
        local ip_wait=0
        local ip_timeout=60
        while [ $ip_wait -lt $ip_timeout ]; do
            local has_plan=$(oc get installplan -n openshift-operators -o json 2>/dev/null | \
                jq -r '[.items[] | select(.spec.approved == false) | select(.spec.clusterServiceVersionNames[] | test("servicemesh|kiali"))] | length' 2>/dev/null)
            if [ -n "$has_plan" ] && [ "$has_plan" -gt 0 ]; then
                print_info "Found pending InstallPlan(s)"
                break
            fi
            sleep 5
            ip_wait=$((ip_wait + 5))
        done

        approve_servicemesh_installplans

        print_step "Waiting for Service Mesh operator to be ready..."
        local timeout=300
        local elapsed=0
        until oc get csv -n openshift-operators 2>/dev/null | grep -q "servicemeshoperator3.*Succeeded"; do
            if [ $elapsed -ge $timeout ]; then
                print_warning "Service Mesh operator not ready after ${timeout}s (continuing anyway)"
                break
            fi
            approve_servicemesh_installplans 2>/dev/null || true
            sleep 10
            elapsed=$((elapsed + 10))
        done
    fi

    approve_servicemesh_installplans 2>/dev/null || true

    print_success "Service Mesh 3 Operator installed"
}

approve_servicemesh_installplans() {
    local approved_any=false

    local all_pending=$(oc get installplan -n openshift-operators --no-headers 2>/dev/null | awk '{print $1}')
    for plan in $all_pending; do
        local is_approved=$(oc get installplan "$plan" -n openshift-operators -o jsonpath='{.spec.approved}' 2>/dev/null)
        if [ "$is_approved" = "false" ]; then
            local csv_names=$(oc get installplan "$plan" -n openshift-operators -o jsonpath='{.spec.clusterServiceVersionNames[*]}' 2>/dev/null)
            if echo "$csv_names" | grep -qiE "servicemesh|kiali|sail"; then
                print_step "Approving InstallPlan: $plan (CSVs: $csv_names)"
                oc patch installplan "$plan" -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
                print_success "Approved InstallPlan: $plan"
                approved_any=true
            fi
        fi
    done

    if [ "$approved_any" = true ]; then
        sleep 10
    fi
}

approve_rhcl_installplans() {
    local all_pending=$(oc get installplan -n openshift-operators --no-headers 2>/dev/null | awk '{print $1}')
    for plan in $all_pending; do
        local is_approved=$(oc get installplan "$plan" -n openshift-operators -o jsonpath='{.spec.approved}' 2>/dev/null)
        if [ "$is_approved" = "false" ]; then
            local csv_names=$(oc get installplan "$plan" -n openshift-operators -o jsonpath='{.spec.clusterServiceVersionNames[*]}' 2>/dev/null)
            if echo "$csv_names" | grep -qiE "rhcl|authorino|limitador|dns-operator"; then
                print_step "Approving RHCL InstallPlan: $plan"
                print_info "  CSVs: $csv_names"
                oc patch installplan "$plan" -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
                print_success "Approved InstallPlan: $plan"
            fi
        fi
    done
}

setup_istio_for_kuadrant() {
    print_step "Setting up Istio for Kuadrant..."

    oc create namespace istio-system 2>/dev/null || true
    oc create namespace istio-cni 2>/dev/null || true

    if oc get istio default -n istio-system &>/dev/null; then
        print_info "Istio instance already exists in istio-system"
    else
        local istio_version=$(oc get istio -A -o jsonpath='{.items[0].spec.version}' 2>/dev/null || echo "v1.26.2")

        print_step "Creating IstioCNI..."
        oc apply -f - <<EOF
apiVersion: sailoperator.io/v1
kind: IstioCNI
metadata:
  name: default
  namespace: istio-system
spec:
  namespace: istio-cni
  version: $istio_version
EOF

        print_step "Waiting for IstioCNI to be ready..."
        local elapsed=0
        local timeout=120
        while [ $elapsed -lt $timeout ]; do
            local cni_ready=$(oc get istiocni default -n istio-cni -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            if [ "$cni_ready" = "True" ]; then
                print_success "IstioCNI is ready"
                break
            fi
            sleep 10
            elapsed=$((elapsed + 10))
            echo "  Waiting for IstioCNI... (${elapsed}s elapsed)"
        done

        print_step "Creating Istio instance in istio-system..."
        oc apply -f - <<EOF
apiVersion: sailoperator.io/v1
kind: Istio
metadata:
  name: default
  namespace: istio-system
spec:
  namespace: istio-system
  version: $istio_version
EOF

        print_step "Waiting for Istio to be healthy..."
        elapsed=0
        timeout=180
        while [ $elapsed -lt $timeout ]; do
            local istio_status=$(oc get istio default -n istio-system -o jsonpath='{.status.state}' 2>/dev/null)
            if [ "$istio_status" = "Healthy" ]; then
                print_success "Istio is healthy"
                break
            fi
            sleep 10
            elapsed=$((elapsed + 10))
            echo "  Waiting for Istio... Status: $istio_status (${elapsed}s elapsed)"
        done
    fi

    if ! oc get gatewayclass openshift-default &>/dev/null; then
        print_step "Creating openshift-default GatewayClass..."
        oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-default
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
    fi

    print_success "Istio setup complete for Kuadrant"
}

restart_kuadrant_operator() {
    print_step "Restarting Kuadrant operator to detect Istio..."

    local pod_name=$(oc get pods -n kuadrant-system -o name 2>/dev/null | grep kuadrant-operator-controller)
    if [ -n "$pod_name" ]; then
        oc delete $pod_name -n kuadrant-system 2>/dev/null || true
        sleep 20
    fi

    print_step "Waiting for Kuadrant to be ready..."
    local elapsed=0
    local timeout=120
    while [ $elapsed -lt $timeout ]; do
        local kuadrant_ready=$(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        local kuadrant_reason=$(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)

        if [ "$kuadrant_ready" = "True" ]; then
            print_success "Kuadrant is ready"
            return 0
        fi

        sleep 10
        elapsed=$((elapsed + 10))
        echo "  Waiting for Kuadrant... Reason: $kuadrant_reason (${elapsed}s elapsed)"
    done

    print_warning "Kuadrant may not be fully ready. Check: oc get kuadrant -n kuadrant-system"
}

install_rhcl_operator() {
    # RHOAI 3.4 MaaS prerequisite (Govern LLM access with Models-as-a-Service, §1.2):
    #   "installed the Red Hat Connectivity Link Operator version 1.2 or later
    #    to the openshift-operators namespace and created a Kuadrant custom resource
    #    in the kuadrant-system namespace with ready status."
    #
    # Note: RHCL 1.3's own docs put everything in kuadrant-system. Both patterns work
    # (AllNamespaces mode). We follow RHOAI's documented prerequisite since this is an RHOAI toolkit.
    #
    # Service Mesh 3 (Sail) is auto-installed as an OLM dependency. It uses Manual InstallPlan
    # approval, so we must ensure plans are approved.
    print_step "Installing Red Hat Connectivity Link (RHCL) v1.2+ Operator..."

    # Service Mesh 3 comes in as an OLM dependency — ensure it's installed and plans approved
    install_servicemesh_operator

    # Check if RHCL already installed
    if oc get csv -n openshift-operators 2>/dev/null | grep -q "rhcl-operator"; then
        print_info "RHCL Operator already installed in openshift-operators"
    elif oc get csv -n kuadrant-system 2>/dev/null | grep -q "rhcl-operator"; then
        print_info "RHCL Operator already installed in kuadrant-system"
    else
        # Subscription goes to openshift-operators (per RHOAI 3.4 MaaS docs)
        # openshift-operators already has a default OperatorGroup — no need to create one
        oc apply -f "$ROOT_DIR/lib/manifests/rhcl/rhcl-operator-34.yaml"

        # Wait for Subscription to create an InstallPlan
        print_step "Waiting for RHCL InstallPlan..."
        local ip_wait=0
        while [ $ip_wait -lt 60 ]; do
            if oc get subscription rhcl-operator -n openshift-operators \
                -o jsonpath='{.status.installPlanRef.name}' &>/dev/null; then
                break
            fi
            sleep 5
            ip_wait=$((ip_wait + 5))
        done

        # Auto-approve RHCL InstallPlan (OLM may set Manual even with Automatic
        # when dependency operators like Authorino/DNS/Limitador are being upgraded)
        approve_rhcl_installplans

        # Wait for operator with periodic re-approval (InstallPlan may appear late)
        print_step "Waiting for rhcl-operator to be ready..."
        local rhcl_elapsed=0
        local rhcl_timeout=300
        while [ $rhcl_elapsed -lt $rhcl_timeout ]; do
            local rhcl_csv=$(oc get csv -n openshift-operators 2>/dev/null | grep "rhcl-operator" | head -1)
            local rhcl_status=$(echo "$rhcl_csv" | awk '{print $NF}')
            
            if [ "$rhcl_status" = "Succeeded" ]; then
                print_success "rhcl-operator is ready"
                break
            fi
            
            # Re-approve any pending InstallPlans on each iteration
            approve_rhcl_installplans 2>/dev/null || true
            
            if [ -z "$rhcl_csv" ] && [ $((rhcl_elapsed % 30)) -eq 0 ] && [ $rhcl_elapsed -gt 0 ]; then
                echo "  rhcl-operator: CSV not yet created — ${rhcl_elapsed}s elapsed"
            elif [ -n "$rhcl_status" ] && [ "$rhcl_status" != "Succeeded" ]; then
                echo "  rhcl-operator: $rhcl_status — ${rhcl_elapsed}s elapsed"
            fi
            
            sleep 10
            rhcl_elapsed=$((rhcl_elapsed + 10))
        done
        
        if [ $rhcl_elapsed -ge $rhcl_timeout ]; then
            print_warning "rhcl-operator may not be fully ready (continuing)"
        fi
    fi

    # Verify RHCL component operators (Authorino, DNS, Limitador)
    # These are installed by the RHCL operator as dependencies
    print_step "Verifying RHCL component operators..."
    local comp_timeout=120
    local comp_elapsed=0
    local all_found=false
    while [ $comp_elapsed -lt $comp_timeout ]; do
        all_found=true
        for component in "authorino" "dns" "limitador"; do
            if ! oc get csv -n openshift-operators 2>/dev/null | grep -qi "$component.*Succeeded"; then
                all_found=false
                break
            fi
        done
        if [ "$all_found" = true ]; then
            break
        fi
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

    # Kuadrant CR goes in kuadrant-system (per RHOAI 3.4 MaaS docs)
    oc create namespace kuadrant-system 2>/dev/null || true

    print_step "Creating Kuadrant instance in kuadrant-system..."
    oc apply -f "$ROOT_DIR/lib/manifests/rhcl/kuadrant-instance.yaml"

    setup_istio_for_kuadrant

    restart_kuadrant_operator

    print_success "RHCL Operator installed and configured"
}

setup_maas_database() {
    # PostgreSQL 14+ is required for MaaS API key validation
    # Secret format: DB_CONNECTION_URL='postgresql://user:pass@host:5432/db?sslmode=require'
    # Reference: https://opendatahub-io.github.io/models-as-a-service/latest/install/maas-setup/#database-setup
    print_step "Setting up MaaS PostgreSQL database..."

    if oc get secret maas-db-config -n redhat-ods-applications &>/dev/null; then
        print_success "maas-db-config secret already exists in redhat-ods-applications"
        return 0
    fi

    # If user provided a connection string via --postgres-connection, use it
    if [ -n "$POSTGRES_CONNECTION" ]; then
        print_step "Creating maas-db-config secret from provided connection string..."
        printf '%s' "$POSTGRES_CONNECTION" | \
            oc create secret generic maas-db-config \
                --from-file=DB_CONNECTION_URL=/dev/stdin \
                --dry-run=client -o yaml | \
            oc label --local -f - app=maas-api --dry-run=client -o yaml | \
            oc apply -n redhat-ods-applications -f -
        print_success "maas-db-config secret created from provided connection string"
        return 0
    fi

    # Deploy a POC-grade PostgreSQL instance (NOT for production)
    print_warning "No --postgres-connection provided. Deploying POC PostgreSQL (NOT for production)."
    print_info "For production, use AWS RDS, Crunchy Operator, or Azure Database for PostgreSQL."
    print_info "Then pass: --postgres-connection 'postgresql://user:pass@host:5432/db?sslmode=require'"
    echo ""

    local pg_user="maas"
    local pg_db="maas"
    local pg_password
    pg_password="$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)"

    # Resolve PostgreSQL image from RHOAI operator CSV (fallback to default)
    local pg_image
    pg_image=$(oc get csv -l 'olm.copiedFrom=redhat-ods-operator' \
        -o jsonpath='{.items[0].spec.relatedImages[?(@.name=="postgresql_16_image")].image}' 2>/dev/null) || true
    if [ -z "$pg_image" ]; then
        pg_image="registry.redhat.io/rhel9/postgresql-16:latest"
        print_info "Using default PostgreSQL image (operator CSV not available)"
    else
        print_info "Resolved PostgreSQL image from operator CSV"
    fi

    print_step "Deploying POC PostgreSQL in redhat-ods-applications..."
    oc apply -n redhat-ods-applications -f - <<PGEOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  labels:
    app: postgres
    purpose: poc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  labels:
    app: postgres
    purpose: poc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: ${pg_image}
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRESQL_USER
          value: "${pg_user}"
        - name: POSTGRESQL_PASSWORD
          value: "${pg_password}"
        - name: POSTGRESQL_DATABASE
          value: "${pg_db}"
        volumeMounts:
        - name: data
          mountPath: /var/lib/pgsql/data
        resources:
          requests:
            cpu: 250m
            memory: 512Mi
          limits:
            cpu: "1"
            memory: 1Gi
        readinessProbe:
          exec:
            command: ["pg_isready", "-U", "${pg_user}", "-d", "${pg_db}"]
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          exec:
            command: ["pg_isready", "-U", "${pg_user}", "-d", "${pg_db}"]
          initialDelaySeconds: 15
          periodSeconds: 10
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: postgres-data
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  labels:
    app: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
PGEOF

    print_step "Waiting for PostgreSQL to be ready..."
    local elapsed=0
    while [ $elapsed -lt 120 ]; do
        if oc rollout status deployment/postgres -n redhat-ods-applications --timeout=5s &>/dev/null; then
            print_success "PostgreSQL is ready"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    # URL-encode the password (encode all chars to be safe with special chars)
    local encoded_password
    encoded_password=$(printf '%s' "$pg_password" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g')
    local db_url="postgresql://${pg_user}:${encoded_password}@postgres:5432/${pg_db}?sslmode=disable"

    print_step "Creating maas-db-config secret..."
    printf '%s' "$db_url" | \
        oc create secret generic maas-db-config \
            --from-file=DB_CONNECTION_URL=/dev/stdin \
            --dry-run=client -o yaml | \
        oc label --local -f - app=maas-api --dry-run=client -o yaml | \
        oc apply -n redhat-ods-applications -f -

    # Store credentials for reference
    oc create secret generic postgres-creds \
        --from-literal=user="$pg_user" \
        --from-literal=password="$pg_password" \
        --from-literal=database="$pg_db" \
        -n redhat-ods-applications --dry-run=client -o yaml | \
        oc apply -n redhat-ods-applications -f -

    print_success "POC PostgreSQL deployed and maas-db-config secret created"
    print_warning "This is NOT production-grade. For production use:"
    print_info "  - AWS RDS for PostgreSQL"
    print_info "  - Crunchy Postgres Operator"
    print_info "  - Azure Database for PostgreSQL"
    print_info "  Then: oc create secret generic maas-db-config \\"
    print_info "    --from-literal=DB_CONNECTION_URL='postgresql://user:pass@host:5432/db?sslmode=require' \\"
    print_info "    -n redhat-ods-applications"
}

configure_maas_tls() {
    # RHOAI 3.4 MaaS TLS uses OpenShift service-ca (NOT cert-manager)
    # Reference: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/govern_llm_access_with_models-as-a-service/deploy-and-manage-models-as-a-service_maas#configure-tls-for-maas_maas-deploy
    print_step "Configuring TLS for Models-as-a-Service (3.4 service-ca method)..."

    # Step 1: Annotate Authorino service for OpenShift service-ca cert generation
    print_step "Annotating Authorino service for service-ca TLS cert..."
    oc annotate service authorino-authorino-authorization \
        -n kuadrant-system \
        service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
        --overwrite 2>/dev/null || {
        print_warning "Could not annotate Authorino service - it may not exist yet"
        return 1
    }

    # Wait for the service-ca operator to generate the TLS secret
    print_step "Waiting for service-ca to generate authorino-server-cert secret..."
    local cert_wait=0
    while [ $cert_wait -lt 60 ]; do
        if oc get secret authorino-server-cert -n kuadrant-system &>/dev/null; then
            print_success "Authorino TLS certificate generated by service-ca"
            break
        fi
        sleep 5
        cert_wait=$((cert_wait + 5))
    done

    if ! oc get secret authorino-server-cert -n kuadrant-system &>/dev/null; then
        print_warning "authorino-server-cert secret not yet available - service-ca may need more time"
    fi

    # Step 2: Patch Authorino CR to enable TLS listener
    print_step "Patching Authorino CR for TLS listener..."
    oc patch authorino authorino -n kuadrant-system --type=merge --patch '{
      "spec": {
        "listener": {
          "tls": {
            "enabled": true,
            "certSecretRef": {
              "name": "authorino-server-cert"
            }
          }
        }
      }
    }' 2>/dev/null || print_warning "Could not patch Authorino CR"

    # Step 3: Set TLS cert env vars on Authorino deployment for CA validation
    print_step "Configuring Authorino TLS certificate validation env vars..."
    oc -n kuadrant-system set env deployment/authorino \
        SSL_CERT_FILE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt \
        REQUESTS_CA_BUNDLE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt \
        2>/dev/null || print_warning "Could not set Authorino TLS env vars"

    # Step 4: Annotate the MaaS gateway for automatic TLS configuration
    print_step "Annotating maas-default-gateway for Authorino TLS bootstrap..."
    oc annotate gateway maas-default-gateway \
        -n openshift-ingress \
        security.opendatahub.io/authorino-tls-bootstrap="true" \
        --overwrite 2>/dev/null || print_warning "Could not annotate maas-default-gateway (it may not exist yet)"

    # Verification
    print_step "Verifying MaaS TLS configuration..."
    local tls_ok=true

    local cert_annotation=$(oc get service authorino-authorino-authorization -n kuadrant-system \
        -o jsonpath='{.metadata.annotations.service\.beta\.openshift\.io/serving-cert-secret-name}' 2>/dev/null)
    if [ "$cert_annotation" = "authorino-server-cert" ]; then
        print_success "Authorino service has serving-cert annotation"
    else
        print_warning "Authorino service missing serving-cert annotation"
        tls_ok=false
    fi

    local tls_enabled=$(oc get authorino authorino -n kuadrant-system \
        -o jsonpath='{.spec.listener.tls.enabled}' 2>/dev/null)
    if [ "$tls_enabled" = "true" ]; then
        print_success "Authorino TLS listener enabled"
    else
        print_warning "Authorino TLS listener not enabled"
        tls_ok=false
    fi

    if [ "$tls_ok" = true ]; then
        print_success "MaaS TLS configuration complete"
    else
        print_warning "MaaS TLS configuration may be incomplete - check manually"
    fi
}

enable_user_workload_monitoring() {
    print_step "Enabling User Workload Monitoring..."

    oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
    alertmanagerMain:
      enableUserAlertmanagerConfig: true
EOF

    print_success "User Workload Monitoring enabled"
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

    oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
EOF

    print_step "Creating RHOAI subscription with channel: $RHOAI_CHANNEL"
    oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  name: rhods-operator
  channel: $RHOAI_CHANNEL
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

    wait_for_operator "rhods" "redhat-ods-operator"

    print_success "RHOAI Operator installed (channel: $RHOAI_CHANNEL)"
}

create_datasciencecluster() {
    print_step "Creating DataScienceCluster..."

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
                "disableLMEval": false
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
                    "vLLMDeploymentOnMaaS": true
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
                    "disableLMEval": false
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

create_inference_gateway() {
    print_step "Creating inference Gateways for llm-d/MaaS..."

    get_cluster_domain

    # GatewayClass for OpenShift Gateway Controller
    if ! oc get gatewayclass openshift-gateway-controller &>/dev/null; then
        print_step "Creating openshift-gateway-controller GatewayClass..."
        oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-gateway-controller
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
    fi

    # MaaS Gateway - MUST have both annotations for MaaS controller to work in 3.4:
    #   opendatahub.io/managed: "false" - lets MaaS controller manage auth policies
    #   security.opendatahub.io/authorino-tls-bootstrap: "true" - enables TLS to Authorino
    print_step "Creating maas-default-gateway with MaaS annotations..."
    oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: maas-default-gateway
  namespace: openshift-ingress
  annotations:
    opendatahub.io/managed: "false"
    security.opendatahub.io/authorino-tls-bootstrap: "true"
spec:
  gatewayClassName: openshift-gateway-controller
  listeners:
    - allowedRoutes:
        namespaces:
          from: All
      hostname: maas.apps.${CLUSTER_DOMAIN}
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

    # llm-d inference gateway (for direct model access outside MaaS)
    print_step "Creating openshift-ai-inference gateway..."
    if ! oc get gatewayclass openshift-ai-inference &>/dev/null; then
        oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-ai-inference
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
    fi

    oc apply -f - <<EOF
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
      hostname: inference-gateway.apps.${CLUSTER_DOMAIN}
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

    # Create default-gateway-tls secret for the HTTPS listeners
    # Without this, Envoy never creates the port 443 listener and the gateway returns 503
    create_gateway_tls_secret

    # Create passthrough Route so *.apps.<cluster> wildcard DNS reaches the gateway
    # The gateway gets its own LoadBalancer ELB, but *.apps.<cluster> DNS points to the
    # default OpenShift Router. A passthrough Route bridges the two.
    create_gateway_passthrough_routes

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

    # Strategy 1: Use cert-manager Certificate CR if a ClusterIssuer exists
    local issuer
    issuer=$(oc get clusterissuers -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -n "$issuer" ]; then
        print_info "Found ClusterIssuer '$issuer' — creating Certificate CR..."
        oc apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: default-gateway-tls
  namespace: openshift-ingress
spec:
  secretName: default-gateway-tls
  duration: 2160h
  renewBefore: 360h
  commonName: "apps.${CLUSTER_DOMAIN}"
  dnsNames:
    - "apps.${CLUSTER_DOMAIN}"
    - "*.apps.${CLUSTER_DOMAIN}"
  issuerRef:
    name: ${issuer}
    kind: ClusterIssuer
  usages:
    - server auth
    - client auth
EOF
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

    # Strategy 2: Copy from existing wildcard cert (e.g. cert-manager-ingress-cert)
    local wildcard_secrets=("cert-manager-ingress-cert" "router-certs-default")
    for src in "${wildcard_secrets[@]}"; do
        if oc get secret "$src" -n openshift-ingress &>/dev/null 2>&1; then
            local cert_cn
            cert_cn=$(oc get secret "$src" -n openshift-ingress -o jsonpath='{.data.tls\.crt}' 2>/dev/null \
                | base64 -d 2>/dev/null | openssl x509 -noout -subject 2>/dev/null || true)
            if echo "$cert_cn" | grep -q "${CLUSTER_DOMAIN}"; then
                print_info "Copying wildcard cert from '$src'..."
                local tls_crt tls_key
                tls_crt=$(oc get secret "$src" -n openshift-ingress -o jsonpath='{.data.tls\.crt}')
                tls_key=$(oc get secret "$src" -n openshift-ingress -o jsonpath='{.data.tls\.key}')
                oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: default-gateway-tls
  namespace: openshift-ingress
  labels:
    app.kubernetes.io/managed-by: rhoai-toolkit
type: kubernetes.io/tls
data:
  tls.crt: ${tls_crt}
  tls.key: ${tls_key}
EOF
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
        oc apply -f - <<EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: ${route_name}
  namespace: openshift-ingress
  labels:
    app.kubernetes.io/managed-by: rhoai-toolkit
  annotations:
    haproxy.router.openshift.io/timeout: 300s
spec:
  host: ${hostname}
  to:
    kind: Service
    name: ${svc_name}
    weight: 100
  port:
    targetPort: 443
  tls:
    termination: passthrough
EOF
    done
    print_success "Gateway passthrough routes configured"
}

create_hardware_profile() {
    print_step "Creating default GPU hardware profile..."

    oc apply -f - <<EOF
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: gpu-profile
    opendatahub.io/description: 'GPU hardware profile for NVIDIA GPU workloads with tolerations'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
  name: gpu-profile
  namespace: redhat-ods-applications
spec:
  identifiers:
    - defaultCount: '1'
      displayName: CPU
      identifier: cpu
      maxCount: '8'
      minCount: 1
      resourceType: CPU
    - defaultCount: 12Gi
      displayName: Memory
      identifier: memory
      maxCount: 24Gi
      minCount: 1Gi
      resourceType: Memory
    - defaultCount: 1
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: 4
      minCount: 1
      resourceType: Accelerator
  scheduling:
    type: Node
    node:
      nodeSelector:
        nvidia.com/gpu.present: 'true'
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
EOF

    print_success "Hardware profile created"
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

    oc apply -f - <<'EOF'
apiVersion: mlflow.opendatahub.io/v1
kind: MLflow
metadata:
  name: mlflow
spec:
  serveArtifacts: true
  artifactsDestination: "file:///mlflow/artifacts"
  backendStoreUri: "sqlite:////mlflow/mlflow.db"
  storage:
    size: 10Gi
EOF

    print_step "Waiting for MLflow server to be ready..."
    local wait=0
    while [ $wait -lt 120 ]; do
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

verify_maas_deployment() {
    print_step "Verifying MaaS deployment..."

    # Check MaaS CRDs
    local maas_crds=$(oc get crd 2>/dev/null | grep -c "maas.opendatahub.io" || echo "0")
    if [ "$maas_crds" -ge 3 ]; then
        print_success "MaaS CRDs installed ($maas_crds found)"
    else
        print_warning "MaaS CRDs not fully installed yet ($maas_crds found, expected 5)"
        print_info "Expected CRDs: maassubscriptions, maasauthpolicies, maasmodelrefs, tenants, externalmodels"
    fi

    # Check Tenant CR
    local tenant_ready=$(oc get tenant default-tenant -n models-as-a-service \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$tenant_ready" = "True" ]; then
        print_success "MaaS Tenant 'default-tenant' is Ready"
    elif [ -n "$tenant_ready" ]; then
        local tenant_msg=$(oc get tenant default-tenant -n models-as-a-service \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
        print_warning "MaaS Tenant not ready yet: $tenant_msg"
    else
        print_info "MaaS Tenant not found yet (it will be auto-created by the MaaS controller)"
    fi

    # Check maas-db-config secret
    print_step "Checking maas-db-config secret..."
    if oc get secret maas-db-config -n redhat-ods-applications &>/dev/null; then
        local has_url=$(oc get secret maas-db-config -n redhat-ods-applications \
            -o jsonpath='{.data.DB_CONNECTION_URL}' 2>/dev/null)
        if [ -n "$has_url" ]; then
            print_success "maas-db-config secret exists with DB_CONNECTION_URL"
        else
            print_warning "maas-db-config secret exists but may be missing DB_CONNECTION_URL key"
        fi
    else
        print_warning "maas-db-config secret NOT found — MaaS Tenant will show Degraded"
    fi

    # Check User Workload Monitoring
    local uwm=$(oc get configmap cluster-monitoring-config -n openshift-monitoring \
        -o jsonpath='{.data.config\.yaml}' 2>/dev/null | grep -c "enableUserWorkload: true" || echo "0")
    if [ "$uwm" -gt 0 ]; then
        print_success "User Workload Monitoring is enabled"
    else
        print_warning "User Workload Monitoring may not be enabled - MaaS requires it"
    fi

    # Check Gateway
    local gw_exists=$(oc get gateway maas-default-gateway -n openshift-ingress &>/dev/null && echo "yes" || echo "no")
    if [ "$gw_exists" = "yes" ]; then
        local gw_managed=$(oc get gateway maas-default-gateway -n openshift-ingress \
            -o jsonpath='{.metadata.annotations.opendatahub\.io/managed}' 2>/dev/null)
        local gw_tls=$(oc get gateway maas-default-gateway -n openshift-ingress \
            -o jsonpath='{.metadata.annotations.security\.opendatahub\.io/authorino-tls-bootstrap}' 2>/dev/null)
        if [ "$gw_managed" = "false" ] && [ "$gw_tls" = "true" ]; then
            print_success "maas-default-gateway has correct annotations"
        else
            print_warning "maas-default-gateway missing required annotations"
            [ "$gw_managed" != "false" ] && print_info "  Missing: opendatahub.io/managed: \"false\""
            [ "$gw_tls" != "true" ] && print_info "  Missing: security.opendatahub.io/authorino-tls-bootstrap: \"true\""
        fi
    else
        print_warning "maas-default-gateway not found"
    fi

    # Check Authorino TLS
    local auth_tls=$(oc get authorino authorino -n kuadrant-system \
        -o jsonpath='{.spec.listener.tls.enabled}' 2>/dev/null)
    if [ "$auth_tls" = "true" ]; then
        print_success "Authorino TLS listener is enabled"
    else
        print_warning "Authorino TLS listener not enabled"
    fi
}

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
    echo -e "${CYAN}Admin Login:${NC}  admin / R3dh4t1!"
    echo -e "${CYAN}Current User:${NC} $(oc whoami 2>/dev/null)"

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
            --postgres-connection)
                POSTGRES_CONNECTION="$2"
                shift 2
                ;;
            --skip-maas-db)
                SKIP_MAAS_DB=true
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
    create_admin_user

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
        install_rhcl_operator
        create_inference_gateway
    elif [ "$SKIP_RHCL" = false ]; then
        install_rhcl_operator
    else
        print_info "Skipping RHCL/MaaS (--skip-rhcl or --skip-maas)"
    fi

    enable_user_workload_monitoring

    install_rhoai_operator
    create_datasciencecluster

    enable_dashboard_features
    create_hardware_profile
    create_mlflow_server

    # MaaS DB + TLS setup (3.4) - must run after RHCL and gateway are created
    # DB secret must exist BEFORE modelsAsService becomes Managed (or restart maas-api after)
    if [ "$SKIP_RHCL" = false ] && [ "$SKIP_MAAS" = false ]; then
        if [ "$SKIP_MAAS_DB" = false ]; then
            setup_maas_database
        else
            print_info "Skipping MaaS DB setup (--skip-maas-db)"
            if ! oc get secret maas-db-config -n redhat-ods-applications &>/dev/null; then
                print_warning "maas-db-config secret not found — MaaS Tenant will show Degraded"
                print_info "Create it with: oc create secret generic maas-db-config \\"
                print_info "  --from-literal=DB_CONNECTION_URL='postgresql://user:pass@host:5432/db?sslmode=require' \\"
                print_info "  -n redhat-ods-applications"
            fi
        fi
        configure_maas_tls
        verify_maas_deployment
    fi

    if [ "$SETUP_USERS" = true ]; then
        setup_demo_users "$NUM_USERS" "$ADMIN_GROUP" "$USER_GROUP" "$USER_PASSWORD"
    fi

    print_summary
}

main "$@"
exit 0
