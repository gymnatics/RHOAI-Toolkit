#!/bin/bash
################################################################################
# mcp.sh — MCP (Model Context Protocol) server deployment functions
################################################################################
# Provides:
#   deploy_mcp_mongodb_only          — Deploy Weather MCP Server + MongoDB (menu wrapper)
#   register_mcp_ai_asset            — Register MCP in AI Asset endpoints ConfigMap
#   register_mcp_llamastack          — Register MCP toolgroup in LlamaStack config
#   show_mcp_status                  — Show MCP server status
#   show_mcp_tools                   — List available MCP tools from LlamaStack
#   deploy_weather_mcp_server        — Deploy Weather MCP Server (core logic)
#   deploy_kubernetes_mcp_server     — Deploy Kubernetes MCP Server (multi-strategy)
#   _mcp_deploy_helm                 — Helm chart install strategy
#   _mcp_ensure_cluster_rbac         — Ensure cluster-wide RBAC for MCP SA
#   _mcp_deploy_buildconfig          — OpenShift BuildConfig strategy
#   _mcp_deploy_local_build          — Local container build + push strategy
#   _mcp_deploy_manifest             — Static manifest fallback strategy
################################################################################

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || true
source "$ROOT_DIR/lib/utils/rhoai-version.sh" 2>/dev/null || true

# Helper: apply manifest with namespace substitution (demo-test → target)
_mcp_apply_manifest() {
    local manifest_file="$1"
    local target_ns="$2"
    
    if [ ! -f "$manifest_file" ]; then
        print_error "Manifest not found: $manifest_file"
        return 1
    fi
    
    sed -e "s/namespace: demo-test/namespace: $target_ns/g" \
        -e "s|demo-test/|$target_ns/|g" \
        "$manifest_file" | oc apply -f -
}

register_mcp_ai_asset() {
    local mcp_name="$1"
    local mcp_url="$2"
    local description="$3"
    
    print_step "Registering '$mcp_name' in AI Asset endpoints..."
    
    local entry_key=$(echo "$mcp_name" | sed 's/ /-/g')
    
    if oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications &>/dev/null; then
        if oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o jsonpath="{.data.${entry_key}}" 2>/dev/null | grep -q "url"; then
            print_info "'$mcp_name' is already registered"
            return 0
        fi
        
        local escaped_desc=$(echo "$description" | sed 's/"/\\"/g')
        oc patch configmap gen-ai-aa-mcp-servers -n redhat-ods-applications \
            --type merge -p "{\"data\":{\"$entry_key\": \"{\\\"url\\\": \\\"$mcp_url\\\", \\\"description\\\": \\\"$escaped_desc\\\"}\"}}"
    else
        export MCP_ENTRY_KEY="$entry_key"
        export MCP_URL="$mcp_url"
        export MCP_DESCRIPTION="$description"
        envsubst < "$ROOT_DIR/lib/manifests/mcp/mcp-ai-asset-configmap.yaml" | oc apply -f -
        unset MCP_ENTRY_KEY MCP_URL MCP_DESCRIPTION
    fi
    
    print_success "Registered '$mcp_name' in AI Asset endpoints"
    print_info "View in: OpenShift AI Dashboard → Settings → AI asset endpoints"
}

register_mcp_llamastack() {
    local toolgroup_id="$1"
    local mcp_url="$2"
    local namespace="$3"

    # RHOAI 3.5+: OGX replaces LlamaStack and does NOT expose a patchable
    # "run.yaml" ConfigMap the way LlamaStack did. MCP registration on OGX goes
    # through the OGXServer CR itself, under:
    #   spec.providers.toolRuntime.remote.modelContextProtocol[]
    # (confirmed via `oc explain ogxserver.spec.providers.toolRuntime.remote.modelContextProtocol`
    # on a live RHOAI 3.5.0 cluster). There is no confirmed way to set the MCP
    # server's URL directly on that field from this toolkit yet -- point the
    # user at the CR instead of guessing at an unverified patch.
    if type is_rhoai_35_or_higher &>/dev/null && is_rhoai_35_or_higher 2>/dev/null; then
        print_step "Registering MCP connector '$toolgroup_id' with OGX..."
        print_warning "RHOAI 3.5+ uses OGX (not LlamaStack) — registration mechanism has changed"
        echo ""
        print_info "Manual step required: edit your OGXServer CR in namespace '$namespace' to add:"
        echo ""
        echo "  spec:"
        echo "    providers:"
        echo "      toolRuntime:"
        echo "        remote:"
        echo "          modelContextProtocol:"
        echo "            - id: $toolgroup_id"
        echo ""
        print_info "MCP server URL: $mcp_url"
        print_info "Find your OGXServer CR: oc get ogxserver -n $namespace"
        print_info "See docs/guides/rhoai-3.5/RHOAI-35-WHATS-NEW.md and the RHCL 1.4 MCP gateway"
        print_info "docs for the full registration workflow (MCPServerRegistration CRs)."
        return 0
    fi

    print_step "Adding connector '$toolgroup_id' to LlamaStack config..."
    
    if ! oc get configmap llama-stack-config -n "$namespace" &>/dev/null; then
        print_warning "LlamaStack config not found in namespace '$namespace'"
        print_info "Deploy LlamaStack first, or the playground will create it"
        return 1
    fi
    
    local current_config=$(oc get configmap llama-stack-config -n "$namespace" -o jsonpath='{.data.run\.yaml}')
    
    if echo "$current_config" | grep -q "connector_id: $toolgroup_id"; then
        print_info "Connector '$toolgroup_id' already registered"
        return 0
    fi
    
    print_info "Adding MCP connector to LlamaStack config..."
    print_warning "Manual step required: Edit the ConfigMap to add:"
    echo ""
    echo "    - connector_id: $toolgroup_id"
    echo "      connector_type: mcp"
    echo "      url: $mcp_url"
    echo ""
    print_info "Then restart LlamaStack: oc delete pod -l app=lsd-genai-playground -n $namespace"
}

