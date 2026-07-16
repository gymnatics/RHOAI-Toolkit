#!/bin/bash
################################################################################
# Deploy MCP Servers on OpenShift
#
# Deploys MCP server infrastructure including:
#   - MCP Gateway controller and extension
#   - Context7, Codebase Search, Repo Docs, Code Sandbox, SearXNG servers
#   - OCP MCP Server (Red Hat OpenShift MCP)
#   - HTTPRoutes and MCPServerRegistrations
#   - Gateway listener patch for MCP endpoint
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFESTS_DIR="$ROOT_DIR/lib/manifests/mcp"

# Source utilities if available
if [ -f "$ROOT_DIR/lib/utils/colors.sh" ]; then
    source "$ROOT_DIR/lib/utils/colors.sh"
fi
if [ -f "$ROOT_DIR/lib/utils/common.sh" ]; then
    source "$ROOT_DIR/lib/utils/common.sh"
fi

# Fallback print functions if colors.sh not loaded
if ! type print_header &>/dev/null; then
    print_header()  { echo ""; echo "=== $1 ==="; echo ""; }
    print_step()    { echo "▶ $1"; }
    print_success() { echo "✓ $1"; }
    print_error()   { echo "✗ $1"; }
    print_warning() { echo "⚠ $1"; }
    print_info()    { echo "ℹ $1"; }
fi

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Deploy MCP servers on OpenShift"
    echo ""
    echo "Options:"
    echo "  --skip-gateway    Skip MCP Gateway controller deployment"
    echo "  --skip-listener   Skip Gateway MCP listener patch"
    echo "  --servers-only    Only deploy MCP server workloads (no gateway/routes)"
    echo "  --routes-only     Only deploy HTTPRoutes and MCPServerRegistrations"
    echo "  -h, --help        Show this help message"
}

SKIP_GATEWAY=false
SKIP_LISTENER=false
SERVERS_ONLY=false
ROUTES_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-gateway)  SKIP_GATEWAY=true; shift ;;
        --skip-listener) SKIP_LISTENER=true; shift ;;
        --servers-only)  SERVERS_ONLY=true; shift ;;
        --routes-only)   ROUTES_ONLY=true; shift ;;
        -h|--help)       usage; exit 0 ;;
        *) print_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Verify oc is available
if ! command -v oc &>/dev/null; then
    print_error "oc CLI not found. Please install the OpenShift CLI."
    exit 1
fi

# Verify cluster connectivity
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Please run 'oc login' first."
    exit 1
fi

