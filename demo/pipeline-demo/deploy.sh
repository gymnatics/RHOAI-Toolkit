#!/bin/bash
################################################################################
# Deploy AI Pipeline Demo
################################################################################
# Sets up infrastructure for AI Pipelines: MinIO, DSPA, Model Registry.
# Provides KFP SDK + Elyra notebook pipelines as files.
#
# Workbench: Create via RHOAI dashboard, then upload/clone notebooks.
#
# Usage:
#   ./deploy.sh                    # Deploy to pipeline-demo namespace
#   ./deploy.sh -n my-namespace    # Custom namespace
#   ./deploy.sh --delete           # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"

NAMESPACE="${1:-pipeline-demo}"
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

print_header "AI Pipeline Demo"

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing pipeline demo from $NAMESPACE..."
    oc delete datasciencepipelineapplication pipelines-definition -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    print_success "Pipeline demo removed"
    exit 0
fi

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

ensure_namespace "$NAMESPACE"
oc label namespace "$NAMESPACE" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true

# --- Step 1: MinIO for pipeline artifacts ---
print_step "Setting up MinIO for pipeline artifacts..."
if oc get deployment minio -n "$NAMESPACE" &>/dev/null; then
    print_info "MinIO already deployed in $NAMESPACE"
else
    if [ -f "$ROOT_DIR/lib/manifests/storage/minio.yaml" ]; then
        export NAMESPACE
        envsubst < "$ROOT_DIR/lib/manifests/storage/minio.yaml" | oc apply -f - 2>/dev/null || \
            print_warning "MinIO manifest not found -- pipeline artifacts may need manual S3 config"
    else
        print_warning "MinIO manifest not found -- set up storage manually"
    fi
fi

# --- Step 2: Pipeline Server (DSPA) ---
if [ -f "$ROOT_DIR/lib/functions/rhoai.sh" ]; then
    source "$ROOT_DIR/lib/functions/rhoai.sh" 2>/dev/null || true
fi

if type setup_pipeline_server &>/dev/null; then
    print_step "Setting up Pipeline Server via toolkit function..."
    setup_pipeline_server "$NAMESPACE"
else
    print_step "Pipeline Server..."
    if oc get crd datasciencepipelinesapplications.datasciencepipelinesapplications.opendatahub.io &>/dev/null 2>&1; then
        print_info "DSPA CRD available. Create pipeline server from RHOAI dashboard > Data Science Pipelines."
    else
        print_info "DSPA CRD not found. Ensure 'aipipelines' is enabled in your DataScienceCluster."
    fi
fi

# --- Step 3: Model Registry ---
print_step "Model Registry..."
if type setup_model_registry &>/dev/null; then
    setup_model_registry 2>/dev/null || true
else
    print_info "Model Registry can be set up via RHOAI dashboard."
fi

# --- Step 4: Create Elyra runtime config ---
print_step "Creating Elyra runtime configuration..."

ELYRA_TEMPLATE="$SCRIPT_DIR/manifests/elyra-runtime-config.json.template"
ELYRA_SETUP="$SCRIPT_DIR/manifests/setup-elyra-runtime.sh"

if [ -f "$ELYRA_TEMPLATE" ] && [ -f "$ELYRA_SETUP" ]; then
    oc create configmap elyra-runtime-config \
        --from-file="template=${ELYRA_TEMPLATE}" \
        --from-file="setup.sh=${ELYRA_SETUP}" \
        -n "$NAMESPACE" --dry-run=client -o yaml | oc apply -f - 2>/dev/null

    WB_SA=$(oc get pods -n "$NAMESPACE" -l app=ai-pipelines -o jsonpath='{.items[0].spec.serviceAccountName}' 2>/dev/null)
    WB_SA="${WB_SA:-$(oc get sa -n "$NAMESPACE" -o jsonpath='{.items[?(@.metadata.name!="builder")].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -v '^default$\|^deployer$\|^pipeline' | head -1)}"
    if [ -n "$WB_SA" ]; then
        oc create rolebinding "${WB_SA}-view" \
            --clusterrole=view \
            --serviceaccount="${NAMESPACE}:${WB_SA}" \
            -n "$NAMESPACE" 2>/dev/null || true
    fi

    print_success "Elyra runtime template + setup script stored in ConfigMap 'elyra-runtime-config'"
    print_info "In workbench terminal, run:"
    echo "    bash <(oc get cm elyra-runtime-config -o jsonpath='{.data.setup\\.sh}')"
else
    print_warning "Elyra manifests not found at $SCRIPT_DIR/manifests/ -- create runtime manually"
fi

# --- Step 5: Compile KFP pipeline if SDK is available ---
print_step "KFP pipeline..."
if command -v python3 &>/dev/null && python3 -c "import kfp" 2>/dev/null; then
    (cd "$SCRIPT_DIR" && python3 pipeline-kfp.py)
    print_success "Pipeline compiled to loan-pipeline.yaml"
    print_info "Upload via: RHOAI Dashboard > Pipelines > Import"
else
    print_info "KFP SDK not installed locally. Compile inside the workbench:"
    echo "    pip install kfp"
    echo "    python pipeline-kfp.py"
fi

echo ""
print_success "AI Pipeline Demo infrastructure ready"
print_info "Namespace: $NAMESPACE"
echo ""
echo "  Next steps:"
echo "  1. Create a workbench in RHOAI dashboard for namespace: $NAMESPACE"
echo "  2. In the workbench terminal, clone and navigate:"
echo "     git clone https://github.com/gymnatics/RHOAI-Toolkit.git"
echo "     cd RHOAI-Toolkit/demo/pipeline-demo"
echo ""
echo "  Included pipelines:"
echo ""
echo "  KFP SDK pipeline:"
echo "     pipeline-kfp.py"
echo "     - data_prep -> train -> evaluate -> register"
echo "     - Compile: python pipeline-kfp.py"
echo "     - Upload YAML to RHOAI dashboard Pipelines"
echo ""
echo "  Elyra notebook pipeline (pipeline-elyra/):"
echo "     01-data-prep.ipynb -> 02-train.ipynb -> 03-evaluate.ipynb -> 04-register.ipynb"
echo "     Setup runtime (run once in workbench terminal):"
echo "       bash <(oc get cm elyra-runtime-config -o jsonpath='{.data.setup\\.sh}')"
echo ""
echo "  Sample data: data/sample-loans.csv"
echo ""