show_mcp_status() {
    print_header "MCP Server Status"
    
    local namespace=$(oc project -q 2>/dev/null)
    echo -e "${CYAN}Current Namespace:${NC} $namespace"
    echo ""
    
    echo -e "${CYAN}MCP Server Pods:${NC}"
    oc get pods -n "$namespace" 2>/dev/null | grep -E "NAME|mcp|weather|kubernetes" || echo "  No MCP pods found in $namespace"
    echo ""
    
    echo -e "${CYAN}AI Asset Endpoints (gen-ai-aa-mcp-servers):${NC}"
    if oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications &>/dev/null; then
        oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o yaml 2>/dev/null | \
            grep -E "^  [A-Za-z].*-.*:" | sed 's/://' | sed 's/^/  - /' || echo "  No entries"
    else
        echo "  ConfigMap not found (no MCP servers registered)"
    fi
    echo ""
    
    if type is_rhoai_35_or_higher &>/dev/null && is_rhoai_35_or_higher 2>/dev/null; then
        echo -e "${CYAN}OGX Servers (RHOAI 3.5+):${NC}"
        if oc get ogxserver -n "$namespace" &>/dev/null 2>&1; then
            oc get ogxserver -n "$namespace" --no-headers 2>/dev/null | awk '{print "  - " $1}'
            print_info "MCP connectors are configured via spec.providers.toolRuntime.remote.modelContextProtocol[]"
            print_info "on the OGXServer CR itself (no separate ConfigMap to inspect)."
        else
            echo "  No OGXServer instances found in $namespace"
        fi
    else
        echo -e "${CYAN}LlamaStack Connectors:${NC}"
        if oc get configmap llama-stack-config -n "$namespace" &>/dev/null; then
            oc get configmap llama-stack-config -n "$namespace" -o jsonpath='{.data.run\.yaml}' 2>/dev/null | \
                grep "connector_id:" | sed 's/.*connector_id: /  - /' || echo "  No MCP connectors in $namespace"
        else
            echo "  LlamaStack config not found in $namespace"
        fi
    fi
}

show_mcp_tools() {
    print_header "Available MCP Tools"
    
    local namespace=$(oc project -q 2>/dev/null)

    # RHOAI 3.5+: query the actual OGXServer deployment (named after the CR,
    # discovered dynamically since it's user-chosen, unlike LlamaStack's fixed
    # lsd-genai-playground name).
    local target_deployment="lsd-genai-playground"
    if type is_rhoai_35_or_higher &>/dev/null && is_rhoai_35_or_higher 2>/dev/null; then
        local ogx_name
        ogx_name=$(oc get ogxserver -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ -z "$ogx_name" ]; then
            print_error "No OGXServer instance found in $namespace"
            return 1
        fi
        target_deployment="$ogx_name"
        echo -e "${CYAN}Querying OGX ('$ogx_name') in namespace: $namespace${NC}"
    else
        echo -e "${CYAN}Querying LlamaStack in namespace: $namespace${NC}"
    fi
    echo ""
    
    oc exec "deployment/${target_deployment}" -n "$namespace" -- \
        curl -s http://localhost:8321/v1/tools 2>/dev/null | python3 -c "
import sys,json
try:
    data=json.load(sys.stdin)
    tools = data if isinstance(data, list) else data.get('data', [])
    groups = {}
    for t in tools:
        g = t.get('connector_id', t.get('toolgroup_id', 'builtin'))
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
    print('Is the server running?')
" 2>/dev/null || print_error "Could not connect to server '$target_deployment' in $namespace"
}

