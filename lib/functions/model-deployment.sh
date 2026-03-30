#!/bin/bash
################################################################################
# Interactive Model Deployment
################################################################################
# This function provides an interactive menu for deploying models using
# available serving runtimes (llm-d, vLLM, etc.)
################################################################################

# Source OS compatibility library
# Use a local variable to avoid overwriting caller's SCRIPT_DIR
_MODEL_DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_MODEL_DEPLOY_DIR}/../utils/os-compat.sh"

# Interactive model deployment function (runtime-agnostic)
deploy_model_interactive() {
    print_header "Interactive Model Deployment"
    
    echo -e "${YELLOW}Would you like to deploy a model now?${NC}"
    echo ""
    read -p "Deploy a model? (y/N): " deploy_choice
    deploy_choice=$(echo "$deploy_choice" | tr -d '[:space:]')  # Remove any whitespace
    
    if [[ ! "$deploy_choice" =~ ^[Yy]$ ]]; then
        print_info "Skipping model deployment. You can deploy later using:"
        echo "  ./scripts/deploy-llmd-model.sh"
        return 0
    fi
    
    echo ""
    print_header "Serving Runtime Selection"
    
    # Detect available serving runtimes
    print_step "Detecting available serving runtimes..."
    echo ""
    
    local runtimes=()
    local runtime_names=()
    local runtime_descriptions=()
    
    # Check for llm-d (LLMInferenceService CRD)
    if oc get crd llminferenceservices.serving.kserve.io &>/dev/null; then
        runtimes+=("llmd")
        runtime_names+=("llm-d (LLMInferenceService)")
        runtime_descriptions+=("Multi-replica, MaaS support, Leader Worker Set")
    fi
    
    # Check for vLLM (InferenceService CRD with vLLM runtime)
    if oc get crd inferenceservices.serving.kserve.io &>/dev/null; then
        runtimes+=("vllm")
        runtime_names+=("vLLM (Red Hat Image)")
        runtime_descriptions+=("Red Hat supported image, GenAI Playground")
        
        # Also offer community vLLM for CUDA 13+ compatibility
        runtimes+=("vllm-community")
        runtime_names+=("vLLM (Community Image - CUDA 13+)")
        runtime_descriptions+=("Community vLLM image, newer GPU driver support, security hardened")
    fi
    
    # Check for ServingRuntime templates
    local serving_runtimes=$(oc get servingruntimes -n redhat-ods-applications -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if [ -n "$serving_runtimes" ]; then
        print_info "Available ServingRuntime templates:"
        echo "$serving_runtimes" | tr ' ' '\n' | sed 's/^/  - /'
        echo ""
    fi
    
    if [ ${#runtimes[@]} -eq 0 ]; then
        print_error "No serving runtimes detected!"
        echo ""
        echo "Please ensure RHOAI is installed with serving components."
        echo ""
        echo "Check with:"
        echo "  oc get crd | grep -E 'inferenceservice|llminferenceservice'"
        return 1
    fi
    
    # Display available runtimes
    echo -e "${BLUE}Available serving runtimes:${NC}"
    echo ""
    
    for i in "${!runtimes[@]}"; do
        local num=$((i + 1))
        echo -e "${YELLOW}$num)${NC} ${runtime_names[$i]}"
        echo "   ${runtime_descriptions[$i]}"
        echo ""
    done
    
    # Let user choose runtime
    local runtime_choice=""
    while true; do
        read -p "Select serving runtime (1-${#runtimes[@]}): " runtime_choice
        runtime_choice=$(echo "$runtime_choice" | tr -d '[:space:]')
        
        if [[ "$runtime_choice" =~ ^[0-9]+$ ]] && [ "$runtime_choice" -ge 1 ] && [ "$runtime_choice" -le ${#runtimes[@]} ]; then
            break
        else
            print_error "Invalid choice. Please select 1-${#runtimes[@]}."
        fi
    done
    
    local selected_runtime="${runtimes[$((runtime_choice - 1))]}"
    print_success "Selected runtime: ${runtime_names[$((runtime_choice - 1))]}"
    
    echo ""
    print_header "Model Selection"
    
    # Pre-defined model catalog from quay.io/redhat-ai-services/modelcar-catalog
    # See: https://quay.io/repository/redhat-ai-services/modelcar-catalog?tab=tags
    echo -e "${BLUE}Available models (from Red Hat AI Services Modelcar Catalog):${NC}"
    echo ""
    echo "  1) Qwen3-4B - 4B params, tool calling support ${GREEN}[Recommended for demos]${NC}"
    echo "     oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b"
    echo ""
    echo "  2) Llama 3.2-3B Instruct - 3B params, tool calling support"
    echo "     oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct"
    echo ""
    echo "  3) Llama 3.1-8B Instruct - 8B params, tool calling support"
    echo "     oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.1-8b-instruct"
    echo ""
    echo "  4) Granite 3.0-8B Instruct - 8B params, IBM Granite model"
    echo "     oci://quay.io/redhat-ai-services/modelcar-catalog:granite-3.0-8b-instruct"
    echo ""
    echo "  5) Granite 3.1-8B Instruct - 8B params, latest Granite"
    echo "     oci://quay.io/redhat-ai-services/modelcar-catalog:granite-3.1-8b-instruct"
    echo ""
    echo "  6) Mistral 7B Instruct v0.3 - 7B params"
    echo "     oci://quay.io/redhat-ai-services/modelcar-catalog:mistral-7b-instruct-v0.3"
    echo ""
    echo "  7) Custom model URI (enter your own)"
    echo ""
    
    read -p "Select a model (1-7): " model_choice
    
    local model_uri=""
    local model_name=""
    local default_gpu="1"
    local default_cpu="4"
    local default_memory="16Gi"
    local tool_calling_enabled=false
    local tool_parser="hermes"  # Default parser
    
    case "$model_choice" in
        1)
            model_uri="oci://quay.io/redhat-ai-services/modelcar-catalog:qwen3-4b"
            model_name="qwen3-4b"
            default_gpu="1"
            default_cpu="4"
            default_memory="16Gi"
            tool_calling_enabled=true
            tool_parser="hermes"
            ;;
        2)
            model_uri="oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct"
            model_name="llama-32-3b-instruct"
            default_gpu="1"
            default_cpu="4"
            default_memory="16Gi"
            tool_calling_enabled=true
            tool_parser="llama3_json"
            ;;
        3)
            model_uri="oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.1-8b-instruct"
            model_name="llama-31-8b-instruct"
            default_gpu="1"
            default_cpu="8"
            default_memory="32Gi"
            tool_calling_enabled=true
            tool_parser="llama3_json"
            ;;
        4)
            model_uri="oci://quay.io/redhat-ai-services/modelcar-catalog:granite-3.0-8b-instruct"
            model_name="granite-30-8b-instruct"
            default_gpu="1"
            default_cpu="8"
            default_memory="32Gi"
            ;;
        5)
            model_uri="oci://quay.io/redhat-ai-services/modelcar-catalog:granite-3.1-8b-instruct"
            model_name="granite-31-8b-instruct"
            default_gpu="1"
            default_cpu="8"
            default_memory="32Gi"
            ;;
        6)
            model_uri="oci://quay.io/redhat-ai-services/modelcar-catalog:mistral-7b-instruct-v0.3"
            model_name="mistral-7b-instruct"
            default_gpu="1"
            default_cpu="8"
            default_memory="32Gi"
            ;;
        7)
            echo ""
            print_info "Enter custom model URI"
            echo "  Examples:"
            echo "    oci://quay.io/redhat-ai-services/modelcar-catalog:qwen2.5-7b-instruct"
            echo "    oci://quay.io/redhat-ai-services/modelcar-catalog:phi-3-mini-128k-instruct"
            echo ""
            echo "  Browse available models at:"
            echo "    https://quay.io/repository/redhat-ai-services/modelcar-catalog?tab=tags"
            echo ""
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
    
    # Detect available hardware profiles
    print_step "Detecting available hardware profiles..."
    echo ""
    
    local profiles=()
    local profile_names=()
    local profile_gpus=()
    local profile_cpus=()
    local profile_memories=()
    
    # Check for all hardware profiles (look for GPU-related ones)
    # Hardware profiles are typically in redhat-ods-applications namespace
    local all_profiles=$(oc get hardwareprofiles -n redhat-ods-applications -o json 2>/dev/null | jq -r '.items[].metadata.name' 2>/dev/null)
    
    # If not found in redhat-ods-applications, try all namespaces
    if [ -z "$all_profiles" ]; then
        all_profiles=$(oc get hardwareprofiles -A -o json 2>/dev/null | jq -r '.items[].metadata.name' 2>/dev/null)
    fi
    
    # Debug: show what we found
    if [ -n "$all_profiles" ]; then
        print_info "Found hardware profiles:"
        echo "$all_profiles" | sed 's/^/  - /'
        echo ""
    else
        print_warning "No hardware profiles found in cluster"
        echo ""
    fi
    
    if [ -n "$all_profiles" ]; then
        while IFS= read -r profile; do
            if [ -n "$profile" ]; then
                # Get profile details (try redhat-ods-applications namespace)
                local cpu=$(oc get hardwareprofile "$profile" -n redhat-ods-applications -o jsonpath='{.spec.hardwareCharacteristic.cpu}' 2>/dev/null)
                local memory=$(oc get hardwareprofile "$profile" -n redhat-ods-applications -o jsonpath='{.spec.hardwareCharacteristic.memory}' 2>/dev/null)
                
                # Get GPU count from nodeSelector
                local gpu_count=$(oc get hardwareprofile "$profile" -n redhat-ods-applications -o jsonpath='{.spec.hardwareCharacteristic.nodeSelector."nvidia\.com/gpu\.count"}' 2>/dev/null)
                
                # If no gpu.count, try gpu.present
                if [ -z "$gpu_count" ]; then
                    local gpu_present=$(oc get hardwareprofile "$profile" -n redhat-ods-applications -o jsonpath='{.spec.hardwareCharacteristic.nodeSelector."nvidia\.com/gpu\.present"}' 2>/dev/null)
                    if [ "$gpu_present" = "true" ]; then
                        gpu_count="1"
                    fi
                fi
                
                # If still no GPU count but profile has "gpu" in name, assume 1 GPU
                if [ -z "$gpu_count" ] && [[ "$profile" =~ [Gg][Pp][Uu] ]]; then
                    gpu_count="1"
                fi
                
                # Default values if not specified
                cpu="${cpu:-4}"
                memory="${memory:-16Gi}"
                gpu_count="${gpu_count:-0}"
                
                # Add all profiles (including non-GPU ones)
                profiles+=("$profile")
                profile_names+=("$profile")
                profile_gpus+=("$gpu_count")
                profile_cpus+=("$cpu")
                profile_memories+=("$memory")
            fi
        done <<< "$all_profiles"
        
        if [ ${#profiles[@]} -gt 0 ]; then
            print_info "Available hardware profiles:"
            echo ""
            for i in "${!profiles[@]}"; do
                if [ "${profile_gpus[$i]}" != "0" ]; then
                    echo "  - ${profile_names[$i]}: ${profile_gpus[$i]} GPU, ${profile_cpus[$i]} CPU, ${profile_memories[$i]} Memory"
                else
                    echo "  - ${profile_names[$i]}: ${profile_cpus[$i]} CPU, ${profile_memories[$i]} Memory (no GPU)"
                fi
            done
            echo ""
        fi
    fi
    
    # Offer hardware profile selection or manual configuration
    local gpu_limit="$default_gpu"
    local cpu_limit="$default_cpu"
    local memory_limit="$default_memory"
    local selected_profile_name=""
    local selected_profile_namespace="redhat-ods-applications"
    
    if [ ${#profiles[@]} -gt 0 ]; then
        echo -e "${BLUE}Resource configuration options:${NC}"
        echo ""
        
        for i in "${!profiles[@]}"; do
            local num=$((i + 1))
            echo -e "${YELLOW}$num)${NC} Use hardware profile: ${profile_names[$i]}"
            echo "   GPU: ${profile_gpus[$i]}, CPU: ${profile_cpus[$i]}, Memory: ${profile_memories[$i]}"
            echo ""
        done
        
        local manual_option=$((${#profiles[@]} + 1))
        echo -e "${YELLOW}$manual_option)${NC} Use default resources (GPU: $default_gpu, CPU: $default_cpu, Memory: $default_memory)"
        echo ""
        
        local custom_option=$((${#profiles[@]} + 2))
        echo -e "${YELLOW}$custom_option)${NC} Custom configuration (enter manually)"
        echo ""
        
        local resource_choice=""
        while true; do
            read -p "Select option (1-$custom_option): " resource_choice
            resource_choice=$(echo "$resource_choice" | tr -d '[:space:]')
            
            if [[ "$resource_choice" =~ ^[0-9]+$ ]] && [ "$resource_choice" -ge 1 ] && [ "$resource_choice" -le "$custom_option" ]; then
                break
            else
                print_error "Invalid choice. Please select 1-$custom_option."
            fi
        done
        
        if [ "$resource_choice" -le ${#profiles[@]} ]; then
            # User selected a hardware profile
            local idx=$((resource_choice - 1))
            gpu_limit="${profile_gpus[$idx]}"
            cpu_limit="${profile_cpus[$idx]}"
            memory_limit="${profile_memories[$idx]}"
            selected_profile_name="${profile_names[$idx]}"
            print_success "Using hardware profile: ${profile_names[$idx]}"
        elif [ "$resource_choice" -eq "$manual_option" ]; then
            # Use defaults
            print_success "Using default resources"
        else
            # Custom configuration
            echo ""
            read -p "GPU limit (default: $default_gpu): " input_gpu
            gpu_limit="${input_gpu:-$default_gpu}"
            
            read -p "CPU limit (default: $default_cpu): " input_cpu
            cpu_limit="${input_cpu:-$default_cpu}"
            
            read -p "Memory limit (default: $default_memory): " input_memory
            memory_limit="${input_memory:-$default_memory}"
        fi
    else
        # No hardware profiles found - offer to create one
        echo -e "${YELLOW}No GPU hardware profiles found.${NC}"
        echo ""
        echo -e "${BLUE}Options:${NC}"
        echo ""
        echo -e "${YELLOW}1)${NC} Create GPU hardware profile (recommended)"
        echo "   Creates a profile with tolerations for GPU nodes"
        echo ""
        echo -e "${YELLOW}2)${NC} Use default resources without profile"
        echo "   GPU: $default_gpu, CPU: $default_cpu, Memory: $default_memory"
        echo ""
        echo -e "${YELLOW}3)${NC} Custom configuration (enter manually)"
        echo ""
        
        read -p "Select option (1-3): " no_profile_choice
        no_profile_choice=$(echo "$no_profile_choice" | tr -d '[:space:]')
        
        case "$no_profile_choice" in
            1)
                # Create hardware profile using quick setup
                echo ""
                print_step "Creating GPU hardware profile..."
                
                local template_dir="${_MODEL_DEPLOY_DIR}/../../lib/manifests/templates"
                
                echo ""
                echo -e "${CYAN}Select profile size:${NC}"
                echo "  1) Small  - 4B-8B models (CPU: 2-8, Mem: 8-24Gi, GPU: 1)"
                echo "  2) Medium - 8B-30B models (CPU: 4-16, Mem: 32-64Gi, GPU: 1)"
                echo "  3) Large  - 70B+ models (CPU: 16-96, Mem: 128-512Gi, GPU: 4-8)"
                echo ""
                read -p "Select size (1-3) [1]: " size_choice
                size_choice="${size_choice:-1}"
                
                local profile_size="small"
                case "$size_choice" in
                    2) profile_size="medium" ;;
                    3) profile_size="large" ;;
                    *) profile_size="small" ;;
                esac
                
                local template_file="$template_dir/hardwareprofile-gpu-${profile_size}.yaml.tmpl"
                
                if [ -f "$template_file" ]; then
                    export NAMESPACE="$target_namespace"
                    envsubst < "$template_file" | oc apply -f -
                    unset NAMESPACE
                    
                    selected_profile_name="gpu-${profile_size}"
                    selected_profile_namespace="$target_namespace"
                    print_success "Created hardware profile: gpu-${profile_size}"
                    
                    # Get the profile's default values
                    case "$profile_size" in
                        small)
                            gpu_limit="1"
                            cpu_limit="2"
                            memory_limit="8Gi"
                            ;;
                        medium)
                            gpu_limit="1"
                            cpu_limit="4"
                            memory_limit="32Gi"
                            ;;
                        large)
                            gpu_limit="4"
                            cpu_limit="16"
                            memory_limit="128Gi"
                            ;;
                    esac
                else
                    print_warning "Template not found, using default resources"
                fi
                ;;
            2)
                # Use defaults
                print_success "Using default resources"
                ;;
            3)
                # Custom configuration
                echo ""
                read -p "GPU limit (default: $default_gpu): " input_gpu
                gpu_limit="${input_gpu:-$default_gpu}"
                
                read -p "CPU limit (default: $default_cpu): " input_cpu
                cpu_limit="${input_cpu:-$default_cpu}"
                
                read -p "Memory limit (default: $default_memory): " input_memory
                memory_limit="${input_memory:-$default_memory}"
                ;;
            *)
                print_info "Using default resources"
                ;;
        esac
    fi
    
    echo ""
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
        echo -e "${CYAN}Parser: $tool_parser${NC}"
        echo ""
        read -p "Enable tool calling? (Y/n): " enable_tools
        
        if [[ ! "$enable_tools" =~ ^[Nn]$ ]]; then
            vllm_args="--enable-auto-tool-choice --tool-call-parser=$tool_parser"
            print_success "Tool calling enabled with $tool_parser parser"
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
    enable_auth=$(echo "$enable_auth" | tr -d '[:space:]')
    
    local auth_annotation=""
    local auth_enabled=false
    local service_account_name=""
    
    if [[ ! "$enable_auth" =~ ^[Nn]$ ]]; then
        auth_enabled=true
        auth_annotation="security.opendatahub.io/enable-auth: 'true'"
        
        # Ask for service account name
        echo ""
        local default_sa="${model_name}-sa"
        read -p "Service account name (default: $default_sa): " service_account_name
        service_account_name="${service_account_name:-$default_sa}"
        
        print_success "Authentication enabled with service account: $service_account_name"
    else
        auth_annotation="security.opendatahub.io/enable-auth: 'false'"
        print_warning "Authentication disabled (model will be publicly accessible)"
    fi
    
    # Deployment confirmation
    echo ""
    print_header "Deployment Summary"
    
    echo -e "${BLUE}Serving Runtime:${NC} ${runtime_names[$((runtime_choice - 1))]}"
    echo -e "${BLUE}Model:${NC} $model_name"
    echo -e "${BLUE}URI:${NC} $model_uri"
    echo -e "${BLUE}Namespace:${NC} $target_namespace"
    echo -e "${BLUE}Resources:${NC} $gpu_limit GPU, $cpu_limit CPU, $memory_limit Memory"
    
    if [ -n "$vllm_args" ]; then
        echo -e "${BLUE}Tool Calling:${NC} Enabled (hermes parser)"
    else
        echo -e "${BLUE}Tool Calling:${NC} Disabled"
    fi
    
    if [ "$auth_enabled" = true ]; then
        echo -e "${BLUE}Authentication:${NC} Required (ServiceAccount: $service_account_name)"
    else
        echo -e "${BLUE}Authentication:${NC} Disabled"
    fi
    
    echo ""
    read -p "Proceed with deployment? (Y/n): " confirm_deploy
    confirm_deploy=$(echo "$confirm_deploy" | tr -d '[:space:]')
    
    if [[ "$confirm_deploy" =~ ^[Nn]$ ]]; then
        print_info "Deployment cancelled."
        return 0
    fi
    
    # Deploy the model based on selected runtime
    echo ""
    print_header "Deploying Model"
    
    if [ "$selected_runtime" = "llmd" ]; then
        # Deploy using llm-d (LLMInferenceService)
        print_step "Creating LLMInferenceService '$model_name' in namespace '$target_namespace'..."
        
        local env_section=""
        if [ -n "$vllm_args" ]; then
            env_section="      env:
        - name: VLLM_ADDITIONAL_ARGS
          value: \"$vllm_args\""
        fi
        
        # Build hardware profile annotations if a profile was selected
        local hw_profile_annotations_llmd=""
        if [ -n "$selected_profile_name" ]; then
            hw_profile_annotations_llmd="    opendatahub.io/hardware-profile-namespace: $selected_profile_namespace
    opendatahub.io/hardware-profile-name: $selected_profile_name"
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
$hw_profile_annotations_llmd
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
    tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
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
            print_success "LLMInferenceService created!"
            echo ""
            print_info "Monitor deployment:"
            echo "  oc get llmisvc $model_name -n $target_namespace -w"
        else
            print_error "Failed to create LLMInferenceService"
            return 1
        fi
        
    elif [ "$selected_runtime" = "vllm" ]; then
        # Deploy using vLLM (InferenceService) - CAI Guide Section 2 format
        print_step "Creating vLLM deployment for '$model_name' in namespace '$target_namespace'..."
        
        # Step 1: Create Secret for model storage URI
        print_step "Creating model storage secret..."
        
        # Base64 encode the model URI (OS-compatible)
        local encoded_uri=$(base64_encode "$model_uri")
        
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${model_name}-storage
  namespace: $target_namespace
  labels:
    opendatahub.io/dashboard: 'true'
  annotations:
    opendatahub.io/connection-type-protocol: uri
    opendatahub.io/connection-type-ref: uri-v1
    openshift.io/description: 'Model storage for ${model_name}'
    openshift.io/display-name: ${model_name}
data:
  URI: ${encoded_uri}
type: Opaque
EOF
        
        print_success "Model storage secret created"
        
        # Step 2: Create ServingRuntime
        print_step "Creating vLLM ServingRuntime..."
        
        cat <<EOF | oc apply -f -
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: ${model_name}-runtime
  namespace: $target_namespace
  labels:
    opendatahub.io/dashboard: 'true'
  annotations:
    opendatahub.io/apiProtocol: REST
    opendatahub.io/recommended-accelerators: '["nvidia.com/gpu"]'
    opendatahub.io/template-display-name: vLLM NVIDIA GPU ServingRuntime for KServe
    opendatahub.io/template-name: vllm-cuda-runtime-template
    openshift.io/display-name: vLLM NVIDIA GPU ServingRuntime for KServe
spec:
  annotations:
    prometheus.io/path: /metrics
    prometheus.io/port: '8080'
  containers:
    - args:
        - '--port=8080'
        - '--model=/mnt/models'
        - '--served-model-name={{.Name}}'
      command:
        - python
        - '-m'
        - vllm.entrypoints.openai.api_server
      env:
        - name: HF_HOME
          value: /tmp/hf_home
      image: 'registry.redhat.io/rhaiis/vllm-cuda-rhel9:latest'
      name: kserve-container
      ports:
        - containerPort: 8080
          protocol: TCP
  multiModel: false
  supportedModelFormats:
    - autoSelect: true
      name: vLLM
EOF
        
        print_success "ServingRuntime created"
        
        # Step 3: Create InferenceService
        print_step "Creating InferenceService..."
        
        # Build model args based on tool calling
        local model_args=""
        if [ -n "$vllm_args" ]; then
            # Extract parser from vllm_args (OS-compatible)
            local parser=$(grep_extract "tool-call-parser=" "$vllm_args")
            model_args="      args:
        - '--dtype=half'
        - '--max-model-len=20000'
        - '--gpu-memory-utilization=0.95'
        - '--enable-auto-tool-choice'
        - '--tool-call-parser=${parser}'"
        else
            model_args="      args:
        - '--dtype=half'
        - '--max-model-len=20000'
        - '--gpu-memory-utilization=0.95'"
        fi
        
        # Calculate resource requests (half of limits, matching CAI guide)
        # Use OS-compatible functions
        local cpu_value=$(parse_cpu "$cpu_limit")
        local cpu_request=$(calc_half "$cpu_value" 1)
        
        local mem_value=$(parse_memory_gi "$memory_limit")
        local mem_half=$(calc_half "$mem_value" 1)
        local memory_request="${mem_half}Gi"
        
        # Build hardware profile annotations if a profile was selected
        local hw_profile_annotations=""
        if [ -n "$selected_profile_name" ]; then
            hw_profile_annotations="    opendatahub.io/hardware-profile-namespace: $selected_profile_namespace
    opendatahub.io/hardware-profile-name: $selected_profile_name"
        fi
        
        cat <<EOF | oc apply -f -
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: $model_name
  namespace: $target_namespace
  labels:
    opendatahub.io/dashboard: 'true'
    opendatahub.io/genai-asset: 'true'
  annotations:
    serving.kserve.io/stop: 'false'
    $auth_annotation
    openshift.io/description: ''
    openshift.io/display-name: $model_name
    serving.kserve.io/deploymentMode: RawDeployment
    opendatahub.io/connections: ${model_name}-storage
    opendatahub.io/model-type: generative
$hw_profile_annotations
spec:
  predictor:
    automountServiceAccountToken: false
    maxReplicas: 1
    minReplicas: 1
    tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
    model:
$model_args
      modelFormat:
        name: vLLM
      name: ''
      resources:
        limits:
          cpu: '$cpu_limit'
          memory: $memory_limit
          nvidia.com/gpu: '$gpu_limit'
        requests:
          cpu: '$cpu_request'
          memory: $memory_request
          nvidia.com/gpu: '$gpu_limit'
      runtime: ${model_name}-runtime
      storageUri: '$model_uri'
EOF
        
        if [ $? -eq 0 ]; then
            print_success "InferenceService created!"
            
            # Create external route
            echo ""
            print_step "Creating external route..."
            
            # Wait a moment for the service to be created
            sleep 5
            
            # Check if service exists
            if oc get service ${model_name}-predictor -n $target_namespace &>/dev/null; then
                oc create route edge ${model_name} --service=${model_name}-predictor --port=8080 -n $target_namespace 2>/dev/null
                if [ $? -eq 0 ]; then
                    print_success "External route created"
                    local route_url=$(oc get route ${model_name} -n $target_namespace -o jsonpath='{.spec.host}' 2>/dev/null)
                    if [ -n "$route_url" ]; then
                        print_info "Model endpoint: https://$route_url"
                    fi
                else
                    print_warning "Route may already exist or service not ready yet"
                    print_info "Create route manually after deployment:"
                    echo "  oc create route edge ${model_name} --service=${model_name}-predictor --port=8080 -n $target_namespace"
                fi
            else
                print_info "Service not ready yet. Create route after deployment:"
                echo "  oc create route edge ${model_name} --service=${model_name}-predictor --port=8080 -n $target_namespace"
            fi
            
            echo ""
            print_info "Monitor deployment:"
            echo "  oc get inferenceservice $model_name -n $target_namespace -w"
        else
            print_error "Failed to create InferenceService"
            return 1
        fi
        
    elif [ "$selected_runtime" = "vllm-community" ]; then
        # Deploy using community vLLM image (CUDA 13+ compatible, security hardened)
        print_step "Creating vLLM deployment with community image for '$model_name'..."
        print_info "Using community vLLM image with CUDA 13+ support and security hardening"
        
        # === vLLM Image Configuration ===
        echo ""
        print_header "vLLM Image Configuration"
        
        local default_vllm_image="docker.io/vllm/vllm-openai:v0.6.6.post1"
        echo -e "${BLUE}Available vLLM images:${NC}"
        echo ""
        echo "  1) v0.6.6.post1 (stable, recommended)"
        echo "  2) v0.6.5 (previous stable)"
        echo "  3) v0.7.0 (latest, experimental)"
        echo "  4) latest (rolling release)"
        echo "  5) Custom image (enter your own)"
        echo ""
        
        read -p "Select vLLM image (1-5, default: 1): " vllm_image_choice
        vllm_image_choice="${vllm_image_choice:-1}"
        
        local vllm_image=""
        case "$vllm_image_choice" in
            1) vllm_image="docker.io/vllm/vllm-openai:v0.6.6.post1" ;;
            2) vllm_image="docker.io/vllm/vllm-openai:v0.6.5" ;;
            3) vllm_image="docker.io/vllm/vllm-openai:v0.7.0" ;;
            4) vllm_image="docker.io/vllm/vllm-openai:latest" ;;
            5)
                echo ""
                read -p "Enter custom vLLM image: " vllm_image
                if [ -z "$vllm_image" ]; then
                    vllm_image="$default_vllm_image"
                fi
                ;;
            *) vllm_image="$default_vllm_image" ;;
        esac
        
        print_success "Using vLLM image: $vllm_image"
        
        # === vLLM Runtime Configuration ===
        echo ""
        print_header "vLLM Runtime Configuration"
        
        # Max model length
        local default_max_model_len="8192"
        echo -e "${BLUE}Max model length:${NC}"
        echo "  This determines the maximum context window size."
        echo "  Higher values use more GPU memory."
        echo ""
        read -p "Max model length (default: $default_max_model_len): " max_model_len
        max_model_len="${max_model_len:-$default_max_model_len}"
        
        # GPU memory utilization
        local default_gpu_mem_util="0.90"
        echo ""
        echo -e "${BLUE}GPU memory utilization:${NC}"
        echo "  Fraction of GPU memory to use (0.0-1.0)."
        echo "  Lower values leave room for other workloads."
        echo ""
        read -p "GPU memory utilization (default: $default_gpu_mem_util): " gpu_mem_util
        gpu_mem_util="${gpu_mem_util:-$default_gpu_mem_util}"
        
        # Data type
        local default_dtype="half"
        echo ""
        echo -e "${BLUE}Data type:${NC}"
        echo "  1) half (FP16, recommended for most GPUs)"
        echo "  2) bfloat16 (BF16, for newer GPUs like A100/H100)"
        echo "  3) float16 (same as half)"
        echo "  4) auto (let vLLM decide)"
        echo ""
        read -p "Select data type (1-4, default: 1): " dtype_choice
        dtype_choice="${dtype_choice:-1}"
        
        local dtype=""
        case "$dtype_choice" in
            1) dtype="half" ;;
            2) dtype="bfloat16" ;;
            3) dtype="float16" ;;
            4) dtype="auto" ;;
            *) dtype="half" ;;
        esac
        
        print_success "Configuration: max_model_len=$max_model_len, gpu_memory_utilization=$gpu_mem_util, dtype=$dtype"
        
        # Tool calling was already configured in the main flow (vllm_args variable)
        # Just display the status
        if [ -n "$vllm_args" ]; then
            print_info "Tool calling: Enabled ($tool_parser parser)"
        fi
        
        # Step 1: Create Secret for model storage URI
        echo ""
        print_step "Creating model storage secret..."
        
        local encoded_uri=$(base64_encode "$model_uri")
        
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${model_name}-storage
  namespace: $target_namespace
  labels:
    opendatahub.io/dashboard: 'true'
  annotations:
    opendatahub.io/connection-type-protocol: uri
    opendatahub.io/connection-type-ref: uri-v1
    openshift.io/description: 'Model storage for ${model_name}'
    openshift.io/display-name: ${model_name}
