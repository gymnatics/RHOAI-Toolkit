#!/bin/bash

################################################################################
# Deploy Qwen3-4B with Tool Calling Enabled
################################################################################
# This script deploys Qwen3-4B with tool calling properly configured.
# It uses YAML deployment to avoid the VLLM_ADDITIONAL_ARGS UI issue.
#
# Usage: ./scripts/deploy-qwen3-4b-with-tools.sh <namespace>
################################################################################

set -e

# Color codes
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

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Check if namespace provided
if [ -z "$1" ]; then
    print_error "Namespace required"
    echo "Usage: $0 <namespace>"
    echo "Example: $0 0-demo"
    exit 1
fi

NAMESPACE=$1

print_header "Deploy Qwen3-4B with Tool Calling"

# Check if logged in
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift"
    echo "Please login first: oc login <cluster-url>"
    exit 1
fi

print_success "Connected to: $(oc whoami --show-server)"

# Check if namespace exists
if ! oc get namespace "$NAMESPACE" &>/dev/null; then
    print_error "Namespace '$NAMESPACE' does not exist"
    exit 1
fi

print_success "Namespace '$NAMESPACE' found"
echo ""

# Check if deployment already exists
if oc get llmisvc qwen3-4b -n "$NAMESPACE" &>/dev/null; then
    print_warning "Deployment 'qwen3-4b' already exists in namespace '$NAMESPACE'"
    read -p "Delete and redeploy? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deleting existing deployment..."
        oc delete llmisvc qwen3-4b -n "$NAMESPACE"
        sleep 5
        print_success "Deleted"
    else
        print_info "Exiting without changes"
        exit 0
    fi
fi

echo ""
print_info "Deploying Qwen3-4B with tool calling enabled..."
echo ""
echo "Configuration:"
echo "  Model: Qwen3-4B (FP8)"
echo "  Tool Calling: Enabled (hermes parser)"
echo "  GPU: 1x NVIDIA GPU"
echo "  CPU: 4 cores"
echo "  Memory: 16Gi"
echo ""

# Create the deployment
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
    tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
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
    print_success "Deployment created!"
    echo ""
    
    print_info "Waiting for pods to start (this may take 2-3 minutes)..."
    sleep 10
    
    # Wait for pod to be created
    timeout=180
    elapsed=0
    until oc get pods -n "$NAMESPACE" -l serving.kserve.io/inferenceservice=qwen3-4b &>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Timeout waiting for pods"
            break
        fi
        echo "Waiting for pods... (${elapsed}s elapsed)"
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    echo ""
    print_header "Deployment Status"
    
    # Show pods
    echo "Pods:"
    oc get pods -n "$NAMESPACE" -l serving.kserve.io/inferenceservice=qwen3-4b
    
    echo ""
    echo "LLMInferenceService:"
    oc get llmisvc qwen3-4b -n "$NAMESPACE"
    
    echo ""
    print_header "Next Steps"
    
    echo "1. Wait for the pod to be Running (check with: oc get pods -n $NAMESPACE)"
    echo ""
    echo "2. Check logs:"
    echo "   POD=\$(oc get pods -n $NAMESPACE -l serving.kserve.io/inferenceservice=qwen3-4b -o name | head -1)"
    echo "   oc logs \$POD -n $NAMESPACE -c kserve-container"
    echo ""
    echo "3. Get the endpoint:"
    echo "   ENDPOINT=\$(oc get route -n $NAMESPACE -l serving.kserve.io/inferenceservice=qwen3-4b -o jsonpath='{.items[0].spec.host}')"
    echo "   echo \"https://\$ENDPOINT\""
    echo ""
    echo "4. Test tool calling:"
    echo "   curl -X POST \"https://\$ENDPOINT/v1/chat/completions\" \\"
    echo "     -H \"Content-Type: application/json\" \\"
    echo "     -d '{"
    echo "       \"model\": \"qwen3-4b\","
    echo "       \"messages\": [{\"role\": \"user\", \"content\": \"What is 2+2?\"}],"
    echo "       \"tools\": [{"
    echo "         \"type\": \"function\","
    echo "         \"function\": {"
    echo "           \"name\": \"calculate\","
    echo "           \"description\": \"Do math\","
    echo "           \"parameters\": {\"type\": \"object\", \"properties\": {\"expr\": {\"type\": \"string\"}}}"
    echo "         }"
    echo "       }]"
    echo "     }'"
    echo ""
    
    print_success "Deployment complete!"
else
    print_error "Deployment failed"
    exit 1
fi

