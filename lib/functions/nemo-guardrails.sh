#!/bin/bash
################################################################################
# NeMo Guardrails Functions
################################################################################
# Reusable functions for deploying and managing NeMo Guardrails on RHOAI 3.4.
# Follows: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/
#          html-single/enabling_ai_safety_with_guardrails/index
################################################################################

_NEMO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! type print_step &>/dev/null; then
    source "$_NEMO_LIB_DIR/lib/utils/colors.sh"
fi

NEMO_MANIFESTS_DIR="${NEMO_MANIFESTS_DIR:-$_NEMO_LIB_DIR/demo/nemo-guardrails-demo/manifests}"

setup_nemo_guardrails_auth() {
    local namespace="$1"
    # 1 year; the token is re-minted on every deploy. It used to be 336h and was never refreshed once the
    # Secret existed, so clients (lemonade-stand) got 401 Unauthorized two weeks after the first deploy.
    local token_duration="${2:-8760h}"

    print_step "Setting up NeMo Guardrails authentication in $namespace..."

    export NAMESPACE="$namespace"
    envsubst < "$NEMO_MANIFESTS_DIR/nemo-guardrails-sa.yaml" | oc apply -f -
    envsubst < "$NEMO_MANIFESTS_DIR/nemo-guardrails-rbac.yaml" | oc apply -f -

    print_step "Refreshing API token secret api-token-secret (duration: $token_duration)..."
    local token
    token="$(oc create token nemo-guardrails-service-account -n "$namespace" --duration="$token_duration")" || {
        print_error "Could not mint a token for nemo-guardrails-service-account"; return 1; }
    oc create secret generic api-token-secret --from-literal=token="$token" \
        -n "$namespace" --dry-run=client -o yaml | oc apply -f - >/dev/null
    unset token

    print_success "NeMo Guardrails auth configured in $namespace"
}

deploy_nemo_guardrails() {
    local namespace="$1"
    local name="${2:-nemo-quickstart}"
    local mode="${3:-basic}"
    local model_url="${4:-}"
    local model_name="${5:-}"

    print_step "Deploying NeMo Guardrails '$name' in $namespace (mode: $mode)..."

    export NAMESPACE="$namespace"
    export GUARDRAILS_NAME="$name"

    if [ "$mode" = "selfcheck" ] && [ -n "$model_url" ]; then
        export MODEL_PREDICTOR_URL="$model_url"
        export MODEL_NAME="$model_name"
        envsubst < "$NEMO_MANIFESTS_DIR/nemo-guardrails-selfcheck-config.yaml" | oc apply -f -
    else
        envsubst < "$NEMO_MANIFESTS_DIR/nemo-guardrails-config.yaml" | oc apply -f -
    fi

    local existed=false
    oc get nemoguardrails "$name" -n "$namespace" &>/dev/null && existed=true
    envsubst < "$NEMO_MANIFESTS_DIR/nemo-guardrails-cr.yaml" | oc apply -f -
    # The server reads its ConfigMap at startup: restart an existing deployment so a mode/model change applies
    if [ "$existed" = true ]; then
        oc rollout restart deployment/"$name" -n "$namespace" >/dev/null 2>&1 || true
    fi

    print_success "NeMo Guardrails '$name' deployed"
}

