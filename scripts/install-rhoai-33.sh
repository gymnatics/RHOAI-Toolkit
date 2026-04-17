#!/bin/bash
################################################################################
# RHOAI 3.3 Installation Script
# Installs Red Hat OpenShift AI 3.3 with all prerequisites
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
ENABLE_LLMD=true
CLUSTER_DOMAIN=""
WAIT_TIMEOUT=600
RHOAI_CHANNEL=""  # Will be selected interactively or via --channel

################################################################################
# Helper Functions
################################################################################

print_banner() {
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║          RHOAI 3.3 Installation Script                         ║${NC}"
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
    echo "  --channel <channel>    RHOAI channel (e.g., fast-3.x, stable-3.3). If not specified, will prompt."
    echo "  --domain <domain>      Cluster domain (e.g., cluster.example.com)"
    echo "  --timeout <seconds>    Wait timeout for operators (default: 600)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --domain cluster.example.com"
    echo "  $0 --channel stable-3.3"
}

wait_for_operator() {
    local operator_name="$1"
    local namespace="$2"
    local timeout="${3:-$WAIT_TIMEOUT}"
    
    print_step "Waiting for $operator_name operator to be ready..."
    
    local elapsed=0
    local interval=10
    
    while [ $elapsed -lt $timeout ]; do
        local status=$(oc get csv -n "$namespace" 2>/dev/null | grep "$operator_name" | awk '{print $NF}')
        if [ "$status" = "Succeeded" ]; then
            print_success "$operator_name operator is ready"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    
    echo ""
    print_error "$operator_name operator did not become ready within ${timeout}s"
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
    
    # Convert to array and sort
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
    
    # Categorize channels for better display
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
    
    # Display fast channels first (latest/preview)
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
    
    # Display stable channels
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
    
    # Display other channels
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
    echo "  • stable-X.Y : Specific version streams (e.g., stable-3.3)"
    echo "  • stable     : Production-ready releases"
    echo ""
    
    # Find default channel index (prefer fast-3.x for 3.3 install)
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
        
        # Use default if empty
        if [ -z "$choice" ]; then
            choice=$default_idx
            break
        fi
        
        # Validate input
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
    
    # Check oc CLI
    if ! command -v oc &> /dev/null; then
        print_error "oc CLI not found. Please install OpenShift CLI."
        exit 1
    fi
    
    # Check cluster connection
    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift cluster. Please run 'oc login' first."
        exit 1
    fi
    
    # Check cluster-admin
    if ! oc auth can-i create clusterrole &> /dev/null; then
        print_error "You need cluster-admin privileges to install RHOAI."
        exit 1
    fi
    
    # Check OpenShift version
    local ocp_version=$(oc version -o json 2>/dev/null | jq -r '.openshiftVersion' | cut -d. -f1,2)
    print_info "OpenShift version: $ocp_version"
    
    if [[ "$ocp_version" < "4.19" ]]; then
        print_error "RHOAI 3.3 requires OpenShift 4.19 or later. Current: $ocp_version"
        exit 1
    fi
    
    if [ "$ENABLE_LLMD" = true ] && [[ "$ocp_version" < "4.20" ]]; then
        print_warning "Distributed inference with llm-d requires OCP 4.20+. Current: $ocp_version"
        print_warning "llm-d will be installed but multi-node inference may not work correctly."
    fi
    
    print_success "Prerequisites check passed"
}

