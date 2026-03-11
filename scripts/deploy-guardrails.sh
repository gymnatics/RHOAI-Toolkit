#!/bin/bash
################################################################################
# Deploy TrustyAI Guardrails Orchestrator
################################################################################
# Deploys Guardrails to protect an LLM with PII detection and safety filters.
#
# Features:
#   - Checks prerequisites (TrustyAI, RawDeployment mode)
#   - Lists available models or offers to deploy one
#   - Deploys Guardrails Orchestrator with Gateway
#   - Creates preset pipelines: /pii, /safe, /passthrough
#
# Usage:
#   ./deploy-guardrails.sh [namespace]
#
################################################################################

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
NAMESPACE="${1:-}"
SELECTED_MODEL=""

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║            Deploy Guardrails Demo ${GREEN}[AI Safety]${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() { echo -e "${YELLOW}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Check if logged in to OpenShift
check_login() {
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        echo "Please login first: oc login <cluster-url>"
        exit 1
    fi
    print_success "Connected to OpenShift cluster"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    echo ""
    
    # Check RHOAI installed
    if ! oc get datasciencecluster default-dsc &>/dev/null; then
        print_error "RHOAI not installed (DataScienceCluster not found)"
        exit 1
    fi
    print_success "RHOAI installed"
    
    # Check TrustyAI component enabled
    TRUSTYAI_STATE=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.trustyai.managementState}' 2>/dev/null || echo "")
    if [ "$TRUSTYAI_STATE" != "Managed" ]; then
        print_error "TrustyAI component not enabled"
        echo ""
        echo "Enable TrustyAI in your DataScienceCluster:"
        echo -e "${YELLOW}  spec.components.trustyai.managementState: Managed${NC}"
        echo ""
        echo "Or run:"
        echo -e "${YELLOW}  oc patch datasciencecluster default-dsc --type=merge -p '{\"spec\":{\"components\":{\"trustyai\":{\"managementState\":\"Managed\"}}}}'${NC}"
        exit 1
    fi
    print_success "TrustyAI component enabled"
    
    # Check KServe RawDeployment mode (required for Guardrails)
    RAW_MODE=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.kserve.rawDeploymentServiceConfig}' 2>/dev/null || echo "")
    if [ "$RAW_MODE" != "Headed" ]; then
        print_warning "KServe RawDeployment mode not configured (found: '$RAW_MODE')"
        echo ""
        echo "Guardrails requires RawDeployment mode. Configure in DataScienceCluster:"
        echo -e "${YELLOW}  spec.components.kserve.rawDeploymentServiceConfig: Headed${NC}"
        echo ""
        read -p "Continue anyway? (y/n): " continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        print_success "KServe RawDeployment mode configured"
    fi
    echo ""
}

# Get or set namespace
get_namespace() {
    if [ -z "$NAMESPACE" ]; then
        CURRENT_NS=$(oc project -q 2>/dev/null || echo "default")
        read -p "Namespace (default: $CURRENT_NS): " input_ns
        NAMESPACE="${input_ns:-$CURRENT_NS}"
    fi
    
    # Check if namespace exists
    if ! oc get namespace "$NAMESPACE" &>/dev/null; then
        print_warning "Namespace '$NAMESPACE' does not exist"
        read -p "Create it? (y/n): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc new-project "$NAMESPACE" || oc create namespace "$NAMESPACE"
            print_success "Namespace created: $NAMESPACE"
        else
            exit 0
        fi
    fi
    
    print_info "Using namespace: $NAMESPACE"
    echo ""
}

