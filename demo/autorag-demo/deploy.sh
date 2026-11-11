#!/bin/bash
################################################################################
# Deploy AutoRAG Demo
################################################################################
# Sets up infrastructure for AutoRAG (Technology Preview):
#   - S3-compatible storage for documents and pipeline artifacts
#     (SeaweedFS by default; --backend=ceph-rgw or --backend=minio also supported)
#   - Milvus vector database (remote -- required by AutoRAG)
#   - Pipeline Server (DSPA) for Kubeflow Pipelines
#   - S3 data connection and sample documents
#   - Activates the Llama Stack Operator (RHOAI 3.4-) or OGX Operator (RHOAI 3.5+)
#     if not already enabled
#
# AutoRAG itself is a dashboard-native feature -- after infrastructure is ready,
# use the RHOAI dashboard: Develop and train > AutoRAG
#
# Prerequisites (RHOAI 3.4 and earlier):
#   - Llama Stack Operator activated (llamastackoperator: Managed in DSC)
#   - Llama Stack instance with foundation + embedding models
#   - Gen AI Studio enabled in dashboard
#
# Prerequisites (RHOAI 3.5+):
#   - OGX Operator activated (ogx: Managed in DSC -- replaces llamastackoperator)
#   - OGXServer instance with foundation + embedding models
#   - Gen AI Studio enabled in dashboard
#
# Usage:
#   ./deploy.sh                    # Deploy to autorag-demo namespace
#   ./deploy.sh -n my-namespace    # Custom namespace
#   ./deploy.sh --delete           # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"
source "$ROOT_DIR/lib/utils/rhoai-version.sh" 2>/dev/null || true
source "$ROOT_DIR/lib/functions/notebook-env.sh"
source "$ROOT_DIR/lib/utils/os-compat.sh"
source "$ROOT_DIR/lib/functions/storage-backend.sh"

# RHOAI 3.5+ renamed Llama Stack to OGX (llamastackoperator -> ogx,
# LlamaStackDistribution -> OGXServer). Detect once and use throughout.
USE_OGX=false
if type is_rhoai_35_or_higher &>/dev/null && is_rhoai_35_or_higher 2>/dev/null; then
    USE_OGX=true
fi

################################################################################
# Helper: Patch llama-stack-config vLLM base_url to internal service endpoint
################################################################################
# The copied config often has base_url pointing at the MaaS external gateway
# (e.g. https://maas.apps.<cluster>/v1) which requires a real bearer token.
# OGX can't provide one (VLLM_API_TOKEN_1 is a placeholder). Detect the
# LLMInferenceService or InferenceService for the LLM and rewrite the
# base_url to the internal k8s service (no auth needed).
_patch_ogx_config_vllm_url() {
    local ns="$1"
    # Find the first LLMInferenceService workload service across all namespaces
    local _llm_svc=""
    _llm_svc=$(oc get llminferenceservice -A -o jsonpath='{range .items[?(@.status.conditions[?(@.type=="Ready")].status=="True")]}{.status.workloads.service.name}.{.metadata.namespace}.svc.cluster.local:{.status.workloads.primary.name}{"\n"}{end}' 2>/dev/null | head -1)
    if [ -z "$_llm_svc" ]; then
        # Fallback: try any LLMInferenceService (even non-Ready)
        _llm_svc=$(oc get llminferenceservice -A -o jsonpath='{range .items[*]}{.status.workloads.service.name}.{.metadata.namespace}.svc.cluster.local{"\n"}{end}' 2>/dev/null | head -1)
    fi
    if [ -z "$_llm_svc" ]; then
        print_warning "No LLMInferenceService found — vLLM base_url not patched"
        return
    fi
    # Extract just the service FQDN (strip the deployment info after the colon)
    local _svc_fqdn="${_llm_svc%%:*}"
    local _internal_url="https://${_svc_fqdn}:8000/v1"

    print_info "Patching OGX config vLLM base_url → ${_internal_url}"
    local _config
    _config=$(oc get configmap llama-stack-config -n "$ns" -o jsonpath='{.data.config\.yaml}')
    # Replace any https://maas.* or https://*.apps.* vLLM base_url with internal
    _config=$(echo "$_config" | sed "s|base_url: https://maas\.[^ ]*|base_url: ${_internal_url}|g")
    oc create configmap llama-stack-config \
        --from-literal=config.yaml="$_config" \
        -n "$ns" --dry-run=client -o yaml | oc apply -f -
}

