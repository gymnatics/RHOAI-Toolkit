#!/bin/bash
################################################################################
# llamastack.sh — LlamaStack distribution deployment and provider configuration
################################################################################
# Provides:
#   deploy_llamastack_demo_interactive    — Deploy LlamaStack Demo UI (interactive)
#   deploy_llamastack_distribution_generic — Deploy LlamaStack (standalone, no demo)
#   show_llm_provider_menu                — Display LLM provider selection menu
#   configure_vllm_provider               — Configure vLLM as LLM provider
#   configure_azure_provider              — Configure Azure OpenAI as LLM provider
#   configure_openai_provider             — Configure OpenAI as LLM provider
#   configure_ollama_provider             — Configure Ollama as LLM provider
#   configure_bedrock_provider            — Configure AWS Bedrock as LLM provider
#   deploy_llamastack_distribution        — Deploy LlamaStack distribution (for demo)
#   deploy_full_stack_with_llamastack     — Deploy LlamaStack + MCP + UI full stack
#   deploy_complete_llamastack_demo       — Deploy demo stack (existing LlamaStack)
################################################################################

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || true

deploy_llamastack_demo_interactive() {
    print_header "Deploy LlamaStack Demo UI"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    
    local demo_dir="$ROOT_DIR/demo/llamastack-demo"
    if [ ! -d "$demo_dir" ]; then
        print_error "LlamaStack demo directory not found"
        echo ""
        echo "Expected: $demo_dir"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           LlamaStack + MCP Demo UI                             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}This will deploy a Streamlit-based chatbot frontend that:${NC}"
    echo "  • Connects to your LlamaStack distribution"
    echo "  • Shows MCP tool calls in real-time"
    echo "  • Provides a chat interface for testing AI agents"
    echo "  • Is fully configurable via environment variables"
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
    echo -e "${CYAN}LlamaStack Configuration:${NC}"
    echo ""
    
    local detected_llamastack=""
    detected_llamastack=$(oc get svc -n "$target_ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -E "llama|lsd" | head -1)
    
    if [ -n "$detected_llamastack" ]; then
        local default_llamastack_url="http://${detected_llamastack}.${target_ns}.svc.cluster.local:8321"
        echo "Detected LlamaStack service: $detected_llamastack"
    else
        local default_llamastack_url="http://lsd-genai-playground-service.${target_ns}.svc.cluster.local:8321"
        echo "No LlamaStack service auto-detected"
    fi
    
    read -p "LlamaStack URL [$default_llamastack_url]: " llamastack_url
    llamastack_url="${llamastack_url:-$default_llamastack_url}"
    
    read -p "Model ID [qwen3-8b]: " model_id
    model_id="${model_id:-qwen3-8b}"
    
    local detected_mcp=""
    detected_mcp=$(oc get svc -n "$target_ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -i mcp | head -1)
    
    if [ -n "$detected_mcp" ]; then
        local default_mcp_url="http://${detected_mcp}.${target_ns}.svc.cluster.local:8000"
        echo "Detected MCP service: $detected_mcp"
    else
        local default_mcp_url="http://mcp-server.${target_ns}.svc.cluster.local:8000"
    fi
    
    read -p "MCP Server URL [$default_mcp_url]: " mcp_url
    mcp_url="${mcp_url:-$default_mcp_url}"
    
    echo ""
    echo -e "${CYAN}UI Customization (optional, press Enter to use defaults):${NC}"
    echo ""
    
    read -p "App Title [LlamaStack + MCP Demo]: " app_title
    app_title="${app_title:-LlamaStack + MCP Demo}"
    
    read -p "MCP Server Name [MCP Server]: " mcp_name
    mcp_name="${mcp_name:-MCP Server}"
    
    echo ""
    echo -e "${CYAN}Deployment Summary:${NC}"
    echo "  Namespace: $target_ns"
    echo "  LlamaStack URL: $llamastack_url"
    echo "  Model ID: $model_id"
    echo "  MCP Server URL: $mcp_url"
    echo "  App Title: $app_title"
    echo ""
    
    read -p "Proceed with deployment? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Deployment cancelled"
        return 0
    fi
    
    echo ""
    print_step "Applying ConfigMap and Deployment manifests..."
    
    sed -e "s/namespace: demo-test/namespace: $target_ns/g" \
        -e "s|demo-test/|$target_ns/|g" \
        -e "s|LLAMASTACK_URL:.*|LLAMASTACK_URL: \"$llamastack_url\"|g" \
        -e "s|MODEL_ID:.*|MODEL_ID: \"$model_id\"|g" \
        -e "s|MCP_SERVER_URL:.*|MCP_SERVER_URL: \"$mcp_url\"|g" \
        -e "s|APP_TITLE:.*|APP_TITLE: \"$app_title\"|g" \
        -e "s|MCP_SERVER_NAME:.*|MCP_SERVER_NAME: \"$mcp_name\"|g" \
        "$demo_dir/deployment.yaml" | oc apply -f -
    
    print_step "Creating BuildConfig and ImageStream..."
    _mcp_apply_manifest "$demo_dir/buildconfig.yaml" "$target_ns"
    
    echo ""
    print_step "Building container image (this may take 1-2 minutes)..."
    echo ""
    
    if oc start-build llamastack-mcp-demo --from-dir="$demo_dir" --follow -n "$target_ns"; then
        print_success "Build completed successfully"
    else
        print_error "Build failed"
        echo ""
        echo "You can check build logs with:"
        echo "  oc logs -f bc/llamastack-mcp-demo -n $target_ns"
        return 1
    fi
    
    echo ""
    print_step "Waiting for deployment to be ready..."
    if oc rollout status deployment/llamastack-mcp-demo -n "$target_ns" --timeout=120s; then
        print_success "Deployment ready"
    else
        print_warning "Deployment may still be starting"
    fi
    
    echo ""
    print_step "Getting application URL..."
    local route_url=$(oc get route llamastack-mcp-demo -n "$target_ns" -o jsonpath='{.spec.host}' 2>/dev/null)
    
    if [ -n "$route_url" ]; then
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✅ LlamaStack Demo UI Deployed Successfully!                  ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}📌 Application URL:${NC}"
        echo -e "   ${GREEN}https://$route_url${NC}"
        echo ""
        echo -e "${CYAN}📋 Configuration:${NC}"
        echo "   • Namespace: $target_ns"
        echo "   • LlamaStack: $llamastack_url"
        echo "   • Model: $model_id"
        echo "   • MCP Server: $mcp_url"
        echo ""
        echo -e "${YELLOW}📝 Next Steps:${NC}"
        echo "   1. Open the URL in your browser"
        echo "   2. Click '🔄 Check' in the sidebar to verify service status"
        echo "   3. Click '🔄 Refresh Tools' to load MCP tools"
        echo "   4. Start chatting!"
        echo ""
        echo -e "${CYAN}📚 To update configuration later:${NC}"
        echo "   oc edit configmap llamastack-demo-config -n $target_ns"
        echo "   oc rollout restart deployment/llamastack-mcp-demo -n $target_ns"
        echo ""
    else
        print_warning "Could not get route URL"
        echo "Check with: oc get route llamastack-mcp-demo -n $target_ns"
    fi
    
    return 0
}

