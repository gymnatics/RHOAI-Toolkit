#!/bin/bash

################################################################################
# Fix GPU ResourceFlavor for Tainted Nodes
################################################################################
# This script configures the Kueue ResourceFlavor to handle GPU node taints.
# 
# Issue: Models fail to deploy with "untolerated taint" error even when using
#        GPU hardware profiles.
#
# Solution: Add toleration to nvidia-gpu-flavor ResourceFlavor.
#
# Usage: ./scripts/fix-gpu-resourceflavor.sh
################################################################################

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils/colors.sh"
source "$SCRIPT_DIR/../lib/utils/common.sh"

################################################################################
# Main Script
################################################################################

print_header "Fix GPU ResourceFlavor for Tainted Nodes"

# Check if logged in to OpenShift
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift"
    echo "Please login first: oc login <cluster-url>"
    exit 1
fi

print_success "Connected to OpenShift cluster"
echo ""

# Check if nvidia-gpu-flavor exists
print_step "Checking for nvidia-gpu-flavor ResourceFlavor..."
if ! oc get resourceflavor nvidia-gpu-flavor &>/dev/null; then
    print_error "ResourceFlavor 'nvidia-gpu-flavor' not found"
    echo ""
    echo "This ResourceFlavor is created automatically by RHOAI when Kueue is enabled."
    echo ""
    echo "Please ensure:"
    echo "  1. RHOAI 3.0 is installed"
    echo "  2. Kueue operator is installed"
    echo "  3. Kueue is set to 'Unmanaged' in DataScienceCluster"
    echo "  4. Kueue is enabled in OdhDashboardConfig"
    echo ""
    exit 1
fi

print_success "ResourceFlavor 'nvidia-gpu-flavor' found"
echo ""

# Check current configuration
print_step "Checking current ResourceFlavor configuration..."
current_tolerations=$(oc get resourceflavor nvidia-gpu-flavor -o jsonpath='{.spec.tolerations}' 2>/dev/null)
current_nodeLabels=$(oc get resourceflavor nvidia-gpu-flavor -o jsonpath='{.spec.nodeLabels}' 2>/dev/null)

echo "Current configuration:"
if [ -n "$current_nodeLabels" ] && [ "$current_nodeLabels" != "null" ]; then
    echo "  Node Labels: $current_nodeLabels"
else
    echo "  Node Labels: (none)"
fi

if [ -n "$current_tolerations" ] && [ "$current_tolerations" != "null" ]; then
    echo "  Tolerations: $current_tolerations"
else
    echo "  Tolerations: (none)"
fi
echo ""

# Check if GPU nodes exist
print_step "Checking for GPU nodes..."
gpu_nodes=$(oc get nodes -l nvidia.com/gpu.present=true -o name 2>/dev/null)

if [ -z "$gpu_nodes" ]; then
    print_warning "No GPU nodes found with label nvidia.com/gpu.present=true"
    echo ""
    echo "GPU nodes will be detected automatically when they are added."
    echo "Configuring ResourceFlavor with node selector only..."
    echo ""
    
    cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
EOF
    
    if [ $? -eq 0 ]; then
        print_success "ResourceFlavor configured with node selector"
        echo ""
        echo "When GPU nodes are added, run this script again to add tolerations if needed."
    else
        print_error "Failed to configure ResourceFlavor"
        exit 1
    fi
    exit 0
fi

print_success "Found GPU nodes:"
echo "$gpu_nodes" | sed 's/node\//  - /'
echo ""

# Check if GPU nodes have taints
print_step "Checking GPU node taints..."
has_taint=$(oc get nodes -l nvidia.com/gpu.present=true -o json | jq -r '.items[].spec.taints[]? | select(.key=="nvidia.com/gpu") | .key' | head -1)

