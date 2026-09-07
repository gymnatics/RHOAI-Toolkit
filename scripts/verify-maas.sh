#!/bin/bash
################################################################################
# End-to-End MaaS Verification (6 Phases)
################################################################################
# Modeled on the BU MaaS Guide's verify.sh:
# https://rh-aiservices-bu.github.io/rhoai-maas-guide/modules/main/06-verification.html
#
# 1. Infrastructure health   - Gateway, PostgreSQL, maas-api, maas-controller,
#                               Authorino, DSC readiness, /maas-api/health
# 2. Deploy simulator model  - temporary CPU-only simulator in a throwaway namespace
# 3. API verification        - create API key, list models, chat completion
# 4. Auth enforcement        - no token / invalid token -> 401/403
# 5. Rate limiting            - rapid requests -> 429
# 6. Cleanup                  - remove all temporary test resources
#
# Usage:
#   ./scripts/verify-maas.sh                # full run (deploy, test, cleanup)
#   ./scripts/verify-maas.sh --no-cleanup   # keep test resources after verification
#   ./scripts/verify-maas.sh --cleanup-only # remove leftover test resources
################################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
}
source "$ROOT_DIR/lib/utils/rhoai-version.sh" 2>/dev/null || true

TEST_NAMESPACE="maas-verify-test"
NO_CLEANUP=false
CLEANUP_ONLY=false
PASSED=0
FAILED=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cleanup) NO_CLEANUP=true; shift ;;
        --cleanup-only) CLEANUP_ONLY=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--no-cleanup] [--cleanup-only]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

print_phase() { echo -e "\n${BLUE}════ $1 ════${NC}"; }
check_pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; PASSED=$((PASSED + 1)); }
check_fail() { echo -e "${RED}✗ FAIL${NC}: $1"; FAILED=$((FAILED + 1)); }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

