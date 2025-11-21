#!/bin/bash
################################################################################
# Setup Demo Model for MaaS
################################################################################
# This script deploys a sample model (Llama 3.2-3B) with MaaS enabled
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          MaaS Demo Model Setup                                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if logged in
if ! oc whoami &>/dev/null; then
    echo -e "${RED}✗ Not logged in to OpenShift${NC}"
    echo "Please login first: oc login <cluster-url>"
    exit 1
fi

echo -e "${GREEN}✓ Connected to OpenShift cluster${NC}"
echo ""

# Check if RHOAI is installed
if ! oc get datasciencecluster default-dsc &>/dev/null; then
    echo -e "${RED}✗ RHOAI not installed${NC}"
    echo "Please install RHOAI first"
    exit 1
fi

echo -e "${GREEN}✓ RHOAI is installed${NC}"
echo ""

# Check if MaaS is set up
if ! oc get namespace maas-api &>/dev/null; then
    echo -e "${YELLOW}⚠ MaaS infrastructure not set up${NC}"
    echo "Run: ../scripts/setup-maas.sh"
    echo ""
    read -p "Continue anyway? (y/n): " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Create a demo project
PROJECT_NAME="maas-demo"
echo -e "${BLUE}Creating demo project: $PROJECT_NAME${NC}"

if oc get project "$PROJECT_NAME" &>/dev/null; then
    echo -e "${YELLOW}⚠ Project $PROJECT_NAME already exists${NC}"
else
    oc new-project "$PROJECT_NAME"
    echo -e "${GREEN}✓ Project created${NC}"
fi
echo ""

# Deploy model via YAML
echo -e "${BLUE}Deploying Llama 3.2-3B model with MaaS...${NC}"
echo ""
echo -e "${YELLOW}Note: This creates a ServingRuntime and InferenceService${NC}"
echo -e "${YELLOW}The model will take 5-10 minutes to download and start${NC}"
echo ""

cat <<EOF | oc apply -f -
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: vllm-runtime
  namespace: $PROJECT_NAME
  labels:
    opendatahub.io/dashboard: "true"
spec:
  annotations:
    prometheus.io/path: /metrics
    prometheus.io/port: "8080"
  containers:
    - args:
        - --model
        - /mnt/models
        - --port
        - "8080"
        - --max-model-len
        - "4096"
      image: quay.io/modh/vllm:rhoai-2.15-20241107
      name: kserve-container
      ports:
        - containerPort: 8080
          protocol: TCP
  multiModel: false
  supportedModelFormats:
    - autoSelect: true
      name: pytorch
---
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: llama-3-2-3b-demo
  namespace: $PROJECT_NAME
  labels:
    opendatahub.io/dashboard: "true"
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
    openshift.io/display-name: "Llama 3.2-3B Demo"
    maas.opendatahub.io/enabled: "true"
spec:
  predictor:
    model:
      modelFormat:
        name: pytorch
      runtime: vllm-runtime
      storage:
        key: aws-connection-models
        path: models/instructlab/granite-7b-lab
    tolerations:
      - effect: NoSchedule
        key: nvidia.com/gpu
        operator: Exists
    resources:
      limits:
        nvidia.com/gpu: "1"
      requests:
        nvidia.com/gpu: "1"
EOF

echo ""
echo -e "${GREEN}✓ Model deployment created${NC}"
echo ""

echo -e "${BLUE}Checking deployment status...${NC}"
echo ""

# Wait a bit for the deployment to start
sleep 5

# Show status
echo "InferenceService status:"
oc get inferenceservice llama-3-2-3b-demo -n "$PROJECT_NAME" 2>/dev/null || echo "Not ready yet"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Demo model deployment initiated!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Wait for model to be ready (5-10 minutes):"
echo -e "   ${YELLOW}oc get inferenceservice -n $PROJECT_NAME -w${NC}"
echo ""
echo "2. Check in RHOAI Dashboard:"
echo "   - Go to Models"
echo "   - Look for 'llama-3-2-3b-demo'"
echo "   - Wait for status: Running"
echo ""
echo "3. Generate MaaS token:"
echo -e "   ${YELLOW}./generate-maas-token.sh${NC}"
echo ""
echo "4. Test the API:"
echo -e "   ${YELLOW}./test-maas-api.sh${NC}"
echo ""


