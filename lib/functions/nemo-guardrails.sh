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
    local token_duration="${2:-336h}"

    print_step "Setting up NeMo Guardrails authentication in $namespace..."

    export NAMESPACE="$namespace"
    envsubst < "$NEMO_MANIFESTS_DIR/nemo-guardrails-sa.yaml" | oc apply -f -
    envsubst < "$NEMO_MANIFESTS_DIR/nemo-guardrails-rbac.yaml" | oc apply -f -

    if oc get secret api-token-secret -n "$namespace" &>/dev/null; then
        print_info "API token secret already exists, skipping"
    else
        print_step "Creating API token secret (duration: $token_duration)..."
        oc create secret generic api-token-secret \
            --from-literal=token="$(oc create token nemo-guardrails-service-account -n "$namespace" --duration="$token_duration")" \
            -n "$namespace"
    fi

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

    envsubst < "$NEMO_MANIFESTS_DIR/nemo-guardrails-cr.yaml" | oc apply -f -

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
    echo ""
    echo "  Test commands:"
    echo "    # Safe content (should pass)"
    echo "    curl -k -X POST $route/v1/guardrail/checks \\"
    echo "      -H 'Content-Type: application/json' \\"
    echo "      -H 'Authorization: Bearer \$(oc whoami -t)' \\"
    echo "      -d '{\"model\": \"test\", \"messages\": [{\"role\": \"user\", \"content\": \"What is the capital of France?\"}]}'"
    echo ""
    echo "    # PII detection (should block)"
    echo "    curl -k -X POST $route/v1/guardrail/checks \\"
    echo "      -H 'Content-Type: application/json' \\"
    echo "      -H 'Authorization: Bearer \$(oc whoami -t)' \\"
    echo "      -d '{\"model\": \"test\", \"messages\": [{\"role\": \"user\", \"content\": \"Contact me at alice@example.com\"}]}'"
    echo ""
}

test_nemo_guardrails() {
    local namespace="$1"
    local name="${2:-nemo-quickstart}"

    local route
    route="https://$(oc get routes/"$name" -n "$namespace" -o jsonpath='{.status.ingress[0].host}' 2>/dev/null)"

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
            -d '{"model": "test", "messages": [{"role": "user", "content": "ping"}]}' 2>/dev/null)
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
        -d '{"model": "test", "messages": [{"role": "user", "content": "What is the capital of France?"}]}')
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
        -d '{"model": "test", "messages": [{"role": "user", "content": "Please contact me at alice@example.com"}]}')
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
        -d '{"model": "test", "messages": [{"role": "user", "content": "Here is my password for the system"}]}')
    status=$(echo "$result" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ "$status" = "blocked" ]; then
        print_success "Regex detection test passed (status: blocked)"
    else
        print_warning "Unexpected status: $status"
        echo "$result"
    fi
}
