#!/bin/bash
################################################################################
# Tier management functions for MaaS Demo
# RHOAI 3.3 built-in tiers based on OpenShift groups
################################################################################

# RHOAI 3.3 Built-in Tiers (from tier-to-group-mapping ConfigMap)
# These tiers are determined by OpenShift group membership
# The auth.identity.tier claim is set by RHOAI based on the user's highest-level group
#
# Tier resolution works via:
# 1. User authenticates with Kubernetes token
# 2. AuthPolicy calls maas-api /v1/tiers/lookup with user's groups
# 3. maas-api returns the highest tier the user belongs to
# 4. Tier is injected into auth.identity.tier for rate limiting
#
# IMPORTANT: The default AuthPolicy created by odh-model-controller does NOT
# include tier lookup. You must patch it to add the metadata section.
# See: demo/maas-demo/manifests/authpolicy-with-tier-lookup.yaml
#
TIER_NAMES=("free" "premium" "enterprise")
TIER_DISPLAY_NAMES=("Free Tier" "Premium Tier" "Enterprise Tier")
TIER_GROUPS=("system:authenticated,tier-free-users" "tier-premium-users,premium-group" "tier-enterprise-users,enterprise-group,admin-group")
TIER_LIMITS=("1000" "5000" "10000")  # tokens per minute (demo mode)
TIER_WINDOW="1m"  # 1-minute window for demo (change to "1h" for production)
TIER_LEVELS=("0" "1" "2")

# Gateway used by RHOAI 3.3 MaaS
MAAS_GATEWAY="maas-default-gateway"
MAAS_GATEWAY_NAMESPACE="openshift-ingress"

