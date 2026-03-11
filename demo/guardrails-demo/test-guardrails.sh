#!/bin/bash
################################################################################
# Test Guardrails Detection API
################################################################################
# Tests the built-in detectors for PII detection (standalone, no LLM needed)
#
# Usage:
#   ./test-guardrails.sh [namespace]
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

NAMESPACE="${1:-$(oc project -q 2>/dev/null || echo 'default')}"

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              Test Guardrails Detection API                      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Namespace: $NAMESPACE${NC}"
echo ""

# Get orchestrator route
ORCHESTRATOR_ROUTE=$(oc get route -n "$NAMESPACE" -l app.kubernetes.io/name=guardrails-orchestrator -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")

if [ -z "$ORCHESTRATOR_ROUTE" ]; then
    # Try specific route name
    ORCHESTRATOR_ROUTE=$(oc get route guardrails-orchestrator-health -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
fi

if [ -z "$ORCHESTRATOR_ROUTE" ]; then
    echo -e "${RED}✗ Could not find Guardrails Orchestrator route${NC}"
    echo "Make sure Guardrails is deployed in namespace '$NAMESPACE'"
    echo ""
    echo "Deploy with: ./scripts/deploy-guardrails.sh $NAMESPACE"
    exit 1
fi

ORCHESTRATOR_URL="https://$ORCHESTRATOR_ROUTE"
echo -e "${GREEN}✓ Found Orchestrator: $ORCHESTRATOR_URL${NC}"
echo ""

# Test health endpoint
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 1: Health Check${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

HEALTH_RESPONSE=$(curl -sk "$ORCHESTRATOR_URL/health" 2>/dev/null)
if echo "$HEALTH_RESPONSE" | grep -q "fms-guardrails"; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    echo "$HEALTH_RESPONSE" | jq . 2>/dev/null || echo "$HEALTH_RESPONSE"
else
    echo -e "${RED}✗ Health check failed${NC}"
    echo "$HEALTH_RESPONSE"
fi
echo ""

# Test email detection
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 2: Email Detection${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Input: \"Contact me at john.doe@example.com for more info\"${NC}"
echo ""

curl -sk -X POST "$ORCHESTRATOR_URL/api/v2/text/detection/content" \
    -H "Content-Type: application/json" \
    -d '{
        "detectors": {
            "built-in-detector": {
                "regex": ["email"]
            }
        },
        "content": "Contact me at john.doe@example.com for more info"
    }' | jq . 2>/dev/null || echo "Request failed"
echo ""

# Test SSN detection
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 3: Social Security Number Detection${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Input: \"My SSN is 123-45-6789\"${NC}"
echo ""

curl -sk -X POST "$ORCHESTRATOR_URL/api/v2/text/detection/content" \
    -H "Content-Type: application/json" \
    -d '{
        "detectors": {
            "built-in-detector": {
                "regex": ["us-social-security-number"]
            }
        },
        "content": "My SSN is 123-45-6789"
    }' | jq . 2>/dev/null || echo "Request failed"
echo ""

# Test credit card detection
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 4: Credit Card Detection${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Input: \"Card number: 4532015112830366\"${NC}"
echo ""

curl -sk -X POST "$ORCHESTRATOR_URL/api/v2/text/detection/content" \
    -H "Content-Type: application/json" \
    -d '{
        "detectors": {
            "built-in-detector": {
                "regex": ["credit-card"]
            }
        },
        "content": "Card number: 4532015112830366"
    }' | jq . 2>/dev/null || echo "Request failed"
echo ""

# Test phone number detection
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 5: Phone Number Detection${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Input: \"Call me at 555-123-4567\"${NC}"
echo ""

curl -sk -X POST "$ORCHESTRATOR_URL/api/v2/text/detection/content" \
    -H "Content-Type: application/json" \
    -d '{
        "detectors": {
            "built-in-detector": {
                "regex": ["us-phone-number"]
            }
        },
        "content": "Call me at 555-123-4567"
    }' | jq . 2>/dev/null || echo "Request failed"
echo ""

# Test safe content (no PII)
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 6: Safe Content (No PII)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Input: \"What is the weather like today?\"${NC}"
echo ""

curl -sk -X POST "$ORCHESTRATOR_URL/api/v2/text/detection/content" \
    -H "Content-Type: application/json" \
    -d '{
        "detectors": {
            "built-in-detector": {
                "regex": ["email", "us-social-security-number", "credit-card", "us-phone-number"]
            }
        },
        "content": "What is the weather like today?"
    }' | jq . 2>/dev/null || echo "Request failed"
echo ""

# Test multiple PII in one message
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 7: Multiple PII Detection${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Input: \"Contact john@example.com, SSN 123-45-6789, card 4532015112830366\"${NC}"
echo ""

curl -sk -X POST "$ORCHESTRATOR_URL/api/v2/text/detection/content" \
    -H "Content-Type: application/json" \
    -d '{
        "detectors": {
            "built-in-detector": {
                "regex": ["email", "us-social-security-number", "credit-card"]
            }
        },
        "content": "Contact john@example.com, SSN 123-45-6789, card 4532015112830366"
    }' | jq . 2>/dev/null || echo "Request failed"
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Detection API tests complete${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Next: Test Gateway pipelines with:"
echo -e "  ${YELLOW}./test-gateway.sh $NAMESPACE${NC}"
echo ""
