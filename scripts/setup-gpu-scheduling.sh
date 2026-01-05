#!/bin/bash
################################################################################
# Setup GPU Scheduling for RHOAI 3.0
################################################################################
# This script automatically configures GPU scheduling for model deployment.
# It detects GPU node taints and configures:
#   - ResourceFlavor with tolerations
#   - ClusterQueue with GPU resources
#   - Hardware Profile with proper scheduling config
#
# Usage:
#   ./scripts/setup-gpu-scheduling.sh [namespace]
#
# What it does:
#   1. Detects GPU nodes and their taints
#   2. Configures ResourceFlavor with node selector + toleration (if needed)
#   3. Updates ClusterQueue to include GPU resources
#   4. Creates/updates Hardware Profile with proper scheduling
#
# This ensures models can be scheduled on tainted GPU nodes without errors.
################################################################################

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "$SCRIPT_DIR/../lib/utils/colors.sh" 2>/dev/null || {
    # Fallback colors if not available
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    
    print_header() {
        echo ""
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║ $1${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
    }
    print_step() { echo -e "${YELLOW}▶ $1${NC}"; }
    print_success() { echo -e "${GREEN}✓ $1${NC}"; }
    print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
    print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
    print_error() { echo -e "${RED}✗ $1${NC}"; }
}

source "$SCRIPT_DIR/../lib/utils/common.sh" 2>/dev/null || true

################################################################################
# Configuration
################################################################################

NAMESPACE="${1:-}"
PROFILE_NAME="gpu-profile"
RESOURCEFLAVOR_NAME="nvidia-gpu-flavor"
GPU_TAINT_KEY="nvidia.com/gpu"
GPU_NODE_LABEL="nvidia.com/gpu.present"

################################################################################
# Functions
################################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check OpenShift login
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        echo "Please login first: oc login <cluster-url>"
        exit 1
    fi
    print_success "Connected to OpenShift: $(oc whoami --show-server 2>/dev/null)"
    
    # Check for GPU nodes
    local gpu_node_count=$(oc get nodes -l ${GPU_NODE_LABEL}=true -o name 2>/dev/null | wc -l | tr -d ' ')
    if [ "$gpu_node_count" -eq 0 ]; then
        print_warning "No GPU nodes found with label ${GPU_NODE_LABEL}=true"
        echo ""
        echo "GPU nodes will be configured when they are available."
        echo "You may need to run this script again after GPU nodes are added."
        echo ""
    else
        print_success "Found $gpu_node_count GPU node(s)"
    fi
    
    # Check Kueue
    if ! oc get clusterqueue &>/dev/null; then
        print_warning "No ClusterQueues found - Kueue may not be configured"
    else
        print_success "Kueue ClusterQueue found"
    fi
    
    echo ""
}

detect_gpu_taints() {
    print_header "Detecting GPU Node Taints"
    
    # Get GPU nodes
    local gpu_nodes=$(oc get nodes -l ${GPU_NODE_LABEL}=true -o name 2>/dev/null)
    
    if [ -z "$gpu_nodes" ]; then
        print_info "No GPU nodes to check"
        GPU_NODES_TAINTED="false"
        return 0
    fi
    
    # Check for nvidia.com/gpu taint
    local taint_found=$(oc get nodes -l ${GPU_NODE_LABEL}=true -o json 2>/dev/null | \
        jq -r '.items[].spec.taints[]? | select(.key=="'${GPU_TAINT_KEY}'") | .key' | head -1)
    
    if [ -n "$taint_found" ]; then
        GPU_NODES_TAINTED="true"
        print_info "GPU nodes ARE tainted with: ${GPU_TAINT_KEY}:NoSchedule"
        echo ""
        echo "  This is a best practice - it prevents non-GPU workloads from"
        echo "  consuming expensive GPU instances."
        echo ""
        echo "  Pods MUST have a toleration to be scheduled on these nodes."
    else
        GPU_NODES_TAINTED="false"
        print_info "GPU nodes are NOT tainted"
        echo ""
        echo "  Any workload can currently be scheduled on GPU nodes."
        echo ""
        
        read -p "  Would you like to taint GPU nodes now? (recommended) (y/N): " taint_choice
        if [[ "$taint_choice" =~ ^[Yy]$ ]]; then
            print_step "Tainting GPU nodes with ${GPU_TAINT_KEY}:NoSchedule..."
            oc adm taint nodes -l ${GPU_NODE_LABEL}=true ${GPU_TAINT_KEY}=:NoSchedule --overwrite
            if [ $? -eq 0 ]; then
                print_success "GPU nodes tainted successfully"
                GPU_NODES_TAINTED="true"
            else
                print_error "Failed to taint GPU nodes"
            fi
        fi
    fi
    
    echo ""
}