scale_cluster_nodes() {
    print_step "Checking and scaling cluster nodes..."
    
    # Get worker machineset
    local worker_ms=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[?(@.spec.template.metadata.labels.machine\.openshift\.io/cluster-api-machine-role=="worker")].metadata.name}' 2>/dev/null | awk '{print $1}')
    
    if [ -z "$worker_ms" ]; then
        print_warning "No worker machineset found, skipping node scaling"
        return 0
    fi
    
    # Check current worker replicas
    local current_replicas=$(oc get machineset "$worker_ms" -n openshift-machine-api -o jsonpath='{.spec.replicas}' 2>/dev/null)
    print_info "Worker machineset: $worker_ms (current replicas: $current_replicas)"
    
    # Scale workers to at least 2 if less
    if [ "$current_replicas" -lt 2 ]; then
        print_step "Scaling worker nodes to 2..."
        oc scale machineset "$worker_ms" -n openshift-machine-api --replicas=2
        print_success "Worker machineset scaled to 2 replicas"
    else
        print_info "Worker nodes already at $current_replicas replicas"
    fi
    
    # Check for existing GPU machineset
    local gpu_ms=$(oc get machineset -n openshift-machine-api -o name 2>/dev/null | grep -i gpu | head -1)
    
    if [ -n "$gpu_ms" ]; then
        print_info "GPU machineset already exists: $gpu_ms"
        # Scale to at least 1 if currently 0
        local gpu_replicas=$(oc get "$gpu_ms" -n openshift-machine-api -o jsonpath='{.spec.replicas}' 2>/dev/null)
        if [ "$gpu_replicas" -eq 0 ]; then
            print_step "Scaling GPU machineset to 1..."
            oc scale "$gpu_ms" -n openshift-machine-api --replicas=1
            print_success "GPU machineset scaled to 1 replica"
        fi
    else
        # Create GPU machineset using the script
        print_step "Creating GPU machineset..."
        if [ -f "$ROOT_DIR/scripts/create-gpu-machineset.sh" ]; then
            # Get first available AZ from existing worker machineset
            local az=$(oc get machineset "$worker_ms" -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.placement.availabilityZone}' 2>/dev/null)
            
            # Create GPU machineset with g6e.xlarge, 1 replica, and apply
            "$ROOT_DIR/scripts/create-gpu-machineset.sh" --instance-type g6e.xlarge --az "$az" --replicas 1 --apply
            print_success "GPU machineset created and scaled to 1 replica"
        else
            print_warning "GPU machineset script not found, skipping GPU node creation"
        fi
    fi
    
    # Wait for nodes to be ready (non-blocking, just inform)
    print_info "Nodes are scaling in the background. Installation will continue."
    print_info "Check node status with: oc get nodes"
}

install_nfd_operator() {
    print_step "Installing Node Feature Discovery (NFD) Operator..."
    
    if oc get csv -n openshift-nfd 2>/dev/null | grep -q nfd; then
        print_info "NFD Operator already installed"
        return 0
    fi
    
    # Create namespace first
    oc create namespace openshift-nfd 2>/dev/null || true
    
    # Check for existing OperatorGroups and clean up duplicates
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
    
    # Create namespace first
    oc create namespace nvidia-gpu-operator 2>/dev/null || true
    
    # Check for existing OperatorGroups and clean up duplicates
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
    
    # Kueue subscription is in openshift-operators, so CSV is there too
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
    
    # Create namespace if it doesn't exist
    oc create namespace cert-manager-operator 2>/dev/null || true
    
    # Check for existing OperatorGroups and clean up duplicates
    local og_count=$(oc get operatorgroup -n cert-manager-operator -o name 2>/dev/null | wc -l | tr -d ' ')
    if [ "$og_count" -gt 0 ]; then
        print_info "Found $og_count existing OperatorGroup(s) in cert-manager-operator namespace"
        # Delete all existing OperatorGroups to avoid conflicts
        oc delete operatorgroup --all -n cert-manager-operator 2>/dev/null || true
        sleep 2
    fi
    
    # Apply our OperatorGroup
    oc apply -f "$ROOT_DIR/lib/manifests/operators/certmanager-operatorgroup.yaml"
    oc apply -f "$ROOT_DIR/lib/manifests/operators/certmanager-subscription.yaml"
    wait_for_operator "cert-manager" "cert-manager-operator"
    
    print_success "cert-manager Operator installed"
}