data:
  URI: ${encoded_uri}
type: Opaque
EOF
        
        print_success "Model storage secret created"
        
        # Step 2: Create ServingRuntime with community vLLM image (security hardened)
        print_step "Creating security-hardened ServingRuntime..."
        
        # Build args array
        local args_section="    args:
    - --port=8080
    - --model=/mnt/models
    - --served-model-name={{.Name}}
    - --dtype=$dtype
    - --max-model-len=$max_model_len
    - --gpu-memory-utilization=$gpu_mem_util"
        
        # Add tool calling args if enabled (from main flow's vllm_args)
        if [ -n "$vllm_args" ]; then
            for arg in $vllm_args; do
                args_section="$args_section
    - $arg"
            done
        fi
        
        cat <<EOF | oc apply -f -
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: ${model_name}-runtime
  namespace: $target_namespace
  labels:
    opendatahub.io/dashboard: "true"
  annotations:
    opendatahub.io/template-display-name: "vLLM Community Runtime (CUDA 13+)"
    openshift.io/display-name: "vLLM Community Runtime"
spec:
  annotations:
    prometheus.io/path: /metrics
    prometheus.io/port: "8080"
  containers:
  - name: kserve-container
    image: $vllm_image
$args_section
    env:
    # Disable telemetry/usage stats
    - name: VLLM_NO_USAGE_STATS
      value: "1"
    - name: DO_NOT_TRACK
      value: "1"
    # Writable directories for non-root container
    - name: HOME
      value: "/tmp/vllm-home"
    - name: HF_HOME
      value: "/tmp/hf-cache"
    - name: HF_HUB_OFFLINE
      value: "1"
    - name: TRANSFORMERS_CACHE
      value: "/tmp/transformers-cache"
    - name: XDG_CACHE_HOME
      value: "/tmp/cache"
    - name: XDG_CONFIG_HOME
      value: "/tmp/config"
    - name: PYTHONDONTWRITEBYTECODE
      value: "1"
    ports:
    - containerPort: 8080
      protocol: TCP
    # Security context - prevent privilege escalation
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      runAsNonRoot: true
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - mountPath: /dev/shm
      name: shm
    - mountPath: /tmp
      name: tmp-volume
  multiModel: false
  supportedModelFormats:
  - autoSelect: true
    name: vLLM
  volumes:
  - emptyDir:
      medium: Memory
      sizeLimit: 12Gi
    name: shm
  - emptyDir:
      sizeLimit: 1Gi
    name: tmp-volume