deploy_weather_mcp_server() {
    local target_ns="$1"
    local mcp_dir="$ROOT_DIR/demo/llamastack-demo/mcp"
    
    if [ ! -d "$mcp_dir" ]; then
        print_error "Weather MCP server directory not found"
        echo "Expected: $mcp_dir"
        return 1
    fi
    
    echo ""
    print_step "Deploying MongoDB..."
    
    if oc get pvc mongodb-data -n "$target_ns" &>/dev/null; then
        print_info "MongoDB PVC already exists, skipping PVC creation"
        sed -e "s/namespace: demo-test/namespace: $target_ns/g" "$mcp_dir/mongodb-deployment.yaml" | \
            awk 'BEGIN{skip=1} /^---$/{skip=0} !skip{print}' | oc apply -f -
    else
        _mcp_apply_manifest "$mcp_dir/mongodb-deployment.yaml" "$target_ns"
    fi
    
    print_step "Waiting for MongoDB to be ready..."
    if ! oc wait --for=condition=available deployment/mongodb -n "$target_ns" --timeout=180s; then
        print_warning "MongoDB may still be starting"
    else
        print_success "MongoDB is ready"
    fi
    
    echo ""
    print_step "Initializing sample weather data..."
    
    oc delete job init-weather-data -n "$target_ns" 2>/dev/null || true
    
    _mcp_apply_manifest "$mcp_dir/init-data-job.yaml" "$target_ns"
    
    print_step "Waiting for data initialization (this may take 30-60 seconds)..."
    if oc wait --for=condition=complete job/init-weather-data -n "$target_ns" --timeout=120s 2>/dev/null; then
        print_success "Sample data loaded"
    else
        print_warning "Data initialization may still be running"
        echo "Check with: oc logs -f job/init-weather-data -n $target_ns"
    fi
    
    echo ""
    print_step "Building Weather MCP Server container..."
    
    _mcp_apply_manifest "$mcp_dir/buildconfig.yaml" "$target_ns"
    
    if oc start-build weather-mcp-server --from-dir="$mcp_dir" --follow -n "$target_ns"; then
        print_success "Build completed"
    else
        print_error "Build failed"
        return 1
    fi
    
    echo ""
    print_step "Deploying Weather MCP Server..."
    
    _mcp_apply_manifest "$mcp_dir/deployment.yaml" "$target_ns"
    
    print_step "Waiting for MCP server to be ready..."
    if oc rollout status deployment/weather-mcp-server -n "$target_ns" --timeout=120s; then
        print_success "Weather MCP Server deployed"
    else
        print_warning "MCP server may still be starting"
    fi
    
    return 0
}

deploy_mcp_mongodb_only() {
    print_header "Deploy Weather MCP Server + MongoDB"
    
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
    echo -e "${CYAN}This will deploy:${NC}"
    echo "  • MongoDB with 1Gi persistent storage"
    echo "  • Sample weather data (14 stations, 48 hours of data)"
    echo "  • Weather MCP Server with 5 tools"
    echo ""
    
    read -p "Proceed? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Cancelled"
        return 0
    fi
    
    deploy_weather_mcp_server "$target_ns"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✅ Weather MCP Server Deployed Successfully!                  ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}📋 Deployed Components:${NC}"
        echo "   • MongoDB: mongodb.$target_ns.svc.cluster.local:27017"
        echo "   • MCP Server: weather-mcp-server.$target_ns.svc.cluster.local:8000"
        echo ""
        echo -e "${CYAN}🔧 Available Tools:${NC}"
        echo "   • search_weather - Search observations with filters"
        echo "   • get_current_weather - Get latest observation for a station"
        echo "   • list_stations - List all weather stations"
        echo "   • get_statistics - Get database stats"
        echo "   • health_check - Check server health"
        echo ""
        echo -e "${YELLOW}📝 Next Steps:${NC}"
        if type is_rhoai_35_or_higher &>/dev/null && is_rhoai_35_or_higher 2>/dev/null; then
            echo "   1. Register MCP server with OGX (RHOAI 3.5+ replaces LlamaStack):"
            echo "      Add to your OGXServer CR under spec.providers.toolRuntime.remote.modelContextProtocol:"
            echo ""
            echo "      - id: weather-data"
            echo "        # URL configuration: oc get ogxserver -n $target_ns"
            echo ""
            echo "   2. Restart the OGXServer pod to pick up the new tools"
        else
            echo "   1. Register MCP server with LlamaStack:"
            echo "      Add to your LlamaStack config under connectors:"
            echo ""
            echo "      - connector_id: weather-data"
            echo "        connector_type: mcp"
            echo "        url: http://weather-mcp-server.$target_ns.svc.cluster.local:8000/mcp"
            echo ""
            echo "   2. Restart LlamaStack to pick up the new tools"
        fi
        echo ""
    fi
    
    return 0
}