install_lws_operator() {
    print_step "Installing Leader Worker Set (LWS) Operator..."
    
    # CSV is named "leader-worker-set", not "lws"
    if oc get csv -n openshift-lws-operator 2>/dev/null | grep -q "leader-worker-set"; then
        print_info "LWS Operator already installed"
        return 0
    fi
    
    # Create namespace
    oc create namespace openshift-lws-operator 2>/dev/null || true
    
    # Check for existing OperatorGroups and clean up duplicates
    local og_count=$(oc get operatorgroup -n openshift-lws-operator -o name 2>/dev/null | wc -l | tr -d ' ')
    if [ "$og_count" -gt 0 ]; then
        print_info "Found $og_count existing OperatorGroup(s) in openshift-lws-operator namespace"
        oc delete operatorgroup --all -n openshift-lws-operator 2>/dev/null || true
        sleep 2
    fi
    
    oc apply -f "$ROOT_DIR/lib/manifests/operators/lws-operatorgroup.yaml"
    oc apply -f "$ROOT_DIR/lib/manifests/operators/lws-subscription.yaml"
    wait_for_operator "leader-worker-set" "openshift-lws-operator"
    
    # Create LWS instance
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
    
    # Check if already installed
    if oc get csv -n openshift-operators 2>/dev/null | grep -q "servicemeshoperator3"; then
        print_info "Service Mesh 3 Operator already installed"
    else
        # Create subscription for Service Mesh 3
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
        
        print_step "Waiting for Service Mesh InstallPlan..."
        sleep 10
    fi
    
    # Check for pending InstallPlans and approve them
    approve_servicemesh_installplans
    
    # Wait for operator to be ready
    wait_for_operator "servicemeshoperator3" "openshift-operators" 300
    
    print_success "Service Mesh 3 Operator installed"
}

approve_servicemesh_installplans() {
    print_step "Checking for pending Service Mesh InstallPlans..."
    
    # Find all pending Service Mesh InstallPlans
    local pending_plans=$(oc get installplan -n openshift-operators -o json 2>/dev/null | \
        jq -r '.items[] | select(.spec.approved == false) | select(.spec.clusterServiceVersionNames[] | contains("servicemeshoperator3")) | .metadata.name' 2>/dev/null)
    
    if [ -n "$pending_plans" ]; then
        for plan in $pending_plans; do
            print_step "Approving InstallPlan: $plan"
            oc patch installplan "$plan" -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
            print_success "Approved InstallPlan: $plan"
        done
        
        # Wait for approval to take effect
        sleep 15
    else
        print_info "No pending Service Mesh InstallPlans found"
    fi
    
    # Also check for any other pending InstallPlans for Service Mesh
    local all_pending=$(oc get installplan -n openshift-operators --no-headers 2>/dev/null | grep -i "false" | awk '{print $1}')
    for plan in $all_pending; do
        local csv_names=$(oc get installplan "$plan" -n openshift-operators -o jsonpath='{.spec.clusterServiceVersionNames[*]}' 2>/dev/null)
        if echo "$csv_names" | grep -qi "servicemesh"; then
            print_step "Approving additional InstallPlan: $plan"
            oc patch installplan "$plan" -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
        fi
    done
}

