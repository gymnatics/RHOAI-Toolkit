#!/bin/bash

#############################################################################
# Create GPU MachineSet for OpenShift Cluster
# This script generates a GPU MachineSet YAML based on existing worker nodes
#
# Usage:
#   ./create-gpu-machineset.sh                    # Interactive mode
#   ./create-gpu-machineset.sh --spot             # Interactive with spot default
#   ./create-gpu-machineset.sh --instance-type g6e.4xlarge --spot --apply
#
# Options:
#   --instance-type TYPE   GPU instance type (g6e.xlarge, g6e.2xlarge, g6e.4xlarge, p5.48xlarge)
#   --spot                 Use spot instances
#   --spot-max-price PRICE Maximum spot price per hour
#   --az ZONE              Availability zone (e.g., us-east-2a)
#   --replicas N           Number of replicas (default: 0)
#   --apply                Apply the MachineSet immediately
#   --help                 Show this help
#
# Key Changes from Regular Worker to GPU Worker:
# 1. machine-role: worker → gpu-worker
# 2. machine-type: worker → gpu-worker  
# 3. Add label: node-role.kubernetes.io/gpu-worker: ''
# 4. Add taint: nvidia.com/gpu:NoSchedule
# 5. Change instanceType to GPU instance (g6e.*, p5.*)
# 6. Update annotations for GPU count, vCPU, memory
#############################################################################

# Parse command line arguments
CLI_INSTANCE_TYPE=""
CLI_SPOT=false
CLI_SPOT_MAX_PRICE=""
CLI_AZ=""
CLI_REPLICAS=""
CLI_APPLY=false
NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --instance-type)
            CLI_INSTANCE_TYPE="$2"
            NON_INTERACTIVE=true
            shift 2
            ;;
        --spot)
            CLI_SPOT=true
            shift
            ;;
        --spot-max-price)
            CLI_SPOT_MAX_PRICE="$2"
            CLI_SPOT=true
            shift 2
            ;;
        --az)
            CLI_AZ="$2"
            shift 2
            ;;
        --replicas)
            CLI_REPLICAS="$2"
            shift 2
            ;;
        --apply)
            CLI_APPLY=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --instance-type TYPE   GPU instance type"
            echo "  --spot                 Use spot instances"
            echo "  --spot-max-price PRICE Maximum spot price per hour"
            echo "  --az ZONE              Availability zone"
            echo "  --replicas N           Number of replicas (default: 0)"
            echo "  --apply                Apply the MachineSet immediately"
            echo "  --help                 Show this help"
            echo ""
            echo "Instance Types:"
            echo "  g6e.xlarge   - 1x NVIDIA L40S | 4 vCPU  | 16 GB RAM"
            echo "  g6e.2xlarge  - 1x NVIDIA L40S | 8 vCPU  | 32 GB RAM"
            echo "  g6e.4xlarge  - 1x NVIDIA L40S | 16 vCPU | 64 GB RAM"
            echo "  p5.48xlarge  - 8x NVIDIA H100 | 192 vCPU| 2048 GB RAM"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}$1${NC}"
}

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                  Create GPU MachineSet for OpenShift                       ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if oc is available
if ! command -v oc &> /dev/null; then
    print_error "oc command not found. Please install the OpenShift CLI."
    exit 1
fi

# Check if connected to cluster
if ! oc whoami &> /dev/null; then
    print_error "Not connected to an OpenShift cluster."
    echo ""
    echo "Please set your KUBECONFIG:"
    echo "  export KUBECONFIG=/Users/dayeo/Openshift-installation/openshift-cluster-install/auth/kubeconfig"
    exit 1
fi

print_success "Connected to cluster: $(oc whoami --show-server)"
echo ""

# Get existing MachineSet to use as template
print_info "Fetching existing worker MachineSet as template..."
EXISTING_MACHINESET=$(oc get machineset -n openshift-machine-api -o name | head -1)

if [ -z "$EXISTING_MACHINESET" ]; then
    print_error "No existing MachineSet found"
    exit 1
fi

