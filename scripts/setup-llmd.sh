#!/bin/bash

################################################################################
# Setup llm-d (Distributed Inference) Prerequisites
################################################################################
# This script sets up the required infrastructure for llm-d serving runtime
# according to the CAI guide Section 3.
#
# Prerequisites:
# - OpenShift CLI (oc) installed and logged in
# - RHOAI installed
# - LWS Operator installed
# - RHCL Operator installed (Kuadrant)
#
# What this script does:
# 1. Creates GatewayClass 'openshift-ai-inference'
# 2. Creates Gateway 'openshift-ai-inference' in openshift-ingress namespace
# 3. Creates LeaderWorkerSetOperator instance
# 4. Verifies all prerequisites are met
#
# Usage: ./scripts/setup-llmd.sh
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR/../lib/utils/colors.sh" 2>/dev/null || true
source "$SCRIPT_DIR/../lib/utils/common.sh" 2>/dev/null || true

################################################################################
# Step 1: Create GatewayClass
################################################################################

create_gatewayclass() {
    print_header "Step 1: Creating GatewayClass 'openshift-ai-inference'"
    
    if oc get gatewayclass openshift-ai-inference &>/dev/null; then
        print_success "GatewayClass 'openshift-ai-inference' already exists"
        return 0
    fi
    
    print_step "Creating GatewayClass..."
    
    cat <<EOF | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-ai-inference
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
    
    print_success "GatewayClass 'openshift-ai-inference' created"
}

################################################################################
# Step 2: Create Gateway
################################################################################

create_gateway() {
    print_header "Step 2: Creating Gateway 'openshift-ai-inference'"
    
    if oc get gateway openshift-ai-inference -n openshift-ingress &>/dev/null; then
        print_success "Gateway 'openshift-ai-inference' already exists"
        return 0
    fi
    
    # Get cluster domain
    print_step "Detecting cluster domain..."
    local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
    print_info "Cluster domain: $cluster_domain"
    
    # Prompt for allowed namespaces
    echo ""
    print_info "The Gateway needs to specify which namespaces can use it."
    print_info "You can allow specific namespaces or all namespaces."
    echo ""
    print_warning "Security Note: Allowing all namespaces can be a security risk."
    print_warning "Rogue actors could create HTTPRoutes to hijack/deny traffic."
    echo ""
    read -p "Allow all namespaces? (y/N): " allow_all
    
    local allowed_namespaces_yaml=""
    if [[ "$allow_all" =~ ^[Yy]$ ]]; then
        allowed_namespaces_yaml="from: All"
        print_info "Allowing all namespaces"
    else
        echo ""
        print_info "Enter namespace names (comma-separated, e.g., user1,user2,0-demo):"
        read -p "Namespaces: " namespaces_input
        
        if [ -z "$namespaces_input" ]; then
            print_error "No namespaces specified. Exiting."
            exit 1
        fi
        
        # Convert comma-separated list to YAML array
        IFS=',' read -ra NS_ARRAY <<< "$namespaces_input"
        local values_yaml=""
        for ns in "${NS_ARRAY[@]}"; do
            ns=$(echo "$ns" | xargs) # Trim whitespace
            values_yaml+="                  - $ns\n"
        done
        
        allowed_namespaces_yaml="from: Selector
          selector:
            matchExpressions:
              - key: kubernetes.io/metadata.name
                operator: In
                values:
$values_yaml"
    fi
    
    print_step "Creating Gateway..."
    
    cat <<EOF | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/rev: openshift-gateway
  name: openshift-ai-inference
  namespace: openshift-ingress
spec:
  gatewayClassName: openshift-ai-inference
  listeners:
    - allowedRoutes:
        namespaces:
          $allowed_namespaces_yaml
      hostname: inference-gateway.apps.$cluster_domain
      name: https
      port: 443
      protocol: HTTPS
      tls:
        certificateRefs:
          - group: ''
            kind: Secret
            name: default-gateway-tls
        mode: Terminate
EOF
    
    print_success "Gateway 'openshift-ai-inference' created"
    echo ""
    print_info "Gateway hostname: inference-gateway.apps.$cluster_domain"
}

################################################################################
# Step 3: Create LeaderWorkerSetOperator Instance
################################################################################

create_lws_instance() {
    print_header "Step 3: Creating LeaderWorkerSetOperator Instance"
    
    # Check if LWS operator is installed
    if ! oc get csv -n openshift-lws-operator 2>/dev/null | grep -q "leader-worker-set"; then
        print_error "LeaderWorkerSet Operator is not installed"
        print_info "Please run the main setup script first to install the LWS operator."
        exit 1
    fi
    
    print_success "LeaderWorkerSet Operator is installed"
    
    # Check if instance already exists
    if oc get leaderworkersetoperator cluster -n openshift-lws-operator &>/dev/null; then
        print_success "LeaderWorkerSetOperator instance 'cluster' already exists"
        local mgmt_state=$(oc get leaderworkersetoperator cluster -n openshift-lws-operator -o jsonpath='{.spec.managementState}')
        print_info "Management State: $mgmt_state"
        return 0
    fi
    
    print_step "Creating LeaderWorkerSetOperator instance..."
    
    cat <<EOF | oc apply -f -
apiVersion: operator.openshift.io/v1
kind: LeaderWorkerSetOperator
metadata:
  name: cluster
  namespace: openshift-lws-operator
spec:
  managementState: Managed
  logLevel: Normal
  operatorLogLevel: Normal
EOF
    
    print_success "LeaderWorkerSetOperator instance created"
    
    # Wait for it to be ready
    print_step "Waiting for LeaderWorkerSetOperator to be ready..."
    sleep 10
    
    local timeout=60
    local elapsed=0
    until oc get leaderworkersetoperator cluster -n openshift-lws-operator -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null | grep -q "True"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Timeout waiting for LeaderWorkerSetOperator to be ready"
            print_info "Check status with: oc get leaderworkersetoperator cluster -n openshift-lws-operator -o yaml"
            break
        fi
        echo "Waiting for LeaderWorkerSetOperator to be ready..."
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    print_success "LeaderWorkerSetOperator is ready"
}