################################################################################
# Kubernetes MCP Server Deployment (Multi-Strategy)
################################################################################

deploy_kubernetes_mcp_server() {
    print_header "Deploy Kubernetes MCP Server"
    print_info "Source: github.com/openshift/openshift-mcp-server"
    echo ""
    
    local MCP_REPO="https://github.com/openshift/openshift-mcp-server.git"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    local current_project=$(oc project -q 2>/dev/null)
    if oc get deployment kubernetes-mcp-server -n "$current_project" &>/dev/null 2>&1; then
        local ready=$(oc get deployment kubernetes-mcp-server -n "$current_project" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        if [ "${ready:-0}" -gt 0 ]; then
            print_success "Kubernetes MCP Server already running in '$current_project'"
            local mcp_url="http://kubernetes-mcp-server.${current_project}.svc.cluster.local:8080/mcp"
            echo -e "  ${CYAN}Endpoint:${NC} $mcp_url"
            echo ""
            read -p "Redeploy/upgrade? (y/N): " redeploy
            if [[ ! "$redeploy" =~ ^[Yy]$ ]]; then
                return 0
            fi
        fi
    fi
    
    ############################################################################
    # Namespace selection
    ############################################################################
    echo -e "${CYAN}Target Namespace:${NC}"
    echo "  Current project: $current_project"
    echo ""
    read -p "Deploy to namespace [$current_project]: " target_ns
    target_ns="${target_ns:-$current_project}"
    
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_warning "Namespace '$target_ns' does not exist"
        read -p "Create it? (y/N): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc new-project "$target_ns" 2>/dev/null || oc create namespace "$target_ns"
            print_success "Namespace created"
        else
            return 1
        fi
    fi
    
    ############################################################################
    # Configuration
    ############################################################################
    echo ""
    print_step "Configuration"
    echo ""
    
    echo -e "${BLUE}Read-only mode${NC} (prevents write/delete operations on the cluster):"
    read -p "  Enable read-only? (Y/n): " readonly_choice
    local read_only="true"
    if [[ "$readonly_choice" =~ ^[Nn]$ ]]; then
        read_only="false"
        print_warning "Write operations enabled -- be careful in shared clusters"
    fi
    
    echo ""
    echo -e "${BLUE}Toolsets${NC} (which capabilities to enable):"
    echo "  1) core          - Pods, Deployments, Services, Namespaces"
    echo "  2) core + events - Add Kubernetes events"
    echo "  3) core + helm   - Add Helm chart management"
    echo "  4) full           - core + events + helm + tekton + exec"
    echo "  5) custom         - Choose individually"
    echo ""
    read -p "  Select toolset profile [1]: " toolset_choice
    toolset_choice="${toolset_choice:-1}"
    
    local toolsets="core"
    case "$toolset_choice" in
        2) toolsets="core,events" ;;
        3) toolsets="core,helm" ;;
        4) toolsets="core,events,helm,tekton,exec" ;;
        5)
            echo ""
            echo "  Available: core, config, events, helm, tekton, exec"
            read -p "  Enter comma-separated toolsets: " toolsets
            toolsets="${toolsets:-core}"
            ;;
        *) toolsets="core" ;;
    esac
    print_info "Toolsets: $toolsets"
    
    ############################################################################
    # Deployment method selection
    ############################################################################
    echo ""
    print_step "Deployment Method"
    echo ""
    
    local has_helm=false
    local has_podman=false
    if command -v helm &>/dev/null; then has_helm=true; fi
    if command -v podman &>/dev/null || command -v docker &>/dev/null; then has_podman=true; fi
    
    local suggested="2"
    if [ "$has_helm" = true ]; then suggested="1"; fi
    
    echo -e "${YELLOW}1)${NC} Helm chart install ${GREEN}$([ "$has_helm" = true ] && echo '[detected]' || echo '[helm not found]')${NC}"
    echo "   Clone chart from GitHub, deploy with helm"
    echo ""
    echo -e "${YELLOW}2)${NC} OpenShift BuildConfig ${GREEN}[works with oc only]${NC}"
    echo "   Build image on-cluster from GitHub repo (no local tools needed)"
    echo ""
    echo -e "${YELLOW}3)${NC} Local container build ${GREEN}$([ "$has_podman" = true ] && echo '[podman/docker detected]' || echo '[not detected]')${NC}"
    echo "   Clone repo, build locally with podman/docker, push to cluster"
    echo ""
    echo -e "${YELLOW}4)${NC} Quick static manifest ${GREEN}[offline/air-gapped]${NC}"
    echo "   Apply bundled manifest (limited toolset, older image)"
    echo ""
    
    read -p "Select method [$suggested]: " method_choice
    method_choice="${method_choice:-$suggested}"
    
    ############################################################################
    # Execute selected method
    ############################################################################
    local mcp_url="http://kubernetes-mcp-server.${target_ns}.svc.cluster.local:8080/mcp"
    
    case "$method_choice" in
        1) _mcp_deploy_helm "$target_ns" "$read_only" "$toolsets" "$MCP_REPO" ;;
        2) _mcp_deploy_buildconfig "$target_ns" "$read_only" "$toolsets" "$MCP_REPO" ;;
        3) _mcp_deploy_local_build "$target_ns" "$read_only" "$toolsets" "$MCP_REPO" ;;
        4) _mcp_deploy_manifest "$target_ns" ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    local deploy_rc=$?
    if [ $deploy_rc -ne 0 ]; then
        print_error "Deployment failed"
        return 1
    fi
    
    ############################################################################
    # Wait for rollout
    ############################################################################
    print_step "Waiting for MCP Server to be ready..."
    if oc rollout status deployment/kubernetes-mcp-server -n "$target_ns" --timeout=180s 2>/dev/null; then
        print_success "Kubernetes MCP Server is running"
    else
        print_warning "MCP Server may still be starting (check pods)"
    fi
    
    ############################################################################
    # Registration and summary
    ############################################################################
    echo ""
    print_header "Kubernetes MCP Server Deployed"
    echo ""
    echo -e "${CYAN}MCP Endpoint:${NC} $mcp_url"
    echo -e "${CYAN}Namespace:${NC}    $target_ns"
    echo -e "${CYAN}Toolsets:${NC}     $toolsets"
    echo -e "${CYAN}Read-Only:${NC}    $read_only"
    echo ""
    echo -e "${YELLOW}Available tools:${NC}"
    echo "  Pods: list, get, delete, logs, exec, top, run"
    echo "  Resources: create/update, get, list, delete (any K8s/OCP resource)"
    echo "  Namespaces, Events, Projects (OpenShift)"
    [ "$toolsets" = *"helm"* ] && echo "  Helm: install, list, uninstall"
    [ "$toolsets" = *"tekton"* ] && echo "  Tekton: start pipeline/task, get logs"
    echo ""
    if type is_rhoai_35_or_higher &>/dev/null && is_rhoai_35_or_higher 2>/dev/null; then
        echo -e "${YELLOW}Use with OGX (RHOAI 3.5+, replaces LlamaStack):${NC}"
        echo "  spec.providers.toolRuntime.remote.modelContextProtocol:"
        echo "  - id: kubernetes"
        echo "    # url: $mcp_url"
    else
        echo -e "${YELLOW}Use with LlamaStack:${NC}"
        echo "  connectors:"
        echo "  - connector_id: kubernetes"
        echo "    connector_type: mcp"
        echo "    url: $mcp_url"
    fi
    echo ""
    
    read -p "Register in AI Asset endpoints (shows in RHOAI UI)? (Y/n): " register_ai
    if [[ ! "$register_ai" =~ ^[Nn]$ ]]; then
        register_mcp_ai_asset "Kubernetes-MCP-Server" "$mcp_url" \
            "Kubernetes/OpenShift operations - pods, deployments, services, logs, helm, tekton." \
            "streamable-http"
    fi
    
    read -p "Register with LlamaStack/OGX config (tool calling)? (Y/n): " register_ls
    if [[ ! "$register_ls" =~ ^[Nn]$ ]]; then
        register_mcp_llamastack "mcp::kubernetes" "$mcp_url" "$target_ns"
    fi
    
    return 0
}

