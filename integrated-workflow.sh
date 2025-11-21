#!/bin/bash

################################################################################
# Integrated OpenShift + RHOAI Installation Workflow
#
# This script orchestrates the complete workflow:
# 1. OpenShift cluster installation (your scripts)
# 2. GPU MachineSet creation (your scripts)
# 3. RHOAI installation (base installation only)
#
# Usage: ./integrated-workflow.sh [--skip-openshift] [--skip-gpu] [--skip-rhoai]
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
RHOAI_VERSION=""

# Flags
SKIP_OPENSHIFT=false
SKIP_GPU=false
SKIP_RHOAI=false

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} $1"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}▶${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    
    for tool in oc aws jq yq make git; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Please install missing tools:"
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                oc)
                    echo "  - oc: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
                    ;;
                aws)
                    echo "  - aws: brew install awscli"
                    ;;
                jq)
                    echo "  - jq: brew install jq"
                    ;;
                yq)
                    echo "  - yq: brew install yq"
                    ;;
                make)
                    echo "  - make: xcode-select --install"
                    ;;
                git)
                    echo "  - git: xcode-select --install"
                    ;;
            esac
        done
        exit 1
    fi
    
    print_success "All required tools are installed"
}

check_scripts() {
    print_header "Checking Required Scripts"
    
    local missing_scripts=()
    
    if [ ! -f "${SCRIPT_DIR}/openshift-installer-master.sh" ]; then
        missing_scripts+=("openshift-installer-master.sh")
    fi
    
    if [ ! -f "${SCRIPT_DIR}/create-gpu-machineset.sh" ]; then
        missing_scripts+=("create-gpu-machineset.sh")
    fi
    
    if [ ${#missing_scripts[@]} -gt 0 ]; then
        print_error "Missing required scripts: ${missing_scripts[*]}"
        exit 1
    fi
    
    print_success "All required scripts are present"
}

################################################################################
# Phase 1: OpenShift Installation
################################################################################

install_openshift() {
    print_header "PHASE 1: OpenShift Cluster Installation"
    
    if [ "$SKIP_OPENSHIFT" = true ]; then
        print_warning "Skipping OpenShift installation (--skip-openshift flag)"
        return
    fi
    
    print_step "Starting OpenShift installation..."
    echo ""
    echo -e "${YELLOW}You will be prompted to configure AWS credentials, pull secret, and other options.${NC}"
    echo -e "${YELLOW}Please follow the interactive prompts.${NC}"
    echo ""
    
    read -p "Press Enter to continue with OpenShift installation..."
    
    "${SCRIPT_DIR}/openshift-installer-master.sh"
    
    # Check if installation was successful
    if [ ! -f "${SCRIPT_DIR}/cluster-info.txt" ]; then
        print_error "OpenShift installation failed or cluster-info.txt not found"
        exit 1
    fi
    
    print_success "OpenShift cluster installed successfully"
}

setup_kubeconfig() {
    print_header "Setting up KUBECONFIG"
    
    # Extract KUBECONFIG path from cluster-info.txt
    if [ -f "${SCRIPT_DIR}/cluster-info.txt" ]; then
        KUBECONFIG_PATH=$(grep "export KUBECONFIG=" "${SCRIPT_DIR}/cluster-info.txt" | head -1 | cut -d'=' -f2)
        
        if [ -n "$KUBECONFIG_PATH" ] && [ -f "$KUBECONFIG_PATH" ]; then
            export KUBECONFIG="$KUBECONFIG_PATH"
            print_success "KUBECONFIG set to: $KUBECONFIG_PATH"
        else
            print_error "Could not find kubeconfig file"
            exit 1
        fi
    else
        print_error "cluster-info.txt not found"
        exit 1
    fi
    
    # Verify cluster access
    print_step "Verifying cluster access..."
    if oc whoami &> /dev/null; then
        print_success "Successfully connected to cluster as: $(oc whoami)"
    else
        print_error "Cannot connect to cluster"
        exit 1
    fi
    
    # Display cluster info
    echo ""
    echo -e "${BLUE}Cluster Information:${NC}"
    oc get nodes
}

################################################################################
# Phase 2: GPU Workers
################################################################################

create_gpu_workers() {
    print_header "PHASE 2: GPU Worker Nodes"
    
    if [ "$SKIP_GPU" = true ]; then
        print_warning "Skipping GPU worker creation (--skip-gpu flag)"
        return
    fi
    
    print_step "Creating GPU worker nodes..."
    echo ""
    echo -e "${YELLOW}You will be prompted to select GPU instance type, subnet, and configuration.${NC}"
    echo ""
    
    read -p "Press Enter to continue with GPU MachineSet creation..."
    
    "${SCRIPT_DIR}/create-gpu-machineset.sh"
    
    print_success "GPU MachineSet created"
    
    # Wait for GPU nodes to be ready
    print_step "Waiting for GPU nodes to be ready..."
    echo ""
    echo "Checking for GPU worker nodes..."
    
    local timeout=600  # 10 minutes
    local elapsed=0
    local interval=10
    
    while [ $elapsed -lt $timeout ]; do
        GPU_NODES=$(oc get nodes -l node-role.kubernetes.io/gpu-worker --no-headers 2>/dev/null | wc -l | tr -d ' ')
        
        if [ "$GPU_NODES" -gt 0 ]; then
            print_success "Found $GPU_NODES GPU worker node(s)"
            oc get nodes -l node-role.kubernetes.io/gpu-worker
            break
        fi
        
        echo "Waiting for GPU nodes... (${elapsed}s elapsed)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    if [ "$GPU_NODES" -eq 0 ]; then
        print_warning "No GPU nodes found yet. You may need to scale the MachineSet manually."
        echo "Run: oc scale machineset <machineset-name> --replicas=1 -n openshift-machine-api"
    fi
}

################################################################################
# Helper Functions for Operator Checks
################################################################################

check_operator_installed() {
    local operator_name=$1
    local namespace=$2
    
    # Check if subscription exists
    if oc get subscription "$operator_name" -n "$namespace" &>/dev/null; then
        return 0  # Operator is installed
    else
        return 1  # Operator is not installed
    fi
}

wait_for_operator_ready() {
    local operator_name=$1
    local namespace=$2
    local timeout=${3:-300}  # Default 5 minutes
    
    print_step "Waiting for $operator_name to be ready..."
    
    local elapsed=0
    local interval=10
    
    while [ $elapsed -lt $timeout ]; do
        # Check if CSV (ClusterServiceVersion) is in Succeeded phase
        local csv_phase=$(oc get csv -n "$namespace" -o jsonpath='{.items[?(@.spec.displayName=="'"$operator_name"'")].status.phase}' 2>/dev/null)
        
        if [ "$csv_phase" = "Succeeded" ]; then
            return 0
        fi
        
        echo "Waiting for $operator_name operator... (${elapsed}s elapsed)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    print_warning "$operator_name operator did not become ready within ${timeout}s"
    return 1
}

################################################################################
# Phase 3: RHOAI Installation
################################################################################

select_rhoai_version() {
    print_header "Select RHOAI Version"
    
    echo -e "${BLUE}Available RHOAI versions:${NC}"
    echo ""
    echo "  1) RHOAI 2.17 (OpenShift 4.16+)"
    echo "  2) RHOAI 2.18 (OpenShift 4.16+)"
    echo "  3) RHOAI 2.19 (OpenShift 4.17+)"
    echo "  4) RHOAI 2.20 (OpenShift 4.17+)"
    echo "  5) RHOAI 2.21 (OpenShift 4.17+)"
    echo "  6) RHOAI 2.22 (OpenShift 4.18+)"
    echo "  7) RHOAI 2.23 (OpenShift 4.19+)"
    echo "  8) RHOAI 2.24 (OpenShift 4.20+)"
    echo "  9) RHOAI 2.25 (OpenShift 4.20+)"
    echo " 10) RHOAI 3.0 (OpenShift 4.19+) - Latest"
    echo ""
    
    while true; do
        read -p "Enter choice [1-10]: " choice
        
        case $choice in
            1) RHOAI_VERSION="2.17"; break ;;
            2) RHOAI_VERSION="2.18"; break ;;
            3) RHOAI_VERSION="2.19"; break ;;
            4) RHOAI_VERSION="2.20"; break ;;
            5) RHOAI_VERSION="2.21"; break ;;
            6) RHOAI_VERSION="2.22"; break ;;
            7) RHOAI_VERSION="2.23"; break ;;
            8) RHOAI_VERSION="2.24"; break ;;
            9) RHOAI_VERSION="2.25"; break ;;
            10) RHOAI_VERSION="3.0"; break ;;
            *) echo "Invalid choice. Please enter 1-10." ;;
        esac
    done
    
    print_success "Selected RHOAI version: $RHOAI_VERSION"
}

