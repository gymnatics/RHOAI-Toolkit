#!/bin/bash
################################################################################
# Deploy MLflow Tracing Demo (Banking Multi-Agent)
################################################################################
# Banking credit risk assessment with MLflow 3.x distributed tracing.
# Multi-agent A2A system: Orchestrator, Customer Analyst, Risk Assessor,
# Compliance Reviewer — all traced end-to-end via RHOAI MLflow.
#
# Requires:
#   - RHOAI 3.4+ with MLflow operator enabled
#   - A vLLM model endpoint (Qwen3-8B or similar with tool-calling)
#   - 1x GPU for the LLM (already deployed via MaaS or InferenceService)
#
# Usage:
#   ./deploy.sh                    # Interactive deployment
#   ./deploy.sh --build-only       # Rebuild container images only
#   ./deploy.sh --apply-only       # Reapply k8s manifests only
#   ./deploy.sh --delete           # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/functions/external-repos.sh"
source "$ROOT_DIR/lib/functions/notebook-env.sh"

DEMO_NAMESPACE="mlflow-tracing-demo"

DELETE_MODE=false
BUILD_ONLY=false
APPLY_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --delete|--teardown) DELETE_MODE=true; shift ;;
        --build-only) BUILD_ONLY=true; shift ;;
        --apply-only) APPLY_ONLY=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--delete] [--build-only] [--apply-only]"
            echo ""
            echo "Deploys a banking multi-agent system with MLflow 3.x tracing:"
            echo "  - Orchestrator (LangGraph + A2A)"
            echo "  - Customer Analyst (MongoDB MCP)"
            echo "  - Risk Assessor (LLM-powered)"
            echo "  - Compliance Reviewer (LLM-powered)"
            echo "  - Streamlit Dashboard"
            echo "  - MongoDB + seed data"
            echo ""
            echo "Options:"
            echo "  --build-only   Rebuild container images only"
            echo "  --apply-only   Reapply k8s manifests only"
            echo "  --delete       Remove everything (namespace + images)"
            exit 0
            ;;
        *) shift ;;
    esac
done

print_header "MLflow Tracing Demo (Banking Multi-Agent)"

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

clone_or_update_repo "mlflow-agent-observability"
REPO_PATH=$(get_repo_path "mlflow-agent-observability")

if [ "$DELETE_MODE" = true ]; then
    print_step "Running teardown from MLflow Tracing Demo repo..."
    if [ -f "$REPO_PATH/deploy.sh" ]; then
        (cd "$REPO_PATH" && bash deploy.sh --teardown)
    else
        print_warning "deploy.sh not found in repo; deleting namespace directly"
        oc delete project mlflow-tracing-demo --ignore-not-found 2>/dev/null || true
    fi
    print_success "MLflow Tracing Demo cleaned up"
    exit 0
fi

# Check MLflow operator is enabled
MLFLOW_STATE=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.mlflowoperator.managementState}' 2>/dev/null || echo "unknown")
if [ "$MLFLOW_STATE" != "Managed" ]; then
    print_warning "MLflow operator is not enabled (state: $MLFLOW_STATE)"
    print_info "Enable it: oc patch datasciencecluster default-dsc --type=merge -p '{\"spec\":{\"components\":{\"mlflowoperator\":{\"managementState\":\"Managed\"}}}}'"
    echo ""
    read -rp "Continue anyway? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

print_info "Prerequisites: RHOAI 3.4+, MLflow operator, and a vLLM model endpoint"
print_info "The demo will create namespace 'mlflow-tracing-demo'"
echo ""

DEPLOY_ARGS=""
if [ "$BUILD_ONLY" = true ]; then
    DEPLOY_ARGS="--build-only"
elif [ "$APPLY_ONLY" = true ]; then
    DEPLOY_ARGS="--apply-only"
fi

print_step "Launching MLflow Tracing Demo deploy.sh..."
echo ""

(cd "$REPO_PATH" && bash deploy.sh $DEPLOY_ARGS)

