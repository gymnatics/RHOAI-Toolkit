#!/bin/bash
################################################################################
# Test MaaS API
################################################################################
# This script tests the MaaS API with a sample prompt. Routing and auth are
# version-aware:
#   RHOAI 3.5+: body-based routing -- model id (publishers/<ns>/models/<name>)
#               looked up from GET /v1/models and sent in the body to a single
#               shared /v1/chat/completions endpoint.
#   RHOAI 3.4:  per-model URL (/<ns>/<model>/v1/chat/completions), sk-oai-* key.
#   RHOAI 3.3-: per-model URL, OpenShift SA token.
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
echo -e "${BLUE}║          MaaS API Test                                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for token file
if [ ! -f "maas-token.txt" ]; then
    echo -e "${RED}✗ Token file not found${NC}"
    echo "Run: ./generate-maas-token.sh"
    exit 1
fi

TOKEN=$(cat maas-token.txt)
echo -e "${GREEN}✓ Token loaded from maas-token.txt${NC}"
echo ""

# Check if logged in
if ! oc whoami &>/dev/null; then
    echo -e "${RED}✗ Not logged in to OpenShift${NC}"
    echo "Please login first: oc login <cluster-url>"
    exit 1
fi

# Detect RHOAI version and get MaaS endpoint
detect_rhoai_version

if ! get_maas_endpoint; then
    echo ""
    if is_rhoai_34_or_higher; then
        echo "For RHOAI 3.4+: Ensure MaaS is enabled in DataScienceCluster"
    elif is_rhoai_33_or_higher; then
        echo "For RHOAI 3.3: Ensure modelsAsService is enabled in DataScienceCluster"
    else
        echo "For RHOAI 3.2 and earlier: Run ../scripts/setup-maas.sh"
    fi
    exit 1
fi

echo ""

if is_rhoai_35_or_higher; then
    ############################################################################
    # RHOAI 3.5+: body-based routing -- fetch /v1/models to get the exact id
    ############################################################################
    echo -e "${BLUE}Fetching available models (GET /v1/models)...${NC}"
    MODELS_JSON=$(curl -sk "https://${MAAS_ENDPOINT}/v1/models" -H "Authorization: Bearer ${TOKEN}" 2>/dev/null)

    if ! echo "$MODELS_JSON" | jq -e '.data[0]' >/dev/null 2>&1; then
        echo -e "${RED}✗ No models returned from /v1/models${NC}"
        echo "Response: $MODELS_JSON"
        echo ""
        echo "Deploy a model first: ../scripts/deploy-maas-model.sh --model simulator"
        exit 1
    fi

    echo -e "${GREEN}✓ Models available:${NC}"
    echo "$MODELS_JSON" | jq -r '.data[] | "  - \(.id)  (ready: \(.ready))"'
    echo ""

    read -p "Enter model id (default: first listed): " MODEL_ID
    if [ -z "$MODEL_ID" ]; then
        MODEL_ID=$(echo "$MODELS_JSON" | jq -r '.data[0].id')
    fi

    CHAT_URL="https://${MAAS_ENDPOINT}/v1/chat/completions"
    echo ""
    echo -e "${GREEN}✓ Chat endpoint (body-based routing): $CHAT_URL${NC}"
    echo -e "${GREEN}✓ Model id: $MODEL_ID${NC}"
else
    ############################################################################
    # RHOAI 3.4 and earlier: per-model URL routing
    ############################################################################
    echo -e "${BLUE}Available models:${NC}"
    if is_rhoai_33_or_higher; then
        oc get llminferenceservice -A 2>/dev/null | grep -v NAME || echo "No LLMInferenceService models found"
        echo ""
        oc get inferenceservice -A 2>/dev/null | grep -v NAME || echo "No InferenceService models found"
    else
        oc get inferenceservice -A 2>/dev/null | grep -v NAME || echo "No models found"
    fi
    echo ""

    read -p "Enter model namespace (default: current project): " MODEL_NAMESPACE
    MODEL_NAMESPACE=${MODEL_NAMESPACE:-$(oc project -q 2>/dev/null)}
    read -p "Enter model name (default: demo-model): " MODEL_ID
    MODEL_ID=${MODEL_ID:-demo-model}

    CHAT_URL=$(get_maas_chat_url "$MODEL_NAMESPACE" "$MODEL_ID")
    echo ""
    echo -e "${GREEN}✓ Chat endpoint (per-model routing): $CHAT_URL${NC}"
fi

# Get prompt
echo ""
echo -e "${BLUE}Enter your prompt (or press Enter for default):${NC}"
read -p "> " USER_PROMPT
USER_PROMPT=${USER_PROMPT:-"What is Red Hat OpenShift AI?"}

echo ""
echo -e "${BLUE}Sending request to MaaS API...${NC}"
echo -e "${CYAN}RHOAI Version: $RHOAI_VERSION${NC}"
echo -e "${CYAN}Model: $MODEL_ID${NC}"
echo -e "${CYAN}Prompt: $USER_PROMPT${NC}"
echo ""

# Make API request
RESPONSE=$(curl -sk -X POST "$CHAT_URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$MODEL_ID\",
    \"messages\": [
      {\"role\": \"user\", \"content\": \"$USER_PROMPT\"}
    ],
    \"max_tokens\": 200,
    \"temperature\": 0.7
  }")

# Check if response is valid
if echo "$RESPONSE" | jq empty 2>/dev/null && echo "$RESPONSE" | jq -e '.choices' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Response received!${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Response:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Extract and display the response
    CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null || echo "")

    if [ -n "$CONTENT" ] && [ "$CONTENT" != "null" ]; then
        echo "$CONTENT"
    else
        echo "Full response:"
        echo "$RESPONSE" | jq '.'
    fi

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Show usage stats
    USAGE=$(echo "$RESPONSE" | jq -r '.usage' 2>/dev/null || echo "")
    if [ -n "$USAGE" ] && [ "$USAGE" != "null" ]; then
        echo -e "${CYAN}Usage:${NC}"
        echo "$USAGE" | jq '.'
        echo ""
    fi

    echo -e "${GREEN}✓ MaaS API test successful!${NC}"
else
    echo -e "${RED}✗ Error in API response${NC}"
    echo ""
    echo "Response:"
    echo "$RESPONSE"
    echo ""

    # Common error checks
    if echo "$RESPONSE" | grep -qi "unauthorized"; then
        echo -e "${YELLOW}⚠ Authentication failed - key/token may be invalid or expired${NC}"
        echo "Generate a new credential: ./generate-maas-token.sh"
    elif echo "$RESPONSE" | grep -qi "not found"; then
        echo -e "${YELLOW}⚠ Model not found - check model id${NC}"
        if is_rhoai_35_or_higher; then
            echo "List models: curl -sk https://${MAAS_ENDPOINT}/v1/models -H \"Authorization: Bearer \$TOKEN\""
        elif is_rhoai_33_or_higher; then
            echo "List models: oc get llminferenceservice -A"
        else
            echo "List models: oc get inferenceservice -A"
        fi
    elif echo "$RESPONSE" | grep -qi "service unavailable"; then
        echo -e "${YELLOW}⚠ Model may not be ready yet${NC}"
        if is_rhoai_33_or_higher; then
            echo "Check status: oc get llminferenceservice -A"
        else
            echo "Check status: oc get inferenceservice -A"
        fi
    fi
fi

echo ""
