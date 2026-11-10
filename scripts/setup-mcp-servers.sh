#!/bin/bash
################################################################################
# Setup MCP Servers for RHOAI GenAI Playground / AI Asset Endpoints
################################################################################
# Deploys MCP servers and registers them as MCPServer CRs so they appear in
# the RHOAI Dashboard → AI Asset Endpoints → MCP Servers tab.
#
# RHOAI 3.5+: Uses MCPServer CRDs (mcp.x-k8s.io/v1alpha1) managed by the
#   MCP Lifecycle Operator. The operator provisions Deployments, Services,
#   NetworkPolicies, and cluster-internal URLs automatically.
#
# Prerequisites created by this script in the target namespace:
#   - openshift-mcp-server-config ConfigMap (config.toml for the server)
#   - mcp-viewer ServiceAccount + cluster-reader ClusterRoleBinding
#   - opendatahub.io/dashboard=true namespace label
#
# Usage:
#   ./setup-mcp-servers.sh                  # Interactive (default ns: ai-tenants)
#   ./setup-mcp-servers.sh -n my-project    # Specific namespace
#   ./setup-mcp-servers.sh --non-interactive # Deploy OpenShift MCP with defaults
#   ./setup-mcp-servers.sh --delete         # Remove MCP servers
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST_DIR="$ROOT_DIR/lib/manifests"

source "$ROOT_DIR/lib/utils/colors.sh"

NAMESPACE="ai-tenants"
DELETE_MODE=false
NON_INTERACTIVE=false
READ_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --delete) DELETE_MODE=true; shift ;;
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        --read-only) READ_ONLY=true; shift ;;
        -h|--help)
            echo "Usage: $0 [-n namespace] [--non-interactive] [--read-only] [--delete]"
            exit 0
            ;;
        *) shift ;;
    esac
done

print_header "Setup MCP Servers"

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift cluster"
    exit 1
fi

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing MCP servers from $NAMESPACE..."
    oc delete mcpserver --all -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete configmap openshift-mcp-server-config -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    oc delete sa mcp-viewer -n "$NAMESPACE" --ignore-not-found 2>/dev/null
    print_success "MCP servers removed from $NAMESPACE"
    exit 0
fi

# Check MCP Lifecycle Operator is available
if ! oc get crd mcpservers.mcp.x-k8s.io &>/dev/null; then
    print_error "MCPServer CRD not found. Ensure mcplifecycleoperator is Managed in your DSC (requires OpenShift 4.22+, Technology Preview)."
    print_info "  oc patch dsc default-dsc --type=merge -p '{\"spec\":{\"components\":{\"mcplifecycleoperator\":{\"managementState\":\"Managed\"}}}}'"
    exit 1
fi
print_success "MCP Lifecycle Operator available"

# Ensure namespace exists with dashboard label
oc get ns "$NAMESPACE" &>/dev/null || oc create ns "$NAMESPACE"
oc label ns "$NAMESPACE" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true

# Create prerequisites in the namespace
print_step "Creating prerequisites in $NAMESPACE..."

# ServiceAccount + RBAC (the MCP server needs cluster-reader to query resources)
oc create sa mcp-viewer -n "$NAMESPACE" 2>/dev/null || true
oc create clusterrolebinding "mcp-viewer-${NAMESPACE}" \
    --clusterrole=cluster-reader \
    --serviceaccount="${NAMESPACE}:mcp-viewer" 2>/dev/null || true

# Config file for the OpenShift MCP server
READ_ONLY_STR="false"
[ "$READ_ONLY" = true ] && READ_ONLY_STR="true"
oc create configmap openshift-mcp-server-config \
    --from-literal=config.toml="read_only = ${READ_ONLY_STR}" \
    -n "$NAMESPACE" --dry-run=client -o yaml | oc apply -f - 2>/dev/null

print_success "Prerequisites created"

