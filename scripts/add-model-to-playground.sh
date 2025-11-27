#!/bin/bash
################################################################################
# Add Model to GenAI Playground
################################################################################
# This script adds a deployed InferenceService to the GenAI Playground
# by creating a LlamaStackDistribution CR
################################################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "$SCRIPT_DIR/../lib/utils/colors.sh"
source "$SCRIPT_DIR/../lib/utils/common.sh"

################################################################################
# Functions
################################################################################

check_connection() {
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        echo "Please login first: oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to OpenShift cluster"
    return 0
}

list_available_models() {
    local namespace=$1
    
    print_step "Scanning for deployed models in namespace: $namespace"
    
    # Get InferenceServices with genai-asset label
    local models=$(oc get inferenceservice -n "$namespace" \
        -l opendatahub.io/genai-asset=true \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\t"}{.status.url}{"\n"}{end}' 2>/dev/null)
    
    if [ -z "$models" ]; then
        print_warning "No GenAI models found in namespace: $namespace"
        echo ""
        echo "Models must have:"
        echo "  - Label: opendatahub.io/genai-asset=true"
        echo "  - Annotation: opendatahub.io/model-type=generative"
        echo "  - Status: Ready=True"
        echo ""
        return 1
    fi
    
    echo ""
    echo "Available models:"
    echo "─────────────────────────────────────────────────────────"
    printf "%-30s %-10s %-30s\n" "MODEL NAME" "STATUS" "URL"
    echo "─────────────────────────────────────────────────────────"
    
    echo "$models" | while IFS=$'\t' read -r name status url; do
        if [ -n "$name" ]; then
            local status_icon="✗"
            [ "$status" = "True" ] && status_icon="✓"
            printf "%-30s %-10s %-30s\n" "$name" "$status_icon" "${url:0:30}..."
        fi
    done
    
    echo ""
    return 0
}

get_model_endpoint() {
    local model_name=$1
    local namespace=$2
    
    # Get the model's endpoint URL
    local url=$(oc get inferenceservice "$model_name" -n "$namespace" \
        -o jsonpath='{.status.url}' 2>/dev/null)
    
    if [ -z "$url" ]; then
        # Try getting from route
        url=$(oc get route "$model_name" -n "$namespace" \
            -o jsonpath='{.spec.host}' 2>/dev/null)
        if [ -n "$url" ]; then
            url="https://$url"
        fi
    fi
    
    echo "$url"
}

detect_model_type() {
    local model_name=$1
    
    # Map common model names to types
    case "$model_name" in
        *llama*3.2*|*llama*32*)
            echo "llama3"
            ;;
        *llama*3.1*|*llama*31*)
            echo "llama3"
            ;;
        *llama*3*)
            echo "llama3"
            ;;
        *llama*2*)
            echo "llama2"
            ;;
        *mistral*)
            echo "mistral"
            ;;
        *qwen*)
            echo "qwen"
            ;;
        *granite*)
            echo "granite"
            ;;
        *)
            echo "llama3"  # Default
            ;;
    esac
}

create_llamastack_distribution() {
    local model_name=$1
    local namespace=$2
    local endpoint=$3
    local model_type=$4
    
    print_step "Creating LlamaStackDistribution for model: $model_name"
    
    cat <<EOF | oc apply -f -
apiVersion: llamastack.io/v1alpha1
kind: LlamaStackDistribution
metadata:
  name: genai-playground
  namespace: $namespace
spec:
  server:
    distribution:
      image: registry.redhat.io/rhoai/odh-llama-stack-core-rhel9@sha256:13ec5c9b96a9ca8c0a1fcc0568cf6f893478742d28d3b1381f073b9bdafb3320
  models:
    - modelId: "$model_name"
      providerConfig:
        config:
          endpoint: "${endpoint}/v1"
          modelType: "$model_type"
        providerId: "remote::vllm"
      model:
        metadata: {}
        modelType: "$model_type"
        providerResourceId: "$model_name"
EOF
    
    if [ $? -eq 0 ]; then
        print_success "LlamaStackDistribution created"
        return 0
    else
        print_error "Failed to create LlamaStackDistribution"
        return 1
    fi
}