setup_istio_for_kuadrant() {
    print_step "Setting up Istio for Kuadrant..."
    
    # Create required namespaces
    oc create namespace istio-system 2>/dev/null || true
    oc create namespace istio-cni 2>/dev/null || true
    
    # Check if Istio already exists in istio-system
    if oc get istio default -n istio-system &>/dev/null; then
        print_info "Istio instance already exists in istio-system"
    else
        # Get the Istio version from existing installation or use default
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
        
        # Wait for IstioCNI to be ready
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
        
        # Wait for Istio to be healthy
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
    
    # Create openshift-default GatewayClass (required by RHCL docs)
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
    
    # Delete the pod to force restart
    local pod_name=$(oc get pods -n kuadrant-system -o name 2>/dev/null | grep kuadrant-operator-controller)
    if [ -n "$pod_name" ]; then
        oc delete $pod_name -n kuadrant-system 2>/dev/null || true
        sleep 20
    fi
    
    # Wait for Kuadrant to be ready
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
    print_step "Installing Red Hat Connectivity Link (RHCL) Operator..."
    
    # First, ensure Service Mesh is installed and approved
    install_servicemesh_operator
    
    # Create namespace
    oc create namespace kuadrant-system 2>/dev/null || true
    
    # CSV is named "rhcl-operator", not "kuadrant"
    if oc get csv -n kuadrant-system 2>/dev/null | grep -q "rhcl-operator"; then
        print_info "RHCL Operator already installed"
    else
        # Check for existing OperatorGroups and clean up duplicates
        local og_count=$(oc get operatorgroup -n kuadrant-system -o name 2>/dev/null | wc -l | tr -d ' ')
        if [ "$og_count" -gt 0 ]; then
            print_info "Found $og_count existing OperatorGroup(s) in kuadrant-system namespace"
            oc delete operatorgroup --all -n kuadrant-system 2>/dev/null || true
            sleep 2
        fi
        
        # Install RHCL operator via subscription
        oc apply -f "$ROOT_DIR/lib/manifests/rhcl/rhcl-operator.yaml"
        wait_for_operator "rhcl-operator" "kuadrant-system"
    fi
    
    # Create Kuadrant instance
    print_step "Creating Kuadrant instance..."
    oc apply -f "$ROOT_DIR/lib/manifests/rhcl/kuadrant-instance.yaml"
    
    sleep 10
    
    # Configure Authorino TLS
    print_step "Configuring Authorino TLS..."
    oc annotate svc/authorino-authorino-authorization \
        service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
        -n kuadrant-system 2>/dev/null || true
    
    oc apply -f "$ROOT_DIR/lib/manifests/rhcl/authorino-tls.yaml"
    
    # Setup Istio for Kuadrant (required for AuthPolicy/RateLimitPolicy enforcement)
    setup_istio_for_kuadrant
    
    # Restart Kuadrant operator to detect Istio
    restart_kuadrant_operator
    
    print_success "RHCL Operator installed and configured"
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
    
    # Create namespace
    oc create namespace redhat-ods-operator 2>/dev/null || true
    
    if oc get csv -n redhat-ods-operator 2>/dev/null | grep -q rhods; then
        print_info "RHOAI Operator already installed"
        return 0
    fi
    
    # Select channel if not already specified
    if [ -z "$RHOAI_CHANNEL" ]; then
        select_rhoai_channel
    else
        print_info "Using specified channel: $RHOAI_CHANNEL"
    fi
    
    # Create OperatorGroup
    oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
EOF
    
    # Create Subscription with selected channel
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
    
    oc apply -f "$ROOT_DIR/lib/manifests/rhoai/datasciencecluster-v3.yaml"
    
    print_step "Waiting for DataScienceCluster to be ready..."
    local elapsed=0
    local timeout=600
    
    while [ $elapsed -lt $timeout ]; do
        local phase=$(oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}' 2>/dev/null)
        if [ "$phase" = "Ready" ]; then
            print_success "DataScienceCluster is ready"
            return 0
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        echo -n "."
    done
    
    echo ""
    print_warning "DataScienceCluster may not be fully ready yet"
}

enable_dashboard_features() {
    print_step "Enabling dashboard features..."
    
    # Wait for OdhDashboardConfig to exist
    local elapsed=0
    while [ $elapsed -lt 120 ]; do
        if oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; then
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    oc patch odhdashboardconfig odh-dashboard-config \
        -n redhat-ods-applications \
        --type=merge \
        -p '{
            "spec": {
                "dashboardConfig": {
                    "disableModelRegistry": false,
                    "disableModelCatalog": false,
                    "disableKServeMetrics": false,
                    "genAiStudio": true,
                    "modelAsService": true,
                    "disableLMEval": false
                }
            }
        }' 2>/dev/null || print_warning "Could not patch dashboard config yet"
    
    print_success "Dashboard features enabled"
}

