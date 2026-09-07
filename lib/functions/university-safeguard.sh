#!/bin/bash
################################################################################
# University Safeguard Demo Functions
################################################################################
# Deploys the granite-guardian-hap-38m HAP detector InferenceService and wires
# it into a NeMo Guardrails deployment via a custom Colang flow + Python
# action (not the built-in hf_classifier rail) that calls the detector
# directly and generates a structured "hap_alert" log entry on every
# detection, on both input and output.
#
# Reuses setup_nemo_guardrails_auth / wait_for_nemo_guardrails / verify_nemo_guardrails
# from lib/functions/nemo-guardrails.sh (NEMO_MANIFESTS_DIR is overridden by the
# caller to point at demo/university-safeguard-demo/manifests).
################################################################################

_UNI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! type print_step &>/dev/null; then
    source "$_UNI_LIB_DIR/lib/utils/colors.sh"
fi

UNI_MANIFESTS_DIR="${UNI_MANIFESTS_DIR:-$_UNI_LIB_DIR/demo/university-safeguard-demo/manifests}"

deploy_hap_detector() {
    local namespace="$1"

    print_step "Deploying HAP detector (granite-guardian-hap-38m) in $namespace..."

    export NAMESPACE="$namespace"
    envsubst < "$UNI_MANIFESTS_DIR/hap-detector-servingruntime.yaml" | oc apply -f -
    envsubst < "$UNI_MANIFESTS_DIR/hap-detector-inferenceservice.yaml" | oc apply -f -

    print_success "HAP detector ServingRuntime + InferenceService applied"
}

wait_for_hap_detector() {
    local namespace="$1"
    local timeout="${2:-600}"

    print_step "Waiting for HAP detector InferenceService to be ready (this pulls the model on first deploy, can take a few minutes)..."

    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local ready
        ready=$(oc get inferenceservice hap-detector -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$ready" = "True" ]; then
            print_success "HAP detector is ready"
            return 0
        fi
        sleep 15
        elapsed=$((elapsed + 15))
        echo "  Waiting for HAP detector... ready=$ready (${elapsed}s elapsed)"
    done

    print_warning "Timeout waiting for HAP detector to become ready"
    return 1
}

ensure_main_model_api_key_secret() {
    local namespace="$1"
    local name="${2:-university-safeguard}"
    local api_key="$3"

    local secret_name="${name}-model-key"

    if oc get secret "$secret_name" -n "$namespace" &>/dev/null; then
        print_info "Main model API key secret '$secret_name' already exists, skipping"
        return 0
    fi

    if [ -z "$api_key" ]; then
        print_error "No API key provided for the main model (pass --model-api-key or set MAIN_MODEL_API_KEY)"
        return 1
    fi

    print_step "Creating main model API key secret '$secret_name'..."
    oc create secret generic "$secret_name" \
        --from-literal=api-key="$api_key" \
        -n "$namespace"
    print_success "Main model API key secret created"
}

deploy_university_guardrails_config() {
    local namespace="$1"
    local name="${2:-university-safeguard}"
    local main_model_url="$3"
    local main_model_name="$4"
    local hap_detector_url="$5"
    local main_model_api_key="$6"

    print_step "Deploying university safeguard NeMo Guardrails config '$name' in $namespace..."

    export NAMESPACE="$namespace"
    export GUARDRAILS_NAME="$name"
    export MAIN_MODEL_URL="$main_model_url"
    export MAIN_MODEL_NAME="$main_model_name"
    export HAP_DETECTOR_URL="$hap_detector_url"
    export MAIN_MODEL_API_KEY="$main_model_api_key"

    # IMPORTANT: nemo-guardrails-config.yaml embeds Colang (rails.co) which uses
    # its own $variable syntax (e.g. $user_message, $hap_flagged). A bare
    # `envsubst` with no variable list would substitute those too (as empty
    # strings, since they're not shell env vars), corrupting the Colang file.
    # Restrict envsubst to only the placeholders we actually want replaced.
    local uni_envsubst_vars='${NAMESPACE} ${GUARDRAILS_NAME} ${MAIN_MODEL_URL} ${MAIN_MODEL_NAME} ${HAP_DETECTOR_URL} ${MAIN_MODEL_API_KEY}'
    envsubst "$uni_envsubst_vars" < "$UNI_MANIFESTS_DIR/nemo-guardrails-config.yaml" | oc apply -f -
    envsubst "$uni_envsubst_vars" < "$UNI_MANIFESTS_DIR/nemo-guardrails-cr.yaml" | oc apply -f -
    unset MAIN_MODEL_API_KEY

    print_success "University safeguard guardrails config '$name' deployed"
}

test_university_safeguard() {
    local namespace="$1"
    local name="${2:-university-safeguard}"

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

    _uni_check() {
        local label="$1" content="$2" expected="$3"
        local result status
        result=$(curl -sk -X POST "$route/v1/guardrail/checks" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            -d "{\"model\": \"test\", \"messages\": [{\"role\": \"user\", \"content\": \"$content\"}]}")
        status=$(echo "$result" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ "$status" = "$expected" ]; then
            print_success "$label test passed (status: $status)"
        else
            print_warning "$label test: expected $expected, got $status"
            echo "$result"
        fi
    }

    print_step "Testing safe content..."
    _uni_check "Safe content" "What is the capital of France?" "success"

    print_step "Testing PII redaction (email)..."
    # NOTE: input PII uses "mask sensitive data on input" (redaction), not a
    # block -- the request is expected to succeed with the PII masked before
    # it reaches the main model. Check "rails_status" in the raw output above
    # if you want to confirm the mask actually fired.
    _uni_check "PII redaction" "Please contact me at alice@example.com" "success"

    print_step "Testing HAP (toxicity) classifier on input..."
    _uni_check "HAP input" "You are a worthless piece of garbage and everyone hates you" "blocked"
    print_info "Verify the alert was logged: oc logs -n $namespace deploy/$name -c nemo-guardrails | grep hap_alert"

    unset -f _uni_check
}
