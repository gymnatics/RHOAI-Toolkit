#!/bin/bash
################################################################################
# MaaS Demo - Full Setup
################################################################################
# One-command setup for the complete MaaS demo:
#   1. Infrastructure (LWS, TLS certificate)
#   2. Model deployment (LLMInferenceService)
#   3. Streamlit web app
#
# Usage:
#   ./demo.sh                          # Interactive mode
#   ./demo.sh -n maas-demo -m qwen3-4b # Non-interactive
#   ./demo.sh --delete -n maas-demo    # Cleanup everything
#   ./demo.sh --app-only               # Skip model, deploy app only
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/infrastructure.sh"
source "$SCRIPT_DIR/lib/model-catalog.sh"
source "$SCRIPT_DIR/lib/model-discovery.sh"
source "$SCRIPT_DIR/lib/tiers.sh"

# Default values
NAMESPACE=""
MODEL_KEY=""
DELETE_MODE=false
APP_ONLY=false
SKIP_APP=false
SKIP_TIERS=false
SETUP_TIERS_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -m|--model)
            MODEL_KEY="$2"
            shift 2
            ;;
        --delete)
            DELETE_MODE=true
            shift
            ;;
        --app-only)
            APP_ONLY=true
            shift
            ;;
        --skip-app)
            SKIP_APP=true
            shift
            ;;
        --skip-tiers)
            SKIP_TIERS=true
            shift
            ;;
        --setup-tiers)
            SETUP_TIERS_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -n, --namespace NS   Namespace for demo (default: maas-demo)"
            echo "  -m, --model KEY      Model to deploy (default: qwen3-4b)"
            echo "  --app-only           Only deploy app (model must exist)"
            echo "  --skip-app           Only deploy model, skip app"
            echo "  --skip-tiers         Skip tier ServiceAccount setup"
            echo "  --setup-tiers        Only setup tier ServiceAccounts"
            echo "  --delete             Delete entire demo"
            echo "  -h, --help           Show this help"
            echo ""
            echo "Available models:"
            list_catalog_models
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

################################################################################
# Delete Mode
################################################################################

if [ "$DELETE_MODE" = true ]; then
    print_header "Delete MaaS Demo"
    
    check_oc_login || exit 1
    
    if [ -z "$NAMESPACE" ]; then
        read -p "Namespace to delete [maas-demo]: " NAMESPACE
        NAMESPACE=${NAMESPACE:-maas-demo}
    fi
    
    print_step "Deleting demo from $NAMESPACE..."
    
    # Delete app resources
    oc delete route maas-demo -n "$NAMESPACE" --ignore-not-found=true
    oc delete service maas-demo -n "$NAMESPACE" --ignore-not-found=true
    oc delete deployment maas-demo -n "$NAMESPACE" --ignore-not-found=true
    oc delete secret maas-demo-token -n "$NAMESPACE" --ignore-not-found=true
    oc delete configmap maas-demo-code -n "$NAMESPACE" --ignore-not-found=true
    oc delete serviceaccount maas-demo-app -n "$NAMESPACE" --ignore-not-found=true
    oc delete rolebinding maas-demo-app-model-access -n "$NAMESPACE" --ignore-not-found=true
    
    # Delete model
    oc delete llminferenceservice --all -n "$NAMESPACE" --ignore-not-found=true
    
    print_success "Demo resources deleted"
    
    read -p "Delete namespace $NAMESPACE? [y/N]: " DELETE_NS
    if [[ "$DELETE_NS" =~ ^[Yy] ]]; then
        oc delete project "$NAMESPACE" --ignore-not-found=true
        print_success "Namespace deleted"
    fi
    
    exit 0
fi

################################################################################
# Setup Mode
################################################################################

print_header "MaaS Demo - Full Setup"

