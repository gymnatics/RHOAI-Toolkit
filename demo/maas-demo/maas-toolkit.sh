#!/bin/bash
################################################################################
# MaaS Demo Toolkit - Modular Setup Script
################################################################################
# Run specific parts of the MaaS demo setup independently.
#
# Usage:
#   ./maas-toolkit.sh                     # Interactive menu
#   ./maas-toolkit.sh --help              # Show all commands
#   ./maas-toolkit.sh tiers               # Setup tiers only
#   ./maas-toolkit.sh authpolicy          # Fix AuthPolicy only
#   ./maas-toolkit.sh model               # Deploy model only
#   ./maas-toolkit.sh app                 # Deploy app only
#   ./maas-toolkit.sh test                # Test rate limiting
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
source "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || {
    # Fallback colors if lib not available
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    print_header() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}\n"; }
    print_step() { echo -e "${CYAN}▶ $1${NC}"; }
    print_success() { echo -e "${GREEN}✓ $1${NC}"; }
    print_error() { echo -e "${RED}✗ $1${NC}"; }
    print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
    print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
}

# Source other libs if available
[ -f "$SCRIPT_DIR/lib/infrastructure.sh" ] && source "$SCRIPT_DIR/lib/infrastructure.sh"
[ -f "$SCRIPT_DIR/lib/model-catalog.sh" ] && source "$SCRIPT_DIR/lib/model-catalog.sh"
[ -f "$SCRIPT_DIR/lib/model-discovery.sh" ] && source "$SCRIPT_DIR/lib/model-discovery.sh"
[ -f "$SCRIPT_DIR/lib/tiers.sh" ] && source "$SCRIPT_DIR/lib/tiers.sh"

# Default values
NAMESPACE="${NAMESPACE:-maas-demo}"
MODEL_KEY="${MODEL_KEY:-qwen3-4b}"
# Audience must match what AuthPolicy expects (Kubernetes token review)
TOKEN_AUDIENCE="${TOKEN_AUDIENCE:-https://kubernetes.default.svc}"

################################################################################
# Helper Functions
################################################################################

check_logged_in() {
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift. Run: oc login"
        return 1
    fi
    return 0
}

get_cluster_domain() {
    oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null
}

show_help() {
    cat << 'EOF'
MaaS Demo Toolkit - Modular Setup Script

USAGE:
    ./maas-toolkit.sh [COMMAND] [OPTIONS]

COMMANDS:
    (no command)      Interactive menu
    
    INFRASTRUCTURE:
    infra             Setup infrastructure (LWS, TLS, Gateway check)
    namespace         Create/verify namespace
    
    TIERS & AUTH:
    tiers             Setup tier ServiceAccounts, groups, RBAC, tokens
    authpolicy        Apply AuthPolicy fix for tier lookup
    authpolicy-check  Check current AuthPolicy status
    ratelimit         Apply combined TokenRateLimitPolicy
    ratelimit-check   Check TokenRateLimitPolicy status
    fix-all           Apply all tier fixes (authpolicy + ratelimit + caches)
    clear-caches      Clear Authorino and Limitador caches
    
    MODEL:
    model             Deploy LLMInferenceService model
    model-status      Check model status
    model-delete      Delete model
    
    APP:
    app               Deploy Streamlit app
    app-delete        Delete Streamlit app
    
    TOKENS:
    tokens            Generate and display tier tokens
    tokens-secret     Store tier tokens in secret
    
    TESTING:
    test              Test rate limiting for all tiers
    test-free         Test free tier only
    test-premium      Test premium tier only
    test-enterprise   Test enterprise tier only
    
    DIAGNOSTICS:
    status            Show overall status
    diagnose          Run full diagnostics
    
    CLEANUP:
    delete            Delete entire demo
    delete-policies   Delete all custom policies

OPTIONS:
    -n, --namespace NS    Namespace (default: maas-demo)
    -m, --model MODEL     Model key (default: qwen3-4b)
    --audience AUD        Token audience (default: maas-default-gateway-sa)
    -h, --help            Show this help

EXAMPLES:
    # Setup tiers without deploying model
    ./maas-toolkit.sh tiers -n my-namespace
    
    # Fix AuthPolicy after model deployment
    ./maas-toolkit.sh authpolicy
    
    # Apply all fixes
    ./maas-toolkit.sh fix-all -n maas-demo
    
    # Test rate limiting
    ./maas-toolkit.sh test -n maas-demo
    
    # Generate tokens for testing
    ./maas-toolkit.sh tokens -n maas-demo
EOF
}

