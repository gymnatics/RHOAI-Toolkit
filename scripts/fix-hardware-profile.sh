#!/bin/bash
################################################################################
# Fix GPU Hardware Profile for RHOAI 3.0 UI Discovery
################################################################################
# This script fixes the common issue where GPU hardware profiles exist but
# aren't visible in the model deployment UI
#
# Key fixes:
# 1. Hardware profiles must be in the SAME NAMESPACE as your models
# 2. Profiles need specific labels and annotations
# 3. Remove scheduling constraints that hide profiles when no GPU nodes exist
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Fix GPU Hardware Profile                             ║${NC}"
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

# Get current namespace
CURRENT_NS=$(oc project -q 2>/dev/null)
echo -e "Current namespace: ${YELLOW}$CURRENT_NS${NC}"
echo ""

# Check for existing hardware profiles in current namespace
echo -e "${BLUE}Checking hardware profiles in $CURRENT_NS...${NC}"
EXISTING_PROFILES=$(oc get hardwareprofile -n "$CURRENT_NS" -o name 2>/dev/null || echo "")

if [ -n "$EXISTING_PROFILES" ]; then
    echo -e "${YELLOW}Found existing hardware profiles:${NC}"
    oc get hardwareprofile -n "$CURRENT_NS" -o custom-columns=NAME:.metadata.name,DISPLAY:.metadata.annotations.'opendatahub\.io/display-name',DISABLED:.metadata.annotations.'opendatahub\.io/disabled' 2>/dev/null || oc get hardwareprofile -n "$CURRENT_NS"
    echo ""
fi

# Check for old API version profiles
OLD_API_PROFILES=$(oc get hardwareprofile -n "$CURRENT_NS" -o json 2>/dev/null | jq -r '.items[] | select(.apiVersion == "dashboard.opendatahub.io/v1") | .metadata.name' 2>/dev/null || echo "")

if [ -n "$OLD_API_PROFILES" ]; then
    echo -e "${YELLOW}⚠ Found hardware profiles with old API version (dashboard.opendatahub.io/v1)${NC}"
    echo "These won't be visible in the model deployment UI!"
    echo ""
    echo "Profiles to fix:"
    echo "$OLD_API_PROFILES"
    echo ""
    read -p "Delete old profiles and recreate with correct API version? (y/n): " fix_old
    
    if [[ "$fix_old" =~ ^[Yy]$ ]]; then
        for profile in $OLD_API_PROFILES; do
            echo -e "${YELLOW}Deleting old profile: $profile${NC}"
            oc delete hardwareprofile "$profile" -n "$CURRENT_NS"
        done
        echo -e "${GREEN}✓ Old profiles deleted${NC}"
        echo ""
    fi
fi

# Create correct hardware profile
echo -e "${BLUE}Creating GPU hardware profile in $CURRENT_NS...${NC}"
echo ""

cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: gpu-profile
  namespace: $CURRENT_NS
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
echo -e "${GREEN}✓ GPU hardware profile created/updated${NC}"
echo ""

# Verify
echo -e "${BLUE}Verifying hardware profile...${NC}"
echo ""

oc get hardwareprofile gpu-profile -n "$CURRENT_NS" -o yaml | grep -E "apiVersion|name:|display-name|disabled" | head -10

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Hardware Profile Fix Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The hardware profile should now be visible in the RHOAI dashboard!"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Refresh your browser (Cmd+Shift+R or Ctrl+Shift+R)"
echo "2. Navigate to model deployment in the RHOAI dashboard"
echo "3. The 'GPU Profile' should now appear in the hardware profile dropdown"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "  • Hardware profiles are namespace-scoped in RHOAI 3.0"
echo "  • The profile must exist in the SAME namespace where you deploy models"
echo "  • Use './scripts/create-hardware-profile.sh <namespace>' for other namespaces"
echo ""
echo -e "${YELLOW}If the profile still doesn't appear:${NC}"
echo "  • Check you're deploying models in the correct namespace ($CURRENT_NS)"
echo "  • Try restarting the dashboard pods:"
echo "    oc delete pod -n redhat-ods-applications -l app=rhods-dashboard"
echo ""

