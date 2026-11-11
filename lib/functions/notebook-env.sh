#!/bin/bash
################################################################################
# notebook-env.sh — Auto-detect model endpoints and inject into workbenches
################################################################################
# Provides:
#   detect_llm_endpoint          — sets LLM_MODEL_NAME, LLM_MODEL_NS, LLM_BASE_URL
#   detect_direct_llm_endpoint   — sets DIRECT_MODEL_NAME, DIRECT_MODEL_NS, DIRECT_BASE_URL, DIRECT_ROUTE_URL
#   detect_predictive_endpoint   — sets SKLEARN_MODEL_NAME, SKLEARN_API_URL
#   resolve_served_model_id      — prints the id vLLM serves (the OpenAI "model" field) for a model resource
#   inject_notebook_env          — creates notebook-env ConfigMap + patches Notebook CRs
#
# Usage in deploy.sh:
#   source "$ROOT_DIR/lib/functions/notebook-env.sh"
#   inject_notebook_env "$NAMESPACE" "S3_ENDPOINT=$S3_ENDPOINT" "CUSTOM_VAR=value"
################################################################################

# Detect the first available LLM (LLMInferenceService > vLLM InferenceService)
# Excludes non-chat models: sklearn/xgboost/lightgbm/onnx (predictive) and
# guardrails-detector-huggingface (TrustyAI safety classifiers, not chat LLMs).
# Prefers a match in the given namespace (if provided) over other namespaces.
# Args: $1 = preferred namespace (optional)
# Sets: LLM_MODEL_NAME, LLM_MODEL_NS, LLM_BASE_URL
detect_llm_endpoint() {
    local preferred_ns="${1:-}"
    LLM_MODEL_NAME=""
    LLM_MODEL_NS=""
    LLM_BASE_URL=""

    local detected="" detected_ns=""

    # Try LLMInferenceService first (llm-d / GenAI models) -- prefer local namespace
    local llmisvc_output=""
    if [ -n "$preferred_ns" ]; then
        llmisvc_output=$(oc get llminferenceservice -n "$preferred_ns" --no-headers \
            -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name' 2>/dev/null | head -1)
    fi
    if [ -z "$llmisvc_output" ]; then
        llmisvc_output=$(oc get llminferenceservice -A --no-headers \
            -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name' 2>/dev/null | head -1)
    fi
    if [ -n "$llmisvc_output" ]; then
        detected_ns=$(echo "$llmisvc_output" | awk '{print $1}')
        detected=$(echo "$llmisvc_output" | awk '{print $2}')
    fi

    # Fallback: vLLM-based InferenceService (skip predictive + guardrails-detector formats)
    if [ -z "$detected" ]; then
        local fallback_ns="" fallback_name=""
        while IFS= read -r line || [ -n "$line" ]; do
            [ -z "$line" ] && continue
            local ns name fmt
            ns=$(echo "$line" | awk '{print $1}')
            name=$(echo "$line" | awk '{print $2}')
            fmt=$(oc get inferenceservice "$name" -n "$ns" \
                -o jsonpath='{.spec.predictor.model.modelFormat.name}' 2>/dev/null || true)
            if echo "$fmt" | grep -qi -E 'sklearn|xgboost|lightgbm|onnx|guardrails-detector'; then
                continue
            fi
            if [ -z "$fallback_name" ]; then
                fallback_ns="$ns"
                fallback_name="$name"
            fi
            if [ -n "$preferred_ns" ] && [ "$ns" = "$preferred_ns" ]; then
                detected_ns="$ns"
                detected="$name"
                break
            fi
        done < <(oc get inferenceservice -A --no-headers 2>/dev/null || true)

        # No match in preferred namespace -- use the first valid one found anywhere
        if [ -z "$detected" ]; then
            detected_ns="$fallback_ns"
            detected="$fallback_name"
        fi
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

# The OpenAI-compatible "model" field must be the id vLLM serves, not the k8s resource name.
# LLMInferenceService serves spec.model.name (e.g. RedHatAI/Qwen3-8B-FP8-dynamic for resource
# qwen3-8b); an InferenceService serves --served-model-name if set, else the resource name.
# Args: $1 = resource name, $2 = namespace. Prints the served id (falls back to $1).
resolve_served_model_id() {
    local name="$1" ns="$2" id=""
    [ -z "$name" ] && return 1
    id=$(oc get llminferenceservice "$name" -n "$ns" -o jsonpath='{.spec.model.name}' 2>/dev/null || true)
    if [ -z "$id" ]; then
        id=$(oc get inferenceservice "$name" -n "$ns" -o json 2>/dev/null | jq -r '
            [.spec.predictor.model.args[]?, .spec.predictor.containers[]?.args[]?]
            | map(select(startswith("--served-model-name=")) | sub("^--served-model-name="; ""))
            | .[0] // empty' 2>/dev/null || true)
    fi
    echo "${id:-$name}"
}

# Detect a standard vLLM InferenceService for direct access (non-MaaS, non-embedding).
# Use this for consumers like LlamaStack (RHOAI 3.4-) / OGX (RHOAI 3.5+) that need
# a standard vLLM /v1 endpoint.
# Excludes predictive models, embedding models, and guardrails-detector safety
# classifiers (not chat LLMs). Prefers a match in the given namespace.
# Args: $1 = preferred namespace (optional)
# Sets: DIRECT_MODEL_NAME, DIRECT_MODEL_NS, DIRECT_BASE_URL
detect_direct_llm_endpoint() {
    local preferred_ns="${1:-}"
    DIRECT_MODEL_NAME=""
    DIRECT_MODEL_NS=""
    DIRECT_BASE_URL=""

    local detected="" detected_ns="" fallback_ns="" fallback_name=""

    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        local ns name
        ns=$(echo "$line" | awk '{print $1}')
        name=$(echo "$line" | awk '{print $2}')
        local fmt
        fmt=$(oc get inferenceservice "$name" -n "$ns" \
            -o jsonpath='{.spec.predictor.model.modelFormat.name}' 2>/dev/null || true)
        if echo "$fmt" | grep -qi -E 'sklearn|xgboost|lightgbm|onnx|guardrails-detector'; then
            continue
        fi
        # Skip embedding models
        if echo "$name" | grep -qi -E 'bge|e5-|embed|nomic-embed'; then
            continue
        fi
        if [ -z "$fallback_name" ]; then
            fallback_ns="$ns"
            fallback_name="$name"
        fi
        if [ -n "$preferred_ns" ] && [ "$ns" = "$preferred_ns" ]; then
            detected_ns="$ns"
            detected="$name"
            break
        fi
    done < <(oc get inferenceservice -A --no-headers 2>/dev/null || true)

    if [ -z "$detected" ]; then
        detected_ns="$fallback_ns"
        detected="$fallback_name"
    fi

    # Fallback: no v1beta1 InferenceService found anywhere (common on RHOAI 3.5+
    # clusters that only deploy models via LLMInferenceService/llm-d). The
    # LLMInferenceService's own workload Service (<name>-kserve-workload-svc)
    # exposes a plain server-TLS (not mTLS) vLLM /v1 endpoint that does NOT go
    # through the MaaS gateway's auth -- confirmed reachable in-cluster with a
    # simple `curl -k` and no client cert. This makes it usable by consumers
    # like LlamaStack/OGX's remote::vllm provider that need a standard vLLM
    # endpoint but can't do MaaS gateway auth. See docs/TODO-next-session.md
    # "Dual Qwen3-8B Endpoint Architecture" for the historical InferenceService-
    # based version of this pattern.
    if [ -z "$detected" ]; then
        local llmisvc_output=""
        if [ -n "$preferred_ns" ]; then
            llmisvc_output=$(oc get llminferenceservice -n "$preferred_ns" --no-headers \
                -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name' 2>/dev/null \
                | grep -v -i -E 'bge|e5-|embed|nomic-embed' | head -1)
        fi
        if [ -z "$llmisvc_output" ]; then
            llmisvc_output=$(oc get llminferenceservice -A --no-headers \
                -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name' 2>/dev/null \
                | grep -v -i -E 'bge|e5-|embed|nomic-embed' | head -1)
        fi
        if [ -n "$llmisvc_output" ]; then
            detected_ns=$(echo "$llmisvc_output" | awk '{print $1}')
            detected=$(echo "$llmisvc_output" | awk '{print $2}')

            [ -z "$detected" ] && return 1

            DIRECT_MODEL_NAME="$detected"
            DIRECT_MODEL_NS="$detected_ns"

            local llm_svc_name="${detected}-kserve-workload-svc"
            local llm_svc_port
            llm_svc_port=$(oc get svc "$llm_svc_name" -n "$detected_ns" \
                -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "8000")
            DIRECT_BASE_URL="https://${llm_svc_name}.${detected_ns}.svc:${llm_svc_port}/v1"

            # No unauthenticated external route exists for LLMInferenceService
            # models -- status.url is the MaaS gateway URL, which requires an
            # sk-oai-* API key. Leave DIRECT_ROUTE_URL unset; consumers that
            # need an external route (e.g. EvalHub adapters) must use the MaaS
            # endpoint + API key instead for this model.
            DIRECT_ROUTE_URL=""
            return 0
        fi
    fi

    [ -z "$detected" ] && return 1

    DIRECT_MODEL_NAME="$detected"
    DIRECT_MODEL_NS="$detected_ns"

    # Resolve actual service name via labels
    local svc_name="" svc_port=""
    for label in "serving.kserve.io/inferenceservice=${detected}" "app.kubernetes.io/name=${detected}"; do
        svc_name=$(oc get svc -n "$detected_ns" -l "$label" \
            -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        if [ -n "$svc_name" ]; then
            svc_port=$(oc get svc "$svc_name" -n "$detected_ns" \
                -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "80")
            break
        fi
    done

    svc_name="${svc_name:-${detected}-predictor}"
    svc_port="${svc_port:-80}"

    # Determine protocol from port name
    local port_name
    port_name=$(oc get svc "$svc_name" -n "$detected_ns" \
        -o jsonpath='{.spec.ports[0].name}' 2>/dev/null || echo "http")
    local proto="http"
    if echo "$port_name" | grep -qi "https"; then
        proto="https"
    fi

    DIRECT_BASE_URL="${proto}://${svc_name}.${detected_ns}.svc:${svc_port}/v1"

    # Also resolve the external route URL (for consumers outside cluster networking,
    # e.g. EvalHub adapter pods that can't trust internal service-ca)
    DIRECT_ROUTE_URL=""
    local route_url
    route_url=$(oc get inferenceservice "$detected" -n "$detected_ns" \
        -o jsonpath='{.status.url}' 2>/dev/null || true)
    if [ -n "$route_url" ]; then
        DIRECT_ROUTE_URL="${route_url%/}/v1"
    fi
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

    # Detect LLM if not already set (prefer a match in this namespace)
    if [ -z "${LLM_MODEL_NAME:-}" ]; then
        detect_llm_endpoint "$ns" || true
    fi

    # Detect direct vLLM endpoint (non-MaaS, for LlamaStack/OGX etc.)
    if [ -z "${DIRECT_MODEL_NAME:-}" ]; then
        detect_direct_llm_endpoint "$ns" || true
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

        # Resolve the HuggingFace model ID (spec.model.name from
        # LLMInferenceService, or spec.predictor.model.modelFormat.name from
        # InferenceService). Many notebooks need this as MODEL_SERVED_NAME
        # (the OpenAI-compatible model name in /v1/models) or HF_MODEL_ID
        # (the tokenizer/model card ID).
        local _hf_model_id=""
        _hf_model_id=$(oc get llminferenceservice "${LLM_MODEL_NAME}" -n "${LLM_MODEL_NS}" \
            -o jsonpath='{.spec.model.name}' 2>/dev/null || true)
        if [ -n "$_hf_model_id" ]; then
            cm_args+=("--from-literal=HF_MODEL_ID=${_hf_model_id}")
            cm_args+=("--from-literal=MODEL_ID=${_hf_model_id}")
        fi
    fi

    if [ -n "${DIRECT_MODEL_NAME:-}" ]; then
        cm_args+=("--from-literal=DIRECT_MODEL_NAME=${DIRECT_MODEL_NAME}")
        cm_args+=("--from-literal=DIRECT_BASE_URL=${DIRECT_BASE_URL}")
        if [ -n "${DIRECT_ROUTE_URL:-}" ]; then
            cm_args+=("--from-literal=DIRECT_ROUTE_URL=${DIRECT_ROUTE_URL}")
        fi
    fi

    if [ -n "${SKLEARN_MODEL_NAME:-}" ]; then
        cm_args+=("--from-literal=SKLEARN_MODEL_NAME=${SKLEARN_MODEL_NAME}")
        cm_args+=("--from-literal=SKLEARN_API_URL=${SKLEARN_API_URL}")
    fi

    # EvalHub URL + auth token (if EvalHub is deployed)
    local evalhub_url="https://evalhub.redhat-ods-applications.svc:8443"
    if oc get svc evalhub -n redhat-ods-applications &>/dev/null; then
        cm_args+=("--from-literal=EVALHUB_URL=${evalhub_url}")

        # Job-writer RBAC: only relevant if the central evalhub-service SA has
        # been mirrored into this namespace (it normally lives centrally in
        # redhat-ods-applications -- see docs/bugs/evalhub-dashboard-namespace-lookup.md).
        if oc get sa evalhub-service -n "$ns" &>/dev/null; then
            oc apply -f - <<EOROLE 2>/dev/null || true
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: evalhub-evaluations-writer
  namespace: ${ns}
rules:
- apiGroups: ["trustyai.opendatahub.io"]
  resources: ["evaluations", "status-events"]
  verbs: ["get", "create", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: evalhub-evaluations-writer-rb
  namespace: ${ns}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: evalhub-evaluations-writer
subjects:
- kind: ServiceAccount
  name: evalhub-service
  namespace: ${ns}
- kind: ServiceAccount
  name: evalhub-redhat-ods-applications-job
  namespace: ${ns}
- kind: ServiceAccount
  name: evalhub-${ns}-job
  namespace: ${ns}
EOROLE
        fi

        # Client-side SDK auth: the eval-hub-sdk client (e.g. client.benchmarks.list())
        # authenticates as whatever identity generated its token. Notebooks default to
        # `oc whoami -t`, which resolves to the workbench's own default SA -- that SA
        # has zero EvalHub-related RBAC. Prefer lmeval-sa (bound to
        # trustyai-operator-lmevaljob-editor-role, the role EvalHub's server-side
        # authorization hard-checks -- see docs/bugs/evalhub-bugs-rhoai-34.md Bug 8),
        # falling back to evalhub-service if lmeval-sa isn't present in this namespace.
        local evalhub_token=""
        if oc get sa lmeval-sa -n "$ns" &>/dev/null; then
            evalhub_token=$(oc create token lmeval-sa -n "$ns" --duration=87600h 2>/dev/null || true)
        elif oc get sa evalhub-service -n "$ns" &>/dev/null; then
            evalhub_token=$(oc create token evalhub-service -n "$ns" --duration=87600h 2>/dev/null || true)
        fi
        if [ -n "$evalhub_token" ]; then
            cm_args+=("--from-literal=EVALHUB_AUTH_TOKEN=${evalhub_token}")
        fi
    fi

    # Append extra key=value pairs from arguments.
    # Skip keys already added by auto-detection above to avoid
    # "another key by that name already exists" from oc create configmap.
    local _existing_keys=""
    local _cm_arg
    for _cm_arg in "${cm_args[@]}"; do
        _existing_keys="${_existing_keys} ${_cm_arg#--from-literal=}"
    done
    local arg
    for arg in "$@"; do
        if [[ "$arg" == *=* ]]; then
            local key="${arg%%=*}"
            local value="${arg#*=}"
            if echo "$_existing_keys" | grep -q "${key}="; then
                continue
            fi
            [ -n "$value" ] && cm_args+=("--from-literal=${key}=${value}")
        fi
    done

    # Merge: keep keys already in notebook-env that this run does not set (demo-specific keys such as
    # MODEL_ID, MAAS_ROUTING, LIMIT, bucket names were dropped by scripts/refresh-notebook-env.sh).
    # NOTEBOOK_ENV_REPLACE=1 restores replace semantics.
    if [ "${NOTEBOOK_ENV_REPLACE:-0}" != "1" ]; then
        local _set_keys=" " _a _k _v
        for _a in "${cm_args[@]}"; do _a="${_a#--from-literal=}"; _set_keys="${_set_keys}${_a%%=*} "; done
        while IFS=$'\t' read -r _k _v; do
            [ -z "$_k" ] && continue
            [[ "$_set_keys" == *" $_k "* ]] && continue
            cm_args+=("--from-literal=${_k}=${_v}")
        done < <(oc get configmap notebook-env -n "$ns" -o json 2>/dev/null \
                 | jq -r '.data // {} | to_entries[] | [.key, .value] | @tsv' 2>/dev/null)
    fi

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

    _restart_notebooks_on_env_change "$ns"
}

################################################################################
# _restart_notebooks_on_env_change <ns>
#
# envFrom is only read at pod start, so a workbench created before the
# ConfigMap was filled sees stale env. Keep a hash of notebook-env (and any
# attached secrets' resourceVersions) in a Notebook *metadata* annotation (the
# Notebook CRD prunes spec.template.metadata, so a pod-template annotation is
# silently dropped); when it changes, delete the running <name>-0 pod and the
# StatefulSet recreates it with the new env. Stopped workbenches pick it up on
# next start. NOTEBOOK_ENV_NO_RESTART=1 skips this.
################################################################################
_restart_notebooks_on_env_change() {
    local ns="$1" mode="${2:-restart}"   # mode=annotate-only: record the hash, don't delete the pod
    [ "${NOTEBOOK_ENV_NO_RESTART:-0}" = "1" ] && return 0
    local hash
    hash=$( { oc get configmap notebook-env -n "$ns" -o jsonpath='{.data}' 2>/dev/null
              oc get secret -n "$ns" -l toolkit.rhoai/notebook-env=true \
                  -o jsonpath='{range .items[*]}{.metadata.name}{.metadata.resourceVersion}{end}' 2>/dev/null
            } | cksum | cut -d" " -f1)
    local nb current
    for nb in $(oc get notebooks.kubeflow.org -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
        current=$(oc get notebook "$nb" -n "$ns" \
            -o jsonpath='{.metadata.annotations.toolkit\.rhoai/notebook-env-hash}' 2>/dev/null || true)
        [ "$current" = "$hash" ] && continue
        oc annotate notebook "$nb" -n "$ns" "toolkit.rhoai/notebook-env-hash=$hash" --overwrite >/dev/null 2>&1 || continue
        if [ "$mode" != "annotate-only" ] && oc get pod "${nb}-0" -n "$ns" &>/dev/null; then
            oc delete pod "${nb}-0" -n "$ns" --wait=false >/dev/null 2>&1 && \
                echo -e "${CYAN:-}ℹ Workbench $nb: environment changed, restarting to apply it${NC:-}"
        fi
    done
}

################################################################################
# attach_secret_to_notebooks <ns> <secret>
#
# Adds envFrom.secretRef to every Notebook in <ns> (for values that must not
# live in the plaintext notebook-env ConfigMap, e.g. MaaS API keys). Label the
# secret toolkit.rhoai/notebook-env=true so key rotation restarts workbenches.
################################################################################
attach_secret_to_notebooks() {
    local ns="$1" secret="$2" nb existing patched=0
    for nb in $(oc get notebooks.kubeflow.org -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
        existing=$(oc get notebook "$nb" -n "$ns" \
            -o jsonpath='{.spec.template.spec.containers[0].envFrom[*].secretRef.name}' 2>/dev/null || true)
        echo "$existing" | grep -qw "$secret" && continue
        oc patch notebook "$nb" -n "$ns" --type=json \
            -p "[{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/envFrom/-\",\"value\":{\"secretRef\":{\"name\":\"$secret\"}}}]" \
            >/dev/null 2>&1 && patched=1
    done
    # A spec change already rolls the pod; only record the hash then (avoids a second restart)
    if [ "$patched" = 1 ]; then
        echo -e "${CYAN:-}ℹ Secret $secret attached to workbenches (pods restart to load it)${NC:-}"
        _restart_notebooks_on_env_change "$ns" annotate-only
    else
        _restart_notebooks_on_env_change "$ns"
    fi
}