# Find available models
find_models() {
    print_step "Looking for available models..."
    echo ""
    
    # Get InferenceServices
    MODELS=$(oc get isvc -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null || echo "")
    
    if [ -z "$MODELS" ]; then
        print_warning "No InferenceServices found in namespace '$NAMESPACE'"
        echo ""
        offer_model_deployment
        return
    fi
    
    echo "Available models:"
    echo ""
    
    local i=1
    local model_array=()
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            MODEL_NAME=$(echo "$line" | awk '{print $1}')
            MODEL_STATUS=$(echo "$line" | awk '{print $2}')
            
            if [ "$MODEL_STATUS" = "True" ]; then
                STATUS_ICON="${GREEN}Running${NC}"
            else
                STATUS_ICON="${YELLOW}Not Ready${NC}"
            fi
            
            echo -e "  ${YELLOW}$i)${NC} $MODEL_NAME ($STATUS_ICON)"
            model_array+=("$MODEL_NAME")
            ((i++))
        fi
    done <<< "$MODELS"
    
    echo ""
    
    if [ ${#model_array[@]} -eq 0 ]; then
        offer_model_deployment
        return
    fi
    
    read -p "Select model to guardrail (1-${#model_array[@]}): " model_choice
    
    if [[ "$model_choice" =~ ^[0-9]+$ ]] && [ "$model_choice" -ge 1 ] && [ "$model_choice" -le ${#model_array[@]} ]; then
        SELECTED_MODEL="${model_array[$((model_choice-1))]}"
        print_success "Selected model: $SELECTED_MODEL"
    else
        print_error "Invalid selection"
        exit 1
    fi
    echo ""
}

# Offer to deploy a model if none exists
offer_model_deployment() {
    echo "Guardrails requires a model to protect. Would you like to deploy one?"
    echo ""
    echo -e "${YELLOW}1)${NC} Deploy Qwen3-8B ${GREEN}(Recommended - 16GB GPU)${NC}"
    echo "   Small, fast, good for demos"
    echo ""
    echo -e "${YELLOW}2)${NC} Deploy Granite-7B-Lab ${BLUE}(24GB GPU)${NC}"
    echo "   Red Hat's instruction-tuned model"
    echo ""
    echo -e "${YELLOW}3)${NC} Enter model details manually"
    echo "   Specify name and S3 path"
    echo ""
    echo -e "${YELLOW}4)${NC} Skip - I'll deploy a model manually"
    echo "   Run: ./scripts/serve-model.sh s3 <name> <path>"
    echo ""
    
    read -p "Select option (1-4): " deploy_choice
    
    case $deploy_choice in
        1)
            deploy_preset_model "qwen3-8b" "Qwen/Qwen3-8B-Instruct"
            ;;
        2)
            deploy_preset_model "granite-7b-lab" "instructlab/granite-7b-lab"
            ;;
        3)
            read -p "Model name: " custom_name
            read -p "S3 path: " custom_path
            deploy_preset_model "$custom_name" "$custom_path"
            ;;
        4)
            echo ""
            print_info "Deploy a model first, then run this script again:"
            echo -e "  ${YELLOW}./scripts/serve-model.sh s3 qwen3-8b Qwen/Qwen3-8B-Instruct${NC}"
            exit 0
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
}

# Deploy a preset model using serve-model.sh
deploy_preset_model() {
    local name="$1"
    local path="$2"
    
    echo ""
    print_step "Deploying model: $name"
    echo ""
    
    # Check if serve-model.sh exists
    if [ ! -f "$SCRIPT_DIR/serve-model.sh" ]; then
        print_error "serve-model.sh not found"
        echo "Please ensure $SCRIPT_DIR/serve-model.sh exists"
        exit 1
    fi
    
    # Deploy using serve-model.sh
    NAMESPACE="$NAMESPACE" "$SCRIPT_DIR/serve-model.sh" s3 "$name" "$path"
    
    echo ""
    print_step "Waiting for model to be ready (this may take 5-10 minutes)..."
    
    if oc wait --for=condition=Ready isvc/"$name" -n "$NAMESPACE" --timeout=600s 2>/dev/null; then
        print_success "Model is ready!"
        SELECTED_MODEL="$name"
    else
        print_error "Model deployment timed out"
        echo "Check status: oc get isvc $name -n $NAMESPACE"
        exit 1
    fi
    echo ""
}

# Deploy Guardrails
deploy_guardrails() {
    print_step "Deploying Guardrails Orchestrator..."
    echo ""
    
    # Get model's predictor service name
    # KServe creates a service named <model>-predictor
    MODEL_SERVICE="${SELECTED_MODEL}-predictor"
    
    # Verify the service exists
    if ! oc get svc "$MODEL_SERVICE" -n "$NAMESPACE" &>/dev/null; then
        # Try without -predictor suffix
        if oc get svc "$SELECTED_MODEL" -n "$NAMESPACE" &>/dev/null; then
            MODEL_SERVICE="$SELECTED_MODEL"
        else
            print_warning "Could not find service for model '$SELECTED_MODEL'"
            print_info "Using model name as service: $SELECTED_MODEL"
            MODEL_SERVICE="$SELECTED_MODEL"
        fi
    fi
    
    print_info "Model service: $MODEL_SERVICE"
    echo ""
    
    # Deploy orchestrator config
    print_step "Creating orchestrator ConfigMap..."
    export MODEL_SERVICE_NAME="$MODEL_SERVICE"
    envsubst < "$BASE_DIR/lib/manifests/guardrails/orchestrator-config.yaml" | oc apply -n "$NAMESPACE" -f -
    print_success "ConfigMap created: guardrails-orchestrator-config"
    
    # Deploy gateway config
    print_step "Creating gateway ConfigMap..."
    oc apply -n "$NAMESPACE" -f "$BASE_DIR/lib/manifests/guardrails/gateway-config.yaml"
    print_success "ConfigMap created: guardrails-gateway-config"
    
    # Deploy GuardrailsOrchestrator CR
    print_step "Creating GuardrailsOrchestrator..."
    export ENABLE_AUTH="false"
    envsubst < "$BASE_DIR/lib/manifests/guardrails/orchestrator-cr.yaml" | oc apply -n "$NAMESPACE" -f -
    print_success "GuardrailsOrchestrator created"
    
    echo ""
}