EXISTING_MACHINESET_NAME=$(echo $EXISTING_MACHINESET | cut -d'/' -f2)
print_info "Using template: $EXISTING_MACHINESET_NAME"
echo ""

# Extract ALL values from existing MachineSet
print_info "Extracting cluster configuration..."
CLUSTER_ID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}')
AMI_ID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].spec.template.spec.providerSpec.value.ami.id}')
IAM_PROFILE=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].spec.template.spec.providerSpec.value.iamInstanceProfile.id}')
REGION=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].spec.template.spec.providerSpec.value.placement.region}')
VOLUME_SIZE=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].spec.template.spec.providerSpec.value.blockDevices[0].ebs.volumeSize}')
VOLUME_TYPE=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].spec.template.spec.providerSpec.value.blockDevices[0].ebs.volumeType}')

echo ""
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_header "Extracted Cluster Configuration"
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Cluster ID:    $CLUSTER_ID"
echo "AMI ID:        $AMI_ID"
echo "IAM Profile:   $IAM_PROFILE"
echo "Region:        $REGION"
echo "Volume:        ${VOLUME_SIZE}GB ${VOLUME_TYPE}"
echo ""

# Simple prompts for only the required inputs
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_header "GPU MachineSet Configuration (3 simple questions)"
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Question 1: GPU Instance Type
echo "1️⃣  Select GPU instance type:"
echo ""
echo "  1) g6e.xlarge   - 1x NVIDIA L40S | 4 vCPU  | 16 GB RAM   | ~\$0.69/hr"
echo "  2) g6e.2xlarge  - 1x NVIDIA L40S | 8 vCPU  | 32 GB RAM   | ~\$1.10/hr"
echo "  3) g6e.4xlarge  - 1x NVIDIA L40S | 16 vCPU | 64 GB RAM   | ~\$1.92/hr"
echo "  4) p5.48xlarge  - 8x NVIDIA H100 | 192 vCPU| 2048 GB RAM | ~\$98/hr"
echo ""
read -p "Enter choice [1-4]: " instance_choice

case $instance_choice in
    1)
        INSTANCE_TYPE="g6e.xlarge"
        GPU_COUNT=1
        VCPU=4
        MEMORY_MB=16384
        ;;
    2)
        INSTANCE_TYPE="g6e.2xlarge"
        GPU_COUNT=1
        VCPU=8
        MEMORY_MB=32768
        ;;
    3)
        INSTANCE_TYPE="g6e.4xlarge"
        GPU_COUNT=1
        VCPU=16
        MEMORY_MB=65536
        ;;
    4)
        INSTANCE_TYPE="p5.48xlarge"
        GPU_COUNT=8
        VCPU=192
        MEMORY_MB=2097152
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
print_success "Selected: $INSTANCE_TYPE ($GPU_COUNT GPU, $VCPU vCPU, $((MEMORY_MB/1024))GB RAM)"
echo ""

# Question 1.5: Spot Instance Option
echo "1.5️⃣  Use Spot Instances? (up to 90% cost savings, but can be interrupted)"
echo ""
echo "  1) On-Demand (default) - Guaranteed capacity, full price"
echo "  2) Spot Instance - Up to 90% cheaper, may be interrupted"
echo ""
read -p "Enter choice [1-2, default: 1]: " spot_choice

USE_SPOT=false
SPOT_MAX_PRICE=""
case ${spot_choice:-1} in
    2)
        USE_SPOT=true
        echo ""
        print_info "Spot Instance selected"
        echo ""
        echo "Spot instances can save 60-90% but may be terminated with 2-min warning."
        echo "Recommended for: development, testing, fault-tolerant workloads"
        echo "Not recommended for: production serving, long-running training"
        echo ""
        read -p "Set max price per hour (leave empty for on-demand price cap): " SPOT_MAX_PRICE
        if [ -n "$SPOT_MAX_PRICE" ]; then
            print_success "Spot max price: \$${SPOT_MAX_PRICE}/hr"
        else
            print_success "Spot max price: On-demand price (default)"
        fi
        ;;
    *)
        print_success "On-Demand instance selected"
        ;;
