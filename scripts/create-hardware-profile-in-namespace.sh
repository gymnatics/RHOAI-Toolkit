#!/bin/bash
################################################################################
# Create GPU Hardware Profile in Namespace
################################################################################
# Hardware profiles in RHOAI 3.0 are namespace-scoped for model deployment.
# This script creates a GPU hardware profile in a specified namespace.
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Create GPU Hardware Profile in Namespace                  ║${NC}"
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

# Get namespace
if [ -z "$1" ]; then
    CURRENT_NS=$(oc project -q 2>/dev/null || echo "")
    if [ -z "$CURRENT_NS" ]; then
        echo -e "${YELLOW}Please specify a namespace:${NC}"
        read -p "Namespace: " NAMESPACE
    else
        echo -e "${YELLOW}Current namespace: ${CURRENT_NS}${NC}"
        read -p "Use this namespace? (y/n): " use_current
        if [[ "$use_current" =~ ^[Yy]$ ]]; then
            NAMESPACE="$CURRENT_NS"
        else
            read -p "Enter namespace: " NAMESPACE
        fi
    fi
else
    NAMESPACE="$1"
fi

# Verify namespace exists
if ! oc get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}✗ Namespace '$NAMESPACE' does not exist${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Using namespace: $NAMESPACE${NC}"
echo ""

# Check if profile already exists
if oc get hardwareprofile gpu-profile -n "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}⚠ GPU hardware profile already exists in $NAMESPACE${NC}"
    read -p "Recreate it? (y/n): " recreate
    if [[ ! "$recreate" =~ ^[Yy]$ ]]; then
        echo "Exiting without changes."
        exit 0
    fi
    echo -e "${YELLOW}Deleting existing profile...${NC}"
    oc delete hardwareprofile gpu-profile -n "$NAMESPACE"
fi

# Create hardware profile
echo -e "${BLUE}Creating GPU hardware profile...${NC}"
echo ""

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
echo -e "${GREEN}✓ GPU hardware profile created in $NAMESPACE${NC}"
echo ""

# Verify
echo -e "${BLUE}Verifying...${NC}"
oc get hardwareprofile gpu-profile -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,DISPLAY:.metadata.annotations.'opendatahub\.io/display-name',DISABLED:.metadata.annotations.'opendatahub\.io/disabled'

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Hardware Profile Created Successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The GPU Profile should now be visible in the RHOAI dashboard"
echo "when deploying models in the '$NAMESPACE' namespace."
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "  • Hardware profiles in RHOAI 3.0 are namespace-scoped"
echo "  • Create this profile in each namespace where you deploy models"
echo "  • The profile will appear in the Hardware Profile dropdown"
echo "  • Refresh your browser (Cmd+Shift+R) if you don't see it immediately"
echo ""
echo -e "${BLUE}To create in another namespace:${NC}"
echo "  $0 <namespace-name>"
echo ""


