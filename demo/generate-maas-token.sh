#!/bin/bash
################################################################################
# Generate MaaS API Token
################################################################################
# Generates a MaaS credential appropriate for the detected RHOAI version:
#   RHOAI 3.4+: sk-oai-* API key via POST /maas-api/v1/api-keys (requires an
#               existing MaaSSubscription -- see scripts/deploy-maas-model.sh
#               or demo/maas-ratelimit-demo/deploy.sh)
#   RHOAI 3.3-: OpenShift ServiceAccount token via `oc create token`
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    if is_rhoai_34_or_higher; then
        echo "For RHOAI 3.4+: Enable modelsAsService/aigateway.modelsAsAService in DataScienceCluster"
        echo "Or run: ../scripts/setup-maas.sh"
    elif is_rhoai_33_or_higher; then
        echo "For RHOAI 3.3: Enable modelsAsService in DataScienceCluster"
    else
        echo "For RHOAI 3.2 and earlier: Run ../scripts/setup-maas.sh"
    fi
    exit 1
fi

echo ""

TOKEN_FILE="maas-token.txt"

if is_rhoai_34_or_higher; then
    ####################################################################
    # RHOAI 3.4+: sk-oai-* API key
    ####################################################################
    echo -e "${BLUE}RHOAI $RHOAI_VERSION uses sk-oai-* API keys (POST /maas-api/v1/api-keys), not${NC}"
    echo -e "${BLUE}OpenShift ServiceAccount tokens. This requires an existing MaaSSubscription.${NC}"
    echo ""

    echo -e "${CYAN}Available subscriptions:${NC}"
    SUBS=$(oc get maassubscription -n models-as-a-service --no-headers 2>/dev/null | awk '{print $1}')
    if [ -n "$SUBS" ]; then
        echo "$SUBS" | sed 's/^/  - /'
    else
        echo "  (none found -- deploy a model first: ../scripts/deploy-maas-model.sh --model simulator)"
    fi
    echo ""

    read -p "Enter subscription name: " SUBSCRIPTION
    if [ -z "$SUBSCRIPTION" ]; then
        echo -e "${RED}✗ Subscription name required${NC}"
        exit 1
    fi

    read -p "Key expiration (e.g. 1h, 24h) [1h]: " EXPIRES_IN
    EXPIRES_IN=${EXPIRES_IN:-1h}

    echo ""
    echo -e "${BLUE}Requesting API key for subscription '$SUBSCRIPTION'...${NC}"
    API_KEY=$(get_maas_api_key "$SUBSCRIPTION" "$EXPIRES_IN")

    if [ -z "$API_KEY" ]; then
        echo -e "${RED}✗ Failed to generate API key${NC}"
        echo "Check the subscription name and that you have access to it:"
        echo "  oc get maassubscription $SUBSCRIPTION -n models-as-a-service"
        exit 1
    fi

    echo "$API_KEY" > "$TOKEN_FILE"

    echo -e "${GREEN}✓ API key generated successfully!${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ MaaS API Key Generated!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Key saved to: $TOKEN_FILE"
    echo ""
    echo -e "${YELLOW}RHOAI Version:${NC} $RHOAI_VERSION"
    echo -e "${YELLOW}Subscription:${NC}  $SUBSCRIPTION"
    echo ""
    if is_rhoai_35_or_higher; then
        echo -e "${YELLOW}API Endpoint (body-based routing):${NC}"
        echo "  https://$MAAS_ENDPOINT/v1/chat/completions"
        echo "  (model id goes in the request body, e.g. \"publishers/<ns>/models/<name>\" --"
        echo "   look it up first with: curl -sk https://$MAAS_ENDPOINT/v1/models -H \"Authorization: Bearer \$MAAS_API_KEY\")"
    else
        echo -e "${YELLOW}API Endpoint (per-model routing):${NC}"
        echo "  https://$MAAS_ENDPOINT/<namespace>/<model>/v1/chat/completions"
    fi
    echo ""
    echo -e "${YELLOW}Key (first 20 chars):${NC}"
    echo "  ${API_KEY:0:20}..."
    echo ""
    echo -e "${YELLOW}Export for use:${NC}"
    echo "  export MAAS_API_KEY=\"$API_KEY\""
    echo "  export MAAS_ENDPOINT=\"https://$MAAS_ENDPOINT\""
    echo ""
    echo -e "${YELLOW}Test the API:${NC}"
    echo "  ./test-maas-api.sh"
    echo ""
    echo -e "${RED}⚠ Keep this key secure! It expires in ${EXPIRES_IN}.${NC}"
    echo ""
else
    ####################################################################
    # RHOAI 3.3 and earlier: OpenShift ServiceAccount token
    ####################################################################
    echo -e "${BLUE}Generating API token (OpenShift ServiceAccount)...${NC}"
    echo ""

    SA_NAME="maas-demo-user"
    SA_NAMESPACE="maas-demo"

    if ! oc get namespace "$SA_NAMESPACE" &>/dev/null; then
        echo -e "${YELLOW}Creating namespace: $SA_NAMESPACE${NC}"
        oc create namespace "$SA_NAMESPACE"
    fi

    if ! oc get sa "$SA_NAME" -n "$SA_NAMESPACE" &>/dev/null; then
        echo -e "${YELLOW}Creating service account: $SA_NAME${NC}"
        oc create sa "$SA_NAME" -n "$SA_NAMESPACE"
    fi

    if is_rhoai_33_or_higher; then
        TOKEN=$(oc create token "$SA_NAME" -n "$SA_NAMESPACE" --duration=24h --audience=https://kubernetes.default.svc 2>/dev/null)
    else
        TOKEN=$(oc create token "$SA_NAME" -n "$SA_NAMESPACE" --duration=24h 2>/dev/null || oc sa get-token "$SA_NAME" -n "$SA_NAMESPACE" 2>/dev/null)
    fi

    if [ -z "$TOKEN" ]; then
        echo -e "${RED}✗ Failed to generate token${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Token generated successfully!${NC}"
    echo ""

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
    echo "  https://$MAAS_ENDPOINT/<namespace>/<model>/v1/chat/completions"
    echo ""
    echo -e "${YELLOW}Token (first 50 chars):${NC}"
    echo "  ${TOKEN:0:50}..."
    echo ""
    echo -e "${YELLOW}Export for use:${NC}"
    echo "  export MAAS_TOKEN=\"$TOKEN\""
    echo "  export MAAS_ENDPOINT=\"https://$MAAS_ENDPOINT\""
    echo ""
    echo -e "${YELLOW}Test the API:${NC}"
    echo "  ./test-maas-api.sh"
    echo ""
    echo -e "${RED}⚠ Keep this token secure! It expires in 24 hours.${NC}"
    echo ""
    if is_rhoai_33_or_higher; then
        echo -e "${CYAN}Note: Token audience must be 'https://kubernetes.default.svc' for RHOAI 3.3+${NC}"
    fi
fi
