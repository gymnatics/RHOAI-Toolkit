#!/bin/bash
################################################################################
# Common functions for MaaS Demo scripts
################################################################################

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m'

# Print functions
print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() { echo -e "${YELLOW}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

# Check if logged in to OpenShift
check_oc_login() {
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        echo "Please login first: oc login <cluster-url>"
        return 1
    fi
    return 0
}

# Get cluster domain
get_cluster_domain() {
    oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null
}

# Get RHOAI version
get_rhoai_version() {
    oc get csv -n redhat-ods-operator -o jsonpath='{.items[0].spec.version}' 2>/dev/null
}

# Apply manifest with envsubst
apply_manifest() {
    local manifest_file="$1"
    local namespace="$2"
    
    if [ ! -f "$manifest_file" ]; then
        print_error "Manifest not found: $manifest_file"
        return 1
    fi
    
    local ns_arg=""
    if [ -n "$namespace" ]; then
        ns_arg="-n $namespace"
    fi
    
    envsubst < "$manifest_file" | oc apply $ns_arg -f -
}

# Delete manifest with envsubst
delete_manifest() {
    local manifest_file="$1"
    local namespace="$2"
    
    if [ ! -f "$manifest_file" ]; then
        return 0
    fi
    
    local ns_arg=""
    if [ -n "$namespace" ]; then
        ns_arg="-n $namespace"
    fi
    
    envsubst < "$manifest_file" | oc delete $ns_arg -f - --ignore-not-found=true
}

# Wait for deployment to be ready
wait_for_deployment() {
    local name="$1"
    local namespace="$2"
    local timeout="${3:-300}"
    
    print_step "Waiting for deployment $name to be ready..."
    oc rollout status deployment/"$name" -n "$namespace" --timeout="${timeout}s"
}

# Generate token with correct audience for RHOAI 3.3+
generate_maas_token() {
    local sa_name="$1"
    local namespace="$2"
    local duration="${3:-1h}"
    
    oc create token "$sa_name" -n "$namespace" \
        --duration="$duration" \
        --audience=https://kubernetes.default.svc 2>/dev/null
}

# Check if TokenRateLimitPolicy CRD exists
check_tokenratelimitpolicy_crd() {
    oc get crd tokenratelimitpolicies.kuadrant.io &>/dev/null
}

# Check if AuthPolicy CRD exists
check_authpolicy_crd() {
    oc get crd authpolicies.kuadrant.io &>/dev/null
}
