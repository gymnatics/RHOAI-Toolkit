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
    
    # Get the model's endpoint URL from InferenceService status
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
    
    # If still no URL, construct it from the predictor service name
    if [ -z "$url" ]; then
        url="http://${model_name}-predictor.${namespace}.svc.cluster.local"
    fi
    
    # For internal cluster URLs, ensure we use port 8080 (vLLM default)
    # KServe InferenceServices use headless services that expose pods directly
    # The service maps port 80 to pod port 8080, but with headless services
    # we need to use the actual pod port (8080) when connecting via DNS name
    if [[ "$url" == *".svc.cluster.local"* ]]; then
        # Remove any existing port and add :8080
        url=$(echo "$url" | sed -E 's|(\.svc\.cluster\.local)(:[0-9]+)?|\1:8080|')
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

create_llamastack_configmap() {
    local model_name=$1
    local namespace=$2
    local endpoint=$3
    
    print_step "Creating ConfigMap with LlamaStack configuration..."
    
    cat <<EOF | oc apply -f -
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: lsd-genai-playground-config
  namespace: $namespace
  labels:
    llamastack.io/distribution: lsd-genai-playground
    opendatahub.io/dashboard: "true"
data:
  run.yaml: |
    version: "2"
    image_name: rh
    apis:
    - agents
    - datasetio
    - files
    - inference
    - safety
    - scoring
    - tool_runtime
    - vector_io
    providers:
      inference:
      - provider_id: sentence-transformers
        provider_type: inline::sentence-transformers
        config: {}
      - provider_id: vllm-inference-1
        provider_type: remote::vllm
        config:
          api_token: \${env.VLLM_API_TOKEN_1:=fake}
          max_tokens: \${env.VLLM_MAX_TOKENS:=4096}
          tls_verify: \${env.VLLM_TLS_VERIFY:=false}
          url: ${endpoint}/v1
      vector_io:
      - provider_id: milvus
        provider_type: inline::milvus
        config:
          db_path: /opt/app-root/src/.llama/distributions/rh/milvus.db
          kvstore:
            db_path: /opt/app-root/src/.llama/distributions/rh/milvus_registry.db
            namespace: null
            type: sqlite
      agents:
      - provider_id: meta-reference
        provider_type: inline::meta-reference
        config:
          persistence_store:
            db_path: /opt/app-root/src/.llama/distributions/rh/agents_store.db
            namespace: null
            type: sqlite
          responses_store:
            db_path: /opt/app-root/src/.llama/distributions/rh/responses_store.db
            type: sqlite
      eval: []
      files:
      - provider_id: meta-reference-files
        provider_type: inline::localfs
        config:
          metadata_store:
            db_path: /opt/app-root/src/.llama/distributions/rh/files_metadata.db
            type: sqlite
          storage_dir: /opt/app-root/src/.llama/distributions/rh/files
      datasetio:
      - provider_id: huggingface
        provider_type: remote::huggingface
        config:
          kvstore:
            db_path: /opt/app-root/src/.llama/distributions/rh/huggingface_datasetio.db
            namespace: null
            type: sqlite
      scoring:
      - provider_id: basic
        provider_type: inline::basic
        config: {}
      - provider_id: llm-as-judge
        provider_type: inline::llm-as-judge
        config: {}
      tool_runtime:
      - provider_id: rag-runtime
        provider_type: inline::rag-runtime
        config: {}
      - provider_id: model-context-protocol
        provider_type: remote::model-context-protocol
        config: {}
    metadata_store:
      type: sqlite
      db_path: /opt/app-root/src/.llama/distributions/rh/inference_store.db
    models:
    - provider_id: sentence-transformers
      model_id: granite-embedding-125m
      provider_model_id: ibm-granite/granite-embedding-125m-english
      model_type: embedding
      metadata:
        embedding_dimension: 768
    - provider_id: vllm-inference-1
      model_id: ${model_name}
      model_type: llm
      metadata:
        description: ""
        display_name: ${model_name}
    shields: []
    vector_dbs: []
    datasets: []
    scoring_fns: []
    benchmarks: []
    tool_groups:
    - toolgroup_id: builtin::rag
      provider_id: rag-runtime
    server:
      port: 8321
EOF
    
    if [ $? -eq 0 ]; then
        print_success "ConfigMap 'lsd-genai-playground-config' created"
        return 0
    else
        print_error "Failed to create ConfigMap"
        return 1
    fi
}

