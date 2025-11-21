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

# Get MaaS API endpoint
if ! oc whoami &>/dev/null; then
    echo -e "${RED}✗ Not logged in to OpenShift${NC}"
    echo "Please login first: oc login <cluster-url>"
    exit 1
fi

MAAS_HOST=$(oc get route maas-api -n maas-api -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

if [ -z "$MAAS_HOST" ]; then
    echo -e "${RED}✗ MaaS API route not found${NC}"
    exit 1
fi

MAAS_ENDPOINT="https://$MAAS_HOST/v1/chat/completions"
echo -e "${GREEN}✓ MaaS endpoint: $MAAS_ENDPOINT${NC}"
echo ""

# Get model name
echo -e "${BLUE}Available models:${NC}"
oc get inferenceservice -A 2>/dev/null | grep -v NAME || echo "No models found"
echo ""

read -p "Enter model name (default: llama-3-2-3b-demo): " MODEL_NAME
MODEL_NAME=${MODEL_NAME:-llama-3-2-3b-demo}

# Get prompt
echo ""
echo -e "${BLUE}Enter your prompt (or press Enter for default):${NC}"
read -p "> " USER_PROMPT
USER_PROMPT=${USER_PROMPT:-"What is Red Hat OpenShift AI?"}

echo ""
echo -e "${BLUE}Sending request to MaaS API...${NC}"
echo -e "${CYAN}Model: $MODEL_NAME${NC}"
echo -e "${CYAN}Prompt: $USER_PROMPT${NC}"
echo ""

# Make API request
RESPONSE=$(curl -s -X POST "$MAAS_ENDPOINT" \
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
        echo "List models: oc get inferenceservice -A"
    elif echo "$RESPONSE" | grep -q "Service Unavailable"; then
        echo -e "${YELLOW}⚠ Model may not be ready yet${NC}"
        echo "Check status: oc get inferenceservice -A"
    fi
fi

echo ""