_mcp_deploy_helm() {
    local target_ns="$1" read_only="$2" toolsets="$3" repo_url="$4"
    
    if ! command -v helm &>/dev/null; then
        print_error "helm CLI not found. Install helm or choose another method."
        return 1
    fi
    
    print_step "Cloning Helm chart from GitHub..."
    local tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" RETURN
    
    git clone --depth=1 --filter=blob:none --sparse "$repo_url" "$tmpdir/repo" 2>&1 | tail -1
    cd "$tmpdir/repo" && git sparse-checkout set charts/kubernetes-mcp-server 2>/dev/null
    
    if [ ! -d "$tmpdir/repo/charts/kubernetes-mcp-server" ]; then
        print_error "Failed to clone Helm chart"
        return 1
    fi
    
    local image_tag=""
    local image_registry="quay.io"
    local image_repo="redhat-user-workloads/crt-nshift-lightspeed-tenant/openshift-mcp-server"
    
    print_step "Resolving container image tag..."
    for sha in $(git log --format='%H' -n 10 2>/dev/null); do
        if skopeo inspect --raw "docker://${image_registry}/${image_repo}:${sha}" &>/dev/null; then
            image_tag="$sha"
            break
        fi
    done
    
    if [ -z "$image_tag" ]; then
        print_warning "Could not resolve image tag from git history, falling back to latest"
        image_tag="latest"
    else
        print_info "Resolved image tag: ${image_tag:0:12}..."
    fi
    
    print_step "Installing via Helm..."
    helm upgrade --install kubernetes-mcp-server \
        "$tmpdir/repo/charts/kubernetes-mcp-server" \
        --namespace "$target_ns" \
        --set image.version="$image_tag" \
        --set server.readOnly="$read_only" \
        --set server.port=8080 \
        --set server.stateless=true \
        --set "server.toolsets={$toolsets}" \
        --set ingress.enabled=false \
        --set route.enabled=false \
        --create-namespace 2>&1
    
    local rc=$?
    
    if [ $rc -eq 0 ]; then
        _mcp_ensure_cluster_rbac "$target_ns" "$read_only"
    fi
    
    cd - &>/dev/null
    return $rc
}