wait_for_playground_pod() {
    local namespace=$1
    
    print_step "Waiting for playground pod to start..."
    
    local timeout=180
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        local pod_status=$(oc get pods -n "$namespace" -l app=lsd-genai-playground \
            -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
        
        if [ "$pod_status" = "Running" ]; then
            print_success "Playground pod is running"
            return 0
        fi
        
        echo "Waiting for playground pod... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_warning "Timeout waiting for playground pod (continuing anyway)"
    return 1
}

show_completion_message() {
    local namespace=$1
    
    print_header "Model Added to Playground Successfully!"
    
    echo "Next steps:"
    echo ""
    echo "1. Access the GenAI Playground:"
    
    local dashboard_url=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null)
    if [ -n "$dashboard_url" ]; then
        echo "   https://$dashboard_url"
    else
        echo "   Check: oc get route rhods-dashboard -n redhat-ods-applications"
    fi
    
    echo ""
    echo "2. Navigate to: GenAI Studio → Playground"
    echo ""
    echo "3. Your model should appear in the Model dropdown"
    echo ""
    echo "4. Select your model and start chatting!"
    echo ""
    echo "Note: If the model doesn't appear immediately:"
    echo "  - Wait 2-3 minutes for the playground pod to fully initialize"
    echo "  - Refresh your browser"
    echo "  - Check playground pod logs:"
    echo "    oc logs -n $namespace deployment/lsd-genai-playground"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    print_header "Add Model to GenAI Playground"
    
    # Check connection
    if ! check_connection; then
        exit 1
    fi
    
    echo ""
    
    # Get namespace
    local current_namespace=$(oc project -q 2>/dev/null)
    echo -e -n "${BLUE}Enter namespace${NC} (default: $current_namespace): "
    read namespace
    namespace=${namespace:-$current_namespace}
    
    echo ""
    
    # List available models
    if ! list_available_models "$namespace"; then
        echo "Deploy a model first using:"
        echo "  ./scripts/quick-deploy-model.sh"
        echo "Or:"
        echo "  ./complete-setup.sh (select option 3: Deploy Model)"
        exit 1
    fi
    
    # Get model name
    echo -e -n "${BLUE}Enter model name to add to playground${NC}: "
    read model_name
    
    if [ -z "$model_name" ]; then
        print_error "Model name is required"
        exit 1
    fi
    
    echo ""
    
    # Verify model exists
    if ! oc get inferenceservice "$model_name" -n "$namespace" &>/dev/null; then
        print_error "Model '$model_name' not found in namespace '$namespace'"
        exit 1
    fi
    
    # Check model is ready
    local ready=$(oc get inferenceservice "$model_name" -n "$namespace" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    
    if [ "$ready" != "True" ]; then
        print_error "Model '$model_name' is not ready yet"
        echo "Current status:"
        oc get inferenceservice "$model_name" -n "$namespace"
        exit 1
    fi
    
    print_success "Model '$model_name' is ready"
    echo ""
    
    # Get model endpoint
    print_step "Detecting model endpoint..."
    local endpoint=$(get_model_endpoint "$model_name" "$namespace")
    
    if [ -z "$endpoint" ]; then
        print_error "Could not determine model endpoint"
        echo "Check manually:"
        echo "  oc get inferenceservice $model_name -n $namespace -o yaml"
        exit 1
    fi
    
    print_success "Model endpoint: $endpoint"
    echo ""
    
    # Detect model type
    print_step "Detecting model type..."
    local model_type=$(detect_model_type "$model_name")
    print_success "Model type: $model_type"
    echo ""
    
    # Confirm
    echo "Summary:"
    echo "  Model: $model_name"
    echo "  Namespace: $namespace"
    echo "  Endpoint: $endpoint"
    echo "  Type: $model_type"
    echo ""
    
    read -p "Add this model to the playground? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        exit 0
    fi
    
    echo ""
    
    # Create LlamaStackDistribution
    if ! create_llamastack_distribution "$model_name" "$namespace" "$endpoint" "$model_type"; then
        print_error "Failed to add model to playground"
        exit 1
    fi
    
    echo ""
    
    # Wait for playground pod
    wait_for_playground_pod "$namespace"
    
    echo ""
    
    # Show completion message
    show_completion_message "$namespace"
    
    print_success "Done!"
}

# Run main function
main "$@"