################################################################################
# Helper: Remove embedding models that can't load in offline mode
################################################################################
# OGX runs with HF_HUB_OFFLINE=1 so models not pre-cached in the container
# image can't be downloaded. The base config may register models like
# nomic-embed-text-v1.5 that appear as options in AutoRAG but fail at runtime.
# Only keep ibm-granite/granite-embedding-125m-english (pre-cached).
_patch_ogx_config_remove_offline_models() {
    local ns="$1"
    local _config
    _config=$(oc get configmap llama-stack-config -n "$ns" -o jsonpath='{.data.config\.yaml}')

    # Check if nomic model is registered — only patch if needed
    if echo "$_config" | grep -q "nomic-ai/nomic-embed-text"; then
        print_info "Removing offline-unavailable models (nomic-embed-text) from OGX config"
        # Use python for reliable YAML manipulation
        _config=$(echo "$_config" | python3 -c "
import sys, yaml

config = yaml.safe_load(sys.stdin.read())

# Filter registered_resources.models — keep only models whose provider_model_id
# doesn't reference nomic-ai (offline-unavailable)
if 'registered_resources' in config and 'models' in config['registered_resources']:
    config['registered_resources']['models'] = [
        m for m in config['registered_resources']['models']
        if 'nomic-ai' not in m.get('provider_model_id', '') and 'nomic-ai' not in m.get('model_id', '')
    ]

yaml.dump(config, sys.stdout, default_flow_style=False, sort_keys=False)
" 2>/dev/null)

        if [ -n "$_config" ]; then
            oc create configmap llama-stack-config \
                --from-literal=config.yaml="$_config" \
                -n "$ns" --dry-run=client -o yaml | oc apply -f -
        else
            print_warning "Could not filter offline models — skipping"
        fi
    fi
}

NAMESPACE="autorag-demo"
# Positional namespace still works (./deploy.sh my-ns); a leading flag (e.g. --delete) is not a namespace
[[ -n "${1:-}" && "${1:-}" != -* ]] && NAMESPACE="$1"
DELETE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --delete) DELETE_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [-n namespace] [--delete]"
            exit 0
            ;;
        *) shift ;;
    esac
done

print_header "AutoRAG Demo (Technology Preview)"

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing AutoRAG infrastructure from $NAMESPACE..."
    export NAMESPACE
    if [ "$USE_OGX" = true ]; then
        oc delete ogxserver autorag-ogx -n "$NAMESPACE" --ignore-not-found 2>/dev/null
        oc delete secret ogx-secret -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    else
        oc delete llamastackdistribution autorag-llamastack -n "$NAMESPACE" --ignore-not-found 2>/dev/null
        oc delete secret llama-stack-secret -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    fi
    envsubst < "$SCRIPT_DIR/manifests/llamastack-postgresql.yaml" | oc delete -f - --ignore-not-found 2>/dev/null
    oc delete secret milvus-connection-secret -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    envsubst < "$SCRIPT_DIR/manifests/bge-m3-embedding.yaml" | oc delete -f - --ignore-not-found 2>/dev/null
    oc delete datasciencepipelineapplication pipelines-definition -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    envsubst < "$SCRIPT_DIR/manifests/milvus.yaml" | oc delete -f - --ignore-not-found 2>/dev/null
    envsubst < "$SCRIPT_DIR/manifests/minio.yaml" | oc delete -f - --ignore-not-found 2>/dev/null
    print_success "AutoRAG infrastructure removed from $NAMESPACE"
    exit 0
fi

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

# --- Step 0: Verify prerequisites ---
print_step "Checking prerequisites..."