EOF
        
        print_success "ServingRuntime created"
        
        # Step 3: Create InferenceService
        print_step "Creating InferenceService..."
        
        # Calculate resource requests
        local cpu_value=$(parse_cpu "$cpu_limit")
        local cpu_request=$(calc_half "$cpu_value" 1)
        local mem_value=$(parse_memory_gi "$memory_limit")
        local mem_half=$(calc_half "$mem_value" 1)
        local memory_request="${mem_half}Gi"
        
        # Build hardware profile annotations if a profile was selected
        local hw_profile_annotations_community=""
        if [ -n "$selected_profile_name" ]; then
            hw_profile_annotations_community="    opendatahub.io/hardware-profile-namespace: $selected_profile_namespace
    opendatahub.io/hardware-profile-name: $selected_profile_name"
        fi
        
        cat <<EOF | oc apply -f -
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: $model_name
  namespace: $target_namespace
  labels:
    opendatahub.io/dashboard: 'true'
    opendatahub.io/genai-asset: 'true'
  annotations:
    serving.kserve.io/stop: 'false'
    $auth_annotation
    openshift.io/description: 'Deployed with community vLLM (CUDA 13+)'
    openshift.io/display-name: $model_name
    serving.kserve.io/deploymentMode: RawDeployment
    opendatahub.io/connections: ${model_name}-storage
    opendatahub.io/model-type: generative
