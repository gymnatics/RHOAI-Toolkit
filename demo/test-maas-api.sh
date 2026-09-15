#!/bin/bash
################################################################################
# Test MaaS API
################################################################################
# This script tests the MaaS API with a sample prompt. Works across RHOAI
# 3.3/3.4/3.5 using per-model URL routing by default (confirmed HTTP 200 on
# a live RHOAI 3.5.0 GA cluster -- contrary to earlier assumptions, this does
# NOT 404 on 3.5+). Set MAAS_ROUTING=body before running to opt into RHOAI
# 3.5+'s single shared /v1/chat/completions endpoint instead.
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

# Detect RHOAI version and get MaaS endpoint (routing defaults to per-model
# URL; export MAAS_ROUTING=body before running this script to opt into
# body-based routing on RHOAI 3.5+ instead)
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

echo -e "${CYAN}Routing: $([ "$MAAS_ROUTING" = "body" ] && echo "body-based (opt-in)" || echo "per-model URL (default)")${NC}"
echo ""

# List available models (k8s resources -- works on all versions)
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
read -p "Enter model name (k8s resource name, default: demo-model): " MODEL_NAME
MODEL_NAME=${MODEL_NAME:-demo-model}

# Resolve the exact model id to send in the request body. This is the
# LLMInferenceService's spec.model.name (e.g. "facebook/opt-125m"), which is
# often DIFFERENT from the k8s resource name (e.g. "simulator") -- sending the
# bare resource name returns a 404 "model does not exist" regardless of
# routing mode. get_maas_model_id resolves this via `oc` (preferred) or the
# API (fallback), and formats it correctly for the active MAAS_ROUTING mode.
MODEL_ID=$(get_maas_model_id "$MODEL_NAMESPACE" "$MODEL_NAME" "$TOKEN")
CHAT_URL=$(get_maas_chat_url "$MODEL_NAMESPACE" "$MODEL_NAME")

echo ""
echo -e "${GREEN}✓ Chat endpoint: $CHAT_URL${NC}"
echo -e "${GREEN}✓ Model id: $MODEL_ID${NC}"

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
        echo -e "${YELLOW}⚠ Model not found - check model id/name${NC}"
        echo "  Verify the k8s resource name matches: oc get llminferenceservice -n $MODEL_NAMESPACE"
        echo "  And that spec.model.name resolved correctly: oc get llminferenceservice $MODEL_NAME -n $MODEL_NAMESPACE -o jsonpath='{.spec.model.name}'"
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