install_nfd_operator() {
    print_step "Checking Node Feature Discovery (NFD) Operator..."
    
    # Check if NFD operator is already installed
    if check_operator_installed "nfd" "openshift-nfd"; then
        print_success "NFD operator is already installed, skipping installation"
        
        # Check if NFD instance exists
        if oc get nodefeaturediscovery nfd-instance -n openshift-nfd &>/dev/null; then
            print_success "NFD instance already exists, skipping creation"
            return 0
        else
            print_step "NFD operator exists but no instance found, creating instance..."
        fi
    else
        print_step "Installing Node Feature Discovery (NFD) Operator..."
        
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-nfd
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-nfd
  namespace: openshift-nfd
spec:
  targetNamespaces:
  - openshift-nfd
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nfd
  namespace: openshift-nfd
spec:
  channel: stable
  installPlanApproval: Automatic
  name: nfd
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

        # Wait for NFD operator to be ready
        print_step "Waiting for NFD operator to be ready..."
        sleep 10
        
        until oc get crd nodefeaturediscoveries.nfd.openshift.io &>/dev/null; do
            echo "Waiting for NFD CRD to be available..."
            sleep 5
        done
    fi
    
    # Create NFD instance (if not already exists)
    if ! oc get nodefeaturediscovery nfd-instance -n openshift-nfd &>/dev/null; then
        print_step "Creating NFD instance..."
    cat <<EOF | oc apply -f -
apiVersion: nfd.openshift.io/v1
kind: NodeFeatureDiscovery
metadata:
  name: nfd-instance
  namespace: openshift-nfd
spec:
  operand:
    image: registry.redhat.io/openshift4/ose-node-feature-discovery:v4.19
    servicePort: 12000
  workerConfig:
    configData: |
      core:
        sleepInterval: 60s
      sources:
        pci:
          deviceClassWhitelist:
            - "0200"
            - "03"
            - "12"
          deviceLabelFields:
            - "vendor"
EOF
        print_success "NFD instance created"
    fi
    
    print_success "NFD operator installation complete"
}