################################################################################
# Command: Infrastructure
################################################################################

cmd_infra() {
    print_header "Infrastructure Setup"
    check_logged_in || return 1
    
    # Check LWS
    print_step "Checking LeaderWorkerSet CRD..."
    if oc get crd leaderworkersets.leaderworkerset.x-k8s.io &>/dev/null; then
        print_success "LWS CRD available"
    else
        print_warning "LWS CRD not found - install 'Red Hat build of Leader Worker Set' from OperatorHub"
    fi
    
    # Check MaaS Gateway
    print_step "Checking MaaS Gateway..."
    if oc get gateway maas-default-gateway -n openshift-ingress &>/dev/null; then
        print_success "MaaS Gateway exists"
    else
        print_warning "MaaS Gateway not found - MaaS may not be enabled"
    fi
    
    # Check GPU nodes
    print_step "Checking GPU nodes..."
    GPU_NODES=$(oc get nodes -l nvidia.com/gpu.present=true --no-headers 2>/dev/null | wc -l)
    if [ "$GPU_NODES" -gt 0 ]; then
        print_success "Found $GPU_NODES GPU node(s)"
    else
        print_warning "No GPU nodes detected"
    fi
    
    # Check RHOAI
    print_step "Checking RHOAI..."
    RHOAI_VERSION=$(oc get csv -n redhat-ods-operator -o jsonpath='{.items[0].spec.version}' 2>/dev/null)
    if [ -n "$RHOAI_VERSION" ]; then
        print_success "RHOAI version: $RHOAI_VERSION"
    else
        print_warning "RHOAI not found"
    fi
}

################################################################################
# Command: Namespace
################################################################################

cmd_namespace() {
    print_header "Namespace Setup"
    check_logged_in || return 1
    
    if oc get project "$NAMESPACE" &>/dev/null; then
        print_success "Namespace exists: $NAMESPACE"
    else
        print_step "Creating namespace: $NAMESPACE"
        oc new-project "$NAMESPACE"
        print_success "Namespace created"
    fi
}

################################################################################
# Command: Tiers
################################################################################

cmd_tiers() {
    print_header "Tier Setup"
    check_logged_in || return 1
    
    # Ensure namespace exists
    cmd_namespace
    
    # Create tier groups
    print_step "Creating tier groups..."
    for tier in free premium enterprise; do
        local group_name="${tier}-users"
        if ! oc get group "$group_name" &>/dev/null 2>&1; then
            oc adm groups new "$group_name" 2>/dev/null && \
                print_success "Created group: $group_name" || true
        else
            print_info "Group exists: $group_name"
        fi
    done
    
    # Create ServiceAccounts
    print_step "Creating tier ServiceAccounts..."
    for tier in free premium enterprise; do
        local sa_name="tier-${tier}-sa"
        if ! oc get serviceaccount "$sa_name" -n "$NAMESPACE" &>/dev/null 2>&1; then
            oc create serviceaccount "$sa_name" -n "$NAMESPACE" && \
                print_success "Created ServiceAccount: $sa_name"
        else
            print_info "ServiceAccount exists: $sa_name"
        fi
    done
    
    # Add SAs to groups using b64: prefix
    print_step "Adding ServiceAccounts to groups..."
    for tier in premium enterprise; do
        local sa_name="tier-${tier}-sa"
        local group_name="${tier}-users"
        local sa_full="system:serviceaccount:${NAMESPACE}:${sa_name}"
        
        oc adm groups add-users "$group_name" "b64:${sa_full}" 2>/dev/null && \
            print_success "Added $sa_name to $group_name" || \
            print_info "$sa_name may already be in $group_name"
    done
    
    # Create RBAC
    print_step "Creating RBAC for model access..."
    cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: llminferenceservice-access
  namespace: $NAMESPACE
rules:
- apiGroups: ["serving.kserve.io"]
  resources: ["llminferenceservices"]
  verbs: ["get", "post"]
EOF
    
    for tier in free premium enterprise; do
        local sa_name="tier-${tier}-sa"
        oc create rolebinding "${sa_name}-access" \
            --role=llminferenceservice-access \
            --serviceaccount="${NAMESPACE}:${sa_name}" \
            -n "$NAMESPACE" 2>/dev/null || true
    done
    print_success "RBAC configured"
    
    print_success "Tier setup complete!"
    echo ""
    echo "ServiceAccounts created:"
    echo "  - tier-free-sa"
    echo "  - tier-premium-sa"
    echo "  - tier-enterprise-sa"
    echo ""
    echo "Generate tokens with:"
    echo "  oc create token tier-free-sa -n $NAMESPACE --audience=$TOKEN_AUDIENCE"
}