create_inference_gateway() {
    print_step "Creating inference Gateway for llm-d/MaaS..."
    
    get_cluster_domain
    
    # Create GatewayClass for OpenShift Gateway Controller
    oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-gateway-controller
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
    
    # Create maas-default-gateway (required for MaaS component)
    print_step "Creating maas-default-gateway..."
    oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: maas-default-gateway
  namespace: openshift-ingress
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
    
    # Also create openshift-ai-inference gateway for llm-d
    print_step "Creating openshift-ai-inference gateway..."
    oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-ai-inference
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
    
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
    
    print_success "Gateways created"
    print_info "MaaS endpoint: https://maas.apps.${CLUSTER_DOMAIN}"
    print_info "Inference endpoint: https://inference-gateway.apps.${CLUSTER_DOMAIN}"
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
EOF
    
    print_success "Hardware profile created"
}

print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          RHOAI 3.3 Installation Complete!                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local dashboard_url=$(oc get route -n redhat-ods-applications -o jsonpath='{.items[?(@.metadata.name=="data-science-gateway")].spec.host}' 2>/dev/null)
    if [ -z "$dashboard_url" ]; then
        dashboard_url="data-science-gateway.apps.${CLUSTER_DOMAIN}"
    fi
    
    echo -e "${CYAN}Dashboard URL:${NC} https://${dashboard_url}"
    
    if [ "$ENABLE_LLMD" = true ] && [ "$SKIP_RHCL" = false ]; then
        echo -e "${CYAN}Inference Gateway:${NC} https://inference-gateway.apps.${CLUSTER_DOMAIN}"
    fi
    
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Access the dashboard and verify all components are ready"
    echo "  2. Create GPU MachineSets if needed: ./scripts/create-gpu-machineset.sh"
    echo "  3. Deploy a model using the dashboard or CLI"
    echo ""
    echo -e "${BLUE}Verification commands:${NC}"
    echo "  oc get datasciencecluster"
    echo "  oc get csv -n redhat-ods-operator"
    echo "  oc get hardwareprofiles -n redhat-ods-applications"
    echo ""
}

################################################################################
# Main
################################################################################

main() {
    # Parse arguments
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
    
    # Scale up cluster nodes first (workers + GPU)
    if [ "$SKIP_NODE_SCALING" = false ]; then
        scale_cluster_nodes
    else
        print_info "Skipping node scaling (--skip-node-scaling)"
    fi
    
    # Install prerequisite operators
    if [ "$SKIP_PREREQUISITES" = false ]; then
        install_nfd_operator
        install_gpu_operator
        install_kueue_operator
        install_certmanager_operator
        
        if [ "$ENABLE_LLMD" = true ]; then
            install_lws_operator
        fi
    fi
    
    # Install RHCL for MaaS/llm-d auth
    if [ "$SKIP_RHCL" = false ] && [ "$SKIP_MAAS" = false ]; then
        install_rhcl_operator
        
        # Create gateways BEFORE DSC (MaaS requires maas-default-gateway to exist)
        create_inference_gateway
    elif [ "$SKIP_RHCL" = false ]; then
        install_rhcl_operator
    else
        print_info "Skipping RHCL/MaaS (--skip-rhcl or --skip-maas)"
    fi
    
    # Enable monitoring
    enable_user_workload_monitoring
    
    # Install RHOAI
    install_rhoai_operator
    create_datasciencecluster
    
    # Post-installation configuration
    enable_dashboard_features
    create_hardware_profile
    
    print_summary
}

main "$@"