install_gpu_operator() {
    print_step "Checking Nvidia GPU Operator..."
    
    # Check if GPU operator is already installed
    if check_operator_installed "gpu-operator-certified" "nvidia-gpu-operator"; then
        print_success "GPU operator is already installed, skipping installation"
        
        # Check if ClusterPolicy exists
        if oc get clusterpolicy gpu-cluster-policy &>/dev/null; then
            print_success "GPU ClusterPolicy already exists, skipping creation"
            return 0
        else
            print_step "GPU operator exists but no ClusterPolicy found, creating ClusterPolicy..."
        fi
    else
        print_step "Installing Nvidia GPU Operator..."
        
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: nvidia-gpu-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: nvidia-gpu-operator-group
  namespace: nvidia-gpu-operator
spec:
  targetNamespaces:
  - nvidia-gpu-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: gpu-operator-certified
  namespace: nvidia-gpu-operator
spec:
  channel: stable
  installPlanApproval: Automatic
  name: gpu-operator-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
EOF

        # Wait for GPU operator to be ready
        print_step "Waiting for GPU operator to be ready..."
        sleep 10
        
        until oc get crd clusterpolicies.nvidia.com &>/dev/null; do
            echo "Waiting for GPU operator CRD to be available..."
            sleep 5
        done
    fi
    
    # Create ClusterPolicy (if not already exists)
    if ! oc get clusterpolicy gpu-cluster-policy &>/dev/null; then
        print_step "Creating GPU ClusterPolicy..."
    cat <<EOF | oc apply -f -
apiVersion: nvidia.com/v1
kind: ClusterPolicy
metadata:
  name: gpu-cluster-policy
spec:
  vgpuDeviceManager:
    config:
      default: default
    enabled: true
  migManager:
    config:
      default: all-disabled
      name: default-mig-parted-config
    enabled: true
  operator:
    defaultRuntime: crio
    initContainer: {}
    runtimeClass: nvidia
    use_ocp_driver_toolkit: true
  dcgm:
    enabled: true
  gfd:
    enabled: true
  dcgmExporter:
    config:
      name: ''
    serviceMonitor:
      enabled: true
    enabled: true
  cdi:
    default: false
    enabled: true
  driver:
    licensingConfig:
      nlsEnabled: true
      secretName: ''
    kernelModuleType: auto
    certConfig:
      name: ''
    kernelModuleConfig:
      name: ''
    upgradePolicy:
      autoUpgrade: true
      drain:
        deleteEmptyDir: false
        enable: false
        force: false
        timeoutSeconds: 300
      maxParallelUpgrades: 1
      maxUnavailable: 25%
      podDeletion:
        deleteEmptyDir: false
        force: false
        timeoutSeconds: 300
      waitForCompletion:
        timeoutSeconds: 0
    repoConfig:
      configMapName: ''
    virtualTopology:
      config: ''
    enabled: true
    useNvidiaDriverCRD: false
  devicePlugin:
    config:
      name: ''
      default: ''
    mps:
      root: /run/nvidia/mps
    enabled: true
  gdrcopy:
    enabled: false
  kataManager:
    config:
      artifactsDir: /opt/nvidia-gpu-operator/artifacts/runtimeclasses
  mig:
    strategy: single
  sandboxDevicePlugin:
    enabled: true
  validator:
    plugin:
      env: []
  nodeStatusExporter:
    enabled: true
  daemonsets:
    rollingUpdate:
      maxUnavailable: '1'
    updateStrategy: RollingUpdate
  sandboxWorkloads:
    defaultWorkload: container
    enabled: false
  gds:
    enabled: false
  vgpuManager:
    enabled: false
  vfioManager:
    enabled: true
  toolkit:
    installDir: /usr/local/nvidia
    enabled: true
EOF
        print_success "GPU ClusterPolicy created"
    fi
    
    print_success "GPU operator installation complete"
}