################################################################################
# Command: AuthPolicy
################################################################################

cmd_authpolicy() {
    print_header "AuthPolicy Fix"
    check_logged_in || return 1
    
    local gateway_ns="openshift-ingress"
    
    # Check current AuthPolicies
    print_step "Checking AuthPolicies..."
    oc get authpolicy -n "$gateway_ns" -o custom-columns='NAME:.metadata.name,ENFORCED:.status.conditions[?(@.type=="Enforced")].status' 2>/dev/null || {
        print_warning "No AuthPolicies found"
        return 0
    }
    
    # Check if maas-default-gateway-authn exists and needs patching
    local policy_name="maas-default-gateway-authn"
    if oc get authpolicy "$policy_name" -n "$gateway_ns" &>/dev/null; then
        local current_body
        current_body=$(oc get authpolicy "$policy_name" -n "$gateway_ns" \
            -o jsonpath='{.spec.rules.metadata.matchedTier.http.body.expression}' 2>/dev/null)
        
        if echo "$current_body" | grep -q "auth.identity.user.username"; then
            print_success "AuthPolicy already includes username in tier lookup"
        else
            print_step "Patching AuthPolicy to include username..."
            oc patch authpolicy "$policy_name" -n "$gateway_ns" --type=merge -p '{
              "spec": {
                "rules": {
                  "metadata": {
                    "matchedTier": {
                      "http": {
                        "body": {
                          "expression": "{ \"groups\": auth.identity.user.groups + [auth.identity.user.username] }"
                        }
                      }
                    }
                  }
                }
              }
            }'
            print_success "AuthPolicy patched"
        fi
    else
        print_info "AuthPolicy $policy_name not found - will be created after model deployment"
    fi
}

cmd_authpolicy_check() {
    print_header "AuthPolicy Status"
    check_logged_in || return 1
    
    echo "AuthPolicies in openshift-ingress:"
    oc get authpolicy -n openshift-ingress -o custom-columns='NAME:.metadata.name,ENFORCED:.status.conditions[?(@.type=="Enforced")].status,MESSAGE:.status.conditions[?(@.type=="Enforced")].message' 2>/dev/null
    
    echo ""
    echo "AuthPolicies in redhat-ods-applications:"
    oc get authpolicy -n redhat-ods-applications -o custom-columns='NAME:.metadata.name,ENFORCED:.status.conditions[?(@.type=="Enforced")].status' 2>/dev/null
}

################################################################################
# Command: Rate Limit Policy
################################################################################