################################################################################
# Step 4: Verify Prerequisites
################################################################################

verify_prerequisites() {
    print_header "Step 4: Verifying llm-d Prerequisites"
    
    local all_good=true
    
    # Check GatewayClass
    print_step "Checking GatewayClass..."
    if oc get gatewayclass openshift-ai-inference &>/dev/null; then
        print_success "GatewayClass exists"
    else
        print_error "GatewayClass NOT FOUND"
        all_good=false
    fi
    
    # Check Gateway
    print_step "Checking Gateway..."
    if oc get gateway openshift-ai-inference -n openshift-ingress &>/dev/null; then
        print_success "Gateway exists"
        local hostname=$(oc get gateway openshift-ai-inference -n openshift-ingress -o jsonpath='{.spec.listeners[0].hostname}')
        print_info "Hostname: $hostname"
    else
        print_error "Gateway NOT FOUND"
        all_good=false
    fi
    
    # Check LWS Operator
    print_step "Checking LeaderWorkerSet Operator..."
    if oc get csv -n openshift-lws-operator 2>/dev/null | grep -q "leader-worker-set.*Succeeded"; then
        print_success "LWS Operator installed"
    else
        print_error "LWS Operator NOT installed or not ready"
        all_good=false
    fi
    
    # Check LWS Instance
    print_step "Checking LeaderWorkerSetOperator instance..."
    if oc get leaderworkersetoperator cluster -n openshift-lws-operator &>/dev/null; then
        print_success "LeaderWorkerSetOperator instance exists"
    else
        print_error "LeaderWorkerSetOperator instance NOT FOUND"
        all_good=false
    fi
    
    # Check Kuadrant
    print_step "Checking Kuadrant..."
    if oc get kuadrant kuadrant -n kuadrant-system &>/dev/null; then
        print_success "Kuadrant instance exists"
    else
        print_warning "Kuadrant instance NOT FOUND (required for authentication)"
        print_info "Run ./scripts/setup-maas.sh to install Kuadrant"
    fi
    
    # Check Authorino
    print_step "Checking Authorino..."
    if oc get authorino authorino -n kuadrant-system &>/dev/null; then
        local tls_enabled=$(oc get authorino authorino -n kuadrant-system -o jsonpath='{.spec.listener.tls.enabled}')
        if [ "$tls_enabled" == "true" ]; then
            print_success "Authorino configured with TLS"
        else
            print_warning "Authorino TLS not enabled (required for authentication)"
            print_info "Run ./scripts/setup-maas.sh to configure Authorino"
        fi
    else
        print_warning "Authorino NOT FOUND (required for authentication)"
        print_info "Run ./scripts/setup-maas.sh to install Authorino"
    fi
    
    echo ""
    if [ "$all_good" = true ]; then
        print_success "All core llm-d prerequisites are configured!"
        echo ""
        print_info "You can now deploy models using llm-d serving runtime."
        print_info "In the RHOAI UI, select 'llm-d' as the serving runtime."
        print_info "Check 'Require authentication' checkbox to enable authentication."
    else
        print_error "Some core llm-d prerequisites are missing."
        print_info "Please fix the issues above before deploying llm-d models."
    fi
}

################################################################################
# Main
################################################################################

main() {
    print_header "llm-d Setup Script (per CAI Guide Section 3)"
    
    echo -e "${YELLOW}This script will set up the required infrastructure for llm-d serving runtime.${NC}"
    echo ""
    echo "Prerequisites:"
    echo "  - OpenShift cluster is running"
    echo "  - RHOAI is installed"
    echo "  - LWS Operator is installed"
    echo "  - RHCL Operator is installed"
    echo ""
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    echo ""
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift. Please run 'oc login' first."
        exit 1
    fi
    print_success "Logged in to OpenShift: $(oc whoami --show-server)"
    echo ""
    
    # Execute setup steps
    create_gatewayclass
    create_gateway
    create_lws_instance
    verify_prerequisites
    
    print_header "llm-d Setup Complete!"
    echo ""
    print_info "Next Steps:"
    echo "  1. Deploy a model using llm-d serving runtime in the RHOAI UI"
    echo "  2. Check 'Require authentication' checkbox for secure access"
    echo "  3. Use ./demo/generate-maas-token.sh to generate API tokens"
    echo ""
    print_info "For more information, see:"
    echo "  - docs/reference/SERVING-RUNTIME-COMPARISON.md"
    echo "  - docs/guides/TOOL-CALLING-GUIDE.md"
    echo ""
}

main "$@"