# Check Llama Stack Operator (3.4-) or OGX Operator (3.5+; DSC field: ogx, was llamastackoperator)
if [ "$USE_OGX" = true ]; then
    OGX_STATE=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.ogx.managementState}' 2>/dev/null)
    if [ "$OGX_STATE" != "Managed" ]; then
        print_warning "OGX Operator is not enabled (current: ${OGX_STATE:-not set})"
        print_info "Activating OGX Operator in DSC..."
        oc patch datasciencecluster default-dsc --type=merge \
            -p '{"spec":{"components":{"ogx":{"managementState":"Managed"}}}}' 2>/dev/null || \
            print_warning "Could not patch DSC -- enable ogx manually"
    fi
else
    LLAMASTACK_STATE=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.llamastackoperator.managementState}' 2>/dev/null)
    if [ "$LLAMASTACK_STATE" != "Managed" ]; then
        print_warning "Llama Stack Operator is not enabled (current: ${LLAMASTACK_STATE:-not set})"
        print_info "Activating Llama Stack Operator in DSC..."
        oc patch datasciencecluster default-dsc --type=merge \
            -p '{"spec":{"components":{"llamastackoperator":{"managementState":"Managed"}}}}' 2>/dev/null || \
            print_warning "Could not patch DSC -- enable llamastackoperator manually"
    fi
fi

# Check AI Pipelines
if ! oc get crd datasciencepipelinesapplications.datasciencepipelinesapplications.opendatahub.io &>/dev/null 2>&1; then
    print_error "DSPA CRD not found. Ensure 'aipipelines: Managed' in your DataScienceCluster."
    exit 1
fi

ensure_namespace "$NAMESPACE"
oc label namespace "$NAMESPACE" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true

# Export NAMESPACE once, unconditionally, for the lifetime of this script.
# IMPORTANT: every subsequent `export NAMESPACE` call below lives inside an
# "only if not already deployed" branch -- on an idempotent re-run where
# earlier resources already exist, none of those branches fire, so without
# this unconditional export here, envsubst calls later in the script (e.g.
# the OGX/LlamaStack manifest at Step 6) would see an EMPTY ${NAMESPACE} and
# `oc apply` would silently fall back to the "default" namespace instead of
# failing loudly. (Root-caused 2026-09-21 after autorag-ogx landed in
# `default` on a re-run where MinIO/Milvus/Postgres/bge-m3 were all already
# deployed.)
export NAMESPACE

# Enable AutoRAG in dashboard
oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
    --type=merge -p '{"spec":{"dashboardConfig":{"autorag":true}}}' 2>/dev/null || true

# --- Step 1: S3 storage for document storage + pipeline artifacts ---
print_step "Deploying S3 storage backend (${S3_BACKEND:-seaweedfs})..."
detect_or_select_storage_backend "$NAMESPACE"
deploy_storage_backend "$NAMESPACE" "20Gi"
wait_for_storage "$NAMESPACE"

# Create buckets
print_step "Creating S3 buckets..."
create_storage_bucket "$NAMESPACE" "pipeline-artifacts"
create_storage_bucket "$NAMESPACE" "autorag-docs"