cmd_ratelimit() {
    print_header "TokenRateLimitPolicy Setup"
    check_logged_in || return 1
    
    # Check CRD
    if ! oc get crd tokenratelimitpolicies.kuadrant.io &>/dev/null; then
        print_error "TokenRateLimitPolicy CRD not found"
        print_info "Install Red Hat Connectivity Link 1.3+ for rate limiting"
        return 1
    fi
    
    # Delete conflicting UI-created policies
    print_step "Removing conflicting UI-created policies..."
    for policy in tier-free-token-rate-limits tier-premium-token-rate-limits tier-enterprise-token-rate-limits; do
        oc delete tokenratelimitpolicy "$policy" -n openshift-ingress --ignore-not-found 2>/dev/null
    done
    
    # Apply combined policy
    print_step "Applying combined TokenRateLimitPolicy..."
    if [ -f "$SCRIPT_DIR/manifests/tiers/tokenratelimitpolicy.yaml" ]; then
        oc apply -f "$SCRIPT_DIR/manifests/tiers/tokenratelimitpolicy.yaml"
        print_success "TokenRateLimitPolicy applied"
    else
        print_warning "TokenRateLimitPolicy manifest not found at $SCRIPT_DIR/manifests/tiers/tokenratelimitpolicy.yaml"
        print_info "Creating default policy..."
        
        cat <<EOF | oc apply -f -
apiVersion: kuadrant.io/v1alpha1
kind: TokenRateLimitPolicy
metadata:
  name: maas-tier-token-rate-limits
  namespace: openshift-ingress
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: maas-default-gateway
  limits:
    free-tokens:
      counters:
        - expression: auth.identity.userid
      rates:
        - limit: 1000
          window: 1m0s
      when:
        - predicate: auth.identity.tier == "free" && !request.path.endsWith("/v1/models")
    premium-tokens:
      counters:
        - expression: auth.identity.userid
      rates:
        - limit: 5000
          window: 1m0s
      when:
        - predicate: auth.identity.tier == "premium" && !request.path.endsWith("/v1/models")
    enterprise-tokens:
      counters:
        - expression: auth.identity.userid
      rates:
        - limit: 10000
          window: 1m0s
      when:
        - predicate: auth.identity.tier == "enterprise" && !request.path.endsWith("/v1/models")
EOF
        print_success "Default TokenRateLimitPolicy created"
    fi
}