_mcp_ensure_cluster_rbac() {
    local target_ns="$1"
    local read_only="${2:-true}"
    
    local cluster_role="view"
    if [ "$read_only" != "true" ]; then
        cluster_role="edit"
    fi
    
    local sa_name=$(oc get sa -n "$target_ns" --no-headers 2>/dev/null | awk '{print $1}' | grep -E "mcp|kubernetes-mcp" | head -1)
    sa_name="${sa_name:-kubernetes-mcp-server}"
    
    local crb_name="kubernetes-mcp-server-${target_ns}"
    
    if oc get clusterrolebinding "$crb_name" &>/dev/null; then
        print_info "ClusterRoleBinding '$crb_name' already exists"
        return 0
    fi
    
    print_step "Creating ClusterRoleBinding for cluster-wide $cluster_role access..."
    export CRB_NAME="$crb_name"
    export SA_NAME="$sa_name"
    export NAMESPACE="$target_ns"
    export CLUSTER_ROLE="$cluster_role"
    envsubst < "$ROOT_DIR/lib/manifests/mcp/cluster-rolebinding.yaml" | oc apply -f -
    local rc=$?
    unset CRB_NAME SA_NAME NAMESPACE CLUSTER_ROLE
    
    if [ $rc -eq 0 ]; then
        print_success "ClusterRoleBinding created (SA: $sa_name, Role: $cluster_role)"
    fi
}

_mcp_deploy_buildconfig() {
    local target_ns="$1" read_only="$2" toolsets="$3" repo_url="$4"
    
    print_step "Creating BuildConfig from GitHub..."
    
    if oc get bc kubernetes-mcp-server -n "$target_ns" &>/dev/null; then
        print_info "BuildConfig already exists, starting new build..."
        oc start-build kubernetes-mcp-server -n "$target_ns" --follow 2>&1 || true
    else
        oc new-build "$repo_url" \
            --name=kubernetes-mcp-server \
            --strategy=docker \
            --dockerfile='FROM registry.access.redhat.com/ubi9/go-toolset:latest AS builder
WORKDIR /opt/app-root/src
RUN git clone --depth=1 https://github.com/openshift/openshift-mcp-server.git . && \
    CGO_ENABLED=0 go build -o /opt/app-root/kubernetes-mcp-server ./cmd/kubernetes-mcp-server/
FROM registry.access.redhat.com/ubi9-micro:latest
COPY --from=builder /opt/app-root/kubernetes-mcp-server /usr/local/bin/kubernetes-mcp-server
USER 1001
ENTRYPOINT ["kubernetes-mcp-server"]' \
            -n "$target_ns" 2>&1
        
        print_step "Waiting for build to complete (this may take 2-3 minutes)..."
        oc logs -f bc/kubernetes-mcp-server -n "$target_ns" 2>&1 | tail -5
    fi
    
    local elapsed=0
    while [ $elapsed -lt 30 ]; do
        if oc get istag kubernetes-mcp-server:latest -n "$target_ns" &>/dev/null; then
            break
        fi
        sleep 3
        elapsed=$((elapsed + 3))
    done
    
    print_step "Deploying from built image..."
    
    local args="--port=8080 --stateless"
    if [ "$read_only" = "true" ]; then
        args="$args --read-only"
    fi
    args="$args --toolsets=$toolsets"
    
    local cluster_role
    cluster_role=$([ "$read_only" = "true" ] && echo "view" || echo "edit")
    local mcp_image="image-registry.openshift-image-registry.svc:5000/${target_ns}/kubernetes-mcp-server:latest"
    local mcp_args
    mcp_args=$(echo "$args" | sed 's/ /", "/g' | sed 's/^/["/;s/$/"]/')
    
    export NAMESPACE="$target_ns"
    export CLUSTER_ROLE="$cluster_role"
    export MCP_SERVER_IMAGE="$mcp_image"
    export MCP_SERVER_ARGS="$mcp_args"
    envsubst < "$ROOT_DIR/lib/manifests/mcp/kubernetes-mcp-server.yaml" | oc apply -f - -n "$target_ns"
    local rc=$?
    unset NAMESPACE CLUSTER_ROLE MCP_SERVER_IMAGE MCP_SERVER_ARGS
    
    return $rc
}

