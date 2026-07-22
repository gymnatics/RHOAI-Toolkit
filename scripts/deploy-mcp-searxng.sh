#!/bin/bash
################################################################################
# Deploy SearXNG MCP Server on OpenShift
#
# Two deployment modes:
#   1) Direct (Route)   — OpenShift Route for external access
#                          No MaaS/Gateway dependency. Simple, always works.
#   2) MaaS Gateway     — Route through MaaS gateway (RHCL/Authorino auth)
#                          Requires RHCL + MaaS gateway to be installed.
#
# Each mode cleans up the other's resources first, so re-running is safe.
#
# Usage:
#   ./deploy-mcp-searxng.sh              # Interactive prompt
#   ./deploy-mcp-searxng.sh --direct     # Direct (Route) mode
#   ./deploy-mcp-searxng.sh --gateway    # MaaS Gateway mode
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m'
}

print_step()    { echo -e "${CYAN}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error()   { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info()    { echo -e "${BLUE}ℹ $1${NC}"; }

MCP_NS="mcp-servers"

################################################################################
# Cluster domain detection
################################################################################

_mcp_get_cluster_domain() {
    if [ -z "$CLUSTER_DOMAIN" ]; then
        CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster \
            -o jsonpath='{.spec.domain}' 2>/dev/null | sed 's/^apps\.//')
        if [ -z "$CLUSTER_DOMAIN" ]; then
            print_error "Could not detect cluster domain"
            exit 1
        fi
    fi
    export CLUSTER_DOMAIN
}

################################################################################
# Shared helpers
################################################################################

_mcp_ensure_namespace() {
    if ! oc get namespace "$MCP_NS" &>/dev/null 2>&1; then
        oc create namespace "$MCP_NS"
        print_info "Created namespace $MCP_NS"
    fi
    oc label namespace "$MCP_NS" \
        opendatahub.io/dashboard=true \
        app.kubernetes.io/part-of=rhoai-toolkit --overwrite 2>/dev/null || true
    oc annotate namespace "$MCP_NS" \
        openshift.io/display-name="MCP Servers" --overwrite 2>/dev/null || true
}

_mcp_deploy_searxng_pod() {
    oc apply -f "$ROOT_DIR/lib/manifests/mcp/searxng.yaml"
    oc wait --for=condition=ready pod -l app=mcp-searxng -n "$MCP_NS" --timeout=120s 2>/dev/null \
        && print_success "SearXNG MCP server is running" \
        || print_warning "SearXNG pod not ready yet (may still be pulling image)"
}

