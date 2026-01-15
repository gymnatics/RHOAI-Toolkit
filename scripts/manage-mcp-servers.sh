#!/bin/bash
################################################################################
# MCP Server Management Script
################################################################################
# Manages MCP servers for LlamaStack and OpenShift AI:
# 1. Deploy MCP server pods
# 2. Register in AI Asset endpoints (gen-ai-aa-mcp-servers ConfigMap)
# 3. Register in LlamaStack config (llama-stack-config ConfigMap)
#
# Usage:
#   ./scripts/manage-mcp-servers.sh                    # Interactive menu
#   ./scripts/manage-mcp-servers.sh deploy kubernetes  # Deploy Kubernetes MCP
#   ./scripts/manage-mcp-servers.sh register weather   # Register Weather MCP
#   ./scripts/manage-mcp-servers.sh status             # Show status
#   ./scripts/manage-mcp-servers.sh tools              # List available tools
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MANIFEST_DIR="$PROJECT_DIR/lib/manifests"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() { echo -e "${YELLOW}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

# Check login
check_login() {
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        echo "Please login first: oc login <cluster-url>"
        exit 1
    fi
}

# Get current namespace
get_namespace() {
    local ns="${NAMESPACE:-$(oc project -q 2>/dev/null)}"
    echo "$ns"
}

################################################################################
# AI Asset Endpoint Registration
################################################################################

# Register MCP server in AI Asset endpoints (gen-ai-aa-mcp-servers ConfigMap)
register_ai_asset_endpoint() {
    local mcp_name="$1"
    local mcp_url="$2"
    local description="$3"
    local transport="${4:-streamable-http}"
    
    print_step "Registering '$mcp_name' in AI Asset endpoints..."
    
    # Get existing ConfigMap or create new
    local existing_data=""
    if oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications &>/dev/null; then
        existing_data=$(oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o json | jq -r '.data // {}')
    fi
    
    # Create the new entry
    local entry_key=$(echo "$mcp_name" | sed 's/ /-/g')
    local entry_value=$(cat <<EOF
{
  "url": "$mcp_url",
  "description": "$description",
  "transport": "$transport"
}
EOF
)
    
    # Merge with existing data
    if [ -n "$existing_data" ] && [ "$existing_data" != "{}" ]; then
        # Add to existing ConfigMap
        local new_data=$(echo "$existing_data" | jq --arg key "$entry_key" --arg val "$entry_value" '. + {($key): $val}')
        
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gen-ai-aa-mcp-servers
  namespace: redhat-ods-applications
  labels:
    app.kubernetes.io/part-of: rhoai-mcp-servers
data:
$(echo "$new_data" | jq -r 'to_entries | .[] | "  \(.key): |\n    \(.value | gsub("\n"; "\n    "))"')
EOF
    else
        # Create new ConfigMap
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gen-ai-aa-mcp-servers
  namespace: redhat-ods-applications
  labels:
    app.kubernetes.io/part-of: rhoai-mcp-servers
data:
  $entry_key: |
    $entry_value
EOF
    fi
    
    print_success "Registered '$mcp_name' in AI Asset endpoints"
    print_info "View in: OpenShift AI Dashboard → Settings → AI asset endpoints"
}

# Simple registration without jq dependency
register_ai_asset_simple() {
    local mcp_name="$1"
    local mcp_url="$2"
    local description="$3"
    local transport="${4:-streamable-http}"
    local namespace="$5"
    
    print_step "Registering '$mcp_name' in AI Asset endpoints..."
    
    local entry_key=$(echo "$mcp_name" | sed 's/ /-/g')
    
    # Check if ConfigMap exists
    if oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications &>/dev/null; then
        # Patch existing ConfigMap
        oc patch configmap gen-ai-aa-mcp-servers -n redhat-ods-applications --type merge \
            -p "{\"data\":{\"$entry_key\":\"{\\\"url\\\": \\\"$mcp_url\\\", \\\"description\\\": \\\"$description\\\", \\\"transport\\\": \\\"$transport\\\"}\"}}"
    else
        # Create new ConfigMap
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gen-ai-aa-mcp-servers
  namespace: redhat-ods-applications
  labels:
    app.kubernetes.io/part-of: rhoai-mcp-servers
data:
  $entry_key: |
    {
      "url": "$mcp_url",
      "description": "$description",
      "transport": "$transport"
    }
EOF
    fi
    
    print_success "Registered '$mcp_name' in AI Asset endpoints"
}

################################################################################
# LlamaStack Config Registration
################################################################################

# Add MCP toolgroup to LlamaStack config
register_llamastack_toolgroup() {
    local toolgroup_id="$1"
    local mcp_url="$2"
    local namespace="$3"
    
    print_step "Adding toolgroup '$toolgroup_id' to LlamaStack config..."
    
    # Check if llama-stack-config exists
    if ! oc get configmap llama-stack-config -n "$namespace" &>/dev/null; then
        print_warning "LlamaStack config not found in namespace '$namespace'"
        print_info "Deploy LlamaStack first or specify correct namespace"
        return 1
    fi
    
    # Get current config
    local current_config=$(oc get configmap llama-stack-config -n "$namespace" -o jsonpath='{.data.run\.yaml}')
    
    # Check if toolgroup already exists
    if echo "$current_config" | grep -q "toolgroup_id: $toolgroup_id"; then
        print_info "Toolgroup '$toolgroup_id' already registered"
        return 0
    fi
    
    # Create new toolgroup entry
    local new_toolgroup="    - toolgroup_id: $toolgroup_id
      provider_id: model-context-protocol
      mcp_endpoint:
        uri: $mcp_url"
    
    # Append to tool_groups section
    local updated_config=$(echo "$current_config" | sed "/^    tool_groups:/a\\
$new_toolgroup")
    
    # Update ConfigMap
    oc create configmap llama-stack-config \
        --from-literal=run.yaml="$updated_config" \
        -n "$namespace" --dry-run=client -o yaml | oc apply -f -
    
    print_success "Added toolgroup '$toolgroup_id' to LlamaStack"
    print_warning "Restart LlamaStack pod to apply changes:"
    echo "  oc delete pod -l app=lsd-genai-playground -n $namespace"
}

################################################################################
# MCP Server Deployments
################################################################################

# Deploy Kubernetes MCP Server
deploy_kubernetes_mcp() {
    local namespace="$1"
    
    print_header "Deploy Kubernetes MCP Server"
    
    print_step "Deploying Kubernetes MCP Server to $namespace..."
    oc apply -f "$MANIFEST_DIR/demo/mcp-kubernetes.yaml" -n "$namespace"
    
    print_step "Waiting for deployment..."
    oc rollout status deployment/kubernetes-mcp-server -n "$namespace" --timeout=120s || true
    
    local mcp_url="http://kubernetes-mcp-server.${namespace}.svc.cluster.local/mcp"
    
    print_success "Kubernetes MCP Server deployed"
    echo ""
    echo -e "${CYAN}MCP Endpoint:${NC} $mcp_url"
    echo ""
    
    # Ask to register
    read -p "Register in AI Asset endpoints? (Y/n): " register_ai
    if [[ ! "$register_ai" =~ ^[Nn]$ ]]; then
        register_ai_asset_simple \
            "Kubernetes-MCP-Server" \
            "$mcp_url" \
            "Kubernetes cluster operations - list pods, deployments, services, get logs. Tools: list_pods, describe_pod, get_pod_logs, list_deployments, list_services." \
            "streamable-http" \
            "$namespace"
    fi
    
    # Ask to register in LlamaStack
    read -p "Register in LlamaStack config? (Y/n): " register_ls
    if [[ ! "$register_ls" =~ ^[Nn]$ ]]; then
        register_llamastack_toolgroup "mcp::kubernetes" "$mcp_url" "$namespace"
    fi
}

# Deploy Weather MCP Server (MongoDB-based)
deploy_weather_mcp() {
    local namespace="$1"
    
    print_header "Deploy Weather MCP Server"
    
    local mcp_dir="$PROJECT_DIR/demo/llamastack-demo/mcp"
    
    if [ ! -d "$mcp_dir" ]; then
        print_error "Weather MCP directory not found: $mcp_dir"
        return 1
    fi
    
    print_step "Deploying MongoDB..."
    oc apply -f "$mcp_dir/mongodb-deployment.yaml" -n "$namespace" 2>/dev/null || \
        sed "s/namespace: demo-test/namespace: $namespace/g" "$mcp_dir/mongodb-deployment.yaml" | oc apply -f -
    
    print_step "Waiting for MongoDB..."
    oc rollout status deployment/mongodb -n "$namespace" --timeout=120s || true
    
    print_step "Initializing weather data..."
    oc apply -f "$mcp_dir/init-data-job.yaml" -n "$namespace" 2>/dev/null || true
    
    print_step "Building Weather MCP Server..."
    oc apply -f "$mcp_dir/buildconfig.yaml" -n "$namespace"
    oc start-build weather-mcp-server --from-dir="$mcp_dir" --follow -n "$namespace" || true
    
    print_step "Deploying Weather MCP Server..."
    oc apply -f "$mcp_dir/deployment.yaml" -n "$namespace"
    oc rollout status deployment/weather-mcp-server -n "$namespace" --timeout=120s || true
    
    local mcp_url="http://weather-mcp-server.${namespace}.svc.cluster.local:8000/mcp"
    
    print_success "Weather MCP Server deployed"
    echo ""
    echo -e "${CYAN}MCP Endpoint:${NC} $mcp_url"
    echo ""
    
    # Ask to register
    read -p "Register in AI Asset endpoints? (Y/n): " register_ai
    if [[ ! "$register_ai" =~ ^[Nn]$ ]]; then
        register_ai_asset_simple \
            "Weather-MCP-Server" \
            "$mcp_url" \
            "Weather data MCP server with MongoDB backend. Tools: search_weather, get_current_weather, list_stations, get_statistics, health_check." \
            "streamable-http" \
            "$namespace"
    fi
    
    # Ask to register in LlamaStack
    read -p "Register in LlamaStack config? (Y/n): " register_ls
    if [[ ! "$register_ls" =~ ^[Nn]$ ]]; then
        register_llamastack_toolgroup "mcp::weather-data" "$mcp_url" "$namespace"
    fi
}

################################################################################
# Status and Tools
################################################################################

show_status() {
    local namespace=$(get_namespace)
    
    print_header "MCP Server Status"
    
    echo -e "${CYAN}Namespace:${NC} $namespace"
    echo ""
    
    echo -e "${CYAN}MCP Server Pods:${NC}"
    oc get pods -n "$namespace" 2>/dev/null | grep -E "NAME|mcp|weather|kubernetes" || echo "  No MCP pods found"
    echo ""
    
    echo -e "${CYAN}AI Asset Endpoints (gen-ai-aa-mcp-servers):${NC}"
    if oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications &>/dev/null; then
        oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o jsonpath='{.data}' | \
            python3 -c "import sys,json; d=json.loads(sys.stdin.read() or '{}'); [print(f'  - {k}') for k in d.keys()]" 2>/dev/null || \
            oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o yaml | grep -E "^  [A-Z].*:" | sed 's/://' | sed 's/^/  - /'
    else
        echo "  ConfigMap not found"
    fi
    echo ""
    
    echo -e "${CYAN}LlamaStack Toolgroups:${NC}"
    if oc get configmap llama-stack-config -n "$namespace" &>/dev/null; then
        oc get configmap llama-stack-config -n "$namespace" -o jsonpath='{.data.run\.yaml}' | \
            grep "toolgroup_id: mcp::" | sed 's/.*toolgroup_id: /  - /' || echo "  No MCP toolgroups"
    else
        echo "  LlamaStack config not found in $namespace"
    fi
}

show_tools() {
    local namespace=$(get_namespace)
    
    print_header "Available MCP Tools"
    
    echo -e "${CYAN}Querying LlamaStack for tools...${NC}"
    echo ""
    
    oc exec deployment/lsd-genai-playground -n "$namespace" -- \
        curl -s http://localhost:8321/v1/tools 2>/dev/null | python3 -c "
import sys,json
try:
    data=json.load(sys.stdin)
    tools = data if isinstance(data, list) else data.get('data', [])
    groups = {}
    for t in tools:
        g = t.get('toolgroup_id', 'builtin')
        if g not in groups:
            groups[g] = []
        groups[g].append(t.get('name', 'unknown'))
    
    print(f'Total: {len(tools)} tools')
    print('')
    for g, tlist in sorted(groups.items()):
        if g.startswith('mcp::'):
            print(f'\033[0;36m{g}:\033[0m')
        else:
            print(f'{g}:')
        for tool in sorted(tlist):
            print(f'  - {tool}')
        print('')
except Exception as e:
    print(f'Error: {e}')
    print('Is LlamaStack running?')
" 2>/dev/null || print_error "Could not connect to LlamaStack"
}

################################################################################
# Interactive Menu
################################################################################

show_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           MCP Server Management                                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${MAGENTA}Deploy MCP Servers:${NC}"
    echo -e "${YELLOW}1)${NC} Deploy Kubernetes MCP Server"
    echo "   └─ Query pods, deployments, services, logs"
    echo -e "${YELLOW}2)${NC} Deploy Weather MCP Server (MongoDB)"
    echo "   └─ Weather data with search, statistics"
    echo ""
    echo -e "${MAGENTA}Register MCP Servers:${NC}"
    echo -e "${YELLOW}3)${NC} Register MCP in AI Asset endpoints"
    echo "   └─ Shows in OpenShift AI Dashboard"
    echo -e "${YELLOW}4)${NC} Register MCP in LlamaStack config"
    echo "   └─ Enables tool calling"
    echo ""
    echo -e "${MAGENTA}Status:${NC}"
    echo -e "${YELLOW}5)${NC} Show MCP server status"
    echo -e "${YELLOW}6)${NC} List available tools"
    echo ""
    echo -e "${YELLOW}0)${NC} Exit"
    echo ""
}

interactive_register_ai_asset() {
    print_header "Register MCP in AI Asset Endpoints"
    
    local namespace=$(get_namespace)
    echo "Current namespace: $namespace"
    echo ""
    
    read -p "MCP Server Name (e.g., My-MCP-Server): " mcp_name
    read -p "MCP URL (e.g., http://my-mcp.ns.svc.cluster.local:8000/mcp): " mcp_url
    read -p "Description: " description
    echo "Transport options: sse, streamable-http"
    read -p "Transport [streamable-http]: " transport
    transport="${transport:-streamable-http}"
    
    register_ai_asset_simple "$mcp_name" "$mcp_url" "$description" "$transport" "$namespace"
}

interactive_register_llamastack() {
    print_header "Register MCP in LlamaStack Config"
    
    local namespace=$(get_namespace)
    echo "Current namespace: $namespace"
    echo ""
    
    read -p "Toolgroup ID (e.g., mcp::my-tools): " toolgroup_id
    read -p "MCP URL (e.g., http://my-mcp.ns.svc.cluster.local:8000/mcp): " mcp_url
    read -p "Namespace for LlamaStack config [$namespace]: " ls_namespace
    ls_namespace="${ls_namespace:-$namespace}"
    
    register_llamastack_toolgroup "$toolgroup_id" "$mcp_url" "$ls_namespace"
}

main_menu() {
    while true; do
        show_menu
        read -p "Select an option (0-6): " choice
        
        local namespace=$(get_namespace)
        
        case $choice in
            1)
                deploy_kubernetes_mcp "$namespace"
                read -p "Press Enter to continue..."
                ;;
            2)
                deploy_weather_mcp "$namespace"
                read -p "Press Enter to continue..."
                ;;
            3)
                interactive_register_ai_asset
                read -p "Press Enter to continue..."
                ;;
            4)
                interactive_register_llamastack
                read -p "Press Enter to continue..."
                ;;
            5)
                show_status
                read -p "Press Enter to continue..."
                ;;
            6)
                show_tools
                read -p "Press Enter to continue..."
                ;;
            0)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

################################################################################
# Main
################################################################################

check_login

case "${1:-}" in
    deploy)
        case "${2:-}" in
            kubernetes|k8s)
                deploy_kubernetes_mcp "$(get_namespace)"
                ;;
            weather)
                deploy_weather_mcp "$(get_namespace)"
                ;;
            *)
                echo "Usage: $0 deploy <kubernetes|weather>"
                exit 1
                ;;
        esac
        ;;
    register)
        case "${2:-}" in
            ai-asset)
                interactive_register_ai_asset
                ;;
            llamastack)
                interactive_register_llamastack
                ;;
            *)
                echo "Usage: $0 register <ai-asset|llamastack>"
                exit 1
                ;;
        esac
        ;;
    status)
        show_status
        ;;
    tools)
        show_tools
        ;;
    *)
        main_menu
        ;;
esac