install_rhoai_operator() {
    print_step "Checking Red Hat OpenShift AI Operator (version $RHOAI_VERSION)..."
    
    # Check if RHOAI operator is already installed
    if check_operator_installed "rhods-operator" "redhat-ods-operator"; then
        print_success "RHOAI operator is already installed, skipping installation"
        return 0
    fi
    
    print_step "Installing Red Hat OpenShift AI Operator (version $RHOAI_VERSION)..."
    
    # Determine the channel based on version
    local channel
    case "$RHOAI_VERSION" in
        2.17|2.18) channel="fast" ;;
        2.19|2.20|2.21) channel="stable" ;;
        2.22|2.23) channel="stable-2.23" ;;
        2.24|2.25) channel="stable" ;;
        3.0) channel="fast-3.x" ;;
        *) channel="stable" ;;
    esac
    
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: redhat-ods-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: redhat-ods-operator
  namespace: redhat-ods-operator
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  channel: $channel
  installPlanApproval: Automatic
  name: rhods-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

    # Wait for RHOAI operator to be ready
    print_step "Waiting for RHOAI operator to be ready (this may take 5-10 minutes)..."
    sleep 30
    
    until oc get crd datascienceclusters.datasciencecluster.opendatahub.io &>/dev/null; do
        echo "Waiting for RHOAI CRDs to be available..."
        sleep 10
    done
    
    print_success "RHOAI operator installed"
}