# Wait for deployment
wait_for_deployment() {
    print_step "Waiting for Guardrails pods to be ready..."
    echo ""
    
    # Wait for the orchestrator pod
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        POD_STATUS=$(oc get pods -n "$NAMESPACE" -l app.kubernetes.io/name=guardrails-orchestrator -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
        READY_CONTAINERS=$(oc get pods -n "$NAMESPACE" -l app.kubernetes.io/name=guardrails-orchestrator -o jsonpath='{.items[0].status.containerStatuses[*].ready}' 2>/dev/null || echo "")
        
        if [ "$POD_STATUS" = "Running" ]; then
            # Check if all containers are ready
            if echo "$READY_CONTAINERS" | grep -qv "false"; then
                print_success "Guardrails pods are ready!"
                return 0
            fi
        fi
        
        echo -n "."
        sleep 5
        ((attempt++))
    done
    
    echo ""
    print_warning "Pods not ready after 5 minutes"
    echo "Check status: oc get pods -n $NAMESPACE -l app.kubernetes.io/name=guardrails-orchestrator"
}

# Verify deployment and print info
verify_deployment() {
    echo ""
    print_step "Verifying deployment..."
    echo ""
    
    # Get routes
    HEALTH_ROUTE=$(oc get route guardrails-orchestrator-health -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    GATEWAY_ROUTE=$(oc get route guardrails-orchestrator-gateway -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    
    # If routes don't exist yet, try alternate names
    if [ -z "$HEALTH_ROUTE" ]; then
        HEALTH_ROUTE=$(oc get route -n "$NAMESPACE" -l app.kubernetes.io/name=guardrails-orchestrator -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "not-available")
    fi
    
    if [ -z "$GATEWAY_ROUTE" ]; then
        GATEWAY_ROUTE=$(oc get route -n "$NAMESPACE" -o jsonpath='{.items[?(@.metadata.name contains "gateway")].spec.host}' 2>/dev/null || echo "not-available")
    fi
    
    # Test health endpoint if available
    if [ "$HEALTH_ROUTE" != "not-available" ] && [ -n "$HEALTH_ROUTE" ]; then
        echo "Testing health endpoint..."
        HEALTH_RESPONSE=$(curl -sk "https://$HEALTH_ROUTE/health" 2>/dev/null || echo "")
        if echo "$HEALTH_RESPONSE" | grep -q "fms-guardrails"; then
            print_success "Health check passed!"
        else
            print_warning "Health check returned unexpected response"
        fi
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Guardrails deployed successfully!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${MAGENTA}Configuration:${NC}"
    echo "  Model:     $SELECTED_MODEL"
    echo "  Namespace: $NAMESPACE"
    echo "  Auth:      disabled"
    echo ""
    echo -e "${MAGENTA}Endpoints:${NC}"
    if [ -n "$HEALTH_ROUTE" ] && [ "$HEALTH_ROUTE" != "not-available" ]; then
        echo "  Health:  https://$HEALTH_ROUTE/health"
    fi
    if [ -n "$GATEWAY_ROUTE" ] && [ "$GATEWAY_ROUTE" != "not-available" ]; then
        echo "  Gateway: https://$GATEWAY_ROUTE"
    fi
    echo ""
    echo -e "${MAGENTA}Gateway Pipelines:${NC}"
    echo "  /pii/v1/chat/completions         - Filters PII (email, SSN, credit card)"
    echo "  /safe/v1/chat/completions        - All safety checks enabled"
    echo "  /passthrough/v1/chat/completions - No filtering (direct to model)"
    echo ""
    echo -e "${MAGENTA}Test with:${NC}"
    echo -e "  ${YELLOW}./demo/guardrails-demo/test-guardrails.sh $NAMESPACE${NC}"
    echo -e "  ${YELLOW}./demo/guardrails-demo/test-gateway.sh $NAMESPACE${NC}"
    echo ""
    echo -e "${MAGENTA}To enable authentication:${NC}"
    echo -e "  ${YELLOW}oc patch guardrailsorchestrator guardrails-orchestrator -n $NAMESPACE --type=merge -p '{\"metadata\":{\"annotations\":{\"security.opendatahub.io/enable-auth\":\"true\"}}}'${NC}"
    echo ""
}

# Main
main() {
    print_header
    check_login
    check_prerequisites
    get_namespace
    find_models
    
    if [ -z "$SELECTED_MODEL" ]; then
        print_error "No model selected"
        exit 1
    fi
    
    # Confirm deployment
    echo -e "${MAGENTA}Configuration Summary:${NC}"
    echo "  Model:     $SELECTED_MODEL"
    echo "  Namespace: $NAMESPACE"
    echo "  Detectors: Built-in (PII, SSN, credit card, phone, IP)"
    echo "  Gateway:   Enabled (pii, safe, passthrough pipelines)"
    echo "  Auth:      Disabled"
    echo ""
    
    read -p "Deploy Guardrails? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    
    echo ""
    deploy_guardrails
    wait_for_deployment
    verify_deployment
}

main "$@"