_mcp_deploy_local_build() {
    local target_ns="$1" read_only="$2" toolsets="$3" repo_url="$4"
    
    local container_cmd=""
    if command -v podman &>/dev/null; then
        container_cmd="podman"
    elif command -v docker &>/dev/null; then
        container_cmd="docker"
    else
        print_error "Neither podman nor docker found"
        return 1
    fi
    
    print_step "Cloning repository..."
    local tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" RETURN
    
    git clone --depth=1 "$repo_url" "$tmpdir/repo" 2>&1 | tail -1
    
    if [ ! -f "$tmpdir/repo/Dockerfile.ocp" ] && [ ! -f "$tmpdir/repo/Dockerfile" ]; then
        print_error "Dockerfile not found in cloned repo"
        return 1
    fi
    
    local dockerfile="Dockerfile.ocp"
    [ ! -f "$tmpdir/repo/$dockerfile" ] && dockerfile="Dockerfile"
    
    print_step "Building image with $container_cmd..."
    $container_cmd build -f "$tmpdir/repo/$dockerfile" -t kubernetes-mcp-server:latest "$tmpdir/repo" 2>&1 | tail -5
    
    if [ $? -ne 0 ]; then
        print_error "Container build failed"
        return 1
    fi
    
    print_step "Pushing to cluster internal registry..."
    local registry=""
    registry=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null)
    
    if [ -z "$registry" ]; then
        oc patch configs.imageregistry.operator.openshift.io/cluster --type merge \
            -p '{"spec":{"defaultRoute":true}}' 2>/dev/null || true
        sleep 5
        registry=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null)
    fi
    
    if [ -z "$registry" ]; then
        print_error "Could not get cluster registry route"
        print_info "Expose it with: oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{\"spec\":{\"defaultRoute\":true}}'"
        return 1
    fi
    
    $container_cmd login -u "$(oc whoami)" -p "$(oc whoami -t)" "$registry" --tls-verify=false 2>&1
    $container_cmd tag kubernetes-mcp-server:latest "$registry/$target_ns/kubernetes-mcp-server:latest"
    $container_cmd push "$registry/$target_ns/kubernetes-mcp-server:latest" --tls-verify=false 2>&1
    
    if [ $? -ne 0 ]; then
        print_error "Push to registry failed"
        return 1
    fi
    
    print_success "Image pushed to cluster registry"
    
    local args="--port=8080 --stateless"
    if [ "$read_only" = "true" ]; then
        args="$args --read-only"
    fi
    args="$args --toolsets=$toolsets"
    
    local cluster_role
    cluster_role=$([ "$read_only" = "true" ] && echo "view" || echo "edit")
    local mcp_image="image-registry.openshift-image-registry.svc:5000/${target_ns}/kubernetes-mcp-server:latest"
    local mcp_args
    mcp_args=$(echo "$args" | sed 's/ /", "/g' | sed 's/^/["/;s/$/"]/')
    
    export NAMESPACE="$target_ns"
    export CLUSTER_ROLE="$cluster_role"
    export MCP_SERVER_IMAGE="$mcp_image"
    export MCP_SERVER_ARGS="$mcp_args"
    envsubst < "$ROOT_DIR/lib/manifests/mcp/kubernetes-mcp-server.yaml" | oc apply -f - -n "$target_ns"
    local rc=$?
    unset NAMESPACE CLUSTER_ROLE MCP_SERVER_IMAGE MCP_SERVER_ARGS
    
    cd - &>/dev/null
    return $rc
}

_mcp_deploy_manifest() {
    local target_ns="$1"
    
    local manifest_file="$ROOT_DIR/lib/manifests/demo/mcp-kubernetes.yaml"
    
    if [ -f "$manifest_file" ]; then
        print_step "Applying bundled manifest (legacy image)..."
        oc apply -f "$manifest_file" -n "$target_ns"
        return $?
    else
        print_error "Manifest not found: $manifest_file"
        return 1
    fi
}

################################################################################
# Gateway-based MCP Server Deployment
################################################################################

