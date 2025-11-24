#!/bin/bash
################################################################################
# Create Hardware Profiles in Project Namespace
################################################################################
# Creates GPU hardware profiles in the specified namespace for model deployment
# In RHOAI 3.0, hardware profiles must be in the PROJECT namespace to appear
# during model deployment
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Create Hardware Profiles in Project Namespace            ║${NC}"
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

echo -e "${YELLOW}This will create the following hardware profiles in $NAMESPACE:${NC}"
echo "  1. gpu-profile (2-16 CPUs, 16-64Gi memory, 1-8 GPUs)"
echo "  2. small-gpu-profile (2-8 CPUs, 8-32Gi memory, 1-2 GPUs)"
echo "  3. large-gpu-profile (4-32 CPUs, 32-128Gi memory, 2-8 GPUs)"
echo ""
read -p "Continue? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}Creating hardware profiles...${NC}"
echo ""

# Create GPU Profile
echo -e "${GREEN}▶${NC} Creating gpu-profile..."
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
    opendatahub.io/description: 'Standard GPU hardware profile for NVIDIA GPU workloads'
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

# Create Small GPU Profile
echo -e "${GREEN}▶${NC} Creating small-gpu-profile..."
cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: small-gpu-profile
  namespace: $NAMESPACE
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: Small GPU Profile
    opendatahub.io/description: 'Small GPU profile for testing and development'
    opendatahub.io/managed: 'false'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
    app.kubernetes.io/part-of: hardwareprofile
spec:
  identifiers:
    - defaultCount: '2'
      displayName: CPU
      identifier: cpu
      maxCount: '8'
      minCount: 1
      resourceType: CPU
    - defaultCount: 8Gi
      displayName: Memory
      identifier: memory
      maxCount: 32Gi
      minCount: 4Gi
      resourceType: Memory
    - defaultCount: 1
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: 2
      minCount: 1
      resourceType: Accelerator
EOF

# Create Large GPU Profile
echo -e "${GREEN}▶${NC} Creating large-gpu-profile..."
cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: large-gpu-profile
  namespace: $NAMESPACE
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: Large GPU Profile
    opendatahub.io/description: 'Large GPU profile for demanding workloads'
    opendatahub.io/managed: 'false'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
    app.kubernetes.io/part-of: hardwareprofile
spec:
  identifiers:
    - defaultCount: '4'
      displayName: CPU
      identifier: cpu
      maxCount: '32'
      minCount: 2
      resourceType: CPU
    - defaultCount: 32Gi
      displayName: Memory
      identifier: memory
      maxCount: 128Gi
      minCount: 8Gi
      resourceType: Memory
    - defaultCount: 2
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: 8
      minCount: 1
      resourceType: Accelerator
EOF

echo ""
echo -e "${GREEN}✓ Hardware profiles created in $NAMESPACE${NC}"
echo ""

# Verify
echo -e "${BLUE}Verifying...${NC}"
oc get hardwareprofiles -n "$NAMESPACE"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Hardware Profile Setup Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The hardware profiles should now be visible in the RHOAI dashboard"
echo "when deploying models in the '$NAMESPACE' project."
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  • Hardware profiles are PROJECT-SCOPED in RHOAI 3.0"
echo "  • Profiles must be created in EACH project where you want to deploy models"
echo "  • The profiles will appear in the 'Hardware profile' dropdown during model deployment"
echo ""
echo -e "${YELLOW}To create in another project:${NC}"
echo "  $0 <project-name>"
echo ""