cleanup_test_resources() {
    print_phase "Phase 6: Cleanup"
    "$SCRIPT_DIR/deploy-maas-model.sh" --model simulator -n "$TEST_NAMESPACE" --delete 2>/dev/null || true
    if [ -n "${API_KEY:-}" ] && [ -n "${API_KEY_ID:-}" ]; then
        curl -sk -X DELETE "https://maas.${CLUSTER_DOMAIN}/maas-api/v1/api-keys/${API_KEY_ID}" \
            -H "Authorization: Bearer $(oc whoami -t)" >/dev/null 2>&1 || true
    fi
    # Remove the namespace only if it's now empty of user workloads
    local remaining
    remaining=$(oc get pods -n "$TEST_NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "${remaining:-0}" -eq 0 ]; then
        oc delete namespace "$TEST_NAMESPACE" --ignore-not-found 2>/dev/null || true
    fi
    check_pass "Test resources cleaned up"
}

if ! oc whoami &>/dev/null; then
    echo "Not logged in to OpenShift. Run: oc login <cluster-url>" >&2
    exit 1
fi

if [ "$CLEANUP_ONLY" = true ]; then
    cleanup_test_resources
    exit 0
fi

detect_rhoai_version 2>/dev/null || true
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
MAAS_HOST="https://maas.${CLUSTER_DOMAIN}"
INFRA_NS=$(get_maas_infra_namespace 2>/dev/null || echo "redhat-ods-applications")

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  MaaS End-to-End Verification                                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
print_info "RHOAI version: ${RHOAI_VERSION:-unknown} | MaaS URL: $MAAS_HOST | infra ns: $INFRA_NS"

################################################################################
# Phase 1: Infrastructure Health
################################################################################
print_phase "Phase 1: Infrastructure Health"

gw_programmed=$(oc get gateway maas-default-gateway -n openshift-ingress \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
[ "$gw_programmed" = "True" ] && check_pass "Gateway Programmed" || check_fail "Gateway not Programmed"

oc get deployment postgres -n "$INFRA_NS" &>/dev/null || oc get deployment postgres -n redhat-ods-applications &>/dev/null
[ $? -eq 0 ] && check_pass "PostgreSQL deployment found" || check_fail "PostgreSQL deployment not found"

oc rollout status deployment/maas-api -n "$INFRA_NS" --timeout=10s &>/dev/null
[ $? -eq 0 ] && check_pass "maas-api rolled out in $INFRA_NS" || check_fail "maas-api not available in $INFRA_NS"

oc get deployment authorino -n kuadrant-system &>/dev/null
[ $? -eq 0 ] && check_pass "Authorino deployment found" || check_fail "Authorino deployment not found"

if is_rhoai_35_or_higher 2>/dev/null; then
    dsc_cond="ModelsAsAServiceReady"
else
    dsc_cond="ModelsAsServiceReady"
fi
dsc_ready=$(oc get datasciencecluster default-dsc -o jsonpath="{.status.conditions[?(@.type==\"$dsc_cond\")].status}" 2>/dev/null)
[ "$dsc_ready" = "True" ] && check_pass "DSC condition $dsc_cond = True" || check_fail "DSC condition $dsc_cond != True (got: ${dsc_ready:-empty})"

health=$(curl -sk "${MAAS_HOST}/maas-api/health" 2>/dev/null)
echo "$health" | grep -q "healthy" && check_pass "MaaS health endpoint: $health" || check_fail "MaaS health endpoint: ${health:-no response}"

################################################################################
# Phase 2: Deploy Simulator Model
################################################################################
print_phase "Phase 2: Deploy Simulator Model (temporary, namespace=$TEST_NAMESPACE)"

"$SCRIPT_DIR/deploy-maas-model.sh" --model simulator -n "$TEST_NAMESPACE" 2>&1 | sed 's/^/  /'

ready=$(oc get llminferenceservice simulator -n "$TEST_NAMESPACE" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
[ "$ready" = "True" ] && check_pass "Simulator LLMInferenceService Ready" || check_fail "Simulator not Ready"

model_ref_phase=$(oc get maasmodelref simulator -n "$TEST_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
[ "$model_ref_phase" = "Ready" ] && check_pass "MaaSModelRef Ready" || check_fail "MaaSModelRef phase: ${model_ref_phase:-not found}"

################################################################################
# Phase 3: API Verification
################################################################################
print_phase "Phase 3: API Verification"

API_KEY_RESPONSE=$(curl -sk -X POST "${MAAS_HOST}/maas-api/v1/api-keys" \
    -H "Authorization: Bearer $(oc whoami -t)" \
    -H "Content-Type: application/json" \
    -d '{"name":"verify-test","subscription":"simulator-free","expiresIn":"1h"}' 2>/dev/null)
API_KEY=$(echo "$API_KEY_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('key',''))" 2>/dev/null)
API_KEY_ID=$(echo "$API_KEY_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

if [ -n "$API_KEY" ]; then
    check_pass "API key created"
else
    check_fail "API key creation failed: $API_KEY_RESPONSE"
fi

MODELS_RESPONSE=$(curl -sk -H "Authorization: Bearer ${API_KEY}" "${MAAS_HOST}/v1/models" 2>/dev/null)
echo "$MODELS_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('data') else 1)" 2>/dev/null
if [ $? -eq 0 ]; then
    check_pass "Model listing returned data"
else
    check_fail "Model listing failed: $MODELS_RESPONSE"
fi

# RHOAI 3.5+ uses OpenAI-compatible body-based routing: /v1/models returns the
# base gateway URL (not a per-model URL), and the model id from that listing
# is sent in the request body to a single shared /v1/chat/completions endpoint.
MODEL_ID=$(echo "$MODELS_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',[{}])[0].get('id',''))" 2>/dev/null)

if [ -n "$MODEL_ID" ]; then
    CHAT_RESPONSE=$(curl -sk -w '\n%{http_code}' "${MAAS_HOST}/v1/chat/completions" \
        -H "Authorization: Bearer ${API_KEY}" -H "Content-Type: application/json" \
        -d "{\"model\":\"${MODEL_ID}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}" 2>/dev/null)
    CHAT_CODE=$(echo "$CHAT_RESPONSE" | tail -1)
    [ "$CHAT_CODE" = "200" ] && check_pass "Chat completion HTTP 200" || check_fail "Chat completion HTTP $CHAT_CODE: $(echo "$CHAT_RESPONSE" | head -1)"
else
    check_fail "Could not determine model id for inference test"
fi

################################################################################
# Phase 4: Auth Enforcement
################################################################################
print_phase "Phase 4: Auth Enforcement"

if [ -n "$MODEL_ID" ]; then
    NO_TOKEN_CODE=$(curl -sk -o /dev/null -w '%{http_code}' \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${MODEL_ID}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}" \
        "${MAAS_HOST}/v1/chat/completions" 2>/dev/null)
    if [ "$NO_TOKEN_CODE" = "401" ] || [ "$NO_TOKEN_CODE" = "403" ]; then
        check_pass "No-token request rejected (HTTP $NO_TOKEN_CODE)"
    else
        check_fail "No-token request NOT rejected (HTTP $NO_TOKEN_CODE)"
    fi

    INVALID_TOKEN_CODE=$(curl -sk -o /dev/null -w '%{http_code}' \
        -H "Authorization: Bearer sk-oai-invalid-token-000000" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${MODEL_ID}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}" \
        "${MAAS_HOST}/v1/chat/completions" 2>/dev/null)
    if [ "$INVALID_TOKEN_CODE" = "401" ] || [ "$INVALID_TOKEN_CODE" = "403" ]; then
        check_pass "Invalid-token request rejected (HTTP $INVALID_TOKEN_CODE)"
    else
        check_fail "Invalid-token request NOT rejected (HTTP $INVALID_TOKEN_CODE)"
    fi
else
    check_fail "Skipped auth enforcement checks (no MODEL_ID)"
fi

################################################################################
# Phase 5: Rate Limiting
################################################################################
print_phase "Phase 5: Rate Limiting"

if [ -n "$MODEL_ID" ] && [ -n "$API_KEY" ]; then
    got_429=false
    for i in $(seq 1 16); do
        code=$(curl -sk -o /dev/null -w '%{http_code}' \
            -H "Authorization: Bearer ${API_KEY}" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"${MODEL_ID}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello, write a long essay\"}],\"max_tokens\":50}" \
            "${MAAS_HOST}/v1/chat/completions" 2>/dev/null)
        if [ "$code" = "429" ]; then
            got_429=true
            break
        fi
    done
    if [ "$got_429" = true ]; then
        check_pass "Rate limit triggered (HTTP 429) within 16 requests"
    else
        check_fail "Rate limit NOT triggered after 16 requests (simulator-free = 100 tokens/min)"
    fi
else
    check_fail "Skipped rate limiting check (no MODEL_ID/API_KEY)"
fi

################################################################################
# Phase 6: Cleanup
################################################################################
if [ "$NO_CLEANUP" = true ]; then
    print_info "Skipping cleanup (--no-cleanup). Remove manually with: $0 --cleanup-only"
else
    cleanup_test_resources
fi

################################################################################
# Summary
################################################################################
echo ""
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "${BLUE}MaaS Verification Summary${NC}"
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo "MaaS API URL:  $MAAS_HOST"
echo -e "Passed:        ${GREEN}${PASSED}${NC}"
echo -e "Failed:        ${RED}${FAILED}${NC}"
if [ "$FAILED" -eq 0 ]; then
    echo -e "Status:        ${GREEN}ALL CHECKS PASSED${NC}"
else
    echo -e "Status:        ${RED}SOME CHECKS FAILED${NC}"
fi
echo -e "${BLUE}═════════════════════════════════════════${NC}"

[ "$FAILED" -gt 0 ] && exit 1
exit 0