################################################################################
# LlamaStack Provider Configuration
################################################################################

show_llm_provider_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 Select LLM Provider                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Choose your LLM backend:${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} vLLM (RHOAI Model Serving / KServe)"
    echo "    → Use a model deployed via OpenShift AI Model Serving"
    echo ""
    echo -e "${YELLOW}2)${NC} Azure OpenAI"
    echo "    → Connect to Azure OpenAI Service (GPT-4, GPT-4o, etc.)"
    echo ""
    echo -e "${YELLOW}3)${NC} OpenAI"
    echo "    → Connect to OpenAI API (GPT-4, GPT-4o, etc.)"
    echo ""
    echo -e "${YELLOW}4)${NC} Ollama"
    echo "    → Connect to an Ollama server"
    echo ""
    echo -e "${YELLOW}5)${NC} AWS Bedrock"
    echo "    → Connect to AWS Bedrock (Claude, Llama, etc.)"
    echo ""
}

configure_vllm_provider() {
    local target_ns="$1"
    
    echo ""
    print_step "Configuring vLLM provider..."
    echo ""
    
    local detected_is=""
    detected_is=$(oc get inferenceservice -n "$target_ns" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    
    if [ -n "$detected_is" ]; then
        local detected_url=$(oc get inferenceservice "$detected_is" -n "$target_ns" -o jsonpath='{.status.url}' 2>/dev/null || true)
        print_info "Detected InferenceService: $detected_is"
        if [ -n "$detected_url" ]; then
            print_info "URL: $detected_url"
        fi
        echo ""
    fi
    
    read -p "vLLM/Model Serving URL (e.g., https://model-name.apps.cluster.example.com): " VLLM_URL
    if [ -z "$VLLM_URL" ]; then
        print_error "vLLM URL is required"
        return 1
    fi
    
    read -p "Model ID (e.g., qwen3-8b, llama-3-8b): " MODEL_ID
    MODEL_ID="${MODEL_ID:-qwen3-8b}"
    
    read -p "API Token (leave empty if not required): " VLLM_API_TOKEN
    
    print_step "Creating vLLM secret..."
    export NAMESPACE="$target_ns"
    export VLLM_URL
    export VLLM_API_TOKEN="${VLLM_API_TOKEN:-}"
    envsubst < "$ROOT_DIR/lib/manifests/llamastack/vllm-secret.yaml" | oc apply -f -
    unset NAMESPACE
    
    DISTRIBUTION_ENV_VARS=$(cat <<'ENVEOF'
      - name: VLLM_URL
        valueFrom:
          secretKeyRef:
            name: vllm-secret
            key: url
      - name: VLLM_API_TOKEN
        valueFrom:
          secretKeyRef:
            name: vllm-secret
            key: api-token
      - name: VLLM_TLS_VERIFY
        value: "false"
      - name: VLLM_MAX_TOKENS
        value: "4096"
ENVEOF
    )
    
    LLM_PROVIDER="vllm"
    CONFIG_FILE="$ROOT_DIR/demo/llamastack-demo/llamastack/llamastack-config-vllm.yaml"
}

configure_azure_provider() {
    local target_ns="$1"
    
    echo ""
    print_step "Configuring Azure OpenAI provider..."
    echo ""
    
    read -p "Azure OpenAI Endpoint (e.g., https://your-resource.openai.azure.com): " AZURE_ENDPOINT
    if [ -z "$AZURE_ENDPOINT" ]; then
        print_error "Azure endpoint is required"
        return 1
    fi
    
    read -p "Deployment Name (e.g., gpt-4o): " AZURE_DEPLOYMENT
    AZURE_DEPLOYMENT="${AZURE_DEPLOYMENT:-gpt-4o}"
    MODEL_ID="$AZURE_DEPLOYMENT"
    
    read -p "API Key: " AZURE_API_KEY
    if [ -z "$AZURE_API_KEY" ]; then
        print_error "API key is required"
        return 1
    fi
    
    read -p "API Version [2024-08-01-preview]: " AZURE_API_VERSION
    AZURE_API_VERSION="${AZURE_API_VERSION:-2024-08-01-preview}"
    
    print_step "Creating Azure OpenAI secret..."
    export NAMESPACE="$target_ns"
    export AZURE_ENDPOINT AZURE_DEPLOYMENT AZURE_API_KEY AZURE_API_VERSION
    envsubst < "$ROOT_DIR/lib/manifests/llamastack/azure-openai-secret.yaml" | oc apply -f -
    unset NAMESPACE
    
    DISTRIBUTION_ENV_VARS=$(cat <<'ENVEOF'
      - name: AZURE_OPENAI_ENDPOINT
        valueFrom:
          secretKeyRef:
            name: azure-openai-secret
            key: endpoint
      - name: AZURE_OPENAI_API_KEY
        valueFrom:
          secretKeyRef:
            name: azure-openai-secret
            key: api-key
      - name: AZURE_OPENAI_DEPLOYMENT
        valueFrom:
          secretKeyRef:
            name: azure-openai-secret
            key: deployment
      - name: AZURE_OPENAI_API_VERSION
        valueFrom:
          secretKeyRef:
            name: azure-openai-secret
            key: api-version
ENVEOF
    )
    
    LLM_PROVIDER="azure"
    CONFIG_FILE="$ROOT_DIR/demo/llamastack-demo/llamastack/llamastack-config-azure.yaml"
}

configure_openai_provider() {
    local target_ns="$1"
    
    echo ""
    print_step "Configuring OpenAI provider..."
    echo ""
    
    read -p "OpenAI API Key: " OPENAI_API_KEY
    if [ -z "$OPENAI_API_KEY" ]; then
        print_error "API key is required"
        return 1
    fi
    
    read -p "Model ID [gpt-4o]: " MODEL_ID
    MODEL_ID="${MODEL_ID:-gpt-4o}"
    
    print_step "Creating OpenAI secret..."
    export NAMESPACE="$target_ns"
    export OPENAI_API_KEY
    envsubst < "$ROOT_DIR/lib/manifests/llamastack/openai-secret.yaml" | oc apply -f -
    unset NAMESPACE
    
    DISTRIBUTION_ENV_VARS=$(cat <<'ENVEOF'
      - name: OPENAI_API_KEY
        valueFrom:
          secretKeyRef:
            name: openai-secret
            key: api-key
ENVEOF
    )
    
    LLM_PROVIDER="openai"
    CONFIG_FILE="$ROOT_DIR/demo/llamastack-demo/llamastack/llamastack-config-openai.yaml"
}

configure_ollama_provider() {
    local target_ns="$1"
    
    echo ""
    print_step "Configuring Ollama provider..."
    echo ""
    
    read -p "Ollama URL [http://ollama.${target_ns}.svc.cluster.local:11434]: " OLLAMA_URL
    OLLAMA_URL="${OLLAMA_URL:-http://ollama.${target_ns}.svc.cluster.local:11434}"
    
    read -p "Model ID [llama3.2]: " MODEL_ID
    MODEL_ID="${MODEL_ID:-llama3.2}"
    
    DISTRIBUTION_ENV_VARS=$(cat <<ENVEOF
      - name: OLLAMA_URL
        value: "$OLLAMA_URL"
ENVEOF
    )
    
    LLM_PROVIDER="ollama"
    CONFIG_FILE="$ROOT_DIR/demo/llamastack-demo/llamastack/llamastack-config-ollama.yaml"
}

configure_bedrock_provider() {
    local target_ns="$1"
    
    echo ""
    print_step "Configuring AWS Bedrock provider..."
    echo ""
    
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
    if [ -z "$AWS_ACCESS_KEY_ID" ]; then
        print_error "AWS Access Key ID is required"
        return 1
    fi
    
    read -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        print_error "AWS Secret Access Key is required"
        return 1
    fi
    
    read -p "AWS Region [us-east-1]: " AWS_REGION
    AWS_REGION="${AWS_REGION:-us-east-1}"
    
    read -p "Model ID [anthropic.claude-3-sonnet-20240229-v1:0]: " MODEL_ID
    MODEL_ID="${MODEL_ID:-anthropic.claude-3-sonnet-20240229-v1:0}"
    
    print_step "Creating Bedrock secret..."
    export NAMESPACE="$target_ns"
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION
    envsubst < "$ROOT_DIR/lib/manifests/llamastack/bedrock-secret.yaml" | oc apply -f -
    unset NAMESPACE
    
    DISTRIBUTION_ENV_VARS=$(cat <<'ENVEOF'
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: bedrock-secret
            key: aws-access-key-id
      - name: AWS_SECRET_ACCESS_KEY
        valueFrom:
          secretKeyRef:
            name: bedrock-secret
            key: aws-secret-access-key
      - name: AWS_REGION
        valueFrom:
          secretKeyRef:
            name: bedrock-secret
            key: aws-region
ENVEOF
    )
    
    LLM_PROVIDER="bedrock"
    CONFIG_FILE="$ROOT_DIR/demo/llamastack-demo/llamastack/llamastack-config-bedrock.yaml"
}

################################################################################
# LlamaStack Distribution Deployment
################################################################################

deploy_llamastack_distribution_generic() {
    local target_ns="$1"
    
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Deploying LlamaStack Distribution${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    show_llm_provider_menu
    read -p "Enter your choice [1]: " provider_choice
    provider_choice="${provider_choice:-1}"
    
    case $provider_choice in
        1) configure_vllm_provider "$target_ns" || return 1 ;;
        2) configure_azure_provider "$target_ns" || return 1 ;;
        3) configure_openai_provider "$target_ns" || return 1 ;;
        4) configure_ollama_provider "$target_ns" || return 1 ;;
        5) configure_bedrock_provider "$target_ns" || return 1 ;;
        *) print_error "Invalid choice"; return 1 ;;
    esac
    
    echo ""
    read -p "Do you want to configure an MCP server? (y/N): " configure_mcp
    local mcp_config=""
    if [[ "$configure_mcp" =~ ^[Yy]$ ]]; then
        read -p "MCP Server Name (e.g., weather-data): " mcp_name
        mcp_name="${mcp_name:-custom-mcp}"
        read -p "MCP Server URL (e.g., http://my-mcp-server.ns.svc.cluster.local:8000/mcp): " mcp_url
        if [ -n "$mcp_url" ]; then
            mcp_config="    - toolgroup_id: mcp::$mcp_name
      provider_id: model-context-protocol
      mcp_endpoint:
        uri: $mcp_url"
        fi
    fi
    
    print_step "Creating LlamaStack ConfigMap..."
    
    if [ -n "$mcp_config" ]; then
        sed -e "s/NAMESPACE_PLACEHOLDER/$target_ns/g" \
            -e "s/MODEL_ID_PLACEHOLDER/$MODEL_ID/g" \
            -e "s|uri: http://weather-mcp-server.*|# Custom MCP configured below|g" \
            "$CONFIG_FILE" | \
        awk -v mcp="$mcp_config" '
            /toolgroup_id: mcp::weather-data/ { 
                print mcp
                getline; getline; getline
                next
            }
            { print }
        ' | oc apply -f -
    else
        sed -e "s/NAMESPACE_PLACEHOLDER/$target_ns/g" \
            -e "s/MODEL_ID_PLACEHOLDER/$MODEL_ID/g" \
            "$CONFIG_FILE" | \
        awk '
            /toolgroup_id: mcp::weather-data/,/uri:.*mcp$/ { next }
            { print }
        ' | oc apply -f -
    fi
    
    print_step "Creating LlamaStackDistribution..."
    
    local dist_file="$ROOT_DIR/demo/llamastack-demo/llamastack/llamastack-distribution.yaml"
    
    sed -e "s/NAMESPACE_PLACEHOLDER/$target_ns/g" "$dist_file" | \
    awk -v env_vars="$DISTRIBUTION_ENV_VARS" '
        /env:/ && !done {
            print
            print env_vars
            done=1
            next
        }
        { print }
    ' | oc apply -f -
    
    print_step "Waiting for LlamaStack pod to be ready..."
    sleep 5
    
    if oc wait --for=condition=available deployment -l llamastack.io/distribution=llamastack-demo -n "$target_ns" --timeout=180s 2>/dev/null; then
        print_success "LlamaStack is ready"
    else
        print_warning "LlamaStack may still be starting. Check with: oc get pods -n $target_ns"
    fi
    
    return 0
}