_mcp_register_configmap() {
    local mcp_url="$1"
    local dashboard_ns="redhat-ods-applications"

    local aa_namespaces
    aa_namespaces=$(oc get ns -l opendatahub.io/dashboard=true \
        -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    aa_namespaces="${aa_namespaces} ${dashboard_ns}"
    aa_namespaces=$(echo "$aa_namespaces" | tr ' ' '\n' | sort -u | tr '\n' ' ')

    for aa_ns in $aa_namespaces; do
        [ -z "$aa_ns" ] && continue
        oc apply -f - <<EOF &>/dev/null
kind: ConfigMap
apiVersion: v1
metadata:
  name: gen-ai-aa-mcp-servers
  namespace: ${aa_ns}
  labels:
    app.kubernetes.io/managed-by: rhoai-toolkit
    opendatahub.io/dashboard: "true"
data:
  SearXNG: |
    {
      "name": "searxng",
      "displayName": "SearXNG - Web Search",
      "description": "Web search for real-time information retrieval",
      "url": "${mcp_url}",
      "transport": "streamable-http",
      "category": "search"
    }
EOF
    done
    print_success "gen-ai-aa-mcp-servers ConfigMap registered (URL: $mcp_url)"
}

################################################################################
# Cleanup helpers — remove the OTHER mode's resources before deploying
################################################################################

_mcp_cleanup_direct_resources() {
    print_step "Cleaning up Direct (Route) mode resources..."
    oc delete route mcp-searxng -n "$MCP_NS" 2>/dev/null \
        && print_info "  Removed Route mcp-searxng" || true
}

_mcp_cleanup_gateway_resources() {
    print_step "Cleaning up MaaS Gateway mode resources..."
    oc delete httproute mcp-searxng -n "$MCP_NS" 2>/dev/null \
        && print_info "  Removed HTTPRoute mcp-searxng" || true
    oc delete referencegrant mcp-gateway-ref -n "$MCP_NS" 2>/dev/null \
        && print_info "  Removed ReferenceGrant mcp-gateway-ref" || true
}

################################################################################
# Mode 1: Direct (Route)
################################################################################

deploy_mcp_direct() {
    print_step "Deploying SearXNG MCP server (Direct / Route mode)..."

    _mcp_ensure_namespace
    _mcp_cleanup_gateway_resources

    _mcp_deploy_searxng_pod

    local route_host
    route_host=$(oc get route mcp-searxng -n "$MCP_NS" \
        -o jsonpath='{.spec.host}' 2>/dev/null || true)
    if [ -z "$route_host" ]; then
        print_warning "Route not found in manifest — creating edge-terminated Route..."
        oc create route edge mcp-searxng \
            --service=mcp-searxng --port=8000 \
            -n "$MCP_NS" 2>/dev/null || true
        route_host=$(oc get route mcp-searxng -n "$MCP_NS" \
            -o jsonpath='{.spec.host}' 2>/dev/null || true)
    fi

    local mcp_url="https://${route_host}/mcp"
    _mcp_register_configmap "$mcp_url"

    print_success "SearXNG MCP deployed (Direct mode)"
    print_info "External endpoint: $mcp_url"
}

################################################################################
# Mode 2: MaaS Gateway
################################################################################

deploy_mcp_via_gateway() {
    print_step "Deploying SearXNG MCP server (MaaS Gateway mode)..."

    _mcp_get_cluster_domain
    local mcp_host="mcp.apps.${CLUSTER_DOMAIN}"

    _mcp_ensure_namespace
    _mcp_cleanup_direct_resources

    _mcp_deploy_searxng_pod
    oc delete route mcp-searxng -n "$MCP_NS" 2>/dev/null || true

    # Add MCP listener to maas-default-gateway if not present
    local has_mcp_listener
    has_mcp_listener=$(oc get gateway maas-default-gateway -n openshift-ingress \
        -o jsonpath='{.spec.listeners[?(@.name=="mcp")].name}' 2>/dev/null || true)

    if [ -z "$has_mcp_listener" ]; then
        print_step "Adding 'mcp' listener to maas-default-gateway..."
        local cert_name
        cert_name=$(oc get gateway maas-default-gateway -n openshift-ingress \
            -o jsonpath='{.spec.listeners[0].tls.certificateRefs[0].name}' \
            2>/dev/null || echo "default-gateway-tls")
        oc patch gateway maas-default-gateway -n openshift-ingress --type=json -p "[{
          \"op\": \"add\",
          \"path\": \"/spec/listeners/-\",
          \"value\": {
            \"name\": \"mcp\",
            \"hostname\": \"${mcp_host}\",
            \"port\": 443,
            \"protocol\": \"HTTPS\",
            \"allowedRoutes\": {\"namespaces\": {\"from\": \"All\"}},
            \"tls\": {\"mode\": \"Terminate\", \"certificateRefs\": [{\"name\": \"${cert_name}\"}]}
          }
        }]" 2>/dev/null
        print_success "MCP listener added to gateway"
    else
        print_info "MCP listener already exists on maas-default-gateway"
    fi

    # ReferenceGrant
    oc apply -f - <<EOF &>/dev/null
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: mcp-gateway-ref
  namespace: ${MCP_NS}
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: ${MCP_NS}
  to:
    - group: ""
      kind: Service
EOF
    print_info "ReferenceGrant created"

    # HTTPRoute
    oc apply -f - <<EOF &>/dev/null
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: mcp-searxng
  namespace: ${MCP_NS}
