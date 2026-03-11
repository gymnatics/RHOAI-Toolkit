#!/bin/bash
################################################################################
# Generate MaaS API Token
################################################################################
# This script helps generate a MaaS API token for authentication
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Source RHOAI detection utility
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/rhoai-detect.sh" ]; then
    source "$SCRIPT_DIR/lib/rhoai-detect.sh"
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          MaaS API Token Generator                              ║${NC}"
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

# Detect RHOAI version and get MaaS endpoint
detect_rhoai_version

if ! get_maas_endpoint; then
    echo ""
    if is_rhoai_33_or_higher; then
        echo "For RHOAI 3.3+: Enable modelsAsService in DataScienceCluster"
    else
        echo "For RHOAI 3.2 and earlier: Run ../scripts/setup-maas.sh"
    fi
    exit 1
fi

echo ""

# Generate token using OpenShift service account
echo -e "${BLUE}Generating API token...${NC}"
echo ""

# Create a service account for MaaS access
SA_NAME="maas-demo-user"
SA_NAMESPACE="maas-demo"

# Ensure namespace exists
if ! oc get namespace "$SA_NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}Creating namespace: $SA_NAMESPACE${NC}"
    oc create namespace "$SA_NAMESPACE"
fi

# Create service account if it doesn't exist
if ! oc get sa "$SA_NAME" -n "$SA_NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}Creating service account: $SA_NAME${NC}"
    oc create sa "$SA_NAME" -n "$SA_NAMESPACE"
fi

# Get the token
TOKEN=$(oc create token "$SA_NAME" -n "$SA_NAMESPACE" --duration=24h 2>/dev/null || oc sa get-token "$SA_NAME" -n "$SA_NAMESPACE" 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}✗ Failed to generate token${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Token generated successfully!${NC}"
echo ""

# Save to file
TOKEN_FILE="maas-token.txt"
echo "$TOKEN" > "$TOKEN_FILE"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ MaaS API Token Generated!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Token saved to: $TOKEN_FILE"
echo ""
echo -e "${YELLOW}RHOAI Version:${NC} $RHOAI_VERSION"
echo ""
echo -e "${YELLOW}API Endpoint:${NC}"
echo "  https://$MAAS_ENDPOINT/v1/chat/completions"
echo ""
echo -e "${YELLOW}Token (first 50 chars):${NC}"
echo "  ${TOKEN:0:50}..."
echo ""
echo -e "${YELLOW}Export for use:${NC}"
echo "  export MAAS_TOKEN=\"$TOKEN\""
echo "  export MAAS_ENDPOINT=\"https://$MAAS_ENDPOINT/v1/chat/completions\""
echo ""
echo -e "${YELLOW}Test the API:${NC}"
echo "  ./test-maas-api.sh"
echo ""
echo -e "${RED}⚠ Keep this token secure! It expires in 24 hours.${NC}"
echo ""