deploy_llamastack_distribution() {
    local target_ns="$1"
    
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Deploying LlamaStack Distribution${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    if ! oc get crd llamastackdistributions.llamastack.io &>/dev/null; then
        print_error "LlamaStackDistribution CRD not found!"
        echo ""
        echo "Please ensure:"
        echo "  1. Red Hat OpenShift AI 3.0+ is installed"
        echo "  2. LlamaStack operator is enabled in DataScienceCluster"
        echo ""
        echo "To enable LlamaStack in your DSC:"
        echo "  oc patch datasciencecluster default-dsc --type merge \\"
        echo "    -p '{\"spec\":{\"components\":{\"llamastackoperator\":{\"managementState\":\"Managed\"}}}}'"
        echo ""
        return 1
    fi
    
    print_success "LlamaStack CRD found"
    
    show_llm_provider_menu
    read -p "Enter your choice [1]: " provider_choice
    provider_choice="${provider_choice:-1}"
    
    case $provider_choice in
        1) configure_vllm_provider "$target_ns" || return 1 ;;
        2) configure_azure_provider "$target_ns" || return 1 ;;
        3) configure_openai_provider "$target_ns" || return 1 ;;
        4) configure_ollama_provider "$target_ns" || return 1 ;;
        5) configure_bedrock_provider "$target_ns" || return 1 ;;
        *) print_error "Invalid choice"; return 1 ;;
    esac
    
    print_step "Creating LlamaStack ConfigMap..."
    sed -e "s/NAMESPACE_PLACEHOLDER/$target_ns/g" \
        -e "s/MODEL_ID_PLACEHOLDER/$MODEL_ID/g" \
        "$CONFIG_FILE" | oc apply -f -
    
    print_step "Creating LlamaStackDistribution..."
    
    local dist_file="$ROOT_DIR/demo/llamastack-demo/llamastack/llamastack-distribution.yaml"
    
    sed -e "s/NAMESPACE_PLACEHOLDER/$target_ns/g" "$dist_file" | \
    awk -v env_vars="$DISTRIBUTION_ENV_VARS" '
        /env:/ && !done {
            print
            print env_vars
            done=1
            next
        }
        { print }
    ' | oc apply -f -
    
    print_step "Waiting for LlamaStack pod to be ready..."
    sleep 5
    
    if oc wait --for=condition=available deployment -l llamastack.io/distribution=llamastack-demo -n "$target_ns" --timeout=180s 2>/dev/null; then
        print_success "LlamaStack is ready"
    else
        print_warning "LlamaStack may still be starting. Check with: oc get pods -n $target_ns"
    fi
    
    LLAMASTACK_URL="http://llamastack-demo-service.${target_ns}.svc.cluster.local:8321"
    
    return 0
}