esac
echo ""

# Question 2: Availability Zone and Subnet Selection
echo "2️⃣  Select availability zone and subnet:"
echo ""

# Get all available AZs and subnets from existing MachineSets
print_info "Scanning available subnets from existing MachineSets..."
echo ""

# Create arrays to store AZ and subnet information
declare -a AZ_LIST
declare -a SUBNET_LIST
declare -a SUBNET_TYPE_LIST  # "id" or "filter"
declare -a MACHINESET_LIST

# Extract unique AZ/subnet combinations - handle both subnet.id and subnet.filters
while IFS='|' read -r ms_name az subnet_id subnet_filter; do
    if [ -n "$az" ] && [ "$az" != "null" ]; then
        AZ_LIST+=("$az")
        MACHINESET_LIST+=("$ms_name")
        
        # Check if subnet.id is used (direct subnet ID)
        if [ -n "$subnet_id" ] && [ "$subnet_id" != "null" ]; then
            SUBNET_LIST+=("$subnet_id")
            SUBNET_TYPE_LIST+=("id")
        # Otherwise check for subnet.filters (tag-based)
        elif [ -n "$subnet_filter" ] && [ "$subnet_filter" != "null" ]; then
            SUBNET_LIST+=("$subnet_filter")
            SUBNET_TYPE_LIST+=("filter")
        else
            # Fallback - try to get the full subnet spec
            SUBNET_LIST+=("(auto-detect from AZ)")
            SUBNET_TYPE_LIST+=("auto")
        fi
    fi
done < <(oc get machineset -n openshift-machine-api -o json | \
    jq -r '.items[] | "\(.metadata.name)|\(.spec.template.spec.providerSpec.value.placement.availabilityZone)|\(.spec.template.spec.providerSpec.value.subnet.id // "null")|\(.spec.template.spec.providerSpec.value.subnet.filters[0].values[0] // "null")"')

