#!/bin/bash
# OpenShift Lightspeed + MCP Troubleshooting Demo
# Deploys a broken app and configures Lightspeed to troubleshoot and fix it
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$REPO_ROOT/lib/utils/colors.sh" 2>/dev/null || true

DEMO_NAMESPACE="${DEMO_NAMESPACE:-lightspeed-demo}"
MCP_SERVER_NAMESPACE="${MCP_SERVER_NAMESPACE:-0-test}"
MCP_SERVER_NAME="${MCP_SERVER_NAME:-oc-mcp-server}"

echo_info() { echo -e "${BLUE:-}[INFO]${NC:-} $*"; }
echo_success() { echo -e "${GREEN:-}[OK]${NC:-} $*"; }
echo_warn() { echo -e "${YELLOW:-}[WARN]${NC:-} $*"; }
echo_error() { echo -e "${RED:-}[ERROR]${NC:-} $*"; }

print_banner() {
    echo ""
    echo "=============================================="
    echo "  OpenShift Lightspeed Troubleshooting Demo"
    echo "=============================================="
    echo ""
}

check_prerequisites() {
    echo_info "Checking prerequisites..."

    if ! oc whoami &>/dev/null; then
        echo_error "Not logged into OpenShift. Please run 'oc login' first."
        exit 1
    fi

    if ! oc get csv -n openshift-lightspeed 2>/dev/null | grep -q lightspeed-operator; then
        echo_error "OpenShift Lightspeed operator not found. Install it first."
        exit 1
    fi

    if ! oc get olsconfig cluster &>/dev/null; then
        echo_warn "No OLSConfig found. Will create one."
    fi

    echo_success "Prerequisites met"
}