create_rhoai_instance() {
    print_step "Checking RHOAI instance..."
    
    # Check if DSCInitialization already exists
    if oc get dscinitialization default-dsci &>/dev/null; then
        print_success "DSCInitialization already exists, skipping creation"
    else
        print_step "Creating DSCInitialization..."
        
        # Create DSCInitialization
    cat <<EOF | oc apply -f -
apiVersion: dscinitialization.opendatahub.io/v1
kind: DSCInitialization
metadata:
  name: default-dsci
spec:
  applicationsNamespace: redhat-ods-applications
  monitoring:
    managementState: Managed
    namespace: redhat-ods-monitoring
  serviceMesh:
    controlPlane:
      metricsCollection: Istio
      name: data-science-smcp
      namespace: istio-system
    managementState: Managed
  trustedCABundle:
    customCABundle: ""
    managementState: Managed
EOF
        
        # Wait for DSCInitialization to be ready
        print_step "Waiting for DSCInitialization to be ready..."
        sleep 10
        
        until oc get DSCInitialization/default-dsci -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null | grep -q "True"; do
            echo "Waiting for DSCInitialization to be available..."
            sleep 10
        done
        
        print_success "DSCInitialization created"
    fi
    
    # Check if DataScienceCluster already exists
    if oc get datasciencecluster default-dsc &>/dev/null; then
        print_success "DataScienceCluster already exists, skipping creation"
        return 0
    fi
    
    print_step "Creating DataScienceCluster..."
    
    # Create DataScienceCluster
    cat <<EOF | oc apply -f -
apiVersion: datasciencecluster.opendatahub.io/v2
kind: DataScienceCluster
metadata:
  name: default-dsc
  labels:
    app.kubernetes.io/name: datasciencecluster
spec:
  components:
    dashboard:
      managementState: Managed
    aipipelines:
      managementState: Managed
    feastoperator:
      managementState: Managed
    kserve:
      managementState: Managed
    llamastackoperator:
      managementState: Managed
    kueue:
      defaultClusterQueueName: default
      defaultLocalQueueName: default
      managementState: Unmanaged
    modelregistry:
      managementState: Managed
      registriesNamespace: rhoai-model-registries
    ray:
      managementState: Managed
    workbenches:
      managementState: Managed
    trainingoperator:
      managementState: Managed
    trustyai:
      managementState: Managed
    codeflare:
      managementState: Removed
EOF

    # Wait for DataScienceCluster to be ready
    print_step "Waiting for DataScienceCluster to be ready (this may take 10-15 minutes)..."
    
    until oc get DataScienceCluster/default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; do
        echo "Waiting for DataScienceCluster to be ready..."
        sleep 15
    done
    
    print_success "RHOAI instance created"
    
    # Configure dashboard for GenAI and MaaS
    configure_dashboard
}

configure_dashboard() {
    print_step "Configuring dashboard for GenAI Playground and Model as a Service..."
    
    # Wait for dashboard config to exist
    sleep 10
    
    # Use patch instead of apply to avoid overwriting existing config and deprecated fields
    oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge --patch='
spec:
  dashboardConfig:
    disableTracking: false
    disableModelRegistry: false
    disableModelCatalog: false
    disableKServeMetrics: false
    genAiStudio: true
    modelAsService: true
    disableLMEval: false
    disableKueue: false
'
    
    print_success "Dashboard configured with GenAI and MaaS features enabled"
}

install_rhoai() {
    print_header "PHASE 3: RHOAI Installation"
    
    if [ "$SKIP_RHOAI" = true ]; then
        print_warning "Skipping RHOAI installation (--skip-rhoai flag)"
        return
    fi
    
    # Select RHOAI version
    select_rhoai_version
    
    echo ""
    echo -e "${YELLOW}This will install:${NC}"
    echo "  - Node Feature Discovery (NFD)"
    echo "  - Nvidia GPU Operator"
    echo "  - Red Hat OpenShift AI $RHOAI_VERSION"
    echo ""
    echo -e "${YELLOW}This process takes 20-30 minutes.${NC}"
    echo ""
    
    read -p "Press Enter to continue with RHOAI installation..."
    
    # Install components
    install_nfd_operator
    install_gpu_operator
    install_rhoai_operator
    create_rhoai_instance
    
    print_success "RHOAI $RHOAI_VERSION installed successfully"
    
    # Display RHOAI dashboard URL
    echo ""
    echo -e "${BLUE}RHOAI Dashboard:${NC}"
    RHOAI_URL=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available yet")
    echo "https://${RHOAI_URL}"
}


################################################################################
# Final Summary
################################################################################

