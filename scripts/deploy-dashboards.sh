#!/bin/bash
################################################################################
# Deploy Observability Dashboards
#
# Supports two methods:
#   1. OpenShift native Observe tab (ConfigMap in openshift-config-managed)
#   2. Standalone Grafana (via Grafana Operator with dashboard CRs)
#
# @name: Deploy Observability Dashboards
# @category: observability
# @params: --method native|grafana (default: native), --dashboard all|dcgm|vllm|vllm-advanced, --delete
# @prerequisites: cluster-admin access; for Grafana method: Grafana Operator installed
# @description: Deploy GPU and vLLM monitoring dashboards to OpenShift
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
}
source "$ROOT_DIR/lib/utils/common.sh" 2>/dev/null || true

DASHBOARD_DIR="$ROOT_DIR/lib/manifests/dashboards"
NAMESPACE="openshift-config-managed"
METHOD="native"
DASHBOARD="all"
DELETE=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy monitoring dashboards to OpenShift"
    echo ""
    echo "Options:"
    echo "  --method native|grafana   Deployment method (default: native)"
    echo "                            native  = OpenShift Observe tab (ConfigMap)"
    echo "                            grafana = Standalone Grafana instance"
    echo "  --dashboard NAME          Which dashboard to deploy (default: all)"
    echo "                            all, dcgm, vllm, vllm-advanced"
    echo "  --delete                  Remove dashboards instead of deploying"
    echo "  -h, --help                Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                              # Deploy all dashboards to Observe tab"
    echo "  $0 --dashboard vllm             # Deploy only vLLM dashboard"
    echo "  $0 --method grafana             # Deploy via standalone Grafana"
    echo "  $0 --delete                     # Remove all dashboards"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --method) METHOD="$2"; shift 2 ;;
        --dashboard) DASHBOARD="$2"; shift 2 ;;
        --delete) DELETE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

DASHBOARD_NAMES="dcgm vllm vllm-advanced"

_dashboard_file() {
    case "$1" in
        dcgm) echo "dcgm-exporter-dashboard.json" ;;
        vllm) echo "vllm-performance-ocp.json" ;;
        vllm-advanced) echo "vllm-advanced-ocp.json" ;;
    esac
}

_dashboard_cm() {
    case "$1" in
        dcgm) echo "nvidia-dcgm-exporter-dashboard" ;;
        vllm) echo "vllm-performance-dashboard" ;;
        vllm-advanced) echo "vllm-advanced-dashboard" ;;
    esac
}

_dashboard_display() {
    case "$1" in
        dcgm) echo "NVIDIA DCGM Exporter Dashboard" ;;
        vllm) echo "vLLM Performance Dashboard" ;;
        vllm-advanced) echo "vLLM Advanced Dashboard" ;;
    esac
}

deploy_native() {
    local file="$1"
    local cm_name="$2"
    local display_name="$3"

    if [ ! -f "$DASHBOARD_DIR/$file" ]; then
        print_error "Dashboard file not found: $DASHBOARD_DIR/$file"
        return 1
    fi

    print_step "Deploying '$display_name' to Observe tab..."

    if oc get configmap "$cm_name" -n "$NAMESPACE" &>/dev/null; then
        print_info "ConfigMap '$cm_name' already exists, replacing..."
        oc delete configmap "$cm_name" -n "$NAMESPACE" 2>/dev/null || true
    fi

    oc create configmap "$cm_name" \
        -n "$NAMESPACE" \
        --from-file="$DASHBOARD_DIR/$file"

    oc label configmap "$cm_name" \
        -n "$NAMESPACE" \
        "console.openshift.io/dashboard=true" --overwrite

    oc label configmap "$cm_name" \
        -n "$NAMESPACE" \
        "console.openshift.io/odc-dashboard=true" --overwrite

    print_success "$display_name deployed -> Observe > Dashboards"
}

delete_native() {
    local cm_name="$2"
    local display_name="$3"

    if oc get configmap "$cm_name" -n "$NAMESPACE" &>/dev/null; then
        oc delete configmap "$cm_name" -n "$NAMESPACE"
        print_success "Removed '$display_name'"
    else
        print_info "'$display_name' not found (already removed)"
    fi
}

deploy_grafana() {
    local file="$1"
    local cm_name="$2"
    local display_name="$3"

    if ! oc get crd grafanadashboards.grafana.integreatly.org &>/dev/null 2>&1; then
        print_error "Grafana Operator not installed. Install from OperatorHub first."
        print_info "Or use: $0 --method native (no Grafana needed)"
        return 1
    fi

    local grafana_ns
    grafana_ns=$(oc get grafana -A --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    if [ -z "$grafana_ns" ]; then
        print_error "No Grafana instance found. Create one first via the Grafana Operator."
        return 1
    fi

    print_step "Deploying '$display_name' to Grafana in namespace '$grafana_ns'..."

    if [ ! -f "$DASHBOARD_DIR/$file" ]; then
        print_error "Dashboard file not found: $DASHBOARD_DIR/$file"
        return 1
    fi

    oc create configmap "$cm_name" \
        -n "$grafana_ns" \
        --from-file="$DASHBOARD_DIR/$file" \
        --dry-run=client -o yaml | oc apply -f -

    cat <<EOF | oc apply -f -
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: $cm_name
  namespace: $grafana_ns
spec:
  instanceSelector:
    matchLabels:
      dashboards: grafana
  configMapRef:
    name: $cm_name
    key: $file
EOF

    print_success "$display_name deployed to Grafana"
}

process_dashboard() {
    local key="$1"
    local file=$(_dashboard_file "$key")
    local cm_name=$(_dashboard_cm "$key")
    local display_name=$(_dashboard_display "$key")

    if [ -z "$file" ]; then
        print_error "Unknown dashboard: $key"
        return 1
    fi

    if [ "$DELETE" = true ]; then
        delete_native "$file" "$cm_name" "$display_name"
    elif [ "$METHOD" = "native" ]; then
        deploy_native "$file" "$cm_name" "$display_name"
    elif [ "$METHOD" = "grafana" ]; then
        deploy_grafana "$file" "$cm_name" "$display_name"
    else
        print_error "Unknown method: $METHOD (use 'native' or 'grafana')"
        exit 1
    fi
}

# Verify cluster access
if ! oc whoami &>/dev/null; then
    print_error "Not logged into OpenShift. Run 'oc login' first."
    exit 1
fi

print_header "Deploy Observability Dashboards"
if [ "$DELETE" = true ]; then
    print_info "Mode: DELETE"
else
    print_info "Method: $METHOD"
fi
print_info "Dashboard: $DASHBOARD"
echo ""

if [ "$DASHBOARD" = "all" ]; then
    for key in $DASHBOARD_NAMES; do
        process_dashboard "$key"
    done
else
    if [ -z "$(_dashboard_file "$DASHBOARD")" ]; then
        print_error "Unknown dashboard: $DASHBOARD"
        echo "Available: all, dcgm, vllm, vllm-advanced"
        exit 1
    fi
    process_dashboard "$DASHBOARD"
fi

echo ""
if [ "$DELETE" != true ]; then
    print_success "Done! View dashboards at: Observe > Dashboards in the OpenShift Console"
    if [ "$METHOD" = "native" ]; then
        echo ""
        print_info "Installed dashboards:"
        oc -n "$NAMESPACE" get cm -l "console.openshift.io/dashboard=true" --no-headers 2>/dev/null | awk '{print "  - " $1}'
    fi
fi
