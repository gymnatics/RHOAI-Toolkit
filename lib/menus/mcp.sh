#!/bin/bash
################################################################################
# mcp.sh — Interactive menus for MCP servers and LlamaStack
################################################################################
# Provides:
#   setup_mcp_servers_interactive         — MCP Server setup menu
#   register_mcp_ai_asset_interactive     — Interactive AI Asset registration
#   register_mcp_llamastack_interactive   — Interactive LlamaStack registration
#   setup_llamastack_interactive          — LlamaStack setup menu (standalone)
#   show_llamastack_demo_submenu          — LlamaStack demo sub-menu display
#   deploy_llamastack_demo_menu           — LlamaStack demo menu handler
################################################################################

_MCP_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

register_mcp_ai_asset_interactive() {
    print_header "Register MCP in AI Asset Endpoints"
    
    echo "This registers an MCP server in the OpenShift AI Dashboard"
    echo "Location: Settings → AI asset endpoints"
    echo ""
    
    read -p "MCP Server Name (e.g., My-MCP-Server): " mcp_name
    if [ -z "$mcp_name" ]; then
        print_error "Name is required"
        return 1
    fi
    
    read -p "MCP URL (e.g., http://my-mcp.ns.svc.cluster.local:8000/mcp): " mcp_url
    if [ -z "$mcp_url" ]; then
        print_error "URL is required"
        return 1
    fi
    
    read -p "Description: " description
    echo "Transport options: sse, streamable-http"
    read -p "Transport [streamable-http]: " transport
    transport="${transport:-streamable-http}"
    
    register_mcp_ai_asset "$mcp_name" "$mcp_url" "$description" "$transport"
}

register_mcp_llamastack_interactive() {
    print_header "Register MCP in LlamaStack Config"
    
    local namespace=$(oc project -q 2>/dev/null)
    echo "This adds an MCP connector to LlamaStack for tool calling"
    echo "Current namespace: $namespace"
    echo ""
    
    read -p "Connector ID (e.g., my-tools): " toolgroup_id
    if [ -z "$toolgroup_id" ]; then
        print_error "Connector ID is required"
        return 1
    fi
    
    read -p "MCP URL (e.g., http://my-mcp.ns.svc.cluster.local:8000/mcp): " mcp_url
    if [ -z "$mcp_url" ]; then
        print_error "URL is required"
        return 1
    fi
    
    read -p "Namespace for LlamaStack config [$namespace]: " ls_namespace
    ls_namespace="${ls_namespace:-$namespace}"
    
    register_mcp_llamastack "$toolgroup_id" "$mcp_url" "$ls_namespace"
}

setup_mcp_servers_interactive() {
    print_header "Setup MCP Servers"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           MCP Server Options                                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}MCP (Model Context Protocol) enables AI agents to use external tools.${NC}"
    echo ""
    echo -e "${MAGENTA}Deploy MCP Servers (Individual):${NC}"
    echo -e "${YELLOW}1)${NC} Deploy Kubernetes MCP Server ${GREEN}[Recommended]${NC}"
    echo "   └─ Query pods, deployments, services, logs via natural language"
    echo -e "${YELLOW}2)${NC} Deploy Weather MCP Server + MongoDB"
    echo "   └─ Sample MCP server with weather data tools (14 airports)"
    echo -e "${YELLOW}3)${NC} Deploy Context7 MCP Server"
    echo "   └─ Documentation lookup for libraries and frameworks"
    echo -e "${YELLOW}4)${NC} Deploy SearXNG MCP Server"
    echo "   └─ Privacy-respecting web search engine"
    echo -e "${YELLOW}5)${NC} Deploy Code Sandbox MCP Server"
    echo "   └─ Sandboxed Python code execution"
    echo -e "${YELLOW}6)${NC} Deploy OCP MCP Server"
    echo "   └─ Red Hat OpenShift cluster operations"
    echo ""
    echo -e "${MAGENTA}Deploy All:${NC}"
    echo -e "${YELLOW}7)${NC} Deploy All Gateway MCP Servers ${CYAN}[Gateway API]${NC}"
    echo "   └─ Context7 + SearXNG + Code Sandbox + OCP + Codebase Search + Repo Docs"
    echo ""
    echo -e "${MAGENTA}Gateway Infrastructure:${NC}"
    echo -e "${YELLOW}8)${NC} Setup MCP Gateway + Listener"
    echo "   └─ Install MCP Gateway controller and add listener to maas-default-gateway"
    echo -e "${YELLOW}9)${NC} Deploy HTTPRoutes"
    echo "   └─ Create routes for deployed MCP servers"
    echo ""
    echo -e "${MAGENTA}Register & Status:${NC}"
    echo -e "${YELLOW}r)${NC} Register MCP in AI Asset Endpoints / LlamaStack"
    echo -e "${YELLOW}s)${NC} Show MCP Server Status"
    echo -e "${YELLOW}t)${NC} List Available Tools (from LlamaStack)"
    echo -e "${YELLOW}m)${NC} Full MCP Management Menu (manage-mcp-servers.sh)"
    echo -e "${YELLOW}0)${NC} Back to RHOAI Management Menu"
    echo ""
    
    read -p "Enter your choice: " mcp_choice
    
    case $mcp_choice in
        1)
            deploy_kubernetes_mcp_server
            ;;
        2)
            deploy_mcp_mongodb_only
            ;;
        3)
            deploy_mcp_server "context7"
            ;;
        4)
            deploy_mcp_server "searxng"
            ;;
        5)
            deploy_mcp_server "code-sandbox"
            ;;
        6)
            deploy_mcp_server "ocp-mcp-server"
            ;;
        7)
            deploy_all_mcp_servers
            ;;
        8)
            setup_mcp_gateway
            setup_mcp_gateway_listener
            ;;
        9)
            deploy_mcp_httproutes
            ;;
        r|R)
            echo ""
            echo -e "${YELLOW}1)${NC} Register in AI Asset Endpoints (Dashboard UI)"
            echo -e "${YELLOW}2)${NC} Register in LlamaStack Config (Tool Calling)"
            echo ""
            read -p "Select: " reg_choice
            case $reg_choice in
                1) register_mcp_ai_asset_interactive ;;
                2) register_mcp_llamastack_interactive ;;
                *) print_error "Invalid option" ;;
            esac
            ;;
        s|S)
            show_mcp_status
            ;;
        t|T)
            show_mcp_tools
            ;;
        m|M)
            if [ -f "$_MCP_MENU_DIR/scripts/manage-mcp-servers.sh" ]; then
                "$_MCP_MENU_DIR/scripts/manage-mcp-servers.sh"
            else
                print_error "MCP management script not found"
            fi
            ;;
        0)
            return 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
    
    return 0
}