$hw_profile_annotations_community
spec:
  predictor:
    automountServiceAccountToken: false
    minReplicas: 1
    maxReplicas: 1
    tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
    model:
      modelFormat:
        name: vLLM
      name: ''
      resources:
        limits:
          cpu: '$cpu_limit'
          memory: $memory_limit
          nvidia.com/gpu: '$gpu_limit'
        requests:
          cpu: '$cpu_request'
          memory: $memory_request
          nvidia.com/gpu: '$gpu_limit'
      runtime: ${model_name}-runtime
      storageUri: '$model_uri'
EOF
        
        if [ $? -eq 0 ]; then
            print_success "InferenceService created!"
            echo ""
            print_info "Deployment configuration:"
            echo "  vLLM Image: $vllm_image"
            echo "  Max Model Length: $max_model_len"
            echo "  GPU Memory Utilization: $gpu_mem_util"
            echo "  Data Type: $dtype"
            if [ -n "$vllm_args" ]; then
                echo "  Tool Calling: Enabled ($tool_parser)"
            fi
            
            # Create external route
            echo ""
            print_step "Creating external route..."
            
            # Wait a moment for the service to be created
            sleep 5
            
            # Check if service exists
            if oc get service ${model_name}-predictor -n $target_namespace &>/dev/null; then
                oc create route edge ${model_name} --service=${model_name}-predictor --port=8080 -n $target_namespace 2>/dev/null
                if [ $? -eq 0 ]; then
                    print_success "External route created"
                    local route_url=$(oc get route ${model_name} -n $target_namespace -o jsonpath='{.spec.host}' 2>/dev/null)
                    if [ -n "$route_url" ]; then
                        print_info "Model endpoint: https://$route_url"
                    fi
                else
                    print_warning "Route may already exist or service not ready yet"
                    print_info "Create route manually after deployment:"
                    echo "  oc create route edge ${model_name} --service=${model_name}-predictor --port=8080 -n $target_namespace"
                fi
            else
                print_info "Service not ready yet. Create route after deployment:"
                echo "  oc create route edge ${model_name} --service=${model_name}-predictor --port=8080 -n $target_namespace"
            fi
            
            echo ""
            print_info "Monitor deployment:"
            echo "  oc get inferenceservice $model_name -n $target_namespace -w"
        else
            print_error "Failed to create InferenceService"
            return 1
        fi
    fi
    
    # Create ServiceAccount and RBAC if authentication is enabled
    if [ "$auth_enabled" = true ] && [ -n "$service_account_name" ]; then
        echo ""
        print_step "Creating ServiceAccount and RBAC for authentication..."
        
        # Determine the resource type for RBAC
        local resource_type="inferenceservices"
        if [ "$selected_runtime" = "llmd" ]; then
            resource_type="llminferenceservices"
        fi
        
        # Create ServiceAccount, Secret, Role, and RoleBinding (based on CAI guide)
        cat <<EOF | oc apply -f -
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $service_account_name
  namespace: $target_namespace