# Detect cluster domain
print_step "Detecting cluster domain..."
CLUSTER_DOMAIN=$(oc get ingress.config cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
if [ -z "$CLUSTER_DOMAIN" ]; then
    print_error "Could not detect cluster domain from ingress.config"
    exit 1
fi
export CLUSTER_DOMAIN
print_success "Cluster domain: $CLUSTER_DOMAIN"

apply_with_envsubst() {
    local file="$1"
    local description="${2:-$(basename "$file")}"

    if [ ! -f "$file" ]; then
        print_error "Manifest not found: $file"
        return 1
    fi

    print_step "Applying $description..."
    if envsubst < "$file" | oc apply -f -; then
        print_success "$description applied"
    else
        print_error "Failed to apply $description"
        return 1
    fi
}

wait_for_deployment() {
    local name="$1"
    local namespace="$2"
    local timeout="${3:-300}"

    print_step "Waiting for $name in $namespace (timeout: ${timeout}s)..."
    if oc rollout status deployment/"$name" -n "$namespace" --timeout="${timeout}s" 2>/dev/null; then
        print_success "$name is ready"
    else
        print_warning "$name did not become ready within ${timeout}s"
        return 1
    fi
}

# ============================================================
print_header "MCP Server Deployment"
# ============================================================

print_info "Cluster: $(oc whoami --show-server 2>/dev/null || echo 'unknown')"
print_info "Domain:  $CLUSTER_DOMAIN"
print_info "MCP URL: https://mcp.$CLUSTER_DOMAIN/mcp"
echo ""

# --- Step 1: Namespaces ---
if [ "$ROUTES_ONLY" != "true" ]; then
    print_header "Step 1: Creating Namespaces"
    apply_with_envsubst "$MANIFESTS_DIR/namespace.yaml" "namespaces"
fi

# --- Step 2: MCP Gateway ---
if [ "$SERVERS_ONLY" != "true" ] && [ "$ROUTES_ONLY" != "true" ] && [ "$SKIP_GATEWAY" != "true" ]; then
    print_header "Step 2: Deploying MCP Gateway"

    # 2a: Install CRDs (required before controller can start)
    MCP_GATEWAY_VERSION="${MCP_GATEWAY_VERSION:-0.7.1}"
    if oc get crd mcpgatewayextensions.mcp.kuadrant.io &>/dev/null; then
        print_info "MCP Gateway CRDs already installed"
    else
        print_step "Installing MCP Gateway CRDs (v${MCP_GATEWAY_VERSION})..."
        if oc apply -k "https://github.com/kuadrant/mcp-gateway/config/crd?ref=v${MCP_GATEWAY_VERSION}"; then
            print_success "MCP Gateway CRDs installed"
        else
            print_warning "Failed to install MCP Gateway CRDs - skipping MCP Gateway"
        fi
    fi

    # 2b: Deploy controller (ServiceAccount, RBAC, Deployment)
    apply_with_envsubst "$MANIFESTS_DIR/mcp-gateway.yaml" "MCP Gateway controller"

    # 2c: Wait for controller to be ready
    print_step "Waiting for MCP Gateway controller to be ready..."
    oc rollout status deployment/mcp-gateway-controller -n mcp-gateway-system --timeout=120s 2>/dev/null || true

    # 2d: Apply the MCPGatewayExtension CR
    if oc get crd mcpgatewayextensions.mcp.kuadrant.io &>/dev/null; then
        apply_with_envsubst "$MANIFESTS_DIR/mcp-gateway-extension.yaml" "MCP Gateway extension"
    else
        print_warning "MCPGatewayExtension CRD not available - skipping extension"
    fi
fi

# --- Step 3: Gateway Listener Patch ---
if [ "$SERVERS_ONLY" != "true" ] && [ "$ROUTES_ONLY" != "true" ] && [ "$SKIP_LISTENER" != "true" ]; then
    print_header "Step 3: Patching Gateway with MCP Listener"

    existing_listeners=$(oc get gateway maas-default-gateway -n openshift-ingress -o jsonpath='{.spec.listeners[*].name}' 2>/dev/null || echo "")
    if echo "$existing_listeners" | grep -q "mcp"; then
        print_info "MCP listener already exists on maas-default-gateway — skipping patch"
    else
        print_step "Adding MCP listener to maas-default-gateway..."
        MCP_LISTENER=$(envsubst <<'PATCH_EOF'
[{
  "op": "add",
  "path": "/spec/listeners/-",
  "value": {
    "name": "mcp",
    "hostname": "mcp.${CLUSTER_DOMAIN}",
    "port": 443,
    "protocol": "HTTPS",
    "allowedRoutes": { "namespaces": { "from": "All" } },
    "tls": {
      "mode": "Terminate",
      "certificateRefs": [{ "group": "", "kind": "Secret", "name": "apps-wildcard-tls" }]
    }
  }
}]
PATCH_EOF
)
        if oc patch gateway maas-default-gateway -n openshift-ingress --type=json -p "$MCP_LISTENER"; then
            print_success "MCP listener added to gateway"
        else
            print_warning "Failed to patch gateway — you may need to apply gateway-mcp-listener.yaml manually"
        fi
    fi
fi

# --- Step 4: Deploy MCP Servers ---
if [ "$ROUTES_ONLY" != "true" ]; then
    print_header "Step 4: Deploying MCP Servers"

    MCP_SERVERS=("context7" "code-sandbox" "searxng" "ocp-mcp-server")
    BUILD_SERVERS=("codebase-search" "repo-docs")

    for server in "${MCP_SERVERS[@]}"; do
        apply_with_envsubst "$MANIFESTS_DIR/${server}.yaml" "$server"
    done

    for server in "${BUILD_SERVERS[@]}"; do
        if [ -f "$MANIFESTS_DIR/${server}.yaml" ]; then
            print_info "$server uses a BuildConfig-based image — deploying manifest"
            apply_with_envsubst "$MANIFESTS_DIR/${server}.yaml" "$server"
        fi
    done
fi

# --- Step 5: HTTPRoutes & Registrations ---
if [ "$SERVERS_ONLY" != "true" ]; then
    print_header "Step 5: Deploying HTTPRoutes & MCPServerRegistrations"
    apply_with_envsubst "$MANIFESTS_DIR/httproutes.yaml" "HTTPRoutes + MCPServerRegistrations"
fi

# --- Step 6: Wait for Deployments ---
if [ "$ROUTES_ONLY" != "true" ]; then
    print_header "Step 6: Waiting for Deployments"

    DEPLOY_TIMEOUT=300
    failed=0

    if [ "$SKIP_GATEWAY" != "true" ] && [ "$SERVERS_ONLY" != "true" ]; then
        wait_for_deployment "mcp-gateway-controller" "mcp-gateway-system" "$DEPLOY_TIMEOUT" || ((failed++))
    fi

    all_servers=("mcp-context7" "mcp-code-sandbox" "mcp-searxng" "ocp-mcp-server" "mcp-codebase-search" "mcp-repo-docs")
    for deploy in "${all_servers[@]}"; do
        wait_for_deployment "$deploy" "mcp-servers" "$DEPLOY_TIMEOUT" || ((failed++))
    done

    if [ "$failed" -gt 0 ]; then
        print_warning "$failed deployment(s) did not become ready"
    fi
fi

# --- Summary ---
print_header "Deployment Summary"

echo ""
print_info "MCP Servers (mcp-servers namespace):"
oc get deployment -n mcp-servers -o wide 2>/dev/null || true
echo ""

if [ "$SKIP_GATEWAY" != "true" ] && [ "$SERVERS_ONLY" != "true" ]; then
    print_info "MCP Gateway (mcp-gateway-system namespace):"
    oc get deployment -n mcp-gateway-system -o wide 2>/dev/null || true
    echo ""
fi

print_info "MCPServerRegistrations:"
oc get mcpserverregistration -n mcp-servers 2>/dev/null || true
echo ""

print_info "HTTPRoutes:"
oc get httproute -n mcp-servers 2>/dev/null || true
echo ""

print_success "MCP endpoint: https://mcp.${CLUSTER_DOMAIN}/mcp"
print_info "To test: curl -sk https://mcp.${CLUSTER_DOMAIN}/mcp -H 'Accept: application/json'"
echo ""