configure_resourceflavor() {
    print_header "Configuring ResourceFlavor"
    
    print_step "Checking existing ResourceFlavor..."
    local existing=$(oc get resourceflavor ${RESOURCEFLAVOR_NAME} -o name 2>/dev/null)
    
    if [ -n "$existing" ]; then
        print_info "ResourceFlavor '${RESOURCEFLAVOR_NAME}' exists - updating"
    else
        print_info "Creating ResourceFlavor '${RESOURCEFLAVOR_NAME}'"
    fi
    
    # Build ResourceFlavor spec based on taint status
    if [ "$GPU_NODES_TAINTED" = "true" ]; then
        print_step "Adding GPU toleration to ResourceFlavor..."
        
        cat <<EOF | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: ${RESOURCEFLAVOR_NAME}
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    ${GPU_NODE_LABEL}: "true"
  tolerations:
  - key: ${GPU_TAINT_KEY}
    operator: Exists
    effect: NoSchedule
EOF
        
        if [ $? -eq 0 ]; then
            print_success "ResourceFlavor configured with:"
            echo "    - Node selector: ${GPU_NODE_LABEL}=true"
            echo "    - Toleration: ${GPU_TAINT_KEY}:NoSchedule"
        else
            print_error "Failed to configure ResourceFlavor"
            return 1
        fi
    else
        cat <<EOF | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: ${RESOURCEFLAVOR_NAME}
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    ${GPU_NODE_LABEL}: "true"
EOF
        
        if [ $? -eq 0 ]; then
            print_success "ResourceFlavor configured with:"
            echo "    - Node selector: ${GPU_NODE_LABEL}=true"
            echo "    - No toleration (GPU nodes not tainted)"
        else
            print_error "Failed to configure ResourceFlavor"
            return 1
        fi
    fi
    
    echo ""
}

configure_clusterqueue() {
    print_header "Configuring ClusterQueue"
    
    print_step "Checking existing ClusterQueue 'default'..."
    
    local cq_exists=$(oc get clusterqueue default -o name 2>/dev/null)
    if [ -z "$cq_exists" ]; then
        print_warning "ClusterQueue 'default' not found"
        echo "  Skipping ClusterQueue configuration."
        echo "  Ensure Kueue is properly configured in your DataScienceCluster."
        return 0
    fi
    
    # Check if GPU resources are already in ClusterQueue
    local has_gpu=$(oc get clusterqueue default -o jsonpath='{.spec.resourceGroups[*].coveredResources}' 2>/dev/null | grep -o 'nvidia.com/gpu')
    
    if [ -n "$has_gpu" ]; then
        print_success "ClusterQueue already includes nvidia.com/gpu resources"
        return 0
    fi
    
    print_step "Adding GPU resources to ClusterQueue..."
    
    # Get current CPU/Memory quotas
    local cpu_quota=$(oc get clusterqueue default -o jsonpath='{.spec.resourceGroups[0].flavors[0].resources[?(@.name=="cpu")].nominalQuota}' 2>/dev/null)
    local memory_quota=$(oc get clusterqueue default -o jsonpath='{.spec.resourceGroups[0].flavors[0].resources[?(@.name=="memory")].nominalQuota}' 2>/dev/null)
    
    cpu_quota="${cpu_quota:-16}"
    memory_quota="${memory_quota:-64Gi}"
    
    # Detect available GPUs
    local total_gpus=$(oc get nodes -l ${GPU_NODE_LABEL}=true -o json 2>/dev/null | \
        jq '[.items[].status.allocatable["nvidia.com/gpu"] // "0" | tonumber] | add // 0')
    total_gpus="${total_gpus:-8}"
    
    print_info "Detected $total_gpus total GPU(s) across GPU nodes"
    
    cat <<EOF | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: default
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  flavorFungibility:
    whenCanBorrow: Borrow
    whenCanPreempt: TryNextFlavor
  namespaceSelector:
    matchLabels:
      kueue.openshift.io/managed: "true"
  preemption:
    borrowWithinCohort:
      policy: Never
    reclaimWithinCohort: Never
    withinClusterQueue: Never
  queueingStrategy: BestEffortFIFO
  resourceGroups:
  # CPU and Memory resources
  - coveredResources:
    - cpu
    - memory
    flavors:
    - name: default-flavor
      resources:
      - name: cpu
        nominalQuota: "${cpu_quota}"
      - name: memory
        nominalQuota: "${memory_quota}"
  # GPU resources
  - coveredResources:
    - nvidia.com/gpu
    flavors:
    - name: ${RESOURCEFLAVOR_NAME}
      resources:
      - name: nvidia.com/gpu
        nominalQuota: "${total_gpus}"
  stopPolicy: None
EOF
    
    if [ $? -eq 0 ]; then
        print_success "ClusterQueue updated with GPU resources"
        echo "    - GPU flavor: ${RESOURCEFLAVOR_NAME}"
        echo "    - GPU quota: ${total_gpus}"
    else
        print_error "Failed to update ClusterQueue"
        return 1
    fi
    
    echo ""
}