---
apiVersion: v1
kind: Secret
metadata:
  name: ${service_account_name}-token
  namespace: $target_namespace
  annotations:
    kubernetes.io/service-account.name: "$service_account_name"
    openshift.io/display-name: $service_account_name
  labels:
    opendatahub.io/dashboard: "true"
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${model_name}-view-role
  namespace: $target_namespace
  labels:
    opendatahub.io/dashboard: "true"
rules:
- apiGroups:
  - serving.kserve.io
  resourceNames:
  - $model_name
  resources:
  - $resource_type
  verbs:
  - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${model_name}-view
  namespace: $target_namespace
  labels:
    opendatahub.io/dashboard: "true"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${model_name}-view-role
subjects:
- kind: ServiceAccount
  name: $service_account_name
EOF
        
        if [ $? -eq 0 ]; then
            print_success "ServiceAccount and RBAC created"
            print_info "Service Account: $service_account_name"
            print_info "Token Secret: ${service_account_name}-token"
        else
            print_warning "Failed to create ServiceAccount/RBAC (authentication may not work)"
        fi
    fi
    
    # Common post-deployment info
    echo ""
    print_info "Deployment initiated. The model will take 5-10 minutes to be ready."
    echo ""
    
    print_info "View pods:"
    echo "  oc get pods -n $target_namespace"
    echo ""
    
    if [ "$auth_enabled" = true ] && [ -n "$service_account_name" ]; then
        print_info "Get API token:"
        echo "  oc get secret ${service_account_name}-token -n $target_namespace -o jsonpath='{.data.token}' | base64 -d"
        echo ""
        print_info "Or create a short-lived token:"
        echo "  oc create token $service_account_name -n $target_namespace --duration=24h"
        echo ""
    fi
    
    print_info "Get model endpoint:"
    echo "  oc get route -n $target_namespace"
    echo ""
    
    return 0
}

################################################################################
# Backward Compatibility Alias
################################################################################
# Maintain backward compatibility with old function name
deploy_llmd_model_interactive() {
    deploy_model_interactive "$@"
}