# ----------------------------------------------------------------------------
# Cluster-specific config fix
#
# The upstream repo (~/.rhoai-demos/mlflow-agent-observability, cloned by
# clone_or_update_repo above) ships k8s/base/configmap.yaml and frontend.yaml
# with MLFLOW_TRACKING_URI / OPENAI_BASE_URL / MLFLOW_UI_URL hardcoded to its
# original author's own dev cluster. Its deploy.sh does a plain `oc apply -k`
# with zero patching, so on any other cluster the 4 agent pods hang forever
# inside ensure_mlflow_initialized() -> mlflow.set_experiment() trying to
# reach a dead host, never bind port 8003, and get SIGKILLed by the liveness
# probe in an infinite CrashLoopBackOff with no log output (the hang happens
# before any log line is emitted). Patch the ConfigMap + frontend Deployment
# to point at THIS cluster's real MLflow route and a real vLLM endpoint, then
# restart the agents so they pick it up.
# ----------------------------------------------------------------------------
if [ "$BUILD_ONLY" != true ] && oc get configmap banking-tracing-demo-config -n "$DEMO_NAMESPACE" &>/dev/null; then
    echo ""
    print_step "Detecting this cluster's MLflow route + a direct vLLM endpoint..."

    MLFLOW_URL=$(oc get mlflow mlflow -o jsonpath='{.status.url}' 2>/dev/null || true)
    if [ -z "$MLFLOW_URL" ]; then
        print_warning "Could not detect MLflow route (mlflow/mlflow CR not found/ready) -- leaving MLFLOW_TRACKING_URI as-is"
    fi

    detect_direct_llm_endpoint "$DEMO_NAMESPACE" || true
    if [ -z "${DIRECT_MODEL_NAME:-}" ] || [ -z "${DIRECT_BASE_URL:-}" ]; then
        print_warning "Could not detect a direct vLLM endpoint -- leaving OPENAI_BASE_URL/LLM_MODEL as-is"
    else
        # The OpenAI API "model" field vLLM expects is the served model name
        # (spec.model.name on LLMInferenceService), which is often different
        # from the k8s resource name (DIRECT_MODEL_NAME) -- e.g. resource
        # "qwen3-8b" serves model "RedHatAI/Qwen3-8B-FP8-dynamic".
        SERVED_MODEL_NAME=$(oc get llminferenceservice "$DIRECT_MODEL_NAME" -n "$DIRECT_MODEL_NS" \
            -o jsonpath='{.spec.model.name}' 2>/dev/null || true)
        SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-$DIRECT_MODEL_NAME}"

        # DIRECT_BASE_URL for an LLMInferenceService is an in-cluster
        # kserve-workload-svc URL whose serving cert is signed by the
        # cluster's internal service-ca -- not in the pod's public CA trust
        # store. The upstream openai client has no TLS-skip knob (unlike the
        # mlflow client's own MLFLOW_TRACKING_INSECURE_TLS), so LLM calls
        # fail with "SSL: CERTIFICATE_VERIFY_FAILED". OPENAI_INSECURE_TLS is
        # read by the patched shared/mlflow_bootstrap.py mounted below.
        OPENAI_INSECURE_TLS="false"
        if echo "$DIRECT_BASE_URL" | grep -q "^https://.*\.svc:"; then
            OPENAI_INSECURE_TLS="true"
        fi

        print_step "Patching banking-tracing-demo-config: OPENAI_BASE_URL=$DIRECT_BASE_URL LLM_MODEL=$SERVED_MODEL_NAME${MLFLOW_URL:+ MLFLOW_TRACKING_URI=$MLFLOW_URL} OPENAI_INSECURE_TLS=$OPENAI_INSECURE_TLS"
        PATCH_JSON=$(jq -n \
            --arg base "$DIRECT_BASE_URL" \
            --arg model "$SERVED_MODEL_NAME" \
            --arg mlflow "$MLFLOW_URL" \
            --arg insecure "$OPENAI_INSECURE_TLS" \
            '{data: ({OPENAI_BASE_URL: $base, LLM_MODEL: $model, OPENAI_INSECURE_TLS: $insecure} + (if $mlflow != "" then {MLFLOW_TRACKING_URI: $mlflow} else {} end))}')
        oc patch configmap banking-tracing-demo-config -n "$DEMO_NAMESPACE" --type=merge -p "$PATCH_JSON"

        if [ -n "$MLFLOW_URL" ]; then
            oc set env deployment/banking-dashboard -n "$DEMO_NAMESPACE" "MLFLOW_UI_URL=$MLFLOW_URL" &>/dev/null || true
        fi

        # Runtime patch overlay for shared/mlflow_bootstrap.py's
        # get_openai_client() -- see patches/mlflow_bootstrap.py and its
        # module docstring for the full rationale. Mounted via subPath over
        # the file the upstream Dockerfile bakes into the image, so no image
        # rebuild is needed and this survives re-running this wrapper script.
        # Only the 4 services that actually call get_openai_client() need it.
        print_step "Applying LLM-client TLS patch overlay (openai client has no built-in insecure-TLS option)..."
        oc create configmap mlflow-bootstrap-tls-patch -n "$DEMO_NAMESPACE" \
            --from-file="mlflow_bootstrap.py=$SCRIPT_DIR/patches/mlflow_bootstrap.py" \
            --dry-run=client -o yaml | oc apply -f - &>/dev/null
        for dep in orchestrator risk-assessor compliance-reviewer banking-dashboard; do
            oc set volume "deployment/$dep" -n "$DEMO_NAMESPACE" --add --overwrite \
                --name=mlflow-bootstrap-tls-patch --type=configmap \
                --configmap-name=mlflow-bootstrap-tls-patch \
                --mount-path=/opt/app-root/src/shared/mlflow_bootstrap.py \
                --sub-path=mlflow_bootstrap.py &>/dev/null || true
        done

        # Second, unrelated upstream bug: requirements.txt pins
        # `fastmcp>=3.0.0,<4`, but `fastmcp.telemetry.suppress_fastmcp_telemetry`
        # (used by customer-analyst's MCP call path) was removed/renamed within
        # that same 3.x line -- fails with ImportError on fastmcp 3.4.7+. Patch
        # overlay makes the import optional. See
        # patches/customer_analyst_agent.py for the full rationale.
        oc create configmap customer-analyst-fastmcp-patch -n "$DEMO_NAMESPACE" \
            --from-file="agent.py=$SCRIPT_DIR/patches/customer_analyst_agent.py" \
            --dry-run=client -o yaml | oc apply -f - &>/dev/null
        oc set volume deployment/customer-analyst -n "$DEMO_NAMESPACE" --add --overwrite \
            --name=customer-analyst-fastmcp-patch --type=configmap \
            --configmap-name=customer-analyst-fastmcp-patch \
            --mount-path=/opt/app-root/src/agent.py \
            --sub-path=agent.py &>/dev/null || true

        # mongodb-mcp also calls ensure_mlflow_initialized() at import time
        # (shared/mlflow_bootstrap.py) but envFrom is only re-read on pod
        # (re)start, so it must be restarted too even though it doesn't need
        # either patch overlay above.
        print_step "Restarting agents to pick up the corrected endpoint config + TLS patch..."
        for dep in compliance-reviewer customer-analyst orchestrator risk-assessor mongodb-mcp; do
            oc rollout restart "deployment/$dep" -n "$DEMO_NAMESPACE" &>/dev/null || true
        done
        for dep in compliance-reviewer customer-analyst orchestrator risk-assessor mongodb-mcp banking-dashboard; do
            echo -n "  $dep: "
            oc rollout status "deployment/$dep" -n "$DEMO_NAMESPACE" --timeout=180s 2>/dev/null && echo "" || print_warning "$dep did not stabilize within timeout -- check logs"
        done
    fi
fi

echo ""
print_success "MLflow Tracing Demo deployment complete"
print_info "Repo: $REPO_PATH"
print_info "Dashboard: https://$(oc get route banking-dashboard -n mlflow-tracing-demo -o jsonpath='{.status.ingress[0].host}' 2>/dev/null || echo '<pending>')"
print_info "MLflow UI: $(oc get route -n redhat-ods-applications -l app=mlflow -o jsonpath='{.items[0].status.ingress[0].host}' 2>/dev/null || echo 'check RHOAI dashboard')"
