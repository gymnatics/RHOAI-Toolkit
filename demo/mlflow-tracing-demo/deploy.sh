#!/bin/bash
################################################################################
# Deploy MLflow Tracing Demo (Banking Multi-Agent)
################################################################################
# Banking credit risk assessment with MLflow 3.x distributed tracing.
# Multi-agent A2A system: Orchestrator, Customer Analyst, Risk Assessor,
# Compliance Reviewer — all traced end-to-end via RHOAI MLflow.
#
# Requires:
#   - RHOAI 3.4 with MLflow operator enabled
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

print_info "Prerequisites: RHOAI 3.4 + MLflow operator + a vLLM model endpoint"
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

echo ""
print_success "MLflow Tracing Demo deployment complete"
print_info "Repo: $REPO_PATH"
print_info "Dashboard: https://$(oc get route banking-dashboard -n mlflow-tracing-demo -o jsonpath='{.status.ingress[0].host}' 2>/dev/null || echo '<pending>')"
print_info "MLflow UI: $(oc get route -n redhat-ods-applications -l app=mlflow -o jsonpath='{.items[0].status.ingress[0].host}' 2>/dev/null || echo 'check RHOAI dashboard')"
