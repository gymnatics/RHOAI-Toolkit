#!/bin/bash
################################################################################
# demos.sh — General demo deployment functions (Open WebUI, GuideLLM)
################################################################################
# Provides:
#   deploy_open_webui    — Deploy Open WebUI chat interface
#   deploy_guidellm      — Deploy GuideLLM benchmarking tool
################################################################################

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || true

deploy_open_webui() {
    print_header "Deploy Open WebUI"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
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
    echo -e "${CYAN}Detecting deployed models...${NC}"
    local models=$(oc get inferenceservice -n "$target_ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    local model_urls=""
    
    if [ -n "$models" ]; then
        echo "Found models in $target_ns:"
        for model in $models; do
            local url="http://${model}-predictor.${target_ns}.svc.cluster.local:8080/v1"
            echo "  • $model → $url"
            if [ -z "$model_urls" ]; then
                model_urls="$url"
            else
                model_urls="${model_urls};${url}"
            fi
        done
    else
        echo "No models found in $target_ns"
        local all_models=$(oc get inferenceservice -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} {end}' 2>/dev/null)
        if [ -n "$all_models" ]; then
            echo ""
            echo "Models in other namespaces:"
            for m in $all_models; do
                local ns=$(echo "$m" | cut -d'/' -f1)
                local name=$(echo "$m" | cut -d'/' -f2)
                echo "  • $name (namespace: $ns)"
            done
        fi
    fi
    
    echo ""
    read -p "Enter model URL(s) [semicolon-separated, or press Enter for detected]: " custom_urls
    if [ -n "$custom_urls" ]; then
        model_urls="$custom_urls"
    fi
    
    if [ -z "$model_urls" ]; then
        print_warning "No model URLs configured. You can add them later via ConfigMap."
        model_urls="http://localhost:8080/v1"
    fi
    
    echo ""
    echo -e "${CYAN}This will deploy:${NC}"
    echo "  • Open WebUI (web interface for chatting with models)"
    echo "  • 2Gi persistent storage for data"
    echo "  • Route for external access"
    echo ""
    echo "Model URL(s): $model_urls"
    echo ""
    
    read -p "Proceed? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Cancelled"
        return 0
    fi
    
    print_step "Deploying Open WebUI..."
    
    local manifest_file="$ROOT_DIR/lib/manifests/demo/open-webui.yaml"
    
    if [ -f "$manifest_file" ]; then
        export MODEL_URL="$model_urls"
        sed -e "s|\${MODEL_URL:-http://localhost:8080/v1}|$model_urls|g" \
            "$manifest_file" | oc apply -n "$target_ns" -f -
        unset MODEL_URL
    else
        print_info "Using external Open WebUI manifest..."
        oc apply -f https://raw.githubusercontent.com/tsailiming/openshift-open-webui/refs/heads/main/open-webui.yaml -n "$target_ns"
        
        oc patch configmap openwebui-config -n "$target_ns" --type merge \
            -p "{\"data\":{\"OPENAI_API_BASE_URLS\":\"$model_urls\",\"OPENAI_API_KEYS\":\"\"}}" 2>/dev/null || true
    fi
    
    oc set env deploy/open-webui ENABLE_PERSISTENT_CONFIG=False -n "$target_ns" 2>/dev/null || true
    
    print_step "Waiting for Open WebUI to be ready..."
    if oc rollout status deployment/open-webui -n "$target_ns" --timeout=180s; then
        print_success "Open WebUI deployed"
    else
        print_warning "Open WebUI may still be starting"
    fi
    
    local route_url=$(oc get route open-webui -n "$target_ns" -o jsonpath='{.spec.host}' 2>/dev/null)
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ Open WebUI Deployed Successfully!                          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    if [ -n "$route_url" ]; then
        echo -e "${CYAN}🌐 Access URL:${NC} https://$route_url"
    fi
    echo ""
    echo -e "${CYAN}📋 Configuration:${NC}"
    echo "   • Model URLs: $model_urls"
    echo "   • Auth disabled (workshop mode)"
    echo ""
    echo -e "${YELLOW}📝 To add more models later:${NC}"
    echo "   oc patch configmap openwebui-config -n $target_ns --type merge \\"
    echo "     -p '{\"data\":{\"OPENAI_API_BASE_URLS\":\"url1;url2\"}}'"
    echo "   oc rollout restart deployment/open-webui -n $target_ns"
    echo ""
    
    return 0
}

deploy_guidellm() {
    print_header "Deploy GuideLLM - LLM Benchmarking Tool"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    echo ""
    
    echo -e "${CYAN}Target Namespace Configuration:${NC}"
    local current_project=$(oc project -q 2>/dev/null)
    echo "Current project: $current_project"
    echo ""
    read -p "Enter target namespace [default: $current_project]: " target_ns
    target_ns="${target_ns:-$current_project}"
    
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_step "Creating namespace $target_ns..."
        oc create namespace "$target_ns"
    fi
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  GuideLLM - LLM Benchmarking Tool                              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "GuideLLM measures key LLM performance metrics:"
    echo "  • TTFT (Time to First Token)"
    echo "  • ITL (Inter-Token Latency)"
    echo "  • Request Latency"
    echo "  • Throughput (tokens/sec)"
    echo ""
    
    echo -e "${CYAN}Model Endpoint Configuration:${NC}"
    echo ""
    
    local detected_models=$(oc get inferenceservice -n "$target_ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if [ -n "$detected_models" ]; then
        echo -e "${GREEN}Detected InferenceServices in $target_ns:${NC}"
        for model in $detected_models; do
            local model_url=$(oc get inferenceservice "$model" -n "$target_ns" -o jsonpath='{.status.url}' 2>/dev/null)
            echo "  • $model: $model_url"
        done
        echo ""
    fi
    
    read -p "Enter model endpoint URL (e.g., http://model-predictor.$target_ns.svc.cluster.local:8080): " model_url
    read -p "Enter model name [default: model]: " model_name
    model_name="${model_name:-model}"
    
    echo ""
    read -p "Deploy GuideLLM to $target_ns? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Cancelled"
        return 0
    fi
    
    print_step "Deploying GuideLLM..."
    
    export MODEL_URL="$model_url"
    export MODEL_NAME="$model_name"
    envsubst < "$ROOT_DIR/lib/manifests/demo/guidellm-simple.yaml" | oc apply -n "$target_ns" -f -
    unset MODEL_URL MODEL_NAME
    
    print_step "Waiting for GuideLLM to be ready..."
    if oc rollout status deployment/guidellm -n "$target_ns" --timeout=120s; then
        print_success "GuideLLM deployed"
    else
        print_warning "GuideLLM may still be starting"
    fi
    
    local pod_name=$(oc get pod -l app=guidellm -n "$target_ns" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ GuideLLM Deployed Successfully!                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📋 How to Run Benchmarks:${NC}"
    echo ""
    echo "1. Shell into the GuideLLM pod:"
    echo -e "   ${YELLOW}oc rsh -n $target_ns $pod_name${NC}"
    echo ""
    echo "2. Run a throughput benchmark:"
    echo -e "   ${YELLOW}guidellm benchmark run \\\\${NC}"
    echo -e "   ${YELLOW}  --target \$TARGET \\\\${NC}"
    echo -e "   ${YELLOW}  --model \$MODEL \\\\${NC}"
    echo -e "   ${YELLOW}  --rate-type throughput \\\\${NC}"
    echo -e "   ${YELLOW}  --max-requests 100 \\\\${NC}"
    echo -e "   ${YELLOW}  --data \"prompt_tokens=768,output_tokens=768\"${NC}"
    echo ""
    echo "3. Run a latency benchmark:"
    echo -e "   ${YELLOW}guidellm benchmark run \\\\${NC}"
    echo -e "   ${YELLOW}  --target \$TARGET \\\\${NC}"
    echo -e "   ${YELLOW}  --model \$MODEL \\\\${NC}"
    echo -e "   ${YELLOW}  --rate-type constant \\\\${NC}"
    echo -e "   ${YELLOW}  --rate 1 \\\\${NC}"
    echo -e "   ${YELLOW}  --max-requests 50${NC}"
    echo ""
    echo -e "${CYAN}📊 Key Metrics to Watch:${NC}"
    echo "  • TTFT (Time to First Token) - How fast the model starts responding"
    echo "  • ITL (Inter-Token Latency) - Time between tokens"
    echo "  • Throughput - Tokens per second"
    echo "  • Request Latency - Total time per request"
    echo ""
    echo -e "${CYAN}🔧 Environment Variables (pre-configured):${NC}"
    echo "  • TARGET=$model_url"
    echo "  • MODEL=$model_name"
    echo ""
    
    return 0
}