print_summary() {
    print_header "Installation Complete! 🎉"
    
    echo -e "${GREEN}Your OpenShift + RHOAI environment is ready!${NC}"
    echo ""
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Cluster Information${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    if [ -f "${SCRIPT_DIR}/cluster-info.txt" ]; then
        cat "${SCRIPT_DIR}/cluster-info.txt"
    fi
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}RHOAI Information${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    echo "RHOAI Version: ${RHOAI_VERSION}"
    
    RHOAI_URL=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")
    echo "RHOAI Dashboard: https://${RHOAI_URL}"
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Installed Components${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "✓ Node Feature Discovery (NFD)"
    echo "✓ Nvidia GPU Operator"
    echo "✓ Red Hat OpenShift AI ${RHOAI_VERSION}"
    echo "✓ KServe (Model Serving)"
    echo "✓ Data Science Pipelines"
    echo "✓ Workbenches"
    echo ""
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}GPU Nodes${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    GPU_NODES=$(oc get nodes -l node-role.kubernetes.io/gpu-worker --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$GPU_NODES" -gt 0 ]; then
        echo "GPU worker nodes: $GPU_NODES"
        oc get nodes -l node-role.kubernetes.io/gpu-worker -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,INSTANCE:.metadata.labels.node\\.kubernetes\\.io/instance-type,GPU:.status.capacity.nvidia\\.com/gpu
    else
        echo "No GPU worker nodes found."
        echo "You can create GPU workers using: ./create-gpu-machineset.sh"
    fi
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Next Steps${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "1. Access the RHOAI Dashboard:"
    echo "   https://${RHOAI_URL}"
    echo ""
    echo "2. Create a Data Science Project"
    echo ""
    echo "3. Create a Workbench with GPU support"
    echo ""
    echo "4. Deploy models using KServe"
    echo ""
    echo "5. For more information, see:"
    echo "   https://access.redhat.com/documentation/en-us/red_hat_openshift_ai"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}Happy AI/ML development! 🚀${NC}"
    echo ""
}

################################################################################
# Main Workflow
################################################################################

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Integrated OpenShift + RHOAI installation workflow.

OPTIONS:
    --skip-openshift    Skip OpenShift cluster installation
    --skip-gpu          Skip GPU worker node creation
    --skip-rhoai        Skip RHOAI installation
    --help, -h          Show this help message

EXAMPLES:
    # Full installation (all phases)
    $0

    # Skip OpenShift installation (cluster already exists)
    $0 --skip-openshift

    # Only install RHOAI (cluster and GPU nodes already exist)
    $0 --skip-openshift --skip-gpu

PHASES:
    1. OpenShift Cluster Installation (your scripts)
    2. GPU Worker Nodes (your scripts)
    3. RHOAI Installation (base installation with version selection)

RHOAI VERSIONS SUPPORTED:
    - RHOAI 2.17 - 2.25, 3.0
    - You will be prompted to select the version during installation

EOF
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-openshift)
                SKIP_OPENSHIFT=true
                shift
                ;;
            --skip-gpu)
                SKIP_GPU=true
                shift
                ;;
            --skip-rhoai)
                SKIP_RHOAI=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Print welcome banner
    clear
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                            ║${NC}"
    echo -e "${CYAN}║          Integrated OpenShift + RHOAI Installation Workflow                ║${NC}"
    echo -e "${CYAN}║                                                                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Run checks
    check_prerequisites
    check_scripts
    
    # Phase 1: OpenShift Installation
    install_openshift
    
    # Setup KUBECONFIG (if not skipping OpenShift)
    if [ "$SKIP_OPENSHIFT" = false ]; then
        setup_kubeconfig
    else
        # If skipping OpenShift, try to use existing KUBECONFIG
        if [ -z "${KUBECONFIG:-}" ]; then
            if [ -f "${SCRIPT_DIR}/cluster-info.txt" ]; then
                KUBECONFIG_PATH=$(grep "export KUBECONFIG=" "${SCRIPT_DIR}/cluster-info.txt" | head -1 | cut -d'=' -f2)
                if [ -n "$KUBECONFIG_PATH" ] && [ -f "$KUBECONFIG_PATH" ]; then
                    export KUBECONFIG="$KUBECONFIG_PATH"
                    print_success "Using existing KUBECONFIG: $KUBECONFIG_PATH"
                fi
            fi
        fi
        
        # Verify we can connect
        if ! oc whoami &> /dev/null; then
            print_error "Cannot connect to cluster. Please set KUBECONFIG environment variable."
            exit 1
        fi
    fi
    
    # Phase 2: GPU Workers
    create_gpu_workers
    
    # Phase 3: RHOAI Installation
    install_rhoai
    
    # Print final summary
    print_summary
}

# Run main function
main "$@"

