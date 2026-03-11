#!/bin/bash
################################################################################
# Test Guardrails Gateway Pipelines
################################################################################
# Tests the Gateway preset pipelines with actual chat completions
#
# Pipelines:
#   /pii/v1/chat/completions         - Filters PII
#   /safe/v1/chat/completions        - All safety checks
#   /passthrough/v1/chat/completions - No filtering
#
# Usage:
#   ./test-gateway.sh [namespace]
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

NAMESPACE="${1:-$(oc project -q 2>/dev/null || echo 'default')}"

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              Test Guardrails Gateway Pipelines                  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Namespace: $NAMESPACE${NC}"
echo ""

# Get gateway route
GATEWAY_ROUTE=$(oc get route -n "$NAMESPACE" -o jsonpath='{.items[?(@.metadata.name contains "gateway")].spec.host}' 2>/dev/null | awk '{print $1}' || echo "")

if [ -z "$GATEWAY_ROUTE" ]; then
    # Try to find any guardrails route
    GATEWAY_ROUTE=$(oc get route -n "$NAMESPACE" -l app.kubernetes.io/name=guardrails-orchestrator -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")
fi

if [ -z "$GATEWAY_ROUTE" ]; then
    echo -e "${RED}✗ Could not find Guardrails Gateway route${NC}"
    echo "Make sure Guardrails is deployed in namespace '$NAMESPACE'"
    echo ""
    echo "Deploy with: ./scripts/deploy-guardrails.sh $NAMESPACE"
    exit 1
fi

GATEWAY_URL="https://$GATEWAY_ROUTE"
echo -e "${GREEN}✓ Found Gateway: $GATEWAY_URL${NC}"
echo ""

# Get model name
MODEL_NAME=$(oc get isvc -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "model")
echo -e "${BLUE}Using model: $MODEL_NAME${NC}"
echo ""

# Test passthrough pipeline (no filtering)
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 1: Passthrough Pipeline (No Filtering)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Endpoint: /passthrough/v1/chat/completions${NC}"
echo -e "${BLUE}Input: \"Hello, how are you?\"${NC}"
echo ""

RESPONSE=$(curl -sk -X POST "$GATEWAY_URL/passthrough/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"$MODEL_NAME\",
        \"messages\": [{\"role\": \"user\", \"content\": \"Hello, how are you?\"}],
        \"max_tokens\": 50
    }" 2>/dev/null)

if echo "$RESPONSE" | jq -e '.choices[0].message.content' &>/dev/null; then
    echo -e "${GREEN}✓ Response received${NC}"
    echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null | head -5
else
    echo -e "${YELLOW}Response:${NC}"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
fi
echo ""

# Test PII pipeline with safe content
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 2: PII Pipeline - Safe Content${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Endpoint: /pii/v1/chat/completions${NC}"
echo -e "${BLUE}Input: \"What is the capital of France?\"${NC}"
echo ""

RESPONSE=$(curl -sk -X POST "$GATEWAY_URL/pii/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"$MODEL_NAME\",
        \"messages\": [{\"role\": \"user\", \"content\": \"What is the capital of France?\"}],
        \"max_tokens\": 50
    }" 2>/dev/null)

if echo "$RESPONSE" | jq -e '.choices[0].message.content' &>/dev/null; then
    echo -e "${GREEN}✓ Response received (no PII detected)${NC}"
    echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null | head -5
else
    echo -e "${YELLOW}Response:${NC}"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
fi
echo ""

# Test PII pipeline with email
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 3: PII Pipeline - Email Detection${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Endpoint: /pii/v1/chat/completions${NC}"
echo -e "${BLUE}Input: \"Send the report to john.doe@company.com\"${NC}"
echo -e "${MAGENTA}Expected: PII detected, request may be blocked or flagged${NC}"
echo ""

RESPONSE=$(curl -sk -X POST "$GATEWAY_URL/pii/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"$MODEL_NAME\",
        \"messages\": [{\"role\": \"user\", \"content\": \"Send the report to john.doe@company.com\"}],
        \"max_tokens\": 50
    }" 2>/dev/null)

echo -e "${YELLOW}Response:${NC}"
echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
echo ""

# Test PII pipeline with SSN
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 4: PII Pipeline - SSN Detection${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Endpoint: /pii/v1/chat/completions${NC}"
echo -e "${BLUE}Input: \"My social security number is 123-45-6789\"${NC}"
echo -e "${MAGENTA}Expected: PII detected, request may be blocked or flagged${NC}"
echo ""

RESPONSE=$(curl -sk -X POST "$GATEWAY_URL/pii/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"$MODEL_NAME\",
        \"messages\": [{\"role\": \"user\", \"content\": \"My social security number is 123-45-6789\"}],
        \"max_tokens\": 50
    }" 2>/dev/null)

echo -e "${YELLOW}Response:${NC}"
echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
echo ""

# Test safe pipeline
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 5: Safe Pipeline - Credit Card Detection${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Endpoint: /safe/v1/chat/completions${NC}"
echo -e "${BLUE}Input: \"Process payment for card 4532015112830366\"${NC}"
echo -e "${MAGENTA}Expected: PII detected, request may be blocked or flagged${NC}"
echo ""

RESPONSE=$(curl -sk -X POST "$GATEWAY_URL/safe/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"$MODEL_NAME\",
        \"messages\": [{\"role\": \"user\", \"content\": \"Process payment for card 4532015112830366\"}],
        \"max_tokens\": 50
    }" 2>/dev/null)

echo -e "${YELLOW}Response:${NC}"
echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Gateway pipeline tests complete${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${MAGENTA}Summary of Pipelines:${NC}"
echo ""
echo "  /passthrough/v1/chat/completions"
echo "    → No filtering, direct to model"
echo ""
echo "  /pii/v1/chat/completions"
echo "    → Filters: email, SSN, credit card, phone, IP"
echo "    → Checks both input and output"
echo ""
echo "  /safe/v1/chat/completions"
echo "    → All safety checks (currently PII on input)"
echo "    → Extensible for future detectors"
echo ""
echo -e "${MAGENTA}Manual Testing:${NC}"
echo ""
echo "  curl -X POST \"$GATEWAY_URL/pii/v1/chat/completions\" \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{\"model\": \"$MODEL_NAME\", \"messages\": [{\"role\": \"user\", \"content\": \"Your message\"}]}'"
echo ""
