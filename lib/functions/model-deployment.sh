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
        runtime_names+=("vLLM (InferenceService)")
        runtime_descriptions+=("Simple deployment, GenAI Playground")
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
    local tool_parser="hermes"  # Default parser for Qwen models
    
    case "$model_choice" in
        1)
            model_uri="oci://registry.redhat.io/rhelai1/modelcar-qwen3-4b-fp8-dynamic:latest"
            model_name="qwen3-4b"
            default_gpu="1"
            default_cpu="4"
            default_memory="16Gi"
            tool_calling_enabled=true
            tool_parser="hermes"
            ;;
        2)
            model_uri="oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b-fp8-dynamic:latest"
            model_name="qwen3-8b"
            default_gpu="1"
            default_cpu="8"
            default_memory="32Gi"
            tool_calling_enabled=true
            tool_parser="hermes"
            ;;
        3)
            model_uri="oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct"
            model_name="llama-32-3b-instruct"
            default_gpu="1"
            default_cpu="4"
            default_memory="16Gi"
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
        # No hardware profiles found, ask for manual or default
        echo -e "${YELLOW}No GPU hardware profiles found.${NC}"
        echo ""
        echo "Default resources:"
        echo "  GPU limit: $default_gpu"
        echo "  CPU limit: $default_cpu"
        echo "  Memory limit: $default_memory"
        echo ""
        
        read -p "Use default resources? (Y/n): " use_defaults
        use_defaults=$(echo "$use_defaults" | tr -d '[:space:]')
        
        if [[ "$use_defaults" =~ ^[Nn]$ ]]; then
            echo ""
            read -p "GPU limit (default: $default_gpu): " input_gpu
            gpu_limit="${input_gpu:-$default_gpu}"
            
            read -p "CPU limit (default: $default_cpu): " input_cpu
            cpu_limit="${input_cpu:-$default_cpu}"
            
            read -p "Memory limit (default: $default_memory): " input_memory
            memory_limit="${input_memory:-$default_memory}"
        fi
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