# Deploy OpenShift MCP Server via MCPServer CR
deploy_openshift_mcp() {
    local image="registry.redhat.io/openshift-mcp-tech-preview/openshift-mcp-server-rhel9:0.4"

    print_step "Deploying OpenShift MCP Server..."

    cat <<EOF | oc apply -f -
apiVersion: mcp.x-k8s.io/v1alpha1
kind: MCPServer
metadata:
  name: oc-mcp-server
  namespace: ${NAMESPACE}
  labels:
    opendatahub.io/dashboard: "true"
spec:
  source:
    type: ContainerImage
    containerImage:
      ref: ${image}
  config:
    port: 8080
    path: /mcp
    arguments:
      - "--config"
      - "/etc/mcp-config/config.toml"
      - "--port"
      - "8080"
      - "--toolsets"
      - "core,config,openshift,observability"
    storage:
      - name: config
        mountPath: /etc/mcp-config
        volumeSource:
          configMap:
            name: openshift-mcp-server-config
EOF

    # Wait for pod
    print_info "Waiting for MCP server pod..."
    local elapsed=0
    while [ $elapsed -lt 90 ]; do
        if oc get pods -n "$NAMESPACE" -l app.kubernetes.io/name=oc-mcp-server --no-headers 2>/dev/null | grep -q Running; then
            print_success "OpenShift MCP Server running"
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done

    if [ $elapsed -ge 90 ]; then
        print_warning "MCP server not ready yet — check: oc get mcpserver -n $NAMESPACE"
    fi

    # Register in the dashboard's gen-ai-aa-mcp-servers ConfigMap.
    # The AI Asset Endpoints → MCP Servers tab reads from this ConfigMap
    # (NOT from MCPServer CRs). Both are needed: CR for the operator to
    # deploy the pod, ConfigMap for the dashboard to list it.
    local mcp_url="http://oc-mcp-server.${NAMESPACE}.svc.cluster.local:8080/mcp"
    print_step "Registering in dashboard ConfigMap (gen-ai-aa-mcp-servers)..."
    local existing
    existing=$(oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o json 2>/dev/null || echo '{"data":{}}')
    echo "$existing" | python3 -c "
import json, sys
cm = json.load(sys.stdin)
if 'data' not in cm:
    cm = {'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':'gen-ai-aa-mcp-servers','namespace':'redhat-ods-applications'},'data':{}}
cm['data']['OpenShift-MCP-Server'] = json.dumps({
    'url': '${mcp_url}',
    'description': 'OpenShift cluster operations — list, get, create, update, delete any resource. Pod logs, exec, events, Helm, observability.'
}, indent=2)
json.dump(cm, sys.stdout)
" | oc apply -f - 2>/dev/null
    print_success "Registered in AI Asset Endpoints"
}

if [ "$NON_INTERACTIVE" = true ]; then
    deploy_openshift_mcp
else
    echo ""
    echo "Available MCP servers:"
    echo "  1) OpenShift Cluster MCP Server (core, config, openshift, observability toolsets)"
    echo "  2) Custom MCP Server (bring your own image)"
    echo ""
    read -p "Which MCP server to deploy? (1/2, default: 1): " choice
    choice="${choice:-1}"

    case "$choice" in
        1)
            deploy_openshift_mcp
            ;;
        2)
            read -p "Enter container image: " custom_image
            read -p "Enter server name: " custom_name
            read -p "Enter port (default 8080): " custom_port
            custom_port="${custom_port:-8080}"

            cat <<EOF | oc apply -f -
apiVersion: mcp.x-k8s.io/v1alpha1
kind: MCPServer
metadata:
  name: ${custom_name}
  namespace: ${NAMESPACE}
  labels:
    opendatahub.io/dashboard: "true"
spec:
  source:
    type: ContainerImage
    containerImage:
      ref: ${custom_image}
  config:
    port: ${custom_port}
EOF
            print_success "Custom MCP Server '${custom_name}' created"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
fi

echo ""
print_success "MCP Server setup complete"
echo ""
echo "  MCPServer CR:"
oc get mcpserver -n "$NAMESPACE" 2>/dev/null | sed 's/^/    /'
echo ""
echo "  View in RHOAI Dashboard:"
echo "    1. Go to AI Hub → AI Asset Endpoints"
echo "    2. Select project: $NAMESPACE"
echo "    3. Click 'MCP Servers' tab"
echo ""
echo "  Use in Playground:"
echo "    1. Go to Gen AI Studio → Playground"
echo "    2. Select project: $NAMESPACE"
echo "    3. Click 'MCP' tab in Settings panel"
echo "    4. Enable the MCP server"
echo ""