spec:
  parentRefs:
    - name: maas-default-gateway
      namespace: openshift-ingress
      sectionName: mcp
  hostnames:
    - "${mcp_host}"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /mcp
      backendRefs:
        - name: mcp-searxng
          port: 8000
EOF
    print_success "HTTPRoute mcp-searxng created"

    # Passthrough route
    if ! oc get route mcp-passthrough -n openshift-ingress &>/dev/null; then
        oc apply -f - <<EOF &>/dev/null
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: mcp-passthrough
  namespace: openshift-ingress
spec:
  host: ${mcp_host}
  to:
    kind: Service
    name: maas-default-gateway-openshift-gateway
  port:
    targetPort: https
  tls:
    termination: passthrough
EOF
        print_info "Passthrough route created for $mcp_host"
    fi

    local mcp_url="https://${mcp_host}/mcp"
    _mcp_register_configmap "$mcp_url"

    print_success "SearXNG MCP deployed (MaaS Gateway mode)"
    print_info "External endpoint: $mcp_url"
}

################################################################################
# Interactive prompt — choose deployment mode
################################################################################

deploy_mcp_searxng() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              MCP Server Deployment (SearXNG)                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Choose how to expose the SearXNG MCP server:"
    echo ""
    echo -e "  ${GREEN}1)${NC} Direct (Route)    — Simple OpenShift Route (no MaaS dependency)"
    echo -e "                         Works immediately, no RHCL/Gateway needed"
    echo ""
    echo -e "  ${GREEN}2)${NC} MaaS Gateway      — Route through MaaS gateway with RHCL auth"
    echo -e "                         Requires RHCL + MaaS gateway to be installed"
    echo ""

    local mcp_choice=""
    local default_choice="1"
    local skip_rhcl="${SKIP_RHCL:-false}"
    local skip_maas="${SKIP_MAAS:-false}"

    if [ "$skip_rhcl" = true ] || [ "$skip_maas" = true ]; then
        default_choice="1"
        print_info "RHCL/MaaS is skipped — defaulting to Direct (Route) mode"
    elif oc get gateway maas-default-gateway -n openshift-ingress &>/dev/null 2>&1; then
        default_choice="2"
    fi

    while true; do
        read -p "Select MCP deployment mode (1-2) [default: $default_choice]: " mcp_choice
        mcp_choice=$(echo "$mcp_choice" | tr -d '[:space:]')
        [ -z "$mcp_choice" ] && mcp_choice="$default_choice"
        case "$mcp_choice" in
            1) deploy_mcp_direct; break ;;
            2)
                if [ "$skip_rhcl" = true ] || [ "$skip_maas" = true ]; then
                    print_error "MaaS Gateway mode requires RHCL and MaaS (remove --skip-rhcl / --skip-maas)"
                    continue
                fi
                if ! oc get gateway maas-default-gateway -n openshift-ingress &>/dev/null 2>&1; then
                    print_error "maas-default-gateway not found — install RHCL/MaaS first or choose option 1"
                    continue
                fi
                deploy_mcp_via_gateway
                break
                ;;
            *) print_warning "Invalid choice. Enter 1 or 2." ;;
        esac
    done
    echo ""
}

################################################################################
# Standalone execution
################################################################################

_main() {
    if ! command -v oc &>/dev/null; then
        print_error "oc CLI not found"
        exit 1
    fi
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift. Run 'oc login' first."
        exit 1
    fi

    local mode=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --direct)   mode="direct"; shift ;;
            --gateway)  mode="gateway"; shift ;;
            -h|--help)
                echo "Usage: $(basename "$0") [--direct|--gateway]"
                echo ""
                echo "  --direct    Deploy with OpenShift Route (no MaaS dependency)"
                echo "  --gateway   Deploy through MaaS gateway (requires RHCL)"
                echo "  (no args)   Interactive prompt"
                exit 0
                ;;
            *) print_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    case "$mode" in
        direct)  deploy_mcp_direct ;;
        gateway) deploy_mcp_via_gateway ;;
        *)       deploy_mcp_searxng ;;
    esac
}

# Run _main only when executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _main "$@"
fi