setup_llamastack_interactive() {
    # RHOAI 3.5+: OGX replaces LlamaStack (DSC field llamastackoperator -> ogx,
    # CRD llamastackdistributions.llamastack.io -> ogxservers.ogx.io).
    local use_ogx=false
    if type is_rhoai_35_or_higher &>/dev/null && is_rhoai_35_or_higher 2>/dev/null; then
        use_ogx=true
    fi

    if [ "$use_ogx" = true ]; then
        print_header "Setup OGX (replaces LlamaStack on RHOAI 3.5+)"
    else
        print_header "Setup LlamaStack"
    fi
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"

    local crd_name="llamastackdistributions.llamastack.io"
    local dsc_field="llamastackoperator"
    local component_label="LlamaStack"
    if [ "$use_ogx" = true ]; then
        crd_name="ogxservers.ogx.io"
        dsc_field="ogx"
        component_label="OGX"
    fi
    
    if ! oc get crd "$crd_name" &>/dev/null; then
        print_error "${component_label} CRD ($crd_name) not found!"
        echo ""
        echo -e "${YELLOW}${component_label} operator is not enabled in your RHOAI installation.${NC}"
        echo ""
        echo "To enable ${component_label}:"
        echo ""
        if [ "$use_ogx" = true ]; then
            echo "  1. Ensure you have RHOAI 3.5+ installed"
        else
            echo "  1. Ensure you have RHOAI 3.0+ installed"
        fi
        echo ""
        echo "  2. Enable ${component_label} in your DataScienceCluster:"
        echo "     oc patch datasciencecluster default-dsc --type merge \\"
        echo "       -p '{\"spec\":{\"components\":{\"${dsc_field}\":{\"managementState\":\"Managed\"}}}}'"
        echo ""
        echo "  3. Wait for the operator to be ready (~2-3 minutes)"
        echo ""
        read -p "Would you like to enable ${component_label} now? (y/N): " enable_component
        if [[ "$enable_component" =~ ^[Yy]$ ]]; then
            print_step "Enabling ${component_label} operator..."
            if oc patch datasciencecluster default-dsc --type merge \
                -p "{\"spec\":{\"components\":{\"${dsc_field}\":{\"managementState\":\"Managed\"}}}}" 2>/dev/null; then
                print_success "${component_label} operator enabled"
                echo ""
                print_step "Waiting for CRD to be available..."
                local max_wait=180
                local waited=0
                while [ $waited -lt $max_wait ]; do
                    if oc get crd "$crd_name" &>/dev/null; then
                        print_success "${component_label} CRD is now available"
                        break
                    fi
                    sleep 5
                    waited=$((waited + 5))
                    echo "  Waiting... ($waited/$max_wait seconds)"
                done
                
                if [ $waited -ge $max_wait ]; then
                    print_warning "Timeout waiting for CRD. Please try again in a few minutes."
                    return 1
                fi
            else
                print_error "Failed to enable ${component_label} operator"
                return 1
            fi
        else
            return 1
        fi
    fi
    
    print_success "${component_label} CRD found"
    echo ""
    
    echo -e "${CYAN}Target Namespace Configuration:${NC}"
    local current_project=$(oc project -q 2>/dev/null)
    echo "Current project: $current_project"
    echo ""
    read -p "Enter target namespace [default: $current_project]: " target_ns
    target_ns="${target_ns:-$current_project}"
    
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_warning "Namespace '$target_ns' does not exist"
        read -p "Create it? (y/N): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc new-project "$target_ns" 2>/dev/null || oc create namespace "$target_ns"
            print_success "Namespace created"
        else
            print_error "Namespace required"
            return 1
        fi
    fi
    
    oc project "$target_ns" &>/dev/null
    
    echo ""
    echo -e "${CYAN}${component_label} will be deployed with:${NC}"
    echo "  • Your chosen LLM provider (vLLM, Azure, OpenAI, Ollama, Bedrock)"
    echo "  • RAG capabilities (Milvus vector DB)"
    echo "  • MCP tool runtime support"
    echo "  • Agent orchestration"
    echo ""
    
    read -p "Proceed? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Cancelled"
        return 0
    fi
    
    deploy_llamastack_distribution_generic "$target_ns"
    
    if [ $? -eq 0 ]; then
        # deploy_llamastack_distribution_generic routes internally to OGX on 3.5+
        # and sets LLAMASTACK_URL either way (see lib/functions/llamastack.sh)
        local service_url="${LLAMASTACK_URL:-http://llamastack-demo-service.$target_ns.svc.cluster.local:8321}"
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✅ ${component_label} Deployed Successfully!                  ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}📦 ${component_label} Service:${NC}"
        echo "   • URL: $service_url"
        echo "   • Provider: $LLM_PROVIDER"
        echo "   • Model: $MODEL_ID"
        echo ""
        echo -e "${CYAN}💡 Next Steps:${NC}"
        echo "   1. Test the connection:"
        echo "      curl $service_url/v1/models"
        echo ""
        if [ "$use_ogx" = true ]; then
            echo "   2. Add MCP servers (optional):"
            echo "      Edit the OGXServer CR's spec.providers.toolRuntime.remote.modelContextProtocol"
            echo ""
            echo "   3. Use from your application:"
            echo "      OGX exposes an OpenAI/LlamaStack-compatible API at the URL above."
        else
            echo "   2. Add MCP servers (optional):"
            echo "      Edit the ConfigMap to add connectors with connector_id and url"
            echo ""
            echo "   3. Use from your application:"
            echo "      from llama_stack_client import LlamaStackClient"
            echo "      client = LlamaStackClient(base_url='$service_url')"
        fi
        echo ""
    fi
    
    return 0
}

