#!/bin/bash
################################################################################
# Create GPU Hardware Profile in Namespace
################################################################################
# Creates a GPU hardware profile with optional tolerations and node affinity
# for model deployment in RHOAI 3.0
#
# Usage:
#   ./scripts/create-hardware-profile.sh [namespace]
#
# Features:
#   - Supports both Kueue (Queue) and Node scheduling types
#   - Optional GPU tolerations for tainted nodes
#   - Optional node affinity/selector
################################################################################

set -e

# Colors
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

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_header "Create GPU Hardware Profile"

# Check if logged in
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift"
    echo "Please login first: oc login <cluster-url>"
    exit 1
fi

print_success "Connected to OpenShift cluster"

# Get namespace from argument or prompt
if [ -n "$1" ]; then
    NAMESPACE="$1"
else
    NAMESPACE=$(oc project -q 2>/dev/null)
    if [ -z "$NAMESPACE" ]; then
        read -p "Enter target namespace: " NAMESPACE
    fi
fi

echo -e "Target namespace: ${YELLOW}$NAMESPACE${NC}"
echo ""

# Check if namespace exists
if ! oc get namespace "$NAMESPACE" &>/dev/null; then
    print_error "Namespace '$NAMESPACE' does not exist"
    exit 1
fi

# Profile name
read -p "Hardware profile name (default: gpu-profile): " PROFILE_NAME
PROFILE_NAME="${PROFILE_NAME:-gpu-profile}"

# Check if profile already exists
if oc get hardwareprofile "$PROFILE_NAME" -n "$NAMESPACE" &>/dev/null; then
    print_warning "Hardware profile '$PROFILE_NAME' already exists in $NAMESPACE"
    read -p "Update existing profile? (y/N): " update
    if [[ ! "$update" =~ ^[Yy]$ ]]; then
        echo "Exiting without changes."
        exit 0
    fi
fi

# Resource configuration
print_header "Resource Configuration"

echo "Configure resource limits for this hardware profile:"
echo ""

read -p "Default CPU count (default: 4): " DEFAULT_CPU
DEFAULT_CPU="${DEFAULT_CPU:-4}"

read -p "Max CPU count (default: 16): " MAX_CPU
MAX_CPU="${MAX_CPU:-16}"

read -p "Default Memory (default: 16Gi): " DEFAULT_MEMORY
DEFAULT_MEMORY="${DEFAULT_MEMORY:-16Gi}"

read -p "Max Memory (default: 64Gi): " MAX_MEMORY
MAX_MEMORY="${MAX_MEMORY:-64Gi}"

read -p "Default GPU count (default: 1): " DEFAULT_GPU
DEFAULT_GPU="${DEFAULT_GPU:-1}"

read -p "Max GPU count (default: 8): " MAX_GPU
MAX_GPU="${MAX_GPU:-8}"

echo ""
print_success "Resources configured: CPU=$DEFAULT_CPU (max $MAX_CPU), Memory=$DEFAULT_MEMORY (max $MAX_MEMORY), GPU=$DEFAULT_GPU (max $MAX_GPU)"

# Scheduling type
print_header "Scheduling Configuration"

echo "Select scheduling type:"
echo ""
echo -e "${YELLOW}1)${NC} Queue (Kueue) - Use Kueue for workload management"
echo "   Best for: Batch workloads, GPU sharing, quota management"
echo ""
echo -e "${YELLOW}2)${NC} Node - Direct node scheduling with tolerations/affinity"
echo "   Best for: Dedicated GPU nodes, specific node targeting"
echo ""

read -p "Select scheduling type (1-2, default: 2): " SCHED_TYPE
SCHED_TYPE="${SCHED_TYPE:-2}"

SCHEDULING_SPEC=""

if [ "$SCHED_TYPE" = "1" ]; then
    # Kueue scheduling
    print_step "Configuring Kueue scheduling..."
    
    read -p "Local queue name (default: default): " LOCAL_QUEUE
    LOCAL_QUEUE="${LOCAL_QUEUE:-default}"
    
    SCHEDULING_SPEC="  scheduling:
    type: Queue
    kueue:
      localQueueName: $LOCAL_QUEUE
      priorityClass: None"
    
    print_success "Kueue scheduling configured with queue: $LOCAL_QUEUE"
