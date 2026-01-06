#!/bin/bash

################################################################################
# Quick Deploy Qwen3-4B Model
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() { echo -e "${CYAN}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

print_header "Quick Deploy Qwen3-4B Model"

# Check if logged in
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift cluster"
    exit 1
fi

print_success "Connected to cluster"

# Ask for namespace
echo ""
echo -e "${YELLOW}Enter namespace name for model deployment:${NC}"
echo ""
echo "Examples: my-models, demo-models, llm-serving"
echo ""
read -p "Namespace: " NAMESPACE

if [ -z "$NAMESPACE" ]; then
    print_error "No namespace provided"
    exit 1
fi

# Create namespace if it doesn't exist
if ! oc get namespace "$NAMESPACE" &>/dev/null; then
    print_step "Creating namespace '$NAMESPACE'..."
    oc create namespace "$NAMESPACE"
    print_success "Namespace created"
else
    print_info "Using existing namespace '$NAMESPACE'"
fi

echo ""
print_header "Deployment Configuration"

echo "Model: Qwen3-4B (FP8)"
echo "URI: oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest"
echo "GPU: 1"
echo "CPU: 4"
echo "Memory: 16Gi"
echo "Tool Calling: Enabled"
echo "Authentication: Enabled"
echo ""

read -p "Proceed with deployment? (Y/n): " confirm
confirm=$(echo "$confirm" | tr -d '[:space:]')

if [[ "$confirm" =~ ^[Nn]$ ]]; then
    print_info "Deployment cancelled"
    exit 0
fi

echo ""
print_header "Deploying Model"

print_step "Creating LLMInferenceService 'qwen3-4b' in namespace '$NAMESPACE'..."

cat <<EOF | oc apply -f -
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen3-4b
  namespace: $NAMESPACE
  labels:
    kueue.x-k8s.io/queue-name: default
    opendatahub.io/dashboard: "true"
    opendatahub.io/genai-asset: "true"
  annotations:
    security.opendatahub.io/enable-auth: "true"
spec:
  replicas: 1
  model:
    uri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest
    name: qwen3-4b
  router:
    route: {}
    gateway: {}
    scheduler: {}
  template:
    containers:
    - name: main
      env:
        - name: VLLM_ADDITIONAL_ARGS
          value: "--enable-auto-tool-choice --tool-call-parser=hermes"
      resources:
        limits:
          cpu: '4'
          memory: 16Gi
          nvidia.com/gpu: "1"
        requests:
          cpu: '2'
          memory: 8Gi
          nvidia.com/gpu: "1"
EOF

if [ $? -eq 0 ]; then
    echo ""
    print_success "✅ Model deployment created!"
    echo ""
    
    print_header "Next Steps"
    
    print_info "1. Monitor deployment status:"
    echo "   oc get llmisvc qwen3-4b -n $NAMESPACE -w"
    echo ""
    
    print_info "2. View pods:"
    echo "   oc get pods -n $NAMESPACE"
    echo ""
    
    print_info "3. Check logs (once pod is running):"
    echo "   oc logs -n $NAMESPACE -l serving.kserve.io/inferenceservice=qwen3-4b -f"
    echo ""
    
    print_warning "Note: Model will take 5-10 minutes to be ready"
    print_warning "You need GPU nodes for this to work!"
    echo ""
    
    print_info "4. Generate API token (once ready):"
    echo "   oc create token default -n $NAMESPACE --duration=24h"
    echo ""
    
    print_info "5. Get model endpoint:"
    echo "   oc get route -n $NAMESPACE"
    echo ""
    
    print_header "Check GPU Nodes"
    
    GPU_NODES=$(oc get nodes -l node-role.kubernetes.io/gpu-worker --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$GPU_NODES" -gt 0 ]; then
        print_success "GPU nodes available: $GPU_NODES"
        oc get nodes -l node-role.kubernetes.io/gpu-worker
    else
        print_warning "No GPU nodes found!"
        echo ""
        echo "The model pod will be pending until GPU nodes are available."
        echo ""
        echo "Create GPU nodes with:"
        echo "  ./scripts/create-gpu-machineset.sh"
    fi
    
else
    print_error "Failed to deploy model"
    exit 1
fi

echo ""

