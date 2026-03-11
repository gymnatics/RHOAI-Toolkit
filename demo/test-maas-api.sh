#!/bin/bash
################################################################################
# Test MaaS API
################################################################################
# This script tests the MaaS API with a sample prompt
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
    if is_rhoai_33_or_higher; then
        echo "For RHOAI 3.3+: Ensure modelsAsService is enabled in DataScienceCluster"
    else
        echo "For RHOAI 3.2 and earlier: Run ../scripts/setup-maas.sh"
    fi
    exit 1
fi

MAAS_API_URL="https://$MAAS_ENDPOINT/v1/chat/completions"
echo ""
echo -e "${GREEN}✓ MaaS endpoint: $MAAS_API_URL${NC}"
echo ""

# Get model name - list differently based on version
echo -e "${BLUE}Available models:${NC}"
if is_rhoai_33_or_higher; then
    oc get llminferenceservice -A 2>/dev/null | grep -v NAME || echo "No LLMInferenceService models found"
    echo ""
    oc get inferenceservice -A 2>/dev/null | grep -v NAME || echo "No InferenceService models found"
else
    oc get inferenceservice -A 2>/dev/null | grep -v NAME || echo "No models found"
fi
echo ""

read -p "Enter model name (default: demo-model): " MODEL_NAME
MODEL_NAME=${MODEL_NAME:-demo-model}

# Get prompt
echo ""
echo -e "${BLUE}Enter your prompt (or press Enter for default):${NC}"
read -p "> " USER_PROMPT
USER_PROMPT=${USER_PROMPT:-"What is Red Hat OpenShift AI?"}

echo ""
echo -e "${BLUE}Sending request to MaaS API...${NC}"
echo -e "${CYAN}RHOAI Version: $RHOAI_VERSION${NC}"
echo -e "${CYAN}Model: $MODEL_NAME${NC}"
echo -e "${CYAN}Prompt: $USER_PROMPT${NC}"
echo ""

# Make API request
RESPONSE=$(curl -s -X POST "$MAAS_API_URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$MODEL_NAME\",
    \"messages\": [
      {\"role\": \"user\", \"content\": \"$USER_PROMPT\"}
    ],
    \"max_tokens\": 200,
    \"temperature\": 0.7
  }")

# Check if response is valid
if echo "$RESPONSE" | jq empty 2>/dev/null; then
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
    if echo "$RESPONSE" | grep -q "Unauthorized"; then
        echo -e "${YELLOW}⚠ Authentication failed - token may be invalid or expired${NC}"
        echo "Generate a new token: ./generate-maas-token.sh"
    elif echo "$RESPONSE" | grep -q "Not Found"; then
        echo -e "${YELLOW}⚠ Model not found - check model name${NC}"
        if is_rhoai_33_or_higher; then
            echo "List models: oc get llminferenceservice -A"
        else
            echo "List models: oc get inferenceservice -A"
        fi
    elif echo "$RESPONSE" | grep -q "Service Unavailable"; then
        echo -e "${YELLOW}⚠ Model may not be ready yet${NC}"
        if is_rhoai_33_or_higher; then
            echo "Check status: oc get llminferenceservice -A"
        else
            echo "Check status: oc get inferenceservice -A"
        fi
    fi
fi

echo ""