deploy_full_stack_with_llamastack() {
    print_header "Deploy Full Stack with LlamaStack"
    
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
    echo "  • LlamaStack Distribution (with your chosen LLM provider)"
    echo "  • Weather MCP Server (5 weather query tools)"
    echo "  • MongoDB with sample weather data"
    echo "  • Demo UI (Streamlit chatbot)"
    echo ""
    echo -e "${YELLOW}Requirements:${NC}"
    echo "  • RHOAI 3.0+ with LlamaStack operator enabled"
    echo "  • Access to your chosen LLM provider"
    echo ""
    
    read -p "Proceed? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Cancelled"
        return 0
    fi
    
    # Step 1: Deploy LlamaStack
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Step 1/3: Deploying LlamaStack${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    if ! deploy_llamastack_distribution "$target_ns"; then
        print_error "Failed to deploy LlamaStack"
        return 1
    fi
    
    # Step 2: Deploy MCP + MongoDB
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Step 2/3: Deploying Weather MCP Server + MongoDB${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    deploy_weather_mcp_server "$target_ns"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to deploy MCP server"
        return 1
    fi
    
    # Step 3: Deploy UI
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Step 3/3: Deploying LlamaStack Demo UI${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    local demo_dir="$ROOT_DIR/demo/llamastack-demo"
    local mcp_url="http://weather-mcp-server.${target_ns}.svc.cluster.local:8000"
    
    print_step "Applying ConfigMap and Deployment manifests..."
    
    sed -e "s/namespace: demo-test/namespace: $target_ns/g" \
        -e "s|demo-test/|$target_ns/|g" \
        -e "s|LLAMASTACK_URL:.*|LLAMASTACK_URL: \"$LLAMASTACK_URL\"|g" \
        -e "s|MODEL_ID:.*|MODEL_ID: \"$MODEL_ID\"|g" \
        -e "s|MCP_SERVER_URL:.*|MCP_SERVER_URL: \"$mcp_url\"|g" \
        -e "s|APP_TITLE:.*|APP_TITLE: \"LlamaStack + MCP Demo\"|g" \
        -e "s|APP_SUBTITLE:.*|APP_SUBTITLE: \"AI Agent with Weather Data Tools\"|g" \
        -e "s|MCP_SERVER_NAME:.*|MCP_SERVER_NAME: \"Weather MCP\"|g" \
        -e "s|MCP_SERVER_DESCRIPTION:.*|MCP_SERVER_DESCRIPTION: \"Provides weather data queries for 14 global airports\"|g" \
        -e "s|DATA_SOURCE_NAME:.*|DATA_SOURCE_NAME: \"MongoDB\"|g" \
        -e "s|CHAT_PLACEHOLDER:.*|CHAT_PLACEHOLDER: \"Ask about weather conditions...\"|g" \
        "$demo_dir/deployment.yaml" | oc apply -f -
    
    print_step "Creating BuildConfig..."
    _mcp_apply_manifest "$demo_dir/buildconfig.yaml" "$target_ns"
    
    echo ""
    print_step "Building Demo UI container..."
    if oc start-build llamastack-mcp-demo --from-dir="$demo_dir" --follow -n "$target_ns"; then
        print_success "Build completed"
    else
        print_error "Build failed"
        return 1
    fi
    
    echo ""
    print_step "Waiting for deployment..."
    if oc rollout status deployment/llamastack-mcp-demo -n "$target_ns" --timeout=120s; then
        print_success "Demo UI deployed"
    else
        print_warning "Deployment may still be starting"
    fi
    
    local route_url=$(oc get route llamastack-mcp-demo -n "$target_ns" -o jsonpath='{.spec.host}' 2>/dev/null)
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ Full LlamaStack Demo Stack Deployed!                       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📦 Deployed Components:${NC}"
    echo "   • LlamaStack: llamastack-demo-service.$target_ns.svc.cluster.local:8321"
    echo "   • Provider: $LLM_PROVIDER"
    echo "   • Model: $MODEL_ID"
    echo "   • MongoDB: mongodb.$target_ns.svc.cluster.local:27017"
    echo "   • Weather MCP: weather-mcp-server.$target_ns.svc.cluster.local:8000"
    echo ""
    echo -e "${CYAN}📌 Application URL:${NC}"
    echo -e "   ${GREEN}https://$route_url${NC}"
    echo ""
    echo -e "${CYAN}💡 MCP tools are pre-registered in LlamaStack config.${NC}"
    echo "   The Weather MCP tools should be available immediately."
    echo ""
    
    return 0
}

deploy_complete_llamastack_demo() {
    print_header "Deploy Complete LlamaStack Demo Stack"
    
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
    echo -e "${CYAN}LlamaStack Configuration:${NC}"
    echo ""
    
    local detected_llamastack=""
    detected_llamastack=$(oc get svc -n "$target_ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -E "llama|lsd" | head -1)
    
    if [ -n "$detected_llamastack" ]; then
        local default_llamastack_url="http://${detected_llamastack}.${target_ns}.svc.cluster.local:8321"
        echo "Detected LlamaStack service: $detected_llamastack"
    else
        local default_llamastack_url="http://lsd-genai-playground-service.${target_ns}.svc.cluster.local:8321"
        echo "No LlamaStack service auto-detected"
    fi
    
    read -p "LlamaStack URL [$default_llamastack_url]: " llamastack_url
    llamastack_url="${llamastack_url:-$default_llamastack_url}"
    
    read -p "Model ID [qwen3-8b]: " model_id
    model_id="${model_id:-qwen3-8b}"
    
    echo ""
    echo -e "${CYAN}This will deploy:${NC}"
    echo "  • MongoDB with sample weather data"
    echo "  • Weather MCP Server (5 weather query tools)"
    echo "  • LlamaStack Demo UI (Streamlit chatbot)"
    echo ""
    echo "  LlamaStack URL: $llamastack_url"
    echo "  Model ID: $model_id"
    echo ""
    
    read -p "Proceed with deployment? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Deployment cancelled"
        return 0
    fi
    
    # Step 1: Deploy MCP + MongoDB
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Step 1/2: Deploying Weather MCP Server + MongoDB${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    deploy_weather_mcp_server "$target_ns"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to deploy MCP server"
        return 1
    fi
    
    # Step 2: Deploy UI with the Weather MCP server
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Step 2/2: Deploying LlamaStack Demo UI${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    local demo_dir="$ROOT_DIR/demo/llamastack-demo"
    local mcp_url="http://weather-mcp-server.${target_ns}.svc.cluster.local:8000"
    
    echo ""
    print_step "Applying ConfigMap and Deployment manifests..."
    
    sed -e "s/namespace: demo-test/namespace: $target_ns/g" \
        -e "s|demo-test/|$target_ns/|g" \
        -e "s|LLAMASTACK_URL:.*|LLAMASTACK_URL: \"$llamastack_url\"|g" \
        -e "s|MODEL_ID:.*|MODEL_ID: \"$model_id\"|g" \
        -e "s|MCP_SERVER_URL:.*|MCP_SERVER_URL: \"$mcp_url\"|g" \
        -e "s|APP_TITLE:.*|APP_TITLE: \"LlamaStack + MCP Demo\"|g" \
        -e "s|APP_SUBTITLE:.*|APP_SUBTITLE: \"AI Agent with Weather Data Tools\"|g" \
        -e "s|MCP_SERVER_NAME:.*|MCP_SERVER_NAME: \"Weather MCP\"|g" \
        -e "s|MCP_SERVER_DESCRIPTION:.*|MCP_SERVER_DESCRIPTION: \"Provides weather data queries for 14 global airports\"|g" \
        -e "s|DATA_SOURCE_NAME:.*|DATA_SOURCE_NAME: \"MongoDB\"|g" \
        -e "s|CHAT_PLACEHOLDER:.*|CHAT_PLACEHOLDER: \"Ask about weather conditions...\"|g" \
        "$demo_dir/deployment.yaml" | oc apply -f -
    
    print_step "Creating BuildConfig..."
    _mcp_apply_manifest "$demo_dir/buildconfig.yaml" "$target_ns"
    
    echo ""
    print_step "Building Demo UI container..."
    if oc start-build llamastack-mcp-demo --from-dir="$demo_dir" --follow -n "$target_ns"; then
        print_success "Build completed"
    else
        print_error "Build failed"
        return 1
    fi
    
    echo ""
    print_step "Waiting for deployment..."
    if oc rollout status deployment/llamastack-mcp-demo -n "$target_ns" --timeout=120s; then
        print_success "Demo UI deployed"
    else
        print_warning "Deployment may still be starting"
    fi
    
    local route_url=$(oc get route llamastack-mcp-demo -n "$target_ns" -o jsonpath='{.spec.host}' 2>/dev/null)
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ Complete LlamaStack Demo Stack Deployed!                   ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📋 Deployed Components:${NC}"
    echo "   • MongoDB: mongodb.$target_ns.svc.cluster.local:27017"
    echo "   • Weather MCP Server: weather-mcp-server.$target_ns.svc.cluster.local:8000"
    echo "   • Demo UI: https://$route_url"
    echo ""
    echo -e "${CYAN}📌 Application URL:${NC}"
    echo -e "   ${GREEN}https://$route_url${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Important: Register MCP with LlamaStack${NC}"
    echo "   Add to your LlamaStack config under tool_groups:"
    echo ""
    echo "   - toolgroup_id: mcp::weather-data"
    echo "     provider_id: model-context-protocol"
    echo "     mcp_endpoint:"
    echo "       uri: http://weather-mcp-server.$target_ns.svc.cluster.local:8000/mcp"
    echo ""
    echo "   Then restart LlamaStack to load the new tools."
    echo ""
    
    return 0
}