wait_for_nemo_guardrails() {
    local namespace="$1"
    local name="${2:-nemo-quickstart}"
    local timeout="${3:-300}"

    print_step "Waiting for NeMo Guardrails '$name' to be ready..."

    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local phase
        phase=$(oc get nemoguardrails "$name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
        if [ "$phase" = "Ready" ]; then
            print_success "NeMo Guardrails '$name' is ready"
            return 0
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        echo "  Waiting for NeMo Guardrails... phase=$phase (${elapsed}s elapsed)"
    done

    print_warning "Timeout waiting for NeMo Guardrails '$name'"
    return 1
}

# Model id to send in NeMo requests. In selfcheck mode NeMo passes the request "model" to the LLM, so it
# must be the served id from the config; the basic (checks-only) config has no LLM and accepts any value.
_nemo_request_model() {
    local m
    m=$(oc get configmap "${2}-config" -n "$1" -o jsonpath='{.data.config\.yaml}' 2>/dev/null \
        | awk '/model_name:/ {gsub(/"/,"",$2); print $2; exit}')
    echo "${m:-test}"
}

verify_nemo_guardrails() {
    local namespace="$1"
    local name="${2:-nemo-quickstart}"

    local route
    route="https://$(oc get routes/"$name" -n "$namespace" -o jsonpath='{.status.ingress[0].host}' 2>/dev/null)"

    if [ "$route" = "https://" ]; then
        print_error "No route found for NeMo Guardrails '$name'"
        return 1
    fi

    print_info "NeMo Guardrails route: $route"
    local model
    model=$(_nemo_request_model "$namespace" "$name")
    echo ""
    echo "  Test commands:"
    echo "    # Safe content (should pass)"
    echo "    curl -k -X POST $route/v1/guardrail/checks \\"
    echo "      -H 'Content-Type: application/json' \\"
    echo "      -H 'Authorization: Bearer \$(oc whoami -t)' \\"
    echo "      -d '{\"model\": \"$model\", \"messages\": [{\"role\": \"user\", \"content\": \"How do I make fresh lemonade?\"}]}'"
    echo ""
    echo "    # PII detection (should block)"
    echo "    curl -k -X POST $route/v1/guardrail/checks \\"
    echo "      -H 'Content-Type: application/json' \\"
    echo "      -H 'Authorization: Bearer \$(oc whoami -t)' \\"
    echo "      -d '{\"model\": \"$model\", \"messages\": [{\"role\": \"user\", \"content\": \"Contact me at alice@example.com\"}]}'"
    echo ""
}

test_nemo_guardrails() {
    local namespace="$1"
    local name="${2:-nemo-quickstart}"

    local route
    route="https://$(oc get routes/"$name" -n "$namespace" -o jsonpath='{.status.ingress[0].host}' 2>/dev/null)"
    local model
    model=$(_nemo_request_model "$namespace" "$name")

    if [ "$route" = "https://" ]; then
        print_error "No route found for NeMo Guardrails '$name'"
        return 1
    fi

    local token
    token=$(oc whoami -t 2>/dev/null)

    print_step "Waiting for route to become ready..."
    local retries=0
    while [ $retries -lt 12 ]; do
        local health_code
        health_code=$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout 5 "$route/v1/guardrail/checks" \
            -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $token" \
            -d '{"model": "'"$model"'", "messages": [{"role": "user", "content": "ping"}]}' 2>/dev/null)
        if [ "$health_code" != "000" ] && [ "$health_code" != "503" ] && ! echo "$health_code" | grep -q "^5"; then
            print_success "Route is live (HTTP $health_code)"
            break
        fi
        retries=$((retries + 1))
        echo "  Waiting for endpoint... ($((retries * 10))s elapsed)"
        sleep 10
    done
    if [ $retries -ge 12 ]; then
        print_warning "Route not ready after 120s -- tests may fail"
    fi

    print_step "Testing safe content..."
    local result
    result=$(curl -sk -X POST "$route/v1/guardrail/checks" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -d '{"model": "'"$model"'", "messages": [{"role": "user", "content": "How do I make fresh lemonade?"}]}')
    local status
    status=$(echo "$result" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ "$status" = "success" ]; then
        print_success "Safe content test passed (status: success)"
    else
        print_warning "Unexpected status: $status"
        echo "$result"
    fi

    print_step "Testing PII detection (email)..."
    result=$(curl -sk -X POST "$route/v1/guardrail/checks" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -d '{"model": "'"$model"'", "messages": [{"role": "user", "content": "Please contact me at alice@example.com"}]}')
    status=$(echo "$result" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ "$status" = "blocked" ]; then
        print_success "PII detection test passed (status: blocked)"
    else
        print_warning "Unexpected status: $status"
        echo "$result"
    fi

    print_step "Testing regex detection (password keyword)..."
    result=$(curl -sk -X POST "$route/v1/guardrail/checks" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -d '{"model": "'"$model"'", "messages": [{"role": "user", "content": "Here is my password for the system"}]}')
    status=$(echo "$result" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ "$status" = "blocked" ]; then
        print_success "Regex detection test passed (status: blocked)"
    else
        print_warning "Unexpected status: $status"
        echo "$result"
    fi
}