configure_hardware_profile() {
    print_header "Configuring Hardware Profile"
    
    # Determine namespace
    if [ -z "$NAMESPACE" ]; then
        NAMESPACE=$(oc project -q 2>/dev/null)
        if [ -z "$NAMESPACE" ] || [ "$NAMESPACE" = "default" ]; then
            NAMESPACE="redhat-ods-applications"
        fi
    fi
    
    print_info "Target namespace: $NAMESPACE"
    echo ""
    
    # Check if namespace exists
    if ! oc get namespace "$NAMESPACE" &>/dev/null; then
        print_error "Namespace '$NAMESPACE' does not exist"
        return 1
    fi
    
    print_step "Checking existing Hardware Profile..."
    local existing=$(oc get hardwareprofile ${PROFILE_NAME} -n "$NAMESPACE" -o name 2>/dev/null)
    
    if [ -n "$existing" ]; then
        print_info "Hardware Profile '${PROFILE_NAME}' exists in $NAMESPACE - updating"
    else
        print_info "Creating Hardware Profile '${PROFILE_NAME}' in $NAMESPACE"
    fi
    
    # Build Hardware Profile with Node scheduling and tolerations
    # NOTE: For RawDeployment mode, tolerations must be in the Hardware Profile
    
    local toleration_spec=""
    if [ "$GPU_NODES_TAINTED" = "true" ]; then
        toleration_spec="      tolerations:
      - key: ${GPU_TAINT_KEY}
        operator: Exists
        effect: NoSchedule"
    fi
    
    cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: ${PROFILE_NAME}
  namespace: ${NAMESPACE}
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: 'GPU Profile'
    opendatahub.io/description: 'GPU hardware profile with tolerations for tainted nodes'
    opendatahub.io/managed: 'false'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
    app.kubernetes.io/part-of: hardwareprofile
spec:
  identifiers:
  - defaultCount: '4'
    displayName: CPU
    identifier: cpu
    maxCount: '16'
    minCount: 1
    resourceType: CPU
  - defaultCount: 16Gi
    displayName: Memory
    identifier: memory
    maxCount: 64Gi
    minCount: 1Gi
    resourceType: Memory
  - defaultCount: 1
    displayName: GPU
    identifier: nvidia.com/gpu
    maxCount: 8
    minCount: 1
    resourceType: Accelerator
  scheduling:
    type: Node
    node:
      nodeSelector:
        ${GPU_NODE_LABEL}: "true"
${toleration_spec}
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Hardware Profile configured with:"
        echo "    - Node selector: ${GPU_NODE_LABEL}=true"
        if [ "$GPU_NODES_TAINTED" = "true" ]; then
            echo "    - Toleration: ${GPU_TAINT_KEY}:NoSchedule"
        fi
    else
        print_error "Failed to configure Hardware Profile"
        return 1
    fi
    
    echo ""
}

show_summary() {
    print_header "GPU Scheduling Configuration Complete! ✅"
    
    echo -e "${CYAN}Summary:${NC}"
    echo ""
    echo "  GPU Nodes Tainted: ${GPU_NODES_TAINTED}"
    echo ""
    echo "  ResourceFlavor: ${RESOURCEFLAVOR_NAME}"
    echo "    - Node selector: ${GPU_NODE_LABEL}=true"
    if [ "$GPU_NODES_TAINTED" = "true" ]; then
        echo "    - Toleration: ${GPU_TAINT_KEY}:NoSchedule"
    fi
    echo ""
    echo "  ClusterQueue: default"
    echo "    - GPU resources: nvidia.com/gpu"
    echo "    - GPU flavor: ${RESOURCEFLAVOR_NAME}"
    echo ""
    echo "  Hardware Profile: ${PROFILE_NAME}"
    echo "    - Namespace: ${NAMESPACE}"
    echo "    - Scheduling: Node (with tolerations)"
    echo ""
    
    echo -e "${GREEN}You can now deploy GPU models without 'untolerated taint' errors!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Go to RHOAI Dashboard"
    echo "  2. Navigate to your project"
    echo "  3. Deploy a model and select 'GPU Profile'"
    echo ""
    
    if [ "$GPU_NODES_TAINTED" = "true" ]; then
        echo -e "${CYAN}Note: If you deploy models via CLI/YAML, include this in your InferenceService:${NC}"
        echo ""
        echo "  spec:"
        echo "    predictor:"
        echo "      nodeSelector:"
        echo "        ${GPU_NODE_LABEL}: \"true\""
        echo "      tolerations:"
        echo "      - key: ${GPU_TAINT_KEY}"
        echo "        operator: Exists"
        echo "        effect: NoSchedule"
        echo ""
    fi
}

################################################################################
# Main
################################################################################

main() {
    clear
    print_header "Setup GPU Scheduling for RHOAI 3.0"
    
    echo "This script will configure GPU scheduling to handle tainted nodes."
    echo ""
    echo "It will:"
    echo "  1. Detect GPU node taints"
    echo "  2. Configure ResourceFlavor with tolerations"
    echo "  3. Update ClusterQueue with GPU resources"
    echo "  4. Create/update Hardware Profile"
    echo ""
    
    read -p "Continue? (Y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]?$ ]]; then
        print_info "Cancelled"
        exit 0
    fi
    echo ""
    
    check_prerequisites
    detect_gpu_taints
    configure_resourceflavor
    configure_clusterqueue
    configure_hardware_profile
    show_summary
}

main "$@"

