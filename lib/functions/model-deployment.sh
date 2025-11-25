#!/bin/bash
################################################################################
# Interactive Model Deployment with llm-d
################################################################################
# This function provides an interactive menu for deploying models using llm-d
# serving runtime after RHOAI installation.
################################################################################

# Interactive model deployment function
deploy_llmd_model_interactive() {
    print_header "Interactive Model Deployment with llm-d"
    
    echo -e "${YELLOW}Would you like to deploy a model now?${NC}"
    echo ""
    read -p "Deploy a model? (y/N): " deploy_choice
    
    if [[ ! "$deploy_choice" =~ ^[Yy]$ ]]; then
        print_info "Skipping model deployment. You can deploy later using:"
        echo "  ./scripts/deploy-llmd-model.sh"
        return 0
    fi
    
    echo ""
    print_header "Model Selection"
    
    # Pre-defined model catalog
    echo -e "${BLUE}Available models:${NC}"
    echo ""
    echo "  1) Qwen3-4B (FP8) - 4B params, tool calling support"
    echo "     oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest"
    echo ""
    echo "  2) Qwen3-8B (FP8) - 8B params, tool calling support"
    echo "     oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b-fp8-dynamic:latest"
    echo ""
    echo "  3) Llama 3.2-3B Instruct"
    echo "     oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct"
    echo ""
    echo "  4) Granite 3.0-8B Instruct"
    echo "     oci://quay.io/redhat-ai-services/modelcar-catalog:granite-3.0-8b-instruct"
    echo ""
    echo "  5) Custom model URI (enter your own)"
    echo ""
    
    read -p "Select a model (1-5): " model_choice
    
    local model_uri=""
    local model_name=""
    local default_gpu="1"
    local default_cpu="4"
    local default_memory="16Gi"
    local tool_calling_enabled=false
    
    case "$model_choice" in
        1)
            model_uri="oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest"
            model_name="qwen3-4b"
            default_gpu="1"
            default_cpu="4"
            default_memory="16Gi"
            tool_calling_enabled=true
            ;;
        2)
            model_uri="oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b-fp8-dynamic:latest"
            model_name="qwen3-8b"
            default_gpu="1"
            default_cpu="8"
            default_memory="32Gi"
            tool_calling_enabled=true
            ;;
        3)
            model_uri="oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct"
            model_name="llama-32-3b-instruct"
            default_gpu="1"
            default_cpu="4"
            default_memory="16Gi"
            ;;
        4)
            model_uri="oci://quay.io/redhat-ai-services/modelcar-catalog:granite-3.0-8b-instruct"
            model_name="granite-30-8b-instruct"
            default_gpu="1"
            default_cpu="8"
            default_memory="32Gi"
            ;;
        5)
            echo ""
            print_info "Enter custom model URI (e.g., oci://registry.example.com/model:tag):"
            read -p "Model URI: " model_uri
            
            if [ -z "$model_uri" ]; then
                print_error "No URI provided. Skipping model deployment."
                return 1
            fi
            
            print_info "Enter model name (alphanumeric, lowercase, hyphens only):"
            read -p "Model name: " model_name
            
            if [ -z "$model_name" ]; then
                print_error "No name provided. Skipping model deployment."
                return 1
            fi
            ;;
        *)
            print_error "Invalid selection. Skipping model deployment."
            return 1
            ;;
    esac
    
    echo ""
    print_success "Selected model: $model_name"
    print_info "URI: $model_uri"
    
    # Namespace selection
    echo ""
    print_header "Namespace Selection"
    
    echo -e "${BLUE}Available namespaces:${NC}"
    echo ""
    
    # List existing namespaces (filter out system namespaces)
    local namespaces=$(oc get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E '^(default|kube-|openshift-|redhat-|kuadrant-|cert-manager)' | sort)
    
    if [ -z "$namespaces" ]; then
        print_warning "No user namespaces found."
    else
        echo "$namespaces" | nl -w2 -s') '
    fi
    
    echo ""
    echo "  0) Create new namespace"
    echo ""
    
    read -p "Select namespace (enter number or name): " ns_choice
    
    local target_namespace=""
    
    if [ "$ns_choice" = "0" ]; then
        echo ""
        print_info "Enter new namespace name (alphanumeric, lowercase, hyphens only):"
        read -p "Namespace: " target_namespace
        
        if [ -z "$target_namespace" ]; then
            print_error "No namespace provided. Skipping model deployment."
            return 1
        fi
        
        print_step "Creating namespace '$target_namespace'..."
        oc create namespace "$target_namespace"
        print_success "Namespace created"
    elif [[ "$ns_choice" =~ ^[0-9]+$ ]]; then
        # User selected by number
        target_namespace=$(echo "$namespaces" | sed -n "${ns_choice}p")
        
        if [ -z "$target_namespace" ]; then
            print_error "Invalid selection. Skipping model deployment."
            return 1
        fi
    else
        # User entered namespace name directly
        target_namespace="$ns_choice"
        
        if ! oc get namespace "$target_namespace" &>/dev/null; then
            print_error "Namespace '$target_namespace' does not exist."
            read -p "Create it? (y/N): " create_ns
            
            if [[ "$create_ns" =~ ^[Yy]$ ]]; then
                oc create namespace "$target_namespace"
                print_success "Namespace created"
            else
                print_error "Skipping model deployment."
                return 1
            fi
        fi
    fi
    
    print_success "Target namespace: $target_namespace"
    
    # Resource configuration
    echo ""
    print_header "Resource Configuration"
    
    echo -e "${YELLOW}Configure resources for the model:${NC}"
    echo ""
    echo "  GPU limit: $default_gpu"
    echo "  CPU limit: $default_cpu"
    echo "  Memory limit: $default_memory"
    echo ""
    
    read -p "Use default resources? (Y/n): " use_defaults
    
    local gpu_limit="$default_gpu"
    local cpu_limit="$default_cpu"
    local memory_limit="$default_memory"
    
    if [[ "$use_defaults" =~ ^[Nn]$ ]]; then
        echo ""
        read -p "GPU limit (default: $default_gpu): " input_gpu
        gpu_limit="${input_gpu:-$default_gpu}"
        
        read -p "CPU limit (default: $default_cpu): " input_cpu
        cpu_limit="${input_cpu:-$default_cpu}"
        
        read -p "Memory limit (default: $default_memory): " input_memory
        memory_limit="${input_memory:-$default_memory}"
    fi
    
    print_success "Resources configured:"
    echo "  GPU: $gpu_limit"
    echo "  CPU: $cpu_limit"
    echo "  Memory: $memory_limit"
    
    # Tool calling configuration
    local vllm_args=""
    
    if [ "$tool_calling_enabled" = true ]; then
        echo ""
        print_header "Tool Calling Configuration"
        
        echo -e "${YELLOW}This model supports tool calling (function calling).${NC}"
        echo ""
        read -p "Enable tool calling? (Y/n): " enable_tools
        
        if [[ ! "$enable_tools" =~ ^[Nn]$ ]]; then
            vllm_args="--enable-auto-tool-choice --tool-call-parser=hermes"
            print_success "Tool calling enabled"
        else
            print_info "Tool calling disabled"
        fi
    fi
    
    # Authentication configuration
    echo ""
    print_header "Authentication Configuration"
    
    echo -e "${YELLOW}Require authentication for this model?${NC}"
    echo -e "${CYAN}(Recommended: Yes for production)${NC}"
    echo ""
    read -p "Require authentication? (Y/n): " enable_auth
    
    local auth_annotation=""
    if [[ ! "$enable_auth" =~ ^[Nn]$ ]]; then
        auth_annotation="security.opendatahub.io/enable-auth: \"true\""
        print_success "Authentication enabled"
    else
        auth_annotation="security.opendatahub.io/enable-auth: \"false\""
        print_warning "Authentication disabled (model will be publicly accessible)"
    fi
    
    # Deployment confirmation
    echo ""
    print_header "Deployment Summary"
    
    echo -e "${BLUE}Model:${NC} $model_name"
    echo -e "${BLUE}URI:${NC} $model_uri"
    echo -e "${BLUE}Namespace:${NC} $target_namespace"
    echo -e "${BLUE}Resources:${NC} $gpu_limit GPU, $cpu_limit CPU, $memory_limit Memory"
    
    if [ -n "$vllm_args" ]; then
        echo -e "${BLUE}Tool Calling:${NC} Enabled (hermes parser)"
    else
        echo -e "${BLUE}Tool Calling:${NC} Disabled"
    fi
    
    if [[ "$auth_annotation" =~ "true" ]]; then
        echo -e "${BLUE}Authentication:${NC} Required"
    else
        echo -e "${BLUE}Authentication:${NC} Disabled"
    fi
    
    echo ""
    read -p "Proceed with deployment? (Y/n): " confirm_deploy
    
    if [[ "$confirm_deploy" =~ ^[Nn]$ ]]; then
        print_info "Deployment cancelled."
        return 0
    fi
    
    # Deploy the model
    echo ""
    print_header "Deploying Model"
    
    print_step "Creating LLMInferenceService '$model_name' in namespace '$target_namespace'..."
    
    local env_section=""
    if [ -n "$vllm_args" ]; then
        env_section="      env:
        - name: VLLM_ADDITIONAL_ARGS
          value: \"$vllm_args\""
    fi
    
    cat <<EOF | oc apply -f -
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: $model_name
  namespace: $target_namespace
  labels:
    kueue.x-k8s.io/queue-name: default
    opendatahub.io/dashboard: "true"
    opendatahub.io/genai-asset: "true"
  annotations:
    $auth_annotation