create_llamastack_distribution() {
    local model_name=$1
    local namespace=$2
    local endpoint=$3
    local model_type=$4
    
    print_step "Creating LlamaStackDistribution for model: $model_name"
    
    # Check if LlamaStackDistribution already exists
    if oc get llamastackdistribution lsd-genai-playground -n "$namespace" &>/dev/null; then
        print_info "LlamaStackDistribution 'lsd-genai-playground' already exists"
        print_info "Adding model to existing playground..."
        
        # Add new model (this is complex, so we'll just inform the user)
        print_warning "To add a model to an existing playground:"
        print_info "1. Edit the ConfigMap: oc edit configmap lsd-genai-playground-config -n $namespace"
        print_info "2. Add your model under 'models:' section in run.yaml"
        print_info "3. Restart the pod: oc delete pod -l app=lsd-genai-playground -n $namespace"
        return 0
    fi
    
    # First, create the ConfigMap with the run.yaml configuration
    if ! create_llamastack_configmap "$model_name" "$namespace" "$endpoint"; then
        return 1
    fi
    
    print_step "Creating LlamaStackDistribution..."
    
    # Now create the LlamaStackDistribution referencing the ConfigMap
    cat <<EOF | oc apply -f -
---
apiVersion: llamastack.io/v1alpha1
kind: LlamaStackDistribution
metadata:
  name: lsd-genai-playground
  namespace: $namespace
  labels:
    opendatahub.io/dashboard: "true"
  annotations:
    openshift.io/display-name: lsd-genai-playground
spec:
  replicas: 1
  server:
    distribution:
      name: rh-dev
    containerSpec:
      name: llama-stack
      port: 8321
      command:
        - /bin/sh
        - -c
        - llama stack run /etc/llama-stack/run.yaml
      env:
        - name: VLLM_TLS_VERIFY
          value: "false"
        - name: MILVUS_DB_PATH
          value: ~/.llama/milvus.db
        - name: FMS_ORCHESTRATOR_URL
          value: http://localhost
        - name: VLLM_MAX_TOKENS
          value: "4096"
        - name: VLLM_API_TOKEN_1
          value: fake
        - name: LLAMA_STACK_CONFIG_DIR
          value: /opt/app-root/src/.llama/distributions/rh/
      resources:
        requests:
          cpu: 250m
          memory: 500Mi
        limits:
          cpu: "2"
          memory: 12Gi
    userConfig:
      configMapName: lsd-genai-playground-config
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
        # Try multiple label selectors - the operator uses different labels
        local pod_status=""
        
        # Try app.kubernetes.io/instance label first (most reliable)
        pod_status=$(oc get pods -n "$namespace" -l app.kubernetes.io/instance=lsd-genai-playground \
            -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
        
        # Fallback to app=llama-stack label
        if [ -z "$pod_status" ]; then
            pod_status=$(oc get pods -n "$namespace" -l app=llama-stack \
                -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
        fi
        
        if [ "$pod_status" = "Running" ]; then
            print_success "Playground pod is running"
            return 0
        fi
        
        echo "Waiting for playground pod... (${elapsed}s elapsed, status: ${pod_status:-pending})"
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
    
    # Verify endpoint connectivity
    print_step "Verifying model endpoint connectivity..."
    local test_url="${endpoint}/v1/models"
    local connectivity_ok=false
    
    # Try to reach the endpoint from a test pod
    if oc run connectivity-test --rm -i --restart=Never --image=registry.access.redhat.com/ubi9/ubi-minimal:latest \
        -n "$namespace" --command -- curl -s --connect-timeout 5 "$test_url" &>/dev/null; then
        connectivity_ok=true
    fi
    
    if [ "$connectivity_ok" = "true" ]; then
        print_success "Model endpoint is reachable"
    else
        print_warning "Could not verify endpoint connectivity (this may be normal)"
        print_info "The endpoint will be tested when the playground starts"
    fi
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