setup_mcp_gateway() {
    print_step "Setting up MCP Gateway infrastructure..."

    local mcp_manifest_dir="$ROOT_DIR/lib/manifests/mcp"
    local MCP_GATEWAY_VERSION="${MCP_GATEWAY_VERSION:-0.7.1}"

    oc apply -f "$mcp_manifest_dir/namespace.yaml"

    if oc get crd mcpgatewayextensions.mcp.kuadrant.io &>/dev/null; then
        print_info "MCP Gateway CRDs already installed"
    else
        print_step "Installing MCP Gateway CRDs (v${MCP_GATEWAY_VERSION})..."
        if oc apply -k "https://github.com/kuadrant/mcp-gateway/config/crd?ref=v${MCP_GATEWAY_VERSION}" 2>/dev/null; then
            print_success "MCP Gateway CRDs installed"
        else
            print_warning "Failed to install MCP Gateway CRDs — gateway routing will not work"
            return 1
        fi
    fi

    oc apply -f "$mcp_manifest_dir/mcp-gateway.yaml"
    oc rollout status deployment/mcp-gateway-controller -n mcp-gateway-system --timeout=120s 2>/dev/null || true

    if oc get crd mcpgatewayextensions.mcp.kuadrant.io &>/dev/null; then
        oc apply -f "$mcp_manifest_dir/mcp-gateway-extension.yaml"
    fi

    print_success "MCP Gateway infrastructure ready"
}

setup_mcp_gateway_listener() {
    print_step "Adding MCP listener to maas-default-gateway..."

    local CLUSTER_DOMAIN
    CLUSTER_DOMAIN=$(oc get ingress.config cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
    if [ -z "$CLUSTER_DOMAIN" ]; then
        print_error "Could not detect cluster domain"
        return 1
    fi

    local existing_listeners
    existing_listeners=$(oc get gateway maas-default-gateway -n openshift-ingress -o jsonpath='{.spec.listeners[*].name}' 2>/dev/null || echo "")
    if echo "$existing_listeners" | grep -q "mcp"; then
        print_info "MCP listener already exists on maas-default-gateway [SKIP]"
        return 0
    fi

    export CLUSTER_DOMAIN
    local MCP_LISTENER
    MCP_LISTENER=$(envsubst '${CLUSTER_DOMAIN}' <<'PATCH_EOF'
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
        print_info "MCP endpoint: https://mcp.${CLUSTER_DOMAIN}/mcp"
    else
        print_warning "Failed to patch gateway — apply lib/manifests/mcp/gateway-mcp-listener.yaml manually"
    fi
}

deploy_mcp_server() {
    local server_name="$1"
    local mcp_manifest_dir="$ROOT_DIR/lib/manifests/mcp"
    local manifest_file="$mcp_manifest_dir/${server_name}.yaml"

    if [ ! -f "$manifest_file" ]; then
        print_error "Manifest not found: $manifest_file"
        return 1
    fi

    oc create namespace mcp-servers 2>/dev/null || true

    print_step "Deploying $server_name..."
    oc apply -f "$manifest_file"

    local deploy_name="mcp-${server_name}"
    if [ "$server_name" = "ocp-mcp-server" ]; then
        deploy_name="ocp-mcp-server"
    fi

    if oc rollout status deployment/"$deploy_name" -n mcp-servers --timeout=300s 2>/dev/null; then
        print_success "$server_name deployed"
    else
        print_warning "$server_name may still be starting"
    fi
}

deploy_mcp_httproutes() {
    local mcp_manifest_dir="$ROOT_DIR/lib/manifests/mcp"

    local CLUSTER_DOMAIN
    CLUSTER_DOMAIN=$(oc get ingress.config cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
    if [ -z "$CLUSTER_DOMAIN" ]; then
        print_error "Could not detect cluster domain"
        return 1
    fi

    export CLUSTER_DOMAIN
    print_step "Applying HTTPRoutes for MCP servers..."
    envsubst '${CLUSTER_DOMAIN}' < "$mcp_manifest_dir/httproutes.yaml" | oc apply -f -
    print_success "HTTPRoutes applied"
    print_info "MCP servers accessible via: https://mcp.${CLUSTER_DOMAIN}/mcp"
}

deploy_all_mcp_servers() {
    print_header "Deploy All MCP Servers (Gateway-based)"

    local servers=("context7" "code-sandbox" "searxng" "ocp-mcp-server")
    local build_servers=("codebase-search" "repo-docs")

    setup_mcp_gateway
    setup_mcp_gateway_listener

    for server in "${servers[@]}"; do
        deploy_mcp_server "$server"
    done

    for server in "${build_servers[@]}"; do
        deploy_mcp_server "$server"
    done

    deploy_mcp_httproutes

    echo ""
    print_header "MCP Server Deployment Summary"
    echo ""
    print_info "MCP Servers (mcp-servers namespace):"
    oc get deployment -n mcp-servers --no-headers 2>/dev/null | while read -r line; do
        echo "  $line"
    done
    echo ""
    local CLUSTER_DOMAIN
    CLUSTER_DOMAIN=$(oc get ingress.config cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
    print_success "MCP endpoint: https://mcp.${CLUSTER_DOMAIN}/mcp"
}