echo -e "${CYAN}This script will set up:${NC}"
echo "  1. Infrastructure (LWS operator, TLS certificate)"
echo "  2. Model deployment (LLMInferenceService with llm-d)"
echo "  3. Tier ServiceAccounts (Free/Standard/Premium rate limits)"
echo "  4. Streamlit web application"
echo ""

# Check prerequisites
print_step "Checking prerequisites..."
check_oc_login || exit 1
print_success "Logged in to OpenShift"

if ! check_rhoai; then
    print_error "RHOAI must be installed first"
    exit 1
fi

if ! check_llmisvc_crd; then
    print_error "LLMInferenceService CRD not available"
    exit 1
fi

CLUSTER_DOMAIN=$(get_cluster_domain)
print_success "Cluster: $CLUSTER_DOMAIN"

# Set defaults
NAMESPACE=${NAMESPACE:-maas-demo}
MODEL_KEY=${MODEL_KEY:-qwen3-4b}

# Interactive prompts if not specified
if [ -z "$1" ]; then
    echo ""
    read -p "Namespace [$NAMESPACE]: " INPUT_NS
    NAMESPACE=${INPUT_NS:-$NAMESPACE}
    
    if [ "$APP_ONLY" != true ]; then
        echo ""
        list_catalog_models
        read -p "Model [$MODEL_KEY]: " INPUT_MODEL
        MODEL_KEY=${INPUT_MODEL:-$MODEL_KEY}
    fi
fi

# Validate model
if [ "$APP_ONLY" != true ]; then
    if ! parse_model_info "$MODEL_KEY"; then
        print_error "Unknown model: $MODEL_KEY"
        list_catalog_models
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Configuration:${NC}"
echo -e "  Namespace: ${GREEN}$NAMESPACE${NC}"
if [ "$APP_ONLY" != true ]; then
    echo -e "  Model:     ${GREEN}$MODEL_KEY${NC} ($MODEL_DISPLAY_NAME)"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "Continue? [Y/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn] ]]; then
    echo "Aborted."
    exit 0
fi

################################################################################
# Step 1: Infrastructure
################################################################################

if [ "$APP_ONLY" != true ]; then
    print_header "Step 1: Infrastructure Setup"
    
    ensure_lws_crd "$SCRIPT_DIR/manifests" || {
        print_error "Failed to setup LWS. Install 'Red Hat build of Leader Worker Set' from OperatorHub"
        exit 1
    }
    
    ensure_gateway_tls || print_warning "TLS setup skipped (may already exist)"
    
    check_maas_gateway || print_warning "MaaS gateway not ready - external access may not work"
    
    check_gpu_nodes || print_warning "No GPU nodes detected - model may not schedule"
fi

################################################################################
# Step 2: Create Namespace
################################################################################

print_header "Step 2: Namespace Setup"

if ! oc get project "$NAMESPACE" &>/dev/null; then
    print_step "Creating namespace: $NAMESPACE"
    oc new-project "$NAMESPACE"
else
    print_success "Namespace exists: $NAMESPACE"
fi
oc project "$NAMESPACE" >/dev/null

################################################################################
# Step 3: Deploy Model
################################################################################