if [ ${#AZ_LIST[@]} -eq 0 ]; then
    print_error "No availability zones found in existing MachineSets"
    exit 1
fi

# Display available options
echo "Available availability zones (from existing MachineSets):"
echo ""
for i in "${!AZ_LIST[@]}"; do
    if [ "${SUBNET_TYPE_LIST[$i]}" = "id" ]; then
        echo "  $((i+1))) ${AZ_LIST[$i]} - Subnet ID: ${SUBNET_LIST[$i]}"
    elif [ "${SUBNET_TYPE_LIST[$i]}" = "filter" ]; then
        echo "  $((i+1))) ${AZ_LIST[$i]} - Subnet Tag: ${SUBNET_LIST[$i]}"
    else
        echo "  $((i+1))) ${AZ_LIST[$i]} - (will use same subnet config as source)"
    fi
    echo "     (from MachineSet: ${MACHINESET_LIST[$i]})"
done
echo ""
echo "  $((${#AZ_LIST[@]}+1))) Enter custom AZ and subnet"
echo ""

read -p "Enter choice [1-$((${#AZ_LIST[@]}+1))]: " subnet_choice

# Variables to track subnet configuration
SUBNET_ID=""
SUBNET_FILTER_NAME=""
USE_SUBNET_FILTER=false

if [ "$subnet_choice" -eq "$((${#AZ_LIST[@]}+1))" ]; then
    # Custom AZ and subnet
    echo ""
    print_info "Enter custom availability zone and subnet"
    read -p "Availability Zone (e.g., us-east-2a): " AZ
    read -p "Subnet ID (e.g., subnet-xxxxx): " SUBNET_ID
else
    # Use selected subnet from list
    idx=$((subnet_choice-1))
    if [ $idx -ge 0 ] && [ $idx -lt ${#AZ_LIST[@]} ]; then
        AZ="${AZ_LIST[$idx]}"
        
        if [ "${SUBNET_TYPE_LIST[$idx]}" = "id" ]; then
            SUBNET_ID="${SUBNET_LIST[$idx]}"
            print_success "Selected: $AZ - Subnet ID: $SUBNET_ID"
        elif [ "${SUBNET_TYPE_LIST[$idx]}" = "filter" ]; then
            SUBNET_FILTER_NAME="${SUBNET_LIST[$idx]}"
            USE_SUBNET_FILTER=true
            print_success "Selected: $AZ - Subnet Tag: $SUBNET_FILTER_NAME"
        else
            # Auto-detect - get full subnet config from source MachineSet
            SOURCE_MS="${MACHINESET_LIST[$idx]}"
            SUBNET_FILTER_NAME=$(oc get machineset "$SOURCE_MS" -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.subnet.filters[0].values[0]}' 2>/dev/null)
            if [ -n "$SUBNET_FILTER_NAME" ]; then
                USE_SUBNET_FILTER=true
                print_success "Selected: $AZ - Subnet Tag: $SUBNET_FILTER_NAME (from $SOURCE_MS)"
            else
                SUBNET_ID=$(oc get machineset "$SOURCE_MS" -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.subnet.id}' 2>/dev/null)
                print_success "Selected: $AZ - Subnet ID: $SUBNET_ID (from $SOURCE_MS)"
            fi
        fi
    else
        print_error "Invalid choice"
        exit 1
    fi
fi

echo ""

# Question 3: Volume configuration
echo "3️⃣  Storage configuration:"
echo ""
echo "Current default: ${VOLUME_SIZE}GB ${VOLUME_TYPE}"
echo ""
read -p "Use default storage? [Y/n]: " use_default_storage

if [[ "$use_default_storage" == "n" || "$use_default_storage" == "N" ]]; then
    echo ""
    read -p "Enter volume size in GB [default: $VOLUME_SIZE]: " custom_volume_size
    VOLUME_SIZE=${custom_volume_size:-$VOLUME_SIZE}
    
    echo ""
    echo "Volume types:"
    echo "  1) gp3 (General Purpose SSD - recommended)"
    echo "  2) gp2 (General Purpose SSD - older)"
    echo "  3) io1 (Provisioned IOPS SSD)"
    echo "  4) io2 (Provisioned IOPS SSD - newer)"
    echo ""
    read -p "Select volume type [1-4, default: 1]: " vol_type_choice
    
    case ${vol_type_choice:-1} in
        1) VOLUME_TYPE="gp3" ;;
        2) VOLUME_TYPE="gp2" ;;
        3) VOLUME_TYPE="io1" ;;
        4) VOLUME_TYPE="io2" ;;
        *) VOLUME_TYPE="gp3" ;;
    esac
fi

print_success "Storage: ${VOLUME_SIZE}GB ${VOLUME_TYPE}"
echo ""

# Question 4: Number of replicas
echo "4️⃣  How many GPU worker nodes to create?"
echo ""
read -p "Enter number of replicas [default: 0 for later scaling]: " REPLICAS
REPLICAS=${REPLICAS:-0}

echo ""
print_success "Configuration complete!"
echo ""

# Generate MachineSet name
MACHINESET_NAME="${CLUSTER_ID}-gpu-worker-${INSTANCE_TYPE}-${AZ}"

# Create the GPU MachineSet YAML
OUTPUT_FILE="gpu-machineset-${INSTANCE_TYPE}-${AZ}.yaml"

print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "Generating GPU MachineSet YAML..."
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Generate subnet configuration based on type
if [ "$USE_SUBNET_FILTER" = true ]; then
    SUBNET_CONFIG="          subnet:
            filters:
              - name: 'tag:Name'
                values:
                  - ${SUBNET_FILTER_NAME}"
else
    SUBNET_CONFIG="          subnet:
            id: ${SUBNET_ID}"
fi

# Generate spot market options if enabled
SPOT_CONFIG=""
if [ "$USE_SPOT" = true ]; then
    if [ -n "$SPOT_MAX_PRICE" ]; then
        SPOT_CONFIG="          spotMarketOptions:
            maxPrice: '${SPOT_MAX_PRICE}'"
    else
        SPOT_CONFIG="          spotMarketOptions: {}"
    fi