show_llamastack_demo_submenu() {
    local component_label="LlamaStack"
    if type is_rhoai_35_or_higher &>/dev/null && is_rhoai_35_or_higher 2>/dev/null; then
        component_label="OGX"
    fi

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           ${component_label} Demo Deployment Options${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}This demo includes:${NC}"
    echo "  • ${component_label} Demo UI - Streamlit chatbot frontend"
    echo "  • Weather MCP Server - Sample MCP server with weather tools"
    echo "  • MongoDB - Database with 14 global weather stations"
    echo ""
    echo -e "${MAGENTA}Full Stack (includes ${component_label}):${NC}"
    echo -e "${YELLOW}1)${NC} Deploy Everything with ${component_label} ${GREEN}[NEW]${NC}"
    echo "    → Deploys ${component_label} + MCP + MongoDB + UI (choose your LLM provider)"
    echo ""
    echo -e "${MAGENTA}Partial Deployment (existing ${component_label}):${NC}"
    echo -e "${YELLOW}2)${NC} Deploy Demo Stack (UI + MCP + MongoDB)"
    echo "    → Connects to your existing ${component_label}"
    echo ""
    echo -e "${YELLOW}3)${NC} Deploy Weather MCP Server + MongoDB only"
    echo -e "${YELLOW}4)${NC} Deploy Demo UI only"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to RHOAI Management Menu"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}💡 Not using OpenShift?${NC}"
    echo "   For Kubernetes or Docker deployment, see:"
    echo -e "   ${YELLOW}https://github.com/gymnatics/llamastack-demo${NC}"
    echo ""
}

deploy_llamastack_demo_menu() {
    print_header "Deploy LlamaStack/OGX Demo"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    
    while true; do
        show_llamastack_demo_submenu
        read -p "Enter your choice: " demo_choice
        
        case $demo_choice in
            1)
                deploy_full_stack_with_llamastack || true
                echo ""
                read -p "Press Enter to continue..."
                return 0
                ;;
            2)
                deploy_complete_llamastack_demo || true
                echo ""
                read -p "Press Enter to continue..."
                return 0
                ;;
            3)
                deploy_mcp_mongodb_only || true
                echo ""
                read -p "Press Enter to continue..."
                return 0
                ;;
            4)
                deploy_llamastack_demo_interactive || true
                echo ""
                read -p "Press Enter to continue..."
                return 0
                ;;
            0)
                return 0
                ;;
            *)
                print_error "Invalid option. Please enter 1-4 or 0."
                sleep 1
                ;;
        esac
    done
}