spec:
  replicas: 1
  model:
    uri: $model_uri
    name: $model_name
  router:
    route: {}
    gateway: {}
    scheduler: {}
  template:
    containers:
    - name: main
$env_section
      resources:
        limits:
          cpu: '$cpu_limit'
          memory: $memory_limit
          nvidia.com/gpu: "$gpu_limit"
        requests:
          cpu: '$(echo "$cpu_limit" | awk '{print int($1/2)}')'
          memory: $(echo "$memory_limit" | sed 's/Gi//' | awk '{print int($1/2)}')Gi
          nvidia.com/gpu: "$gpu_limit"
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Model deployment created!"
        echo ""
        
        print_info "Deployment initiated. The model will take 5-10 minutes to be ready."
        echo ""
        
        print_info "Monitor deployment status:"
        echo "  oc get llmisvc $model_name -n $target_namespace -w"
        echo ""
        
        print_info "View pods:"
        echo "  oc get pods -n $target_namespace -l serving.kserve.io/inferenceservice=$model_name"
        echo ""
        
        if [[ "$auth_annotation" =~ "true" ]]; then
            print_info "Generate API token:"
            echo "  oc create token default -n $target_namespace --duration=24h"
            echo ""
            print_info "Or use the demo script:"
            echo "  ./demo/generate-maas-token.sh"
        fi
        
        echo ""
        print_info "Test the model (after it's ready):"
        echo "  ./demo/test-maas-api.sh"
        
    else
        print_error "Failed to deploy model."
        return 1
    fi
}