# Upload sample documents via aws-cli one-shot pod
print_step "Uploading sample documents..."
S3_EP="$(get_storage_endpoint "$NAMESPACE")"
_UPLOAD_OK=false
for doc in "$SCRIPT_DIR/sample-data/docs"/*; do
    if [ -f "$doc" ]; then
        BASENAME=$(basename "$doc")
        oc run s3-upload-"${BASENAME%%.*}" --rm -i --restart=Never \
            --image=docker.io/amazon/aws-cli:latest \
            -n "$NAMESPACE" \
            --env="AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY:-admin}" \
            --env="AWS_SECRET_ACCESS_KEY=${S3_SECRET_KEY:-admin123}" \
            --env="AWS_DEFAULT_REGION=us-east-1" \
            -- s3 cp - "s3://autorag-docs/$BASENAME" --endpoint-url "$S3_EP" \
            < "$doc" 2>/dev/null && _UPLOAD_OK=true || true
    fi
done
if [ -f "$SCRIPT_DIR/sample-data/test-data.json" ]; then
    oc run s3-upload-testdata --rm -i --restart=Never \
        --image=docker.io/amazon/aws-cli:latest \
        -n "$NAMESPACE" \
        --env="AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY:-admin}" \
        --env="AWS_SECRET_ACCESS_KEY=${S3_SECRET_KEY:-admin123}" \
        --env="AWS_DEFAULT_REGION=us-east-1" \
        -- s3 cp - "s3://autorag-docs/test-data.json" --endpoint-url "$S3_EP" \
        < "$SCRIPT_DIR/sample-data/test-data.json" 2>/dev/null || true
fi
if [ "$_UPLOAD_OK" = true ]; then
    print_success "Sample documents uploaded to s3://autorag-docs/"
else
    print_warning "Some uploads may have failed -- check: aws --endpoint-url $S3_EP s3 ls s3://autorag-docs/"
fi

# --- Step 2: S3 data connection ---
print_step "Creating S3 data connection for AutoRAG documents..."
S3_EP="$(get_storage_endpoint "$NAMESPACE")"
# Dashboard AutoRAG/AutoML UI requires an HTTPS S3 endpoint for connections
S3_EXT_EP="$(get_storage_external_endpoint "$NAMESPACE")"
DATA_CONNECTION_NAME=aws-connection-autorag-docs DATA_CONNECTION_ENDPOINT="$S3_EXT_EP" DATA_CONNECTION_COMPAT=false \
    create_data_connection "$NAMESPACE" autorag-docs "$NAMESPACE" "AutoRAG Documents" >/dev/null

# --- Step 3: Milvus vector database ---
print_step "Deploying Milvus vector database..."
if oc get deployment milvus-standalone -n "$NAMESPACE" &>/dev/null; then
    print_info "Milvus already deployed in $NAMESPACE"
else
    export NAMESPACE
    envsubst < "$SCRIPT_DIR/manifests/milvus.yaml" | oc apply -f -
    print_info "Milvus deploying (takes 1-2 minutes for readiness)..."
    oc rollout status deployment/milvus-standalone -n "$NAMESPACE" --timeout=180s 2>/dev/null || \
        print_warning "Milvus not ready yet -- check: oc get pods -l app=milvus -n $NAMESPACE"
fi

MILVUS_ENDPOINT="milvus.${NAMESPACE}.svc.cluster.local:19530"

# --- Step 4: Pipeline Server (DSPA) ---
print_step "Deploying Pipeline Server (DSPA)..."
# Object storage comes from the active backend (SeaweedFS by default), never a hard-coded MinIO host.
_s3_ep="$(get_storage_endpoint "$NAMESPACE")"
export NAMESPACE S3_SCHEME="${_s3_ep%%://*}"
_s3_hostport="${_s3_ep#*://}"
export S3_HOST="${_s3_hostport%%:*}" S3_PORT="${_s3_hostport##*:}"
oc create secret generic pipelines-s3-credentials -n "$NAMESPACE" \
    --from-literal=AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY:-admin}" \
    --from-literal=AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY:-admin123}" \
    --dry-run=client -o yaml | oc apply -f - >/dev/null
_dspa_host=$(oc get datasciencepipelinesapplication pipelines-definition -n "$NAMESPACE" \
    -o jsonpath='{.spec.objectStorage.externalStorage.host}' 2>/dev/null || true)
if [ -n "$_dspa_host" ] && [ "$_dspa_host" = "$S3_HOST" ]; then
    print_info "Pipeline server already exists in $NAMESPACE (storage: $S3_HOST:$S3_PORT)"
else
    [ -n "$_dspa_host" ] && print_warning "Pipeline server points at '$_dspa_host'; re-pointing to $S3_HOST:$S3_PORT"
    envsubst '${NAMESPACE} ${S3_HOST} ${S3_PORT} ${S3_SCHEME}' < "$SCRIPT_DIR/manifests/pipeline-server.yaml" | oc apply -f -
    print_info "Pipeline server deploying (takes 1-2 minutes)..."
fi

# --- Step 5: PostgreSQL for LlamaStack metadata ---
print_step "Deploying PostgreSQL for LlamaStack metadata store..."
if oc get deployment llamastack-postgres -n "$NAMESPACE" &>/dev/null; then
    print_info "LlamaStack PostgreSQL already deployed in $NAMESPACE"
else
    export NAMESPACE
    envsubst < "$SCRIPT_DIR/manifests/llamastack-postgresql.yaml" | oc apply -f -
    oc rollout status deployment/llamastack-postgres -n "$NAMESPACE" --timeout=120s 2>/dev/null || \
        print_warning "PostgreSQL not ready yet -- check: oc get pods -l app=llamastack-postgres -n $NAMESPACE"
fi

# --- Step 5b: bge-m3 embedding model (CPU) if no embedding model exists yet ---
# Check for an existing embedding-like InferenceService first (covers the case
# where a user already deployed one, e.g. on a multi-GPU cluster).
if ! oc get inferenceservice -n "$NAMESPACE" --no-headers 2>/dev/null \
        | awk '{print $1}' | grep -qi -E 'bge|e5-|embed|nomic-embed'; then
    print_step "Deploying bge-m3 embedding model (CPU-only, no GPU required)..."
    export NAMESPACE
    envsubst < "$SCRIPT_DIR/manifests/bge-m3-embedding.yaml" | oc apply -f -
    print_info "bge-m3 deploying (CPU inference server startup can take a few minutes)..."
    oc rollout status deployment/bge-m3-predictor -n "$NAMESPACE" --timeout=300s 2>/dev/null || \
        print_warning "bge-m3 not ready yet -- check: oc get pods -n $NAMESPACE -l serving.kserve.io/inferenceservice=bge-m3"
else
    print_info "Embedding model already present in $NAMESPACE"
fi

# --- Step 6: OGX Server (overrideConfig approach — bypasses operator config generation) ---
if [ "$USE_OGX" = true ]; then
    print_step "Deploying OGX (replaces Llama Stack on RHOAI 3.5+)..."

    # An OGXServer from before the overrideConfig fix (rh + baseConfig + inline providers) crashes with
    # "MilvusVectorIOConfig token/persistence: Field required" (docs/bugs/autorag-ogx-3.5-cascade.md).
    # oc apply can't reliably drop those fields, so recreate it.
    if oc get ogxserver autorag-ogx -n "$NAMESPACE" -o json 2>/dev/null \
        | jq -e '[.. | objects | select(has("baseConfig"))] | length > 0' >/dev/null 2>&1; then
        print_warning "Existing OGXServer autorag-ogx uses baseConfig (pre-fix); recreating with overrideConfig"
        oc delete ogxserver autorag-ogx -n "$NAMESPACE" --wait=true --timeout=120s
    fi

    # Deploy pgvector (required by OGX for vector_io + responses persistence)
    print_step "Deploying pgvector database for OGX..."
    # Reuse the existing password: the database on the PVC was initialised with it, and a new random
    # password on re-run would lock OGX out of pgvector.
    if [ -z "${PGVECTOR_PASSWORD:-}" ]; then
        _pg_b64=$(oc get secret genai-pgvector-credentials -n "$NAMESPACE" -o jsonpath='{.data.password}' 2>/dev/null || true)
        [ -n "$_pg_b64" ] && PGVECTOR_PASSWORD=$(base64_decode "$_pg_b64" 2>/dev/null || true)
    fi
    export PGVECTOR_PASSWORD="${PGVECTOR_PASSWORD:-$(openssl rand -hex 16)}"
    envsubst < "$SCRIPT_DIR/manifests/ogxserver.yaml" | oc apply -f -

    # Wait for pgvector
    oc rollout status deployment/genai-pgvector -n "$NAMESPACE" --timeout=120s 2>/dev/null || true

    # Copy the working llama-stack-config from the Playground (ai-studio-demo)
    # or any namespace that has a Ready OGXServer. This config has all the
    # provider definitions (inference, vector_io, responses, tool_runtime)
    # that the Python runtime needs, without the CRD schema gaps.
    if ! oc get configmap llama-stack-config -n "$NAMESPACE" &>/dev/null; then
        print_step "Copying OGX base config (llama-stack-config)..."
        # Try to find a working config from another namespace
        _src_ns=""
        for _ns in ai-studio-demo redhat-ods-applications; do
            if oc get configmap llama-stack-config -n "$_ns" &>/dev/null; then
                _src_ns="$_ns"
                break
            fi
        done

        if [ -n "$_src_ns" ]; then
            oc get configmap llama-stack-config -n "$_src_ns" -o json \
                | jq ".metadata.namespace = \"$NAMESPACE\" | del(.metadata.uid, .metadata.resourceVersion, .metadata.creationTimestamp, .metadata.managedFields, .metadata.ownerReferences)" \
                | oc apply -f -
            print_success "Copied llama-stack-config from $_src_ns"

            # --- Post-copy patches ---
            # The copied config may reference the source namespace's MaaS gateway
            # or external model endpoints. Patch the vLLM inference base_url to
            # use the internal service endpoint (no auth required) instead of the
            # MaaS external route (which requires a real bearer token that OGX
            # can't provide via env-var substitution).
            _patch_ogx_config_vllm_url "$NAMESPACE"

            # Remove nomic-embed-text-v1.5 from registered models — it's
            # registered in the base config but can't be downloaded because
            # OGX runs with HF_HUB_OFFLINE=1. Leaving it registered causes
            # AutoRAG to offer it as an embedding option, but the pipeline
            # fails at search-space-preparation when it can't load the model.
            _patch_ogx_config_remove_offline_models "$NAMESPACE"
        else
            # Fallback: extract from OCI image labels (RHOAIENG-96724 workaround)
            print_step "Extracting OGX base config from OCI image labels..."
            _ogx_digest
            _ogx_digest=$(oc get deployment -n redhat-ods-applications -l app.kubernetes.io/name=ogx-k8s-operator \
                -o jsonpath='{.items[0].spec.template.spec.containers[0].env[?(@.name=="RELATED_IMAGE_ODH_OGX_CORE_IMAGE")].value}' 2>/dev/null)
            if [ -n "$_ogx_digest" ]; then
                _pull_secret_file
                _pull_secret_file=$(mktemp)
                oc get secret pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > "$_pull_secret_file" 2>/dev/null
                _config_yaml
                _config_yaml=$(oc image info --filter-by-os linux/amd64 -a "$_pull_secret_file" "$_ogx_digest" -o json 2>/dev/null \
                    | jq -r '.config.config.Labels["com.ogx.config.config.yaml"]' 2>/dev/null)
                rm -f "$_pull_secret_file"
                if [ -n "$_config_yaml" ] && [ "$_config_yaml" != "null" ]; then
                    oc create configmap llama-stack-config \
                        --from-literal=config.yaml="$_config_yaml" \
                        -n "$NAMESPACE" --dry-run=client -o yaml | oc apply -f -
                    print_success "Extracted OGX config from OCI labels"
                else
                    print_warning "Could not extract OGX config -- OGXServer will fail"
                fi
            fi
        fi
    else
        # An existing config may have been copied from another namespace or cluster (its MaaS base_url then
        # points elsewhere). Both patches are idempotent, so always apply them.
        print_info "llama-stack-config already exists: re-applying endpoint patches"
        _patch_ogx_config_vllm_url "$NAMESPACE"
        _patch_ogx_config_remove_offline_models "$NAMESPACE"
    fi

    # The OGX operator's namespace-scoped informer only sees ConfigMaps labelled ogx.io/watch=true;
    # without it the OGXServer fails with "failed to find referenced ConfigMap .../llama-stack-config"
    # (docs/bugs/autorag-ogx-3.5-cascade.md issue 2). The patch helpers re-apply the ConfigMap, which can
    # drop labels, so label it after them.
    oc label configmap llama-stack-config -n "$NAMESPACE" ogx.io/watch=true --overwrite >/dev/null 2>&1 || \
        print_warning "Could not label llama-stack-config with ogx.io/watch=true"

    # Apply OGXServer CR (uses overrideConfig, not baseConfig)
    # The manifest references llama-stack-config via overrideConfig which
    # completely bypasses the operator's config generation.
    print_info "OGX deploying (takes 1-2 minutes)..."

    envsubst < "$SCRIPT_DIR/manifests/ogxserver.yaml" | oc apply -f -

    # Wait for OGX pod to start
    sleep 5
    oc rollout status deployment/autorag-ogx -n "$NAMESPACE" --timeout=180s 2>/dev/null || \
        print_warning "OGX not ready yet -- check: oc get pods -l app.kubernetes.io/instance=autorag-ogx -n $NAMESPACE"

    LLAMASTACK_URL="http://autorag-ogx-service.${NAMESPACE}.svc.cluster.local:8321"

    # --- Step 6b: Create OGX connection secret for AutoRAG ---
    # AutoRAG's pipeline reads OGX_CLIENT_BASE_URL and OGX_CLIENT_API_KEY from
    # the secret specified as ogx_secret_name. Create it automatically so the
    # user can skip the manual "Add connection" step in the dashboard.
    if ! oc get secret autorag-ogx-connection -n "$NAMESPACE" &>/dev/null; then
        print_step "Creating OGX connection secret..."
        export NAMESPACE LLAMASTACK_URL
        envsubst '${NAMESPACE} ${LLAMASTACK_URL}' < "$SCRIPT_DIR/manifests/ogx-connection-secret.yaml.tmpl" | oc apply -f -
        print_success "OGX connection 'autorag-ogx-connection' created"
    else
        print_info "OGX connection secret already exists [SKIP]"
    fi
else
    envsubst < "$SCRIPT_DIR/manifests/llamastack.yaml" | oc apply -f -
    print_info "LlamaStack deploying (takes 1-2 minutes)..."

    # Wait briefly for LlamaStack pod to start
    sleep 5
    oc rollout status deployment/autorag-llamastack -n "$NAMESPACE" --timeout=180s 2>/dev/null || \
        print_warning "LlamaStack not ready yet -- check: oc get pods -l app.kubernetes.io/name=autorag-llamastack -n $NAMESPACE"

    LLAMASTACK_URL="http://autorag-llamastack-service.${NAMESPACE}.svc.cluster.local:8321"
fi

echo ""
print_success "AutoRAG Demo infrastructure deployed"
print_info "Namespace: $NAMESPACE"
print_info "Milvus endpoint: $MILVUS_ENDPOINT"
if [ -n "${DIRECT_MODEL_NAME:-}" ]; then
    print_info "LLM (direct vLLM): $DIRECT_MODEL_NAME → $VLLM_URL"
fi
if [ -n "${EMBEDDING_ISVC:-}" ]; then
    print_info "Embedding: $EMBEDDING_ISVC → $VLLM_EMBEDDING_URL"
fi
if [ "$USE_OGX" = true ]; then
    print_info "OGX: $LLAMASTACK_URL"
else
    print_info "LlamaStack: $LLAMASTACK_URL"
fi
echo ""
echo "  Remaining manual steps:"
echo ""
if [ "$USE_OGX" = true ]; then
    echo "  1. CREATE OGX CONNECTION IN PROJECT:"
    echo "     - Dashboard > $NAMESPACE > Connections"
    echo "     - Add connection: Llama Stack / OGX (naming may vary by dashboard build)"
else
    echo "  1. CREATE LLAMA STACK CONNECTION IN PROJECT:"
    echo "     - Dashboard > $NAMESPACE > Connections"
    echo "     - Add connection: Llama Stack"
fi
echo "       Base URL: $LLAMASTACK_URL"
echo "       API Key: (leave empty or use any value)"
echo ""
echo "  2. RUN AUTORAG:"
echo "     - Dashboard > Develop and train > AutoRAG"
echo "     - Click 'Create run'"
echo "     - S3 Connection: 'AutoRAG Documents'"
if [ "$USE_OGX" = true ]; then
    echo "     - Llama Stack / OGX Connection: (created in step 1)"
else
    echo "     - Llama Stack Connection: (created in step 1)"
fi
echo "     - Select optimization metric (e.g. Answer correctness)"
echo "     - Upload test data: sample-data/test-data.json"
echo "     - Click 'Create run'"
echo ""
echo "  3. EVALUATE AND USE:"
echo "     - Review RAG patterns on the leaderboard"
echo "     - Save indexing and inference notebooks"
echo "     - Run notebooks in a workbench"
echo ""
echo "  Sample data provided:"
echo "    Documents: sample-data/docs/ (uploaded to s3://autorag-docs/)"
echo "    Test data: sample-data/test-data.json (upload via dashboard)"
echo ""
