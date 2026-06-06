#!/bin/bash
################################################################################
# notebook-env.sh — Auto-detect model endpoints and inject into workbenches
################################################################################
# Provides:
#   detect_llm_endpoint          — sets LLM_MODEL_NAME, LLM_MODEL_NS, LLM_BASE_URL
#   detect_predictive_endpoint   — sets SKLEARN_MODEL_NAME, SKLEARN_API_URL
#   inject_notebook_env          — creates notebook-env ConfigMap + patches Notebook CRs
#
# Usage in deploy.sh:
#   source "$ROOT_DIR/lib/functions/notebook-env.sh"
#   inject_notebook_env "$NAMESPACE" "S3_ENDPOINT=$S3_ENDPOINT" "CUSTOM_VAR=value"
################################################################################

# Detect the first available LLM (LLMInferenceService > vLLM InferenceService)
# Sets: LLM_MODEL_NAME, LLM_MODEL_NS, LLM_BASE_URL
detect_llm_endpoint() {
    LLM_MODEL_NAME=""
    LLM_MODEL_NS=""
    LLM_BASE_URL=""

    local detected="" detected_ns=""

    # Try LLMInferenceService first (llm-d / GenAI models)
    local llmisvc_output
    llmisvc_output=$(oc get llminferenceservice -A --no-headers \
        -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name' 2>/dev/null | head -1)
    if [ -n "$llmisvc_output" ]; then
        detected_ns=$(echo "$llmisvc_output" | awk '{print $1}')
        detected=$(echo "$llmisvc_output" | awk '{print $2}')
    fi

    # Fallback: vLLM-based InferenceService (skip sklearn/xgboost/lightgbm/onnx)
    if [ -z "$detected" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            [ -z "$line" ] && continue
            local ns name fmt
            ns=$(echo "$line" | awk '{print $1}')
            name=$(echo "$line" | awk '{print $2}')
            fmt=$(oc get inferenceservice "$name" -n "$ns" \
                -o jsonpath='{.spec.predictor.model.modelFormat.name}' 2>/dev/null || true)
            if echo "$fmt" | grep -qi -E 'sklearn|xgboost|lightgbm|onnx'; then
                continue
            fi
            detected_ns="$ns"
            detected="$name"
            break
        done < <(oc get inferenceservice -A --no-headers 2>/dev/null || true)
    fi

    [ -z "$detected" ] && return 1

    LLM_MODEL_NAME="$detected"
    LLM_MODEL_NS="$detected_ns"

    # Resolve actual service name via labels
    local svc_name="" svc_port=""
    for label in "app.kubernetes.io/name=${detected}" "serving.kserve.io/inferenceservice=${detected}"; do
        svc_name=$(oc get svc -n "$detected_ns" -l "$label" \
            -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        if [ -n "$svc_name" ]; then
            svc_port=$(oc get svc "$svc_name" -n "$detected_ns" \
                -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "8000")
            break
        fi
    done

    svc_name="${svc_name:-${detected}-kserve-workload-svc}"
    svc_port="${svc_port:-8000}"
    LLM_BASE_URL="https://${svc_name}.${detected_ns}.svc:${svc_port}/v1"
}

# Detect predictive model (sklearn/xgboost) InferenceService
# Args: $1 = namespace to check first (optional)
# Sets: SKLEARN_MODEL_NAME, SKLEARN_MODEL_NS, SKLEARN_API_URL
detect_predictive_endpoint() {
    local target_ns="${1:-}"
    SKLEARN_MODEL_NAME=""
    SKLEARN_MODEL_NS=""
    SKLEARN_API_URL=""

    local cluster_domain
    cluster_domain=$(oc get ingress.config.openshift.io cluster \
        -o jsonpath='{.spec.domain}' 2>/dev/null || true)

    # Always search cluster-wide with custom-columns for consistent parsing
    local search_output
    search_output=$(oc get inferenceservice -A --no-headers \
        -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FORMAT:.spec.predictor.model.modelFormat.name' \
        2>/dev/null || true)

    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        local ns name fmt
        ns=$(echo "$line" | awk '{print $1}')
        name=$(echo "$line" | awk '{print $2}')
        fmt=$(echo "$line" | awk '{print $3}')
        if echo "$fmt" | grep -qi -E 'sklearn|xgboost|lightgbm|onnx'; then
            # Prefer match in target namespace
            if [ -n "$target_ns" ] && [ "$ns" != "$target_ns" ] && [ -z "$SKLEARN_MODEL_NAME" ]; then
                SKLEARN_MODEL_NAME="$name"
                SKLEARN_MODEL_NS="$ns"
                continue
            fi
            SKLEARN_MODEL_NAME="$name"
            SKLEARN_MODEL_NS="$ns"
            if [ "$ns" = "$target_ns" ]; then
                break
            fi
        fi
    done <<< "$search_output"

    if [ -n "$SKLEARN_MODEL_NAME" ] && [ -n "$cluster_domain" ]; then
        SKLEARN_API_URL="https://${SKLEARN_MODEL_NAME}-${SKLEARN_MODEL_NS}.${cluster_domain}/v2/models/${SKLEARN_MODEL_NAME}/infer"
    fi

    [ -n "$SKLEARN_MODEL_NAME" ] && return 0 || return 1
}

# Create/update notebook-env ConfigMap and patch Notebook CRs in a namespace.
# Args: $1 = namespace, $2..N = extra KEY=VALUE pairs
inject_notebook_env() {
    local ns="$1"; shift
    [ -z "$ns" ] && { echo "ERROR: inject_notebook_env requires a namespace"; return 1; }

    # Detect LLM if not already set
    if [ -z "${LLM_MODEL_NAME:-}" ]; then
        detect_llm_endpoint || true
    fi

    # Detect predictive model
    if [ -z "${SKLEARN_MODEL_NAME:-}" ]; then
        detect_predictive_endpoint "$ns" || true
    fi

    # Build ConfigMap data args
    local cm_args=()
    cm_args+=("--from-literal=NAMESPACE=${ns}")

    if [ -n "${LLM_MODEL_NAME:-}" ]; then
        cm_args+=("--from-literal=MODEL_NAME=${LLM_MODEL_NAME}")
        cm_args+=("--from-literal=MODEL_NAMESPACE=${LLM_MODEL_NS}")
        cm_args+=("--from-literal=BASE_URL=${LLM_BASE_URL}")
        cm_args+=("--from-literal=LLM_API_URL=${LLM_BASE_URL}/chat/completions")
        cm_args+=("--from-literal=LLM_MODEL_NAME=${LLM_MODEL_NAME}")
    fi

    if [ -n "${SKLEARN_MODEL_NAME:-}" ]; then
        cm_args+=("--from-literal=SKLEARN_MODEL_NAME=${SKLEARN_MODEL_NAME}")
        cm_args+=("--from-literal=SKLEARN_API_URL=${SKLEARN_API_URL}")
    fi

    # EvalHub URL + auth token (if EvalHub is deployed)
    local evalhub_url="https://evalhub.redhat-ods-applications.svc:8443"
    if oc get svc evalhub -n redhat-ods-applications &>/dev/null; then
        cm_args+=("--from-literal=EVALHUB_URL=${evalhub_url}")
        # Generate a long-lived token from the evalhub-service SA for SDK auth
        local evalhub_token
        evalhub_token=$(oc create token evalhub-service -n "$ns" --duration=87600h 2>/dev/null || true)
        if [ -n "$evalhub_token" ]; then
            cm_args+=("--from-literal=EVALHUB_AUTH_TOKEN=${evalhub_token}")
        fi
    fi

    # Append extra key=value pairs from arguments
    local arg
    for arg in "$@"; do
        if [[ "$arg" == *=* ]]; then
            local key="${arg%%=*}"
            local value="${arg#*=}"
            [ -n "$value" ] && cm_args+=("--from-literal=${key}=${value}")
        fi
    done

    # Create/update the ConfigMap
    oc create configmap notebook-env "${cm_args[@]}" \
        -n "$ns" --dry-run=client -o yaml | oc apply -f - 2>/dev/null

    # Patch any Notebook CRs in this namespace to add envFrom
    local notebooks
    notebooks=$(oc get notebooks.kubeflow.org -n "$ns" --no-headers \
        -o custom-columns='NAME:.metadata.name' 2>/dev/null || true)

    local nb
    for nb in $notebooks; do
        [ -z "$nb" ] && continue

        # Check if envFrom already references notebook-env
        local existing
        existing=$(oc get notebook "$nb" -n "$ns" \
            -o jsonpath='{.spec.template.spec.containers[0].envFrom[*].configMapRef.name}' 2>/dev/null || true)

        if echo "$existing" | grep -q "notebook-env"; then
            continue
        fi

        # Patch: add envFrom entry
        if [ -z "$existing" ]; then
            # No envFrom at all -- create it
            oc patch notebook "$nb" -n "$ns" --type=json \
                -p '[{"op": "add", "path": "/spec/template/spec/containers/0/envFrom", "value": [{"configMapRef": {"name": "notebook-env"}}]}]' \
                2>/dev/null || true
        else
            # envFrom exists -- append to it
            oc patch notebook "$nb" -n "$ns" --type=json \
                -p '[{"op": "add", "path": "/spec/template/spec/containers/0/envFrom/-", "value": {"configMapRef": {"name": "notebook-env"}}}]' \
                2>/dev/null || true
        fi
    done
}
