#!/bin/bash
################################################################################
# Fix GPU Hardware Profile for RHOAI 3.0 UI Discovery
################################################################################
# This script fixes the common issue where GPU hardware profiles exist but
# aren't visible in the model deployment UI
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

# Check for existing hardware profiles
echo -e "${BLUE}Checking existing hardware profiles...${NC}"
EXISTING_PROFILES=$(oc get hardwareprofile -n redhat-ods-applications -o name 2>/dev/null || echo "")

if [ -n "$EXISTING_PROFILES" ]; then
    echo -e "${YELLOW}Found existing hardware profiles:${NC}"
    oc get hardwareprofile -n redhat-ods-applications -o custom-columns=NAME:.metadata.name,API:.apiVersion,DISPLAY:.metadata.annotations.'opendatahub\.io/display-name' 2>/dev/null || oc get hardwareprofile -n redhat-ods-applications
    echo ""
fi

# Check for old API version profiles
OLD_API_PROFILES=$(oc get hardwareprofile -n redhat-ods-applications -o json 2>/dev/null | jq -r '.items[] | select(.apiVersion == "dashboard.opendatahub.io/v1") | .metadata.name' 2>/dev/null || echo "")

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
            oc delete hardwareprofile "$profile" -n redhat-ods-applications
        done
        echo -e "${GREEN}✓ Old profiles deleted${NC}"
        echo ""
    fi
fi

# Create correct hardware profile
echo -e "${BLUE}Creating GPU hardware profile with correct API version...${NC}"
echo ""

cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1alpha1
kind: HardwareProfile
metadata:
  name: gpu-profile
  namespace: redhat-ods-applications
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: GPU Profile
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
  tolerations:
    - effect: NoSchedule
      key: nvidia.com/gpu
      operator: Exists
EOF

echo ""
echo -e "${GREEN}✓ GPU hardware profile created/updated${NC}"
echo ""

# Verify
echo -e "${BLUE}Verifying hardware profile...${NC}"
echo ""

oc get hardwareprofile gpu-profile -n redhat-ods-applications -o yaml | grep -A 5 "apiVersion\|annotations\|spec:" || true

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Hardware Profile Fix Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The hardware profile should now be visible in the RHOAI dashboard!"
echo ""
echo "To verify:"
echo "1. Go to RHOAI Dashboard → Settings → Hardware Profiles"
echo "2. You should see 'GPU Profile'"
echo "3. When deploying a model, select 'GPU Profile' from the dropdown"
echo ""
echo -e "${YELLOW}Key Requirements for UI Visibility:${NC}"
echo "  ✓ API Version: infrastructure.opendatahub.io/v1alpha1"
echo "  ✓ Namespace: redhat-ods-applications"
echo "  ✓ Annotations: opendatahub.io/display-name"
echo "  ✓ Spec: identifiers array with CPU, Memory, GPU"
echo ""