if [ -n "$has_taint" ]; then
    print_info "✓ GPU nodes are tainted with nvidia.com/gpu:NoSchedule"
    echo ""
    echo -e "${CYAN}GPU nodes are tainted to prevent non-GPU workloads.${NC}"
    echo -e "${CYAN}ResourceFlavor needs toleration to schedule GPU workloads.${NC}"
    echo ""
    
    read -p "Configure ResourceFlavor with GPU toleration? (Y/n): " add_toleration
    add_toleration=${add_toleration:-Y}
    
    if [[ ! "$add_toleration" =~ ^[Yy]$ ]]; then
        print_warning "Skipping toleration configuration"
        print_warning "GPU workloads may fail with 'untolerated taint' error"
        exit 0
    fi
    
    echo ""
    echo "Updating nvidia-gpu-flavor ResourceFlavor with toleration..."
    echo ""
    
    cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
EOF
    
    if [ $? -eq 0 ]; then
        print_success "ResourceFlavor configured with GPU toleration"
        echo ""
        echo "✓ Node selector: nvidia.com/gpu.present=true"
        echo "✓ Toleration: nvidia.com/gpu:NoSchedule"
    else
        print_error "Failed to configure ResourceFlavor"
        exit 1
    fi
else
    print_info "✓ GPU nodes are NOT tainted"
    echo ""
    echo -e "${YELLOW}GPU nodes are not tainted.${NC}"
    echo -e "${YELLOW}This means any workload can be scheduled on GPU nodes.${NC}"
    echo ""
    echo -e "${CYAN}Recommendation: Taint GPU nodes to reserve them for GPU workloads only.${NC}"
    echo -e "${CYAN}This prevents expensive GPU instances from being used by non-GPU workloads.${NC}"
    echo ""
    echo -e "${CYAN}Command: oc adm taint nodes -l nvidia.com/gpu.present=true nvidia.com/gpu=:NoSchedule${NC}"
    echo ""
    
    read -p "Do you want to taint GPU nodes now? (y/N): " taint_nodes
    taint_nodes=${taint_nodes:-N}
    
    if [[ "$taint_nodes" =~ ^[Yy]$ ]]; then
        print_step "Tainting GPU nodes..."
        oc adm taint nodes -l nvidia.com/gpu.present=true nvidia.com/gpu=:NoSchedule --overwrite
        
        if [ $? -eq 0 ]; then
            print_success "GPU nodes tainted successfully"
            echo ""
            echo "Now updating ResourceFlavor with toleration..."
            echo ""
            
            cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
EOF
            
            if [ $? -eq 0 ]; then
                print_success "ResourceFlavor configured with GPU toleration"
                echo ""
                echo "✓ GPU nodes tainted"
                echo "✓ Node selector: nvidia.com/gpu.present=true"
                echo "✓ Toleration: nvidia.com/gpu:NoSchedule"
            else
                print_error "Failed to configure ResourceFlavor"
                exit 1
            fi
        else
            print_error "Failed to taint GPU nodes"
            exit 1
        fi
        
        echo ""
        print_header "Configuration Complete! ✅"
        echo ""
        echo "GPU nodes are now tainted and ResourceFlavor is configured."
        echo "You can deploy models with GPU hardware profiles."
        exit 0
    fi
    
    echo ""
    echo "Updating nvidia-gpu-flavor ResourceFlavor with node selector only..."
    echo ""
    
    cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
EOF
    
    if [ $? -eq 0 ]; then
        print_success "ResourceFlavor configured with node selector"
        echo ""
        echo "✓ Node selector: nvidia.com/gpu.present=true"
        echo "✓ No tolerations needed (GPU nodes not tainted)"
        echo ""
        print_info "Recommendation: Consider tainting GPU nodes to prevent non-GPU workloads"
        echo "  Command: oc adm taint nodes -l nvidia.com/gpu.present=true nvidia.com/gpu=:NoSchedule"
    else
        print_error "Failed to configure ResourceFlavor"
        exit 1
    fi
fi

echo ""
print_header "Configuration Complete! ✅"
echo ""
echo "You can now deploy models with GPU hardware profiles."
echo ""
echo "Test by deploying a model through the RHOAI dashboard:"
echo "  1. Navigate to a Data Science Project"
echo "  2. Click 'Deploy model'"
echo "  3. Select a GPU hardware profile"
echo "  4. Deploy"
echo ""
echo "For more information, see: docs/GPU-TAINTS-RHOAI3.md"