else
    # Node scheduling with tolerations and affinity
    print_step "Configuring Node scheduling..."
    echo ""
    
    # Check for GPU node taints
    print_step "Checking for GPU node taints..."
    has_taint=$(oc get nodes -l nvidia.com/gpu.present=true -o json 2>/dev/null | jq -r '.items[].spec.taints[]? | select(.key=="nvidia.com/gpu") | .key' | head -1)
    
    ADD_TOLERATION="n"
    if [ -n "$has_taint" ]; then
        print_info "GPU nodes are tainted with nvidia.com/gpu:NoSchedule"
        echo ""
        read -p "Add GPU toleration to hardware profile? (Y/n): " ADD_TOLERATION
        ADD_TOLERATION="${ADD_TOLERATION:-Y}"
    else
        print_info "GPU nodes are not tainted"
        read -p "Add GPU toleration anyway (for future use)? (y/N): " ADD_TOLERATION
        ADD_TOLERATION="${ADD_TOLERATION:-N}"
    fi
    
    # Node selector
    echo ""
    print_step "Configuring node selector..."
    echo ""
    echo "Node selector options:"
    echo -e "${YELLOW}1)${NC} nvidia.com/gpu.present=true (recommended for GPU nodes)"
    echo -e "${YELLOW}2)${NC} Custom node selector"
    echo -e "${YELLOW}3)${NC} No node selector"
    echo ""
    
    read -p "Select option (1-3, default: 1): " NODE_SEL_OPTION
    NODE_SEL_OPTION="${NODE_SEL_OPTION:-1}"
    
    NODE_SELECTOR=""
    case "$NODE_SEL_OPTION" in
        1)
            NODE_SELECTOR="      nodeSelector:
        nvidia.com/gpu.present: \"true\""
            print_success "Node selector: nvidia.com/gpu.present=true"
            ;;
        2)
            read -p "Enter node selector key: " NODE_SEL_KEY
            read -p "Enter node selector value: " NODE_SEL_VALUE
            NODE_SELECTOR="      nodeSelector:
        $NODE_SEL_KEY: \"$NODE_SEL_VALUE\""
            print_success "Node selector: $NODE_SEL_KEY=$NODE_SEL_VALUE"
            ;;
        3)
            print_info "No node selector configured"
            ;;
    esac
    
    # Build tolerations
    TOLERATIONS=""
    if [[ "$ADD_TOLERATION" =~ ^[Yy]$ ]]; then
        TOLERATIONS="      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule"
        print_success "GPU toleration added: nvidia.com/gpu:NoSchedule"
    fi
    
    # Build scheduling spec
    SCHEDULING_SPEC="  scheduling:
    type: Node
    node:"
    
    if [ -n "$NODE_SELECTOR" ]; then
        SCHEDULING_SPEC="$SCHEDULING_SPEC
$NODE_SELECTOR"
    fi
    
    if [ -n "$TOLERATIONS" ]; then
        SCHEDULING_SPEC="$SCHEDULING_SPEC
$TOLERATIONS"
    fi
fi

# Display name
echo ""
read -p "Display name (default: GPU Profile): " DISPLAY_NAME
DISPLAY_NAME="${DISPLAY_NAME:-GPU Profile}"

# Create the hardware profile
print_header "Creating Hardware Profile"

cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: $PROFILE_NAME
  namespace: $NAMESPACE
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: '$DISPLAY_NAME'
    opendatahub.io/description: 'GPU hardware profile with ${DEFAULT_GPU} GPU(s), ${DEFAULT_CPU} CPU(s), ${DEFAULT_MEMORY} Memory'
    opendatahub.io/managed: 'false'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
    app.kubernetes.io/part-of: hardwareprofile
spec:
  identifiers:
    - defaultCount: '$DEFAULT_CPU'
      displayName: CPU
      identifier: cpu
      maxCount: '$MAX_CPU'
      minCount: 1
      resourceType: CPU
    - defaultCount: $DEFAULT_MEMORY
      displayName: Memory
      identifier: memory
      maxCount: $MAX_MEMORY
      minCount: 1Gi
      resourceType: Memory
    - defaultCount: $DEFAULT_GPU
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: $MAX_GPU
      minCount: 1
      resourceType: Accelerator
$SCHEDULING_SPEC
EOF

if [ $? -eq 0 ]; then
    echo ""
    print_success "Hardware profile '$PROFILE_NAME' created/updated in $NAMESPACE"
else
    print_error "Failed to create hardware profile"
    exit 1
fi

# Verify
echo ""
print_step "Verifying hardware profile..."
oc get hardwareprofile "$PROFILE_NAME" -n "$NAMESPACE" -o yaml | grep -A 20 "spec:"

echo ""
print_header "Hardware Profile Created Successfully!"

echo -e "${CYAN}Summary:${NC}"
echo "  Name: $PROFILE_NAME"
echo "  Namespace: $NAMESPACE"
echo "  Display Name: $DISPLAY_NAME"
echo "  Resources: $DEFAULT_GPU GPU, $DEFAULT_CPU CPU, $DEFAULT_MEMORY Memory"
if [ "$SCHED_TYPE" = "1" ]; then
    echo "  Scheduling: Kueue (queue: $LOCAL_QUEUE)"
else
    echo "  Scheduling: Node"
    if [[ "$ADD_TOLERATION" =~ ^[Yy]$ ]]; then
        echo "  Tolerations: nvidia.com/gpu:NoSchedule"
    fi
    if [ -n "$NODE_SELECTOR" ]; then
        echo "  Node Selector: configured"
    fi
fi

echo ""
print_info "The hardware profile will appear in the RHOAI dashboard when deploying models."
echo ""