cmd_ratelimit_check() {
    print_header "TokenRateLimitPolicy Status"
    check_logged_in || return 1
    
    echo "TokenRateLimitPolicies:"
    oc get tokenratelimitpolicy -n openshift-ingress -o custom-columns='NAME:.metadata.name,ENFORCED:.status.conditions[?(@.type=="Enforced")].status,MESSAGE:.status.conditions[?(@.type=="Enforced")].message' 2>/dev/null
    
    echo ""
    echo "Limitador counters:"
    LIMITADOR_POD=$(oc get pods -n kuadrant-system -l app=limitador -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$LIMITADOR_POD" ]; then
        oc exec -n kuadrant-system "$LIMITADOR_POD" -- curl -s localhost:8080/counters 2>/dev/null || echo "(empty)"
    else
        echo "(Limitador pod not found)"
    fi
}

################################################################################
# Command: Fix All (Engineer-recommended steps)
################################################################################

cmd_fix_all() {
    print_header "Apply All Tier Fixes (Engineer-Recommended)"
    check_logged_in || return 1
    
    # Step 1: Label gateway as NOT managed by RHOAI
    print_step "Step 1: Labeling gateway as not managed by RHOAI..."
    oc label gateway maas-default-gateway -n openshift-ingress \
        opendatahub.io/managed=false --overwrite 2>/dev/null && \
        print_success "Gateway labeled as not managed" || \
        print_warning "Could not label gateway (may not exist yet)"
    
    # Step 2: Remove conflicting AuthPolicy created by RHOAI
    print_step "Step 2: Removing conflicting maas-default-gateway-authn AuthPolicy..."
    oc delete authpolicy maas-default-gateway-authn -n openshift-ingress --ignore-not-found 2>/dev/null && \
        print_success "Conflicting AuthPolicy removed" || \
        print_info "AuthPolicy not found (already removed)"
    
    # Step 3: Apply AuthPolicy fix (if needed)
    echo ""
    cmd_authpolicy
    
    # Step 4: Apply combined TokenRateLimitPolicy
    echo ""
    cmd_ratelimit
    
    # Step 5: Clear caches
    echo ""
    cmd_clear_caches
    
    print_success "All fixes applied!"
    echo ""
    echo "IMPORTANT: Do NOT use the UI to create or manage tiers."
    echo "Use CLI/API only for tier management."
}

################################################################################
# Command: Clear Caches
################################################################################

cmd_clear_caches() {
    print_header "Clear Rate Limit Caches"
    check_logged_in || return 1
    
    print_step "Restarting Authorino..."
    oc rollout restart deployment/authorino -n kuadrant-system 2>/dev/null && \
        oc rollout status deployment/authorino -n kuadrant-system --timeout=60s 2>/dev/null || true
    
    print_step "Restarting Limitador..."
    oc rollout restart deployment/limitador-limitador -n kuadrant-system 2>/dev/null && \
        oc rollout status deployment/limitador-limitador -n kuadrant-system --timeout=60s 2>/dev/null || true
    
    print_step "Restarting MaaS API..."
    oc rollout restart deployment/maas-api -n redhat-ods-applications 2>/dev/null && \
        oc rollout status deployment/maas-api -n redhat-ods-applications --timeout=60s 2>/dev/null || true
    
    print_success "Caches cleared"
}

################################################################################
# Command: Model
################################################################################

cmd_model() {
    print_header "Model Deployment"
    check_logged_in || return 1
    
    cmd_namespace
    
    if oc get llminferenceservice "$MODEL_KEY" -n "$NAMESPACE" &>/dev/null; then
        print_success "Model already exists: $MODEL_KEY"
        cmd_model_status
        return 0
    fi
    
    # Get model info from catalog
    if ! parse_model_info "$MODEL_KEY"; then
        print_error "Model '$MODEL_KEY' not found in catalog"
        print_info "Available models:"
        list_catalog_models
        return 1
    fi
    
    print_step "Deploying model: $MODEL_KEY"
    print_info "Display name: $MODEL_DISPLAY_NAME"
    print_info "URI: $MODEL_URI"
    print_info "Tool parser: $TOOL_PARSER"
    
    if [ -f "$SCRIPT_DIR/manifests/llminferenceservice.yaml" ]; then
        export MODEL_NAME="$MODEL_KEY"
        export AUTH_ENABLED="true"
        # MODEL_DISPLAY_NAME, MODEL_URI, TOOL_PARSER already exported by parse_model_info
        envsubst < "$SCRIPT_DIR/manifests/llminferenceservice.yaml" | oc apply -f -
    else
        print_error "Model manifest not found"
        return 1
    fi
    
    print_success "Model deployment initiated"
    print_info "Run './maas-toolkit.sh model-status' to check progress"
}

cmd_model_status() {
    print_header "Model Status"
    check_logged_in || return 1
    
    echo "LLMInferenceServices in $NAMESPACE:"
    oc get llminferenceservice -n "$NAMESPACE" -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,URL:.status.url' 2>/dev/null
}

cmd_model_delete() {
    print_header "Delete Model"
    check_logged_in || return 1
    
    print_step "Deleting model: $MODEL_KEY"
    oc delete llminferenceservice "$MODEL_KEY" -n "$NAMESPACE" --ignore-not-found
    print_success "Model deleted"
}

################################################################################
# Command: Tokens
################################################################################

cmd_tokens() {
    print_header "Generate Tier Tokens"
    check_logged_in || return 1
    
    local duration="${1:-1h}"
    
    echo "Generating tokens with audience: $TOKEN_AUDIENCE"
    echo "Duration: $duration"
    echo ""
    
    for tier in free premium enterprise; do
        local tier_upper=$(echo "$tier" | tr '[:lower:]' '[:upper:]')
        echo "=== ${tier_upper} TIER ==="
        oc create token "tier-${tier}-sa" -n "$NAMESPACE" \
            --duration="$duration" \
            --audience="$TOKEN_AUDIENCE" 2>/dev/null || echo "Failed to generate token"
        echo ""
    done
}

cmd_tokens_secret() {
    print_header "Store Tier Tokens in Secret"
    check_logged_in || return 1
    
    local duration="24h"
    
    print_step "Generating tokens..."
    
    local free_token premium_token enterprise_token
    free_token=$(oc create token tier-free-sa -n "$NAMESPACE" --duration="$duration" --audience="$TOKEN_AUDIENCE" 2>/dev/null)
    premium_token=$(oc create token tier-premium-sa -n "$NAMESPACE" --duration="$duration" --audience="$TOKEN_AUDIENCE" 2>/dev/null)
    enterprise_token=$(oc create token tier-enterprise-sa -n "$NAMESPACE" --duration="$duration" --audience="$TOKEN_AUDIENCE" 2>/dev/null)
    
    if [ -z "$free_token" ] || [ -z "$premium_token" ] || [ -z "$enterprise_token" ]; then
        print_error "Failed to generate tokens. Make sure tier ServiceAccounts exist."
        print_info "Run: ./maas-toolkit.sh tiers"
        return 1
    fi
    
    print_step "Creating secret..."
    oc create secret generic maas-tier-tokens \
        --from-literal=free="$free_token" \
        --from-literal=premium="$premium_token" \
        --from-literal=enterprise="$enterprise_token" \
        -n "$NAMESPACE" --dry-run=client -o yaml | oc apply -f -
    
    print_success "Tokens stored in secret: maas-tier-tokens"
}

################################################################################
# Command: Test
################################################################################

cmd_test() {
    print_header "Test Rate Limiting"
    check_logged_in || return 1
    
    local cluster_domain
    cluster_domain=$(get_cluster_domain)
    # Use inference-gateway endpoint (not maas-api which doesn't exist)
    local endpoint="inference-gateway.${cluster_domain}"
    
    echo "Endpoint: https://$endpoint"
    echo "Namespace: $NAMESPACE"
    echo "Model: $MODEL_KEY"
    echo ""
    
    for tier in free premium enterprise; do
        cmd_test_tier "$tier" "$endpoint"
        echo ""
    done
}

cmd_test_tier() {
    local tier="$1"
    local endpoint="$2"
    
    if [ -z "$endpoint" ]; then
        local cluster_domain
        cluster_domain=$(get_cluster_domain)
        # Use inference-gateway endpoint (not maas-api which doesn't exist)
        endpoint="inference-gateway.${cluster_domain}"
    fi
    
    local tier_upper
    tier_upper=$(echo "$tier" | tr '[:lower:]' '[:upper:]')
    echo "=== Testing ${tier_upper} tier ==="
    
    local token
    token=$(oc create token "tier-${tier}-sa" -n "$NAMESPACE" --duration=10m --audience="$TOKEN_AUDIENCE" 2>/dev/null)
    
    if [ -z "$token" ]; then
        print_error "Failed to generate token for tier-${tier}-sa"
        return 1
    fi
    
    for i in {1..3}; do
        echo -n "Request $i: "
        local http_code
        http_code=$(curl -sk -o /dev/null -w "%{http_code}" \
            "https://${endpoint}/${NAMESPACE}/${MODEL_KEY}/v1/chat/completions" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d '{"model": "'"$MODEL_KEY"'", "messages": [{"role": "user", "content": "Hi"}], "max_tokens": 20}')
        
        if [ "$http_code" = "429" ]; then
            echo "HTTP $http_code (RATE LIMITED)"
        else
            echo "HTTP $http_code"
        fi
        sleep 1
    done
}

cmd_test_free() { cmd_test_tier "free"; }
cmd_test_premium() { cmd_test_tier "premium"; }
cmd_test_enterprise() { cmd_test_tier "enterprise"; }

################################################################################
# Command: Status
################################################################################

cmd_status() {
    print_header "MaaS Demo Status"
    check_logged_in || return 1
    
    local cluster_domain
    cluster_domain=$(get_cluster_domain)
    
    echo "Cluster: $cluster_domain"
    echo "Namespace: $NAMESPACE"
    echo ""
    
    echo "=== Models ==="
    oc get llminferenceservice -n "$NAMESPACE" --no-headers 2>/dev/null || echo "None"
    echo ""
    
    echo "=== Tier ServiceAccounts ==="
    oc get serviceaccount -n "$NAMESPACE" -l '!kubernetes.io/service-account.name' --no-headers 2>/dev/null | grep tier || echo "None"
    echo ""
    
    echo "=== AuthPolicies (openshift-ingress) ==="
    oc get authpolicy -n openshift-ingress -o custom-columns='NAME:.metadata.name,ENFORCED:.status.conditions[?(@.type=="Enforced")].status' --no-headers 2>/dev/null || echo "None"
    echo ""
    
    echo "=== TokenRateLimitPolicies ==="
    oc get tokenratelimitpolicy -n openshift-ingress -o custom-columns='NAME:.metadata.name,ENFORCED:.status.conditions[?(@.type=="Enforced")].status' --no-headers 2>/dev/null || echo "None"
    echo ""
    
    echo "=== Streamlit App ==="
    local app_url
    app_url=$(oc get route maas-demo -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null)
    if [ -n "$app_url" ]; then
        echo "URL: https://$app_url"
    else
        echo "Not deployed"
    fi
}

################################################################################
# Command: Diagnose
################################################################################

cmd_diagnose() {
    print_header "Full Diagnostics"
    check_logged_in || return 1
    
    cmd_status
    echo ""
    
    echo "=== tier-to-group-mapping ConfigMap ==="
    oc get configmap tier-to-group-mapping -n redhat-ods-applications -o jsonpath='{.data.tiers}' 2>/dev/null || echo "Not found"
    echo ""
    
    echo "=== OpenShift Groups ==="
    oc get groups -o custom-columns='NAME:.metadata.name,USERS:.users' 2>/dev/null | grep -E "free|premium|enterprise|NAME" || echo "None"
    echo ""
    
    echo "=== Limitador Status ==="
    LIMITADOR_POD=$(oc get pods -n kuadrant-system -l app=limitador -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$LIMITADOR_POD" ]; then
        echo "Limits:"
        oc exec -n kuadrant-system "$LIMITADOR_POD" -- curl -s localhost:8080/limits 2>/dev/null | head -20 || echo "(empty)"
        echo ""
        echo "Counters:"
        oc exec -n kuadrant-system "$LIMITADOR_POD" -- curl -s localhost:8080/counters 2>/dev/null || echo "(empty)"
    else
        echo "Limitador pod not found"
    fi
}

################################################################################
# Command: Delete
################################################################################

cmd_delete() {
    print_header "Delete MaaS Demo"
    check_logged_in || return 1
    
    read -p "Delete all demo resources from $NAMESPACE? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo "Aborted."
        return 0
    fi
    
    print_step "Deleting app resources..."
    oc delete route maas-demo -n "$NAMESPACE" --ignore-not-found
    oc delete service maas-demo -n "$NAMESPACE" --ignore-not-found
    oc delete deployment maas-demo -n "$NAMESPACE" --ignore-not-found
    oc delete secret maas-demo-token maas-tier-tokens -n "$NAMESPACE" --ignore-not-found
    oc delete configmap maas-demo-code -n "$NAMESPACE" --ignore-not-found
    
    print_step "Deleting tier resources..."
    for tier in free premium enterprise; do
        oc delete serviceaccount "tier-${tier}-sa" -n "$NAMESPACE" --ignore-not-found
        oc delete rolebinding "tier-${tier}-sa-access" -n "$NAMESPACE" --ignore-not-found
    done
    oc delete role llminferenceservice-access -n "$NAMESPACE" --ignore-not-found
    
    print_step "Deleting model..."
    oc delete llminferenceservice --all -n "$NAMESPACE" --ignore-not-found
    
    print_success "Demo resources deleted"
    
    read -p "Delete namespace $NAMESPACE? [y/N]: " delete_ns
    if [[ "$delete_ns" =~ ^[Yy] ]]; then
        oc delete project "$NAMESPACE" --ignore-not-found
        print_success "Namespace deleted"
    fi
}

cmd_delete_policies() {
    print_header "Delete Custom Policies"
    check_logged_in || return 1
    
    print_step "Deleting TokenRateLimitPolicies..."
    oc delete tokenratelimitpolicy maas-tier-token-rate-limits -n openshift-ingress --ignore-not-found
    oc delete tokenratelimitpolicy tier-free-token-rate-limits tier-premium-token-rate-limits tier-enterprise-token-rate-limits -n openshift-ingress --ignore-not-found
    
    print_success "Policies deleted"
}

################################################################################
# Interactive Menu
################################################################################

show_menu() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${GREEN}MaaS Demo Toolkit${NC}                                            ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Namespace: ${GREEN}$NAMESPACE${NC}"
    echo -e "  Model:     ${GREEN}$MODEL_KEY${NC}"
    echo ""
    echo -e "${CYAN}  INFRASTRUCTURE${NC}"
    echo "    1) Check infrastructure"
    echo "    2) Create namespace"
    echo ""
    echo -e "${CYAN}  TIERS & AUTH${NC}"
    echo "    3) Setup tiers (ServiceAccounts, groups, RBAC)"
    echo "    4) Fix AuthPolicy"
    echo "    5) Apply TokenRateLimitPolicy"
    echo "    6) Apply ALL fixes"
    echo "    7) Clear caches"
    echo ""
    echo -e "${CYAN}  MODEL${NC}"
    echo "    8) Deploy model"
    echo "    9) Check model status"
    echo ""
    echo -e "${CYAN}  TESTING${NC}"
    echo "   10) Generate tier tokens"
    echo "   11) Test rate limiting"
    echo ""
    echo -e "${CYAN}  DIAGNOSTICS${NC}"
    echo "   12) Show status"
    echo "   13) Full diagnostics"
    echo ""
    echo -e "${CYAN}  CLEANUP${NC}"
    echo "   14) Delete demo"
    echo ""
    echo "    q) Quit"
    echo ""
}

interactive_menu() {
    while true; do
        show_menu
        read -p "Select option: " choice
        echo ""
        
        case $choice in
            1) cmd_infra ;;
            2) cmd_namespace ;;
            3) cmd_tiers ;;
            4) cmd_authpolicy ;;
            5) cmd_ratelimit ;;
            6) cmd_fix_all ;;
            7) cmd_clear_caches ;;
            8) cmd_model ;;
            9) cmd_model_status ;;
            10) cmd_tokens ;;
            11) cmd_test ;;
            12) cmd_status ;;
            13) cmd_diagnose ;;
            14) cmd_delete ;;
            q|Q) echo "Goodbye!"; exit 0 ;;
            *) echo "Invalid option" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

