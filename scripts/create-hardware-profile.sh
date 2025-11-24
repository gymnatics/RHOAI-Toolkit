#!/bin/bash
################################################################################
# Create GPU Hardware Profile in Namespace
################################################################################
# Creates a GPU hardware profile in the specified namespace for model deployment
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Create GPU Hardware Profile                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if logged in
if ! oc whoami &>/dev/null; then
    echo -e "${RED}✗ Not logged in to OpenShift${NC}"
    echo "Please login first: oc login <cluster-url>"
    exit 1
fi

# Get namespace from argument or current project
if [ -n "$1" ]; then
    NAMESPACE="$1"
else
    NAMESPACE=$(oc project -q 2>/dev/null)
    if [ -z "$NAMESPACE" ]; then
        echo -e "${RED}✗ Could not determine current namespace${NC}"
        echo "Usage: $0 [namespace]"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Connected to OpenShift cluster${NC}"
echo -e "Target namespace: ${YELLOW}$NAMESPACE${NC}"
echo ""

# Check if namespace exists
if ! oc get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}✗ Namespace '$NAMESPACE' does not exist${NC}"
    exit 1
fi

# Check if profile already exists
if oc get hardwareprofile gpu-profile -n "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}⚠ GPU hardware profile already exists in $NAMESPACE${NC}"
    read -p "Do you want to update it? (y/n): " update
    if [[ ! "$update" =~ ^[Yy]$ ]]; then
        echo "Exiting without changes."
        exit 0
    fi
fi

echo -e "${BLUE}Creating GPU hardware profile...${NC}"
echo ""

# Create hardware profile WITHOUT scheduling constraints
# This makes it visible in the UI regardless of GPU node availability
# The GPU resource request will still ensure pods are scheduled on GPU nodes
cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: gpu-profile
  namespace: $NAMESPACE
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: GPU Profile
    opendatahub.io/description: 'GPU hardware profile for NVIDIA GPU workloads'
    opendatahub.io/managed: 'false'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
    app.kubernetes.io/part-of: hardwareprofile
spec:
  identifiers:
    - defaultCount: '2'
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
EOF

echo ""
echo -e "${GREEN}✓ GPU hardware profile created/updated in $NAMESPACE${NC}"
echo ""

# Verify
echo -e "${BLUE}Verifying...${NC}"
oc get hardwareprofile gpu-profile -n "$NAMESPACE" -o jsonpath='{.metadata.name}{"\t"}{.metadata.annotations.opendatahub\.io/display-name}{"\t"}{.metadata.annotations.opendatahub\.io/disabled}{"\n"}' | \
    awk '{printf "Name: %s\nDisplay Name: %s\nDisabled: %s\n", $1, $2, $3}'

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Hardware Profile Setup Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The GPU Profile should now be visible in the RHOAI dashboard when deploying models in this namespace."
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "  • Hardware profiles are namespace-scoped in RHOAI 3.0"
echo "  • Create this profile in each namespace where you want to deploy GPU models"
echo "  • The profile will appear in the 'Hardware profile' dropdown during model deployment"
echo ""
echo -e "${YELLOW}To create in another namespace:${NC}"
echo "  $0 <namespace-name>"
echo ""