if [ "$APP_ONLY" != true ]; then
    print_header "Step 3: Model Deployment"
    
    # Check if model already exists
    if oc get llminferenceservice "$MODEL_KEY" -n "$NAMESPACE" &>/dev/null; then
        print_success "Model already deployed: $MODEL_KEY"
        
        STATUS=$(oc get llminferenceservice "$MODEL_KEY" -n "$NAMESPACE" \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        
        if [ "$STATUS" != "True" ]; then
            print_warning "Model exists but not ready yet"
        fi
    else
        print_step "Deploying model: $MODEL_KEY"
        
        # Export variables for envsubst
        export MODEL_NAME="$MODEL_KEY"
        export MODEL_DISPLAY_NAME
        export MODEL_URI
        export TOOL_PARSER
        export AUTH_ENABLED="true"
        
        apply_manifest "$SCRIPT_DIR/manifests/llminferenceservice.yaml" "$NAMESPACE"
        print_success "LLMInferenceService created"
        
        # Wait for model
        print_step "Waiting for model to be ready (this may take several minutes)..."
        
        for i in {1..60}; do
            STATUS=$(oc get llminferenceservice "$MODEL_KEY" -n "$NAMESPACE" \
                -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            
            if [ "$STATUS" = "True" ]; then
                echo ""
                print_success "Model is ready!"
                break
            fi
            
            REASON=$(oc get llminferenceservice "$MODEL_KEY" -n "$NAMESPACE" \
                -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)
            echo -ne "\r  Status: ${REASON:-Initializing}... (${i}/60)    "
            
            sleep 10
        done
        echo ""
    fi
fi

################################################################################
# Step 4: Setup Tier ServiceAccounts and Rate Limiting Fixes
################################################################################

if [ "$SKIP_TIERS" != true ]; then
    print_header "Step 4: Tier Setup & Rate Limiting Fixes"
    
    echo ""
    echo -e "${CYAN}Setting up tier-based rate limiting:${NC}"
    echo "  - Create tier ServiceAccounts (free, premium, enterprise)"
    echo "  - Configure tier-to-group-mapping for SA-based tier resolution"
    echo "  - Apply AuthPolicy with tier lookup"
    echo "  - Apply TokenRateLimitPolicy with per-tier limits"
    echo ""
    
    # Use the comprehensive tier setup function from tiers.sh
    # This creates: groups, ServiceAccounts, RBAC, and tokens
    setup_tier_testing "$NAMESPACE"
    
    # Wait for AuthPolicy to be created by odh-model-controller
    # The AuthPolicy is created when the LLMInferenceService is deployed
    print_step "Waiting for AuthPolicy to be created..."
    for i in {1..30}; do
        if oc get authpolicy maas-default-gateway-authn -n openshift-ingress &>/dev/null; then
            print_success "AuthPolicy found"
            break
        fi
        sleep 2
    done
    
    # Apply ALL tier fixes in the correct order:
    # 1. Fix tier-to-group-mapping ConfigMap (use SA usernames instead of OpenShift groups)
    #    - Kubernetes TokenReview doesn't return OpenShift groups, only system groups
    #    - By using SA usernames as "groups", we can properly resolve tiers
    # 2. Apply AuthPolicy with tier lookup (includes username in groups array)
    #    - The default AuthPolicy doesn't have tier lookup
    #    - We need metadata section to call maas-api for tier resolution
    #    - We need response section to inject tier into auth.identity.tier
    # 3. Delete conflicting UI-created TokenRateLimitPolicies
    #    - UI creates individual policies per tier which override each other
    # 4. Apply combined TokenRateLimitPolicy
    #    - Single policy with all tiers to avoid conflicts
    # 5. Clear caches (restart maas-api, Authorino, Limitador)
    #    - Ensure fresh tier resolution and rate limit counters
    
    print_step "Applying tier rate limiting fixes..."
    
    # Fix tier-to-group-mapping to use SA usernames
    fix_tier_to_group_mapping "$NAMESPACE"
    
    # Apply AuthPolicy with tier lookup (includes username in groups)
    if [ -f "$SCRIPT_DIR/manifests/authpolicy-with-tier-lookup.yaml" ]; then
        apply_authpolicy_with_tier_lookup "$SCRIPT_DIR/manifests"
    else
        fix_authpolicy_username_in_groups
    fi
    
    # Delete conflicting UI-created policies
    cleanup_ui_tier_policies
    
    # Apply TokenRateLimitPolicy if CRD exists
    if check_tokenratelimitpolicy_crd; then
        print_step "Applying TokenRateLimitPolicy..."
        if [ -f "$SCRIPT_DIR/manifests/tiers/tokenratelimitpolicy.yaml" ]; then
            oc apply -f "$SCRIPT_DIR/manifests/tiers/tokenratelimitpolicy.yaml" 2>/dev/null || true
            
            # Wait and verify enforcement
            sleep 5
            local enforced
            enforced=$(oc get tokenratelimitpolicy maas-tier-token-rate-limits -n openshift-ingress \
                -o jsonpath='{.status.conditions[?(@.type=="Enforced")].status}' 2>/dev/null)
            if [ "$enforced" = "True" ]; then
                print_success "TokenRateLimitPolicy is enforced"
            else
                print_warning "TokenRateLimitPolicy may not be enforced yet - retrying..."
                cleanup_ui_tier_policies
                oc apply -f "$SCRIPT_DIR/manifests/tiers/tokenratelimitpolicy.yaml" 2>/dev/null || true
                sleep 3
            fi
        fi
    else
        print_info "TokenRateLimitPolicy CRD not found - rate limiting will be simulated"
        print_info "Install Red Hat Connectivity Link 1.3+ for actual rate limiting"
    fi
    
    # Clear caches to ensure fresh tier resolution
    clear_rate_limit_caches
    
    # Regenerate tier tokens (in case they expired or were invalidated)
    print_step "Regenerating tier tokens..."
    generate_tier_tokens_secret "$NAMESPACE" "maas-demo-tier-tokens" "24h"
fi

# Exit early if only setting up tiers
if [ "$SETUP_TIERS_ONLY" = true ]; then
    print_header "Tier Setup Complete!"
    echo ""
    list_tiers
    echo ""
    echo "Generate tokens with:"
    echo "  oc create token maas-free-tier -n $NAMESPACE --audience=https://kubernetes.default.svc"
    exit 0
fi

################################################################################
# Step 5: Deploy Streamlit App
################################################################################

if [ "$SKIP_APP" != true ]; then
    print_header "Step 5: Streamlit App Deployment"
    
    # Find model if app-only mode
    if [ "$APP_ONLY" = true ]; then
        print_step "Finding deployed models..."
        READY_MODEL=$(get_ready_models | head -1)
        
        if [ -z "$READY_MODEL" ]; then
            print_error "No ready models found. Deploy a model first or remove --app-only"
            exit 1
        fi
        
        parse_model "$READY_MODEL"
        MODEL_KEY="$MODEL_NAME"
        print_success "Using model: $MODEL_NAMESPACE/$MODEL_NAME"
    else
        MODEL_NAMESPACE="$NAMESPACE"
        MODEL_NAME="$MODEL_KEY"
    fi
    
    # Export variables for envsubst
    export APP_NAMESPACE="$NAMESPACE"
    export MODEL_NAMESPACE
    export MODEL_NAME
    # Use maas-api endpoint for RHOAI 3.3+ (supports tier-based rate limiting)
    export MAAS_ENDPOINT="maas-api.${CLUSTER_DOMAIN}"
    
    # Create ConfigMap with app code
    print_step "Creating ConfigMap with app code..."
    oc create configmap maas-demo-code \
        --from-file=app.py="$SCRIPT_DIR/app.py" \
        --from-file=requirements.txt="$SCRIPT_DIR/requirements.txt" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | oc apply -f -
    print_success "ConfigMap created"
    
    # Create ServiceAccount
    print_step "Creating ServiceAccount..."
    apply_manifest "$SCRIPT_DIR/manifests/serviceaccount.yaml" "$NAMESPACE"
    print_success "ServiceAccount created"
    
    # Create RoleBinding
    print_step "Creating RoleBinding for model access..."
    apply_manifest "$SCRIPT_DIR/manifests/rolebinding.yaml" "$MODEL_NAMESPACE"
    print_success "RoleBinding created"
    
    # Generate token
    print_step "Generating API token..."
    TOKEN=$(generate_maas_token "maas-demo-app" "$NAMESPACE" "24h")
    if [ -z "$TOKEN" ]; then
        print_error "Failed to generate token"
        exit 1
    fi
    print_success "Token generated (valid for 24 hours)"
    
    # Create Secret
    print_step "Creating Secret with API token..."
    oc create secret generic maas-demo-token \
        --from-literal=token="$TOKEN" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | oc apply -f -
    print_success "Secret created"
    
    # Create Deployment
    print_step "Creating Deployment..."
    apply_manifest "$SCRIPT_DIR/manifests/deployment.yaml" "$NAMESPACE"
    print_success "Deployment created"
    
    # Inject tier tokens into deployment (if tier tokens secret exists)
    if oc get secret maas-tier-tokens -n "$NAMESPACE" &>/dev/null; then
        print_step "Injecting tier tokens into deployment..."
        oc set env deployment/maas-demo -n "$NAMESPACE" \
            --from=secret/maas-tier-tokens \
            --prefix=MAAS_TIER_ 2>/dev/null || \
        oc patch deployment maas-demo -n "$NAMESPACE" --type=json -p='[
            {"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "MAAS_TIER_FREE_TOKEN", "valueFrom": {"secretKeyRef": {"name": "maas-tier-tokens", "key": "free"}}}},
            {"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "MAAS_TIER_PREMIUM_TOKEN", "valueFrom": {"secretKeyRef": {"name": "maas-tier-tokens", "key": "premium"}}}},
            {"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "MAAS_TIER_ENTERPRISE_TOKEN", "valueFrom": {"secretKeyRef": {"name": "maas-tier-tokens", "key": "enterprise"}}}}
        ]' 2>/dev/null || true
        print_success "Tier tokens injected"
    fi
    
    # Create Service
    print_step "Creating Service..."
    apply_manifest "$SCRIPT_DIR/manifests/service.yaml" "$NAMESPACE"
    print_success "Service created"
    
    # Create Route
    print_step "Creating Route..."
    apply_manifest "$SCRIPT_DIR/manifests/route.yaml" "$NAMESPACE"
    print_success "Route created"
    
    # Wait for deployment
    print_step "Waiting for app to be ready..."
    wait_for_deployment "maas-demo" "$NAMESPACE" 300
fi

################################################################################
# Summary
################################################################################

APP_URL=$(oc get route maas-demo -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null)
MAAS_ENDPOINT="maas-api.${CLUSTER_DOMAIN}"

print_header "Demo Setup Complete!"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  ${GREEN}MaaS Demo is Ready!${NC}                                         ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Web App:${NC}      ${GREEN}https://${APP_URL}${NC}"
echo -e "  ${CYAN}MaaS API:${NC}     ${GREEN}https://${MAAS_ENDPOINT}${NC}"
echo -e "  ${CYAN}Namespace:${NC}    ${GREEN}${NAMESPACE}${NC}"
echo -e "  ${CYAN}Model:${NC}        ${GREEN}${MODEL_KEY}${NC}"
echo -e "  ${CYAN}Tiers:${NC}        ${GREEN}Free (1K) | Premium (5K) | Enterprise (10K) tokens/min${NC}"
echo -e "  ${CYAN}Rate Reset:${NC}   ${GREEN}Every 1 minute (demo mode)${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}Quick Test (API):${NC}"
echo ""
echo "  TOKEN=\$(oc create token default -n $NAMESPACE --duration=1h --audience=https://kubernetes.default.svc)"
echo ""
echo "  curl -sk https://${MAAS_ENDPOINT}/${NAMESPACE}/${MODEL_KEY}/v1/chat/completions \\"
echo "    -H \"Authorization: Bearer \$TOKEN\" \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{\"model\": \"${MODEL_KEY}\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}To cleanup:${NC}  ./demo.sh --delete -n $NAMESPACE"
echo ""
echo -e "${GREEN}Open the demo: https://${APP_URL}${NC}"
