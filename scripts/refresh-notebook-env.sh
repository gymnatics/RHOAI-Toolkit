#!/bin/bash
################################################################################
# refresh-notebook-env.sh — Re-detect model endpoints and update workbench env
################################################################################
# Run this after deploying new models (e.g. sklearn classifier trained in notebook)
# to refresh the notebook-env ConfigMap and restart workbenches.
#
# Usage:
#   ./scripts/refresh-notebook-env.sh <namespace>          # Single namespace
#   ./scripts/refresh-notebook-env.sh --all                # All demo namespaces
#   ./scripts/refresh-notebook-env.sh --list               # Show current state
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/functions/notebook-env.sh"

DEMO_NAMESPACES=(
    "lmeval-demo"
    "financial-loan-demo"
    "pipeline-demo"
    "maas-ratelimit-demo"
    "feast-demo"
    "a-rh-dept"
)

usage() {
    echo "Usage: $0 <namespace> | --all | --list"
    echo ""
    echo "  <namespace>   Refresh env for a specific demo namespace"
    echo "  --all         Refresh all demo namespaces that exist on the cluster"
    echo "  --list        Show current notebook-env ConfigMap values for all namespaces"
    exit 0
}

list_current() {
    print_header "Current notebook-env ConfigMaps"
    for ns in "${DEMO_NAMESPACES[@]}"; do
        if oc get namespace "$ns" &>/dev/null 2>&1; then
            local data
            data=$(oc get configmap notebook-env -n "$ns" -o jsonpath='{.data}' 2>/dev/null || true)
            if [ -n "$data" ]; then
                echo ""
                print_info "Namespace: $ns"
                echo "$data" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in sorted(d.keys()):
    print(f'    {k}={d[k]}')
" 2>/dev/null || echo "    (could not parse)"
            else
                echo ""
                print_warning "Namespace: $ns — no notebook-env ConfigMap"
            fi
        fi
    done
}

refresh_namespace() {
    local ns="$1"

    if ! oc get namespace "$ns" &>/dev/null 2>&1; then
        print_warning "Namespace $ns does not exist — skipping"
        return 0
    fi

    print_step "Refreshing notebook-env for $ns..."

    # Reset detection state
    LLM_MODEL_NAME=""
    LLM_MODEL_NS=""
    LLM_BASE_URL=""
    SKLEARN_MODEL_NAME=""
    SKLEARN_MODEL_NS=""
    SKLEARN_API_URL=""

    # Detect endpoints
    detect_llm_endpoint || true
    detect_predictive_endpoint "$ns" || true

    # Build extra args based on namespace-specific needs
    local extra_args=()

    # Check for MinIO in this namespace
    if oc get svc minio -n "$ns" &>/dev/null 2>&1; then
        extra_args+=("S3_ENDPOINT=http://minio.${ns}.svc:9000")
        extra_args+=("AWS_ACCESS_KEY_ID=minio")
        extra_args+=("AWS_SECRET_ACCESS_KEY=minio123")
    fi

    # Check for MaaS gateway
    local cluster_domain
    cluster_domain=$(oc get ingress.config.openshift.io cluster \
        -o jsonpath='{.spec.domain}' 2>/dev/null || true)
    if [ -n "$cluster_domain" ]; then
        local maas_endpoint="https://maas.apps.${cluster_domain##*.apps.}"
        # Only add if inference-gateway exists
        if oc get route inference-gateway -n istio-system &>/dev/null 2>&1 || \
           oc get route inference-gateway -n knative-serving &>/dev/null 2>&1; then
            extra_args+=("MAAS_ENDPOINT=https://inference-gateway.${cluster_domain}")
        fi
    fi

    # Inject
    inject_notebook_env "$ns" "${extra_args[@]}"

    # Report what was detected
    if [ -n "$LLM_MODEL_NAME" ]; then
        print_success "LLM: $LLM_MODEL_NAME (ns: $LLM_MODEL_NS)"
    else
        print_warning "No LLM model detected"
    fi
    if [ -n "$SKLEARN_MODEL_NAME" ]; then
        print_success "Predictive: $SKLEARN_MODEL_NAME (ns: $SKLEARN_MODEL_NS)"
    fi

    # Restart workbenches to pick up changes
    local notebooks
    notebooks=$(oc get notebooks.kubeflow.org -n "$ns" --no-headers \
        -o custom-columns='NAME:.metadata.name' 2>/dev/null || true)
    for nb in $notebooks; do
        [ -z "$nb" ] && continue
        # Trigger restart by annotating the pod template
        oc patch notebook "$nb" -n "$ns" --type=merge \
            -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"notebook-env/refreshed\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}}}}" \
            2>/dev/null || true
        print_info "Restarted workbench: $nb"
    done
}

# --- Main ---
case "${1:-}" in
    -h|--help) usage ;;
    --list) list_current ;;
    --all)
        print_header "Refreshing all demo namespaces"
        for ns in "${DEMO_NAMESPACES[@]}"; do
            refresh_namespace "$ns"
        done
        echo ""
        print_success "Done. All demo namespaces refreshed."
        ;;
    "")
        usage
        ;;
    *)
        refresh_namespace "$1"
        echo ""
        print_success "Done. Namespace $1 refreshed."
        ;;
esac