################################################################################
# Main
################################################################################

# Parse global options first
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
        --audience)
            TOKEN_AUDIENCE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            # First non-option argument is the command
            break
            ;;
    esac
done

# Get command
COMMAND="${1:-}"
shift 2>/dev/null || true

# Execute command
case "$COMMAND" in
    "")
        interactive_menu
        ;;
    infra)
        cmd_infra
        ;;
    namespace)
        cmd_namespace
        ;;
    tiers)
        cmd_tiers
        ;;
    authpolicy)
        cmd_authpolicy
        ;;
    authpolicy-check)
        cmd_authpolicy_check
        ;;
    ratelimit)
        cmd_ratelimit
        ;;
    ratelimit-check)
        cmd_ratelimit_check
        ;;
    fix-all)
        cmd_fix_all
        ;;
    clear-caches)
        cmd_clear_caches
        ;;
    model)
        cmd_model
        ;;
    model-status)
        cmd_model_status
        ;;
    model-delete)
        cmd_model_delete
        ;;
    app)
        # Delegate to existing deploy-app.sh if available
        if [ -f "$SCRIPT_DIR/deploy-app.sh" ]; then
            "$SCRIPT_DIR/deploy-app.sh" -n "$NAMESPACE"
        else
            print_error "deploy-app.sh not found"
        fi
        ;;
    app-delete)
        print_step "Deleting app..."
        oc delete route,service,deployment,configmap,secret -l app=maas-demo -n "$NAMESPACE" --ignore-not-found
        print_success "App deleted"
        ;;
    tokens)
        cmd_tokens "$@"
        ;;
    tokens-secret)
        cmd_tokens_secret
        ;;
    test)
        cmd_test
        ;;
    test-free)
        cmd_test_free
        ;;
    test-premium)
        cmd_test_premium
        ;;
    test-enterprise)
        cmd_test_enterprise
        ;;
    status)
        cmd_status
        ;;
    diagnose)
        cmd_diagnose
        ;;
    delete)
        cmd_delete
        ;;
    delete-policies)
        cmd_delete_policies
        ;;
    *)
        echo "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