fi

cat > "$OUTPUT_FILE" << EOF
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  name: ${MACHINESET_NAME}
  namespace: openshift-machine-api
  labels:
    machine.openshift.io/cluster-api-cluster: ${CLUSTER_ID}
  annotations:
    capacity.cluster-autoscaler.kubernetes.io/labels: kubernetes.io/arch=amd64
    machine.openshift.io/GPU: '${GPU_COUNT}'
    machine.openshift.io/memoryMb: '${MEMORY_MB}'
    machine.openshift.io/vCPU: '${VCPU}'
spec:
  replicas: ${REPLICAS}
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ${CLUSTER_ID}
      machine.openshift.io/cluster-api-machineset: ${MACHINESET_NAME}
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: ${CLUSTER_ID}
        machine.openshift.io/cluster-api-machine-role: gpu-worker
        machine.openshift.io/cluster-api-machine-type: gpu-worker
        machine.openshift.io/cluster-api-machineset: ${MACHINESET_NAME}
        node-role.kubernetes.io/gpu-worker: ''
    spec:
      metadata:
        labels:
          node-role.kubernetes.io/gpu-worker: ''
      taints:
        - effect: NoSchedule
          key: nvidia.com/gpu
      lifecycleHooks: {}
      providerSpec:
        value:
          apiVersion: machine.openshift.io/v1beta1
          kind: AWSMachineProviderConfig
          ami:
            id: ${AMI_ID}
          blockDevices:
            - ebs:
                encrypted: true
                iops: 0
                kmsKey:
                  arn: ''
                volumeSize: ${VOLUME_SIZE}
                volumeType: ${VOLUME_TYPE}
          capacityReservationId: ''
          credentialsSecret:
            name: aws-cloud-credentials
          deviceIndex: 0
          iamInstanceProfile:
            id: ${IAM_PROFILE}
          instanceType: ${INSTANCE_TYPE}
          metadata:
            creationTimestamp: null
          metadataServiceOptions: {}
          placement:
            availabilityZone: ${AZ}
            region: ${REGION}
          securityGroups:
            - filters:
                - name: 'tag:Name'
                  values:
                    - ${CLUSTER_ID}-node
            - filters:
                - name: 'tag:Name'
                  values:
                    - ${CLUSTER_ID}-lb
${SUBNET_CONFIG}
${SPOT_CONFIG}
          tags:
            - name: kubernetes.io/cluster/${CLUSTER_ID}
              value: owned
          userDataSecret:
            name: worker-user-data
EOF

print_success "GPU MachineSet YAML created: $OUTPUT_FILE"
echo ""

# Display the configuration summary
print_header "╔════════════════════════════════════════════════════════════════════════════╗"
print_header "║                    GPU MachineSet Summary                                  ║"
print_header "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📝 MachineSet Name:    $MACHINESET_NAME"
echo "💻 Instance Type:      $INSTANCE_TYPE"
echo "🎮 GPU Count:          $GPU_COUNT"
echo "⚙️  vCPU:               $VCPU"
echo "💾 Memory:             $((MEMORY_MB/1024)) GB"
echo "🌍 Availability Zone:  $AZ"
if [ "$USE_SUBNET_FILTER" = true ]; then
    echo "🔗 Subnet:             $SUBNET_FILTER_NAME (tag filter)"
else
    echo "🔗 Subnet:             $SUBNET_ID"
fi
echo "💿 Storage:            ${VOLUME_SIZE}GB ${VOLUME_TYPE}"
if [ "$USE_SPOT" = true ]; then
    if [ -n "$SPOT_MAX_PRICE" ]; then
        echo "💰 Pricing:            Spot Instance (max: \$${SPOT_MAX_PRICE}/hr)"
    else
        echo "💰 Pricing:            Spot Instance (on-demand price cap)"
    fi
else
    echo "💰 Pricing:            On-Demand"
fi
echo "📊 Replicas:           $REPLICAS"
echo ""
echo "📄 File:               $OUTPUT_FILE"
echo ""