# Get tier index
_get_tier_index() {
    local tier="$1"
    for i in "${!TIER_NAMES[@]}"; do
        if [ "${TIER_NAMES[$i]}" = "$tier" ]; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

# List available tiers
list_tiers() {
    echo "RHOAI 3.3 Built-in Tiers (Demo Mode - 1 minute window):"
    echo ""
    printf "  %-12s %-18s %-10s %s\n" "Tier" "Limit" "Level" "Groups"
    printf "  %-12s %-18s %-10s %s\n" "----" "-----" "-----" "------"
    for i in "${!TIER_NAMES[@]}"; do
        printf "  %-12s %-18s %-10s %s\n" \
            "${TIER_NAMES[$i]}" \
            "${TIER_LIMITS[$i]} tokens/min" \
            "Level ${TIER_LEVELS[$i]}" \
            "${TIER_GROUPS[$i]}"
    done
    echo ""
    echo "Note: Rate limits reset every minute for easy demo testing."
    echo ""
}

# Get groups for a tier
get_tier_groups() {
    local tier="$1"
    local idx
    idx=$(_get_tier_index "$tier")
    
    if [ -z "$idx" ]; then
        return 1
    fi
    
    echo "${TIER_GROUPS[$idx]}"
}

# Get token limit for tier
get_tier_limit() {
    local tier="$1"
    local idx
    idx=$(_get_tier_index "$tier")
    
    if [ -z "$idx" ]; then
        return 1
    fi
    
    echo "${TIER_LIMITS[$idx]}"
}

# Check if user is in a tier group
check_user_tier() {
    local username="$1"
    
    # Get user's groups
    local user_groups
    user_groups=$(oc get groups -o jsonpath='{range .items[*]}{.metadata.name}:{.users}{"\n"}{end}' 2>/dev/null | grep "$username")
    
    # Check from highest tier to lowest
    for i in $(seq $((${#TIER_NAMES[@]} - 1)) -1 0); do
        local tier_groups="${TIER_GROUPS[$i]}"
        IFS=',' read -ra groups <<< "$tier_groups"
        for group in "${groups[@]}"; do
            if echo "$user_groups" | grep -q "^${group}:"; then
                echo "${TIER_NAMES[$i]}"
                return 0
            fi
        done
    done
    
    # Default to free (system:authenticated)
    echo "free"
}

# Add user to tier group
add_user_to_tier() {
    local username="$1"
    local tier="$2"
    
    local idx
    idx=$(_get_tier_index "$tier")
    
    if [ -z "$idx" ]; then
        print_error "Unknown tier: $tier"
        return 1
    fi
    
    # Get primary group for tier (first one, excluding system:authenticated)
    local tier_groups="${TIER_GROUPS[$idx]}"
    local primary_group
    primary_group=$(echo "$tier_groups" | cut -d',' -f1)
    
    if [ "$primary_group" = "system:authenticated" ]; then
        print_info "Free tier is automatic for all authenticated users"
        return 0
    fi
    
    # Create group if it doesn't exist
    if ! oc get group "$primary_group" &>/dev/null; then
        print_step "Creating group: $primary_group"
        oc adm groups new "$primary_group"
    fi
    
    # Add user to group
    print_step "Adding $username to $primary_group"
    oc adm groups add-users "$primary_group" "$username"
    
    print_success "User $username added to ${TIER_NAMES[$idx]} tier"
}

# Check if TokenRateLimitPolicy CRD exists
check_tokenratelimitpolicy_crd() {
    if oc get crd tokenratelimitpolicies.kuadrant.io &>/dev/null; then
        return 0
    fi
    return 1
}

# Apply TokenRateLimitPolicy for tiers
apply_tier_rate_limits() {
    local manifests_dir="$1"
    
    if ! check_tokenratelimitpolicy_crd; then
        print_warning "TokenRateLimitPolicy CRD not found"
        print_info "Tier-based rate limiting requires Red Hat Connectivity Link 1.3+"
        return 1
    fi
    
    print_step "Applying TokenRateLimitPolicy for tiers..."
    
    if [ -f "$manifests_dir/tiers/tokenratelimitpolicy.yaml" ]; then
        oc apply -f "$manifests_dir/tiers/tokenratelimitpolicy.yaml"
        print_success "TokenRateLimitPolicy applied"
    else
        print_warning "TokenRateLimitPolicy manifest not found"
        return 1
    fi
}

# Get tier configuration from cluster
get_tier_config_from_cluster() {
    oc get configmap tier-to-group-mapping -n redhat-ods-applications -o yaml 2>/dev/null
}

# Show current tier rate limits
show_tier_rate_limits() {
    echo "Current TokenRateLimitPolicy:"
    oc get tokenratelimitpolicy -n openshift-ingress -o yaml 2>/dev/null | grep -A 50 "limits:" | head -60
}

################################################################################
# Critical Fixes for Tier-Based Rate Limiting
################################################################################

# Fix tier-to-group-mapping ConfigMap to use ServiceAccount usernames
# This is needed because Kubernetes TokenReview doesn't return OpenShift groups,
# only system groups like system:authenticated. By using SA usernames as "groups"
# in the mapping, we can properly resolve tiers.
fix_tier_to_group_mapping() {
    local namespace="$1"
    
    if [ -z "$namespace" ]; then
        print_error "Namespace required"
        return 1
    fi
    
    print_step "Fixing tier-to-group-mapping ConfigMap..."
    
    # Create ConfigMap with SA usernames as groups
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: tier-to-group-mapping
  namespace: redhat-ods-applications
  labels:
    app: maas-api
    app.kubernetes.io/component: api
    app.kubernetes.io/name: maas-api
    app.kubernetes.io/part-of: models-as-a-service
    app.opendatahub.io/modelsasservice: "true"
    component: tier-mapping
    platform.opendatahub.io/part-of: modelsasservice
data:
  tiers: |
    - name: enterprise
      displayName: Enterprise Tier
      groups:
        - system:serviceaccount:${namespace}:tier-enterprise-sa
      level: 2
    - name: premium
      displayName: Premium Tier
      groups:
        - system:serviceaccount:${namespace}:tier-premium-sa
      level: 1
    - name: free
      displayName: Free Tier
      groups:
        - system:serviceaccount:${namespace}:tier-free-sa
        - system:authenticated
      level: 0
EOF
    
    if [ $? -eq 0 ]; then
        print_success "tier-to-group-mapping ConfigMap updated"
        
        # Restart maas-api to pick up the change
        print_step "Restarting maas-api..."
        oc rollout restart deployment/maas-api -n redhat-ods-applications 2>/dev/null || true
        oc rollout status deployment/maas-api -n redhat-ods-applications --timeout=60s 2>/dev/null || true
        
        return 0
    else
        print_error "Failed to update tier-to-group-mapping"
        return 1
    fi
}

# Patch AuthPolicy to include username in tier lookup
# The tier lookup needs the username to match against SA-specific tier mappings
fix_authpolicy_username_in_groups() {
    local gateway_ns="openshift-ingress"
    local policy_name="maas-default-gateway-authn"
    
    # Check if AuthPolicy exists
    if ! oc get authpolicy "$policy_name" -n "$gateway_ns" &>/dev/null; then
        print_info "AuthPolicy $policy_name not found yet - will be created after model deployment"
        return 0
    fi
    
    # Check current body expression
    local current_body
    current_body=$(oc get authpolicy "$policy_name" -n "$gateway_ns" \
        -o jsonpath='{.spec.rules.metadata.matchedTier.http.body.expression}' 2>/dev/null)
    
    # Check if already includes username
    if echo "$current_body" | grep -q "auth.identity.user.username"; then
        print_success "AuthPolicy already includes username in tier lookup"
        return 0
    fi
    
    print_step "Patching AuthPolicy to include username in tier lookup..."
    
    # Patch to include username in the groups array
    oc patch authpolicy "$policy_name" -n "$gateway_ns" --type=merge -p '
{
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
    
    if [ $? -eq 0 ]; then
        print_success "AuthPolicy patched to include username"
        return 0
    else
        print_error "Failed to patch AuthPolicy"
        return 1
    fi
}

# Delete UI-created individual tier TokenRateLimitPolicies
# The UI creates separate policies per tier which override each other.
# We need a single combined policy for all tiers to work correctly.
cleanup_ui_tier_policies() {
    local gateway_ns="openshift-ingress"
    
    print_step "Checking for conflicting UI-created tier policies..."
    
    local deleted=0
    for policy in tier-free-token-rate-limits tier-premium-token-rate-limits tier-enterprise-token-rate-limits; do
        if oc get tokenratelimitpolicy "$policy" -n "$gateway_ns" &>/dev/null; then
            print_info "Deleting conflicting policy: $policy"
            oc delete tokenratelimitpolicy "$policy" -n "$gateway_ns" 2>/dev/null
            deleted=$((deleted + 1))
        fi
    done
    
    if [ $deleted -gt 0 ]; then
        print_success "Deleted $deleted conflicting UI-created policies"
    else
        print_info "No conflicting UI policies found"
    fi
}

# Clear rate limit caches by restarting Authorino and Limitador
clear_rate_limit_caches() {
    print_step "Clearing rate limit caches..."
    
    # Restart Authorino to clear tier lookup cache
    if oc get deployment authorino -n kuadrant-system &>/dev/null; then
        oc rollout restart deployment/authorino -n kuadrant-system 2>/dev/null
        oc rollout status deployment/authorino -n kuadrant-system --timeout=60s 2>/dev/null || true
    fi
    
    # Restart Limitador to clear rate limit counters
    if oc get deployment limitador-limitador -n kuadrant-system &>/dev/null; then
        oc rollout restart deployment/limitador-limitador -n kuadrant-system 2>/dev/null
        oc rollout status deployment/limitador-limitador -n kuadrant-system --timeout=60s 2>/dev/null || true
    fi
    
    print_success "Rate limit caches cleared"
}

# Apply all tier fixes
apply_all_tier_fixes() {
    local namespace="$1"
    
    if [ -z "$namespace" ]; then
        print_error "Namespace required"
        return 1
    fi
    
    print_header "Applying Tier Rate Limiting Fixes"
    
    # 1. Fix tier-to-group-mapping to use SA usernames
    fix_tier_to_group_mapping "$namespace"
    
    # 2. Patch AuthPolicy to include username
    fix_authpolicy_username_in_groups
    
    # 3. Delete conflicting UI-created policies
    cleanup_ui_tier_policies
    
    # 4. Clear caches
    clear_rate_limit_caches
    
    print_success "All tier fixes applied!"
}

################################################################################
# Tier ServiceAccount and Token Management
################################################################################

# Create tier groups (OpenShift groups for tier membership)
create_tier_groups() {
    print_step "Creating tier groups..."
    
    for tier in "${TIER_NAMES[@]}"; do
        local group_name="tier-${tier}-users"
        
        # Skip creating group for free tier (uses system:authenticated)
        if [ "$tier" = "free" ]; then
            continue
        fi
        
        if oc get group "$group_name" &>/dev/null; then
            print_info "Group $group_name already exists"
        else
            oc adm groups new "$group_name" 2>/dev/null && \
                print_success "Created group: $group_name" || \
                print_warning "Failed to create group: $group_name"
        fi
    done
}

# Create tier ServiceAccounts for testing
create_tier_serviceaccounts() {
    local namespace="$1"
    
    if [ -z "$namespace" ]; then
        print_error "Namespace required"
        return 1
    fi
    
    print_step "Creating tier ServiceAccounts in $namespace..."
    
    for tier in "${TIER_NAMES[@]}"; do
        local sa_name="tier-${tier}-sa"
        
        # Create ServiceAccount
        if oc get serviceaccount "$sa_name" -n "$namespace" &>/dev/null; then
            print_info "ServiceAccount $sa_name already exists"
        else
            oc create serviceaccount "$sa_name" -n "$namespace" && \
                print_success "Created ServiceAccount: $sa_name" || \
                print_warning "Failed to create ServiceAccount: $sa_name"
        fi
    done
}

# Add tier ServiceAccounts to their respective groups
add_serviceaccounts_to_tier_groups() {
    local namespace="$1"
    
    if [ -z "$namespace" ]; then
        print_error "Namespace required"
        return 1
    fi
    
    print_step "Adding ServiceAccounts to tier groups..."
    
    for tier in "${TIER_NAMES[@]}"; do
        local sa_name="tier-${tier}-sa"
        local group_name="tier-${tier}-users"
        local sa_full="system:serviceaccount:${namespace}:${sa_name}"
        
        # Base64 encode the SA name (required for usernames with colons)
        local sa_encoded="b64:$(echo -n "$sa_full" | base64)"
        
        # Add to tier group
        if oc adm groups add-users "$group_name" "$sa_encoded" 2>/dev/null; then
            print_success "Added $sa_name to $group_name"
        else
            # Check if already a member
            if oc get group "$group_name" -o jsonpath='{.users}' 2>/dev/null | grep -q "$sa_encoded"; then
                print_info "$sa_name already in $group_name"
            else
                print_warning "Failed to add $sa_name to $group_name"
            fi
        fi
    done
}

# Create RBAC for tier ServiceAccounts to access models
create_tier_rbac() {
    local namespace="$1"
    
    if [ -z "$namespace" ]; then
        print_error "Namespace required"
        return 1
    fi
    
    print_step "Creating RBAC for tier ServiceAccounts..."
    
    # Create Role for model access
    cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: llminferenceservice-access
  namespace: $namespace
rules:
- apiGroups: ["serving.kserve.io"]
  resources: ["llminferenceservices"]
  verbs: ["get"]
EOF
    
    # Create RoleBindings for each tier SA
    for tier in "${TIER_NAMES[@]}"; do
        local sa_name="tier-${tier}-sa"
        local rb_name="${sa_name}-access"
        
        if oc get rolebinding "$rb_name" -n "$namespace" &>/dev/null; then
            print_info "RoleBinding $rb_name already exists"
        else
            oc create rolebinding "$rb_name" \
                --role=llminferenceservice-access \
                --serviceaccount="${namespace}:${sa_name}" \
                -n "$namespace" && \
                print_success "Created RoleBinding: $rb_name" || \
                print_warning "Failed to create RoleBinding: $rb_name"
        fi
    done
}

# Generate tokens for tier ServiceAccounts and store in secret
generate_tier_tokens_secret() {
    local namespace="$1"
    local secret_name="${2:-maas-tier-tokens}"
    local duration="${3:-24h}"
    
    if [ -z "$namespace" ]; then
        print_error "Namespace required"
        return 1
    fi
    
    print_step "Generating tier tokens..."
    
    local free_token premium_token enterprise_token
    
    free_token=$(oc create token tier-free-sa -n "$namespace" \
        --duration="$duration" \
        --audience=https://kubernetes.default.svc 2>/dev/null)
    
    premium_token=$(oc create token tier-premium-sa -n "$namespace" \
        --duration="$duration" \
        --audience=https://kubernetes.default.svc 2>/dev/null)
    
    enterprise_token=$(oc create token tier-enterprise-sa -n "$namespace" \
        --duration="$duration" \
        --audience=https://kubernetes.default.svc 2>/dev/null)
    
    if [ -z "$free_token" ] || [ -z "$premium_token" ] || [ -z "$enterprise_token" ]; then
        print_error "Failed to generate one or more tier tokens"
        return 1
    fi
    
    # Create/update secret with tokens
    oc create secret generic "$secret_name" \
        --from-literal=free="$free_token" \
        --from-literal=premium="$premium_token" \
        --from-literal=enterprise="$enterprise_token" \
        -n "$namespace" --dry-run=client -o yaml | oc apply -f -
    
    print_success "Tier tokens stored in secret: $secret_name"
}

# Setup all tier resources (groups, SAs, RBAC, tokens)
setup_tier_testing() {
    local namespace="$1"
    
    if [ -z "$namespace" ]; then
        print_error "Namespace required"
        return 1
    fi
    
    print_header "Setting up Tier Testing Resources"
    
    # Create groups
    create_tier_groups
    
    # Create ServiceAccounts
    create_tier_serviceaccounts "$namespace"
    
    # Add SAs to groups
    add_serviceaccounts_to_tier_groups "$namespace"
    
    # Create RBAC
    create_tier_rbac "$namespace"
    
    # Generate tokens
    generate_tier_tokens_secret "$namespace"
    
    print_success "Tier testing setup complete!"
    echo ""
    echo "Tier ServiceAccounts created:"
    for tier in "${TIER_NAMES[@]}"; do
        local limit
        limit=$(get_tier_limit "$tier")
        echo "  - tier-${tier}-sa: ${limit} tokens/hour"
    done
    echo ""
    echo "Tokens stored in secret: maas-tier-tokens"
}

# Print tier tokens for manual testing
print_tier_tokens() {
    local namespace="$1"
    local duration="${2:-1h}"
    
    if [ -z "$namespace" ]; then
        print_error "Namespace required"
        return 1
    fi
    
    echo ""
    echo "=============================================="
    echo "       TIER TOKENS FOR TESTING"
    echo "=============================================="
    echo ""
    
    for tier in "${TIER_NAMES[@]}"; do
        local limit
        limit=$(get_tier_limit "$tier")
        local display_name="${tier^^}"
        
        echo "--- ${display_name} TIER (${limit} tokens/hour) ---"
        oc create token "tier-${tier}-sa" -n "$namespace" \
            --duration="$duration" \
            --audience=https://kubernetes.default.svc 2>/dev/null || \
            echo "Failed to generate token"
        echo ""
    done
}