detect_model() {
    echo_info "Detecting available model for Lightspeed..."

    local isvc_name isvc_ns isvc_url
    isvc_name=$(oc get inferenceservice --all-namespaces -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    isvc_ns=$(oc get inferenceservice --all-namespaces -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null || true)

    if [[ -z "$isvc_name" ]]; then
        echo_error "No InferenceService found. Deploy a model first."
        exit 1
    fi

    isvc_url=$(oc get inferenceservice "$isvc_name" -n "$isvc_ns" -o jsonpath='{.status.url}' 2>/dev/null)

    # Query model name from vLLM /v1/models endpoint
    local model_id
    model_id=$(curl -sk "${isvc_url}/v1/models" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['data'][0]['id'])" 2>/dev/null || echo "$isvc_name")

    export OLS_MODEL_NAME="$model_id"
    export OLS_MODEL_URL="${isvc_url}/v1"
    export OLS_PROVIDER_NAME="${isvc_name}"
    export OLS_CREDENTIALS_SECRET="ols-model-credentials"

    echo_success "Using model: $OLS_MODEL_NAME ($OLS_MODEL_URL)"
}

setup_namespace() {
    echo_info "Setting up demo namespace: $DEMO_NAMESPACE"
    oc new-project "$DEMO_NAMESPACE" 2>/dev/null || oc project "$DEMO_NAMESPACE" 2>/dev/null
    echo_success "Namespace ready"
}

setup_credentials() {
    echo_info "Creating credentials secret for Lightspeed..."

    local auth_enabled
    auth_enabled=$(oc get inferenceservice "$OLS_PROVIDER_NAME" --all-namespaces -o jsonpath='{.items[0].metadata.annotations.security\.opendatahub\.io/enable-auth}' 2>/dev/null || echo "false")

    if [[ "$auth_enabled" == "false" ]]; then
        oc create secret generic "$OLS_CREDENTIALS_SECRET" \
            -n openshift-lightspeed \
            --from-literal=apitoken=no-auth-required \
            --dry-run=client -o yaml | oc apply -f -
        echo_success "Credentials secret created (auth disabled on model)"
    else
        echo_warn "Model has auth enabled. You may need to manually create the secret."
        echo_warn "  oc create secret generic $OLS_CREDENTIALS_SECRET -n openshift-lightspeed --from-literal=apitoken=<your-token>"
    fi
}

configure_mcp_server() {
    echo_info "Configuring MCP server for write operations..."

    if ! oc get deployment "$MCP_SERVER_NAME" -n "$MCP_SERVER_NAMESPACE" &>/dev/null; then
        echo_warn "MCP server '$MCP_SERVER_NAME' not found in namespace '$MCP_SERVER_NAMESPACE'"
        echo_warn "Skipping custom MCP server configuration. Built-in MCP will be used (read-only)."
        export MCP_SERVER_ENABLED=false
        return
    fi

    export MCP_SERVER_NAMESPACE MCP_SERVER_NAME
    envsubst < "$SCRIPT_DIR/manifests/mcp-server-config.yaml" | oc apply -f -

    oc rollout restart deployment/"$MCP_SERVER_NAME" -n "$MCP_SERVER_NAMESPACE"
    oc rollout status deployment/"$MCP_SERVER_NAME" -n "$MCP_SERVER_NAMESPACE" --timeout=120s

    export MCP_SERVER_ENABLED=true
    echo_success "MCP server configured with write access"
}

deploy_olsconfig() {
    echo_info "Deploying OLSConfig..."

    export MCP_SERVER_NAMESPACE MCP_SERVER_NAME
    if [[ "${MCP_SERVER_ENABLED:-false}" == "true" ]]; then
        envsubst < "$SCRIPT_DIR/manifests/olsconfig.yaml" | oc apply -f -
    else
        # Deploy without custom MCP server
        envsubst < "$SCRIPT_DIR/manifests/olsconfig.yaml" | \
            python3 -c "
import yaml, sys
config = yaml.safe_load(sys.stdin)
del config['spec']['mcpServers']
del config['spec']['featureGates']
yaml.dump(config, sys.stdout, default_flow_style=False)
" | oc apply -f -
    fi

    echo_info "Waiting for Lightspeed to become ready..."
    local retries=0
    while [[ $retries -lt 30 ]]; do
        local status
        status=$(oc get olsconfig cluster -o jsonpath='{.status.overallStatus}' 2>/dev/null || echo "")
        if [[ "$status" == "Ready" ]]; then
            echo_success "Lightspeed is Ready"
            return
        fi
        sleep 10
        retries=$((retries + 1))
    done
    echo_warn "Lightspeed not ready after 5 minutes. Check: oc get olsconfig cluster -o yaml"
}

deploy_broken_app() {
    echo_info "Deploying broken application (with intentional image typo)..."
    oc apply -f "$SCRIPT_DIR/manifests/broken-app.yaml"

    sleep 10
    echo ""
    echo_warn "=== BROKEN DEPLOYMENT STATUS ==="
    oc get pods -n "$DEMO_NAMESPACE"
    echo ""
    oc get events -n "$DEMO_NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null | grep -i "failed\|error\|backoff" | tail -5
    echo ""
    echo_success "Broken app deployed. Pods should be in ImagePullBackOff."
}

print_demo_instructions() {
    local console_url
    console_url=$(oc get route console -n openshift-console -o jsonpath='{.spec.host}' 2>/dev/null || echo "console-openshift-console.apps.<cluster>")

    echo ""
    echo "=============================================="
    echo "  DEMO READY"
    echo "=============================================="
    echo ""
    echo "  Console:   https://$console_url"
    echo "  Namespace: $DEMO_NAMESPACE"
    echo "  Model:     $OLS_MODEL_NAME"
    echo ""
    echo "  --- Demo Flow ---"
    echo ""
    echo "  1. Open the OpenShift Console"
    echo "  2. Navigate to Workloads > Deployments in '$DEMO_NAMESPACE'"
    echo "  3. Observe the failing 'customer-portal' deployment"
    echo "  4. Click the Lightspeed spark icon (top-right)"
    echo "  5. Ask: 'What is wrong with the customer-portal deployment"
    echo "     in lightspeed-demo? The pods are not starting.'"
    echo "  6. Lightspeed uses MCP tools to inspect pods/events"
    echo "  7. It identifies the image typo (nginxx → nginx)"
    echo "  8. Ask: 'Fix the image name for me'"
    echo "  9. Lightspeed proposes a fix → you approve it"
    echo " 10. Pods start running"
    echo ""
    echo "  --- Suggested Prompts ---"
    echo ""
    echo "  • 'Why are my pods failing in lightspeed-demo?'"
    echo "  • 'Check events for customer-portal pods'"
    echo "  • 'The image has a typo, fix it to hello-world-nginx'"
    echo ""
    echo "  --- Manual Fix (if needed) ---"
    echo ""
    echo "  oc set image deployment/customer-portal \\"
    echo "    web=quay.io/redhattraining/hello-world-nginx:latest \\"
    echo "    -n $DEMO_NAMESPACE"
    echo ""
    echo "=============================================="
}

cleanup() {
    echo_info "Cleaning up demo resources..."
    oc delete project "$DEMO_NAMESPACE" --ignore-not-found
    oc delete olsconfig cluster --ignore-not-found
    oc delete secret "$OLS_CREDENTIALS_SECRET" -n openshift-lightspeed --ignore-not-found 2>/dev/null
    echo_success "Cleanup complete"
}

# --- Main ---
print_banner

case "${1:-deploy}" in
    deploy)
        check_prerequisites
        detect_model
        setup_namespace
        setup_credentials
        configure_mcp_server
        deploy_olsconfig
        deploy_broken_app
        print_demo_instructions
        ;;
    broken-app)
        setup_namespace
        deploy_broken_app
        ;;
    fix)
        echo_info "Applying the fix manually..."
        oc apply -f "$SCRIPT_DIR/manifests/fixed-app.yaml"
        sleep 5
        oc get pods -n "$DEMO_NAMESPACE"
        echo_success "Fixed app deployed"
        ;;
    cleanup)
        cleanup
        ;;
    *)
        echo "Usage: $0 {deploy|broken-app|fix|cleanup}"
        echo ""
        echo "  deploy     - Full setup (Lightspeed + MCP + broken app)"
        echo "  broken-app - Deploy only the broken app (assumes Lightspeed is configured)"
        echo "  fix        - Apply the fix manually"
        echo "  cleanup    - Remove all demo resources"
        exit 1
        ;;
esac