# Show what changed from regular worker
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_header "Key Changes from Regular Worker MachineSet"
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✓ machine-role: worker → gpu-worker"
echo "✓ machine-type: worker → gpu-worker"
echo "✓ Added label: node-role.kubernetes.io/gpu-worker"
echo "✓ Added taint: nvidia.com/gpu:NoSchedule"
echo "✓ Instance type: m6a.4xlarge → $INSTANCE_TYPE"
echo "✓ GPU annotation: 0 → $GPU_COUNT"
echo ""

# Ask to apply
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Apply this MachineSet now? [y/N]: " apply_now

if [[ "$apply_now" == "y" || "$apply_now" == "Y" ]]; then
    echo ""
    print_info "Applying MachineSet..."
    oc apply -f "$OUTPUT_FILE"
    
    if [ $? -eq 0 ]; then
        echo ""
        print_success "✅ MachineSet applied successfully!"
        echo ""
        
        # Check if GPU ClusterPolicy needs to be created
        if oc get crd clusterpolicies.nvidia.com &>/dev/null; then
            if ! oc get clusterpolicy gpu-cluster-policy &>/dev/null; then
                print_info "GPU Operator detected but no ClusterPolicy found"
                echo ""
                read -p "Create GPU ClusterPolicy now? [Y/n]: " create_policy
                create_policy="${create_policy:-Y}"
                
                if [[ "$create_policy" =~ ^[Yy]$ ]]; then
                    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                    PARENT_DIR="$(dirname "$SCRIPT_DIR")"
                    POLICY_FILE="$PARENT_DIR/lib/manifests/operators/gpu-clusterpolicy.yaml"
                    
                    if [ -f "$POLICY_FILE" ]; then
                        print_info "Creating GPU ClusterPolicy..."
                        oc apply -f "$POLICY_FILE"
                        
                        if [ $? -eq 0 ]; then
                            echo ""
                            print_success "✅ GPU ClusterPolicy created!"
                            print_info "GPU operator daemonsets will deploy when nodes are ready"
                        else
                            print_warning "Failed to create ClusterPolicy"
                            echo "You can create it manually later:"
                            echo "  oc apply -f $POLICY_FILE"
                        fi
                    else
                        print_warning "ClusterPolicy manifest not found at: $POLICY_FILE"
                        echo "You can create it manually from the GPU Operator console"
                    fi
                    echo ""
                fi
            fi
        fi
        
        print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_header "Next Steps"
        print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "1️⃣  Monitor machine creation:"
        echo "   oc get machines -n openshift-machine-api -w"
        echo ""
        echo "2️⃣  Check MachineSet status:"
        echo "   oc get machineset ${MACHINESET_NAME} -n openshift-machine-api"
        echo ""
        echo "3️⃣  View GPU nodes when ready:"
        echo "   oc get nodes -l node-role.kubernetes.io/gpu-worker"
        echo ""
        echo "4️⃣  Verify GPU operator pods (once nodes are ready):"
        echo "   oc get pods -n nvidia-gpu-operator"
        echo ""
        echo "5️⃣  Scale up/down:"
        echo "   oc scale machineset ${MACHINESET_NAME} -n openshift-machine-api --replicas=<number>"
        echo ""
    else
        echo ""
        print_error "❌ Failed to apply MachineSet"
        echo ""
        echo "You can try applying manually:"
        echo "  oc apply -f $OUTPUT_FILE"
    fi
else
    echo ""
    print_info "MachineSet YAML saved to: $OUTPUT_FILE"
    echo ""
    print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_header "To Apply Later"
    print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Apply the MachineSet:"
    echo "  oc apply -f $OUTPUT_FILE"
    echo ""
    echo "Scale the MachineSet:"
    echo "  oc scale machineset ${MACHINESET_NAME} -n openshift-machine-api --replicas=1"
    echo ""
    echo "Monitor machines:"
    echo "  oc get machines -n openshift-machine-api -w"
    echo ""
fi

echo ""
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "✅ Done!"
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

