#!/bin/bash
################################################################################
# Fix Kuadrant/Istio Integration
# 
# This script fixes the common issue where Kuadrant shows "MissingDependency"
# for Gateway API provider (istio / envoy gateway).
#
# The fix involves:
# 1. Approving any pending Service Mesh 3 InstallPlans (manual approval required)
# 2. Creating Istio and IstioCNI instances in the correct namespaces
# 3. Restarting the Kuadrant operator to detect Istio
################################################################################

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source utilities
source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m'
}

print_banner() {
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║          Fix Kuadrant/Istio Integration                        ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

################################################################################
# Check Prerequisites
################################################################################

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check oc command
    if ! command -v oc &> /dev/null; then
        print_error "oc command not found"
        exit 1
    fi
    
    # Check cluster connection
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo "Please log in first: oc login <cluster-url>"
        exit 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found - some features may be limited"
    fi
}

################################################################################
# Diagnose Current State
################################################################################

diagnose_current_state() {
    print_step "Diagnosing current state..."
    echo ""
    
    # Check Service Mesh operator
    echo -e "${BLUE}Service Mesh Operator:${NC}"
    if oc get csv -n openshift-operators 2>/dev/null | grep -q "servicemeshoperator3"; then
        local sm_status=$(oc get csv -n openshift-operators 2>/dev/null | grep "servicemeshoperator3" | awk '{print $NF}')
        echo "  Status: $sm_status"
    else
        echo "  Status: Not installed"
    fi
    echo ""
    
    # Check for pending InstallPlans
    echo -e "${BLUE}Pending InstallPlans:${NC}"
    local pending=$(oc get installplan -n openshift-operators --no-headers 2>/dev/null | grep -i "false" || true)
    if [ -n "$pending" ]; then
        echo "$pending" | while read line; do
            echo "  $line"
        done
    else
        echo "  None"
    fi
    echo ""
    
    # Check Istio
    echo -e "${BLUE}Istio Instances:${NC}"
    if oc get istio -A 2>/dev/null | grep -v "^$"; then
        oc get istio -A 2>/dev/null | head -5
    else
        echo "  No Istio instances found"
    fi
    echo ""
    
    # Check IstioCNI
    echo -e "${BLUE}IstioCNI Instances:${NC}"
    if oc get istiocni -A 2>/dev/null | grep -v "^$"; then
        oc get istiocni -A 2>/dev/null | head -5
    else
        echo "  No IstioCNI instances found"
    fi
    echo ""
    
    # Check Kuadrant
    echo -e "${BLUE}Kuadrant Status:${NC}"
    if oc get kuadrant kuadrant -n kuadrant-system &>/dev/null; then
        local kuadrant_ready=$(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        local kuadrant_reason=$(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)
        local kuadrant_message=$(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
        echo "  Ready: $kuadrant_ready"
        echo "  Reason: $kuadrant_reason"
        if [ -n "$kuadrant_message" ]; then
            echo "  Message: $kuadrant_message"
        fi
    else
        echo "  Kuadrant not found in kuadrant-system"
    fi
    echo ""
}

################################################################################
# Approve Service Mesh InstallPlans
################################################################################

approve_servicemesh_installplans() {
    print_step "Checking for pending Service Mesh InstallPlans..."
    
    local approved_count=0
    
    # Find all pending InstallPlans (check approved field directly, not grep)
    local all_pending=$(oc get installplan -n openshift-operators --no-headers 2>/dev/null | awk '{print $1}')
    
    for plan in $all_pending; do
        local is_approved=$(oc get installplan "$plan" -n openshift-operators -o jsonpath='{.spec.approved}' 2>/dev/null)
        if [ "$is_approved" = "false" ]; then
            local csv_names=$(oc get installplan "$plan" -n openshift-operators -o jsonpath='{.spec.clusterServiceVersionNames[*]}' 2>/dev/null)
            
            # Match Service Mesh, Kiali (SM Console), and Sail (Istio) operators
            if echo "$csv_names" | grep -qiE "servicemesh|kiali|sail"; then
                print_step "Approving InstallPlan: $plan"
                print_info "  CSVs: $csv_names"
                
                oc patch installplan "$plan" -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
                
                if [ $? -eq 0 ]; then
                    print_success "Approved: $plan"
                    approved_count=$((approved_count + 1))
                else
                    print_error "Failed to approve: $plan"
                fi
            fi
        fi
    done
    
    if [ $approved_count -gt 0 ]; then
        print_success "Approved $approved_count InstallPlan(s)"
        print_info "Waiting for operator to install..."
        sleep 30
    else
        print_info "No pending Service Mesh InstallPlans found"
    fi
}

################################################################################
# Setup Istio for Kuadrant
################################################################################

setup_istio_for_kuadrant() {
    print_step "Setting up Istio for Kuadrant..."
    
    # Create required namespaces
    oc create namespace istio-system 2>/dev/null || true
    oc create namespace istio-cni 2>/dev/null || true
    
    # Check if Istio already exists
    if oc get istio default -n istio-system &>/dev/null; then
        print_info "Istio instance already exists in istio-system"
        
        # Check status
        local istio_status=$(oc get istio default -n istio-system -o jsonpath='{.status.state}' 2>/dev/null)
        print_info "Istio status: $istio_status"
        
        if [ "$istio_status" = "Healthy" ]; then
            print_success "Istio is healthy"
            return 0
        fi
    fi
    
    # Get the Istio version from existing installation or use default
    local istio_version=$(oc get istio -A -o jsonpath='{.items[0].spec.version}' 2>/dev/null)
    if [ -z "$istio_version" ]; then
        # Try to get from IstioRevision
        istio_version=$(oc get istiorevision -A -o jsonpath='{.items[0].spec.version}' 2>/dev/null)
    fi
    if [ -z "$istio_version" ]; then
        istio_version="v1.26.2"
    fi
    print_info "Using Istio version: $istio_version"
    
    # Create IstioCNI if not exists
    if ! oc get istiocni default -n istio-cni &>/dev/null && ! oc get istiocni default -n istio-system &>/dev/null; then
        print_step "Creating IstioCNI..."
        cat <<EOF | oc apply -f -
apiVersion: sailoperator.io/v1
kind: IstioCNI
metadata:
  name: default
  namespace: istio-system
spec:
  namespace: istio-cni
  version: $istio_version
EOF
        
        # Wait for IstioCNI to be ready
        print_step "Waiting for IstioCNI to be ready..."
        local elapsed=0
        local timeout=120
        while [ $elapsed -lt $timeout ]; do
            local cni_ready=$(oc get istiocni default -n istio-cni -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            if [ -z "$cni_ready" ]; then
                cni_ready=$(oc get istiocni default -n istio-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            fi
            if [ "$cni_ready" = "True" ]; then
                print_success "IstioCNI is ready"
                break
            fi
            sleep 10
            elapsed=$((elapsed + 10))
            echo "  Waiting for IstioCNI... (${elapsed}s elapsed)"
        done
    else
        print_info "IstioCNI already exists"
    fi
    
    # Create Istio if not exists
    if ! oc get istio default -n istio-system &>/dev/null; then
        print_step "Creating Istio instance in istio-system..."
        cat <<EOF | oc apply -f -
apiVersion: sailoperator.io/v1
kind: Istio
metadata:
  name: default
  namespace: istio-system
spec:
  namespace: istio-system
  version: $istio_version
EOF
        
        # Wait for Istio to be healthy
        print_step "Waiting for Istio to be healthy..."
        local elapsed=0
        local timeout=180
        while [ $elapsed -lt $timeout ]; do
            local istio_status=$(oc get istio default -n istio-system -o jsonpath='{.status.state}' 2>/dev/null)
            if [ "$istio_status" = "Healthy" ]; then
                print_success "Istio is healthy"
                break
            fi
            sleep 10
            elapsed=$((elapsed + 10))
            echo "  Waiting for Istio... Status: $istio_status (${elapsed}s elapsed)"
        done
    fi
    
    # Create openshift-default GatewayClass if not exists
    if ! oc get gatewayclass openshift-default &>/dev/null; then
        print_step "Creating openshift-default GatewayClass..."
        cat <<EOF | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-default
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
    fi
    
    print_success "Istio setup complete"
}

################################################################################
# Restart Kuadrant Operator
################################################################################

restart_kuadrant_operator() {
    print_step "Restarting Kuadrant operator to detect Istio..."
    
    # Find and delete the Kuadrant operator pod
    local pod_name=$(oc get pods -n kuadrant-system -o name 2>/dev/null | grep kuadrant-operator-controller)
    
    if [ -n "$pod_name" ]; then
        print_info "Deleting pod: $pod_name"
        oc delete $pod_name -n kuadrant-system 2>/dev/null || true
        
        print_info "Waiting for new pod to start..."
        sleep 20
    else
        print_warning "Kuadrant operator pod not found"
    fi
    
    # Wait for Kuadrant to be ready
    print_step "Waiting for Kuadrant to be ready..."
    local elapsed=0
    local timeout=120
    while [ $elapsed -lt $timeout ]; do
        local kuadrant_ready=$(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        local kuadrant_reason=$(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)
        
        if [ "$kuadrant_ready" = "True" ]; then
            print_success "Kuadrant is ready!"
            return 0
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
        echo "  Waiting for Kuadrant... Reason: $kuadrant_reason (${elapsed}s elapsed)"
    done
    
    print_warning "Kuadrant may not be fully ready. Check: oc get kuadrant -n kuadrant-system -o yaml"
}

################################################################################
# Verify Fix
################################################################################

verify_fix() {
    print_step "Verifying fix..."
    echo ""
    
    # Check Kuadrant status
    local kuadrant_ready=$(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    local kuadrant_reason=$(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)
    
    echo -e "${BLUE}Kuadrant Status:${NC}"
    echo "  Ready: $kuadrant_ready"
    echo "  Reason: $kuadrant_reason"
    echo ""
    
    # Check AuthPolicy/RateLimitPolicy enforcement
    echo -e "${BLUE}Checking AuthPolicy enforcement:${NC}"
    local authpolicies=$(oc get authpolicy -A --no-headers 2>/dev/null | head -5)
    if [ -n "$authpolicies" ]; then
        echo "$authpolicies" | while read line; do
            local ns=$(echo "$line" | awk '{print $1}')
            local name=$(echo "$line" | awk '{print $2}')
            local enforced=$(oc get authpolicy "$name" -n "$ns" -o jsonpath='{.status.conditions[?(@.type=="Enforced")].status}' 2>/dev/null)
            echo "  $ns/$name: Enforced=$enforced"
        done
    else
        echo "  No AuthPolicies found"
    fi
    echo ""
    
    echo -e "${BLUE}Checking TokenRateLimitPolicy enforcement:${NC}"
    local ratelimitpolicies=$(oc get tokenratelimitpolicy -A --no-headers 2>/dev/null | head -5)
    if [ -n "$ratelimitpolicies" ]; then
        echo "$ratelimitpolicies" | while read line; do
            local ns=$(echo "$line" | awk '{print $1}')
            local name=$(echo "$line" | awk '{print $2}')
            local enforced=$(oc get tokenratelimitpolicy "$name" -n "$ns" -o jsonpath='{.status.conditions[?(@.type=="Enforced")].status}' 2>/dev/null)
            echo "  $ns/$name: Enforced=$enforced"
        done
    else
        echo "  No TokenRateLimitPolicies found"
    fi
    echo ""
    
    if [ "$kuadrant_ready" = "True" ]; then
        print_success "Kuadrant/Istio integration is working!"
    else
        print_warning "Kuadrant may still have issues. Check the logs:"
        echo "  oc logs -n kuadrant-system deployment/kuadrant-operator-controller-manager"
    fi
}

################################################################################
# Main
################################################################################

main() {
    print_banner
    
    check_prerequisites
    echo ""
    
    diagnose_current_state
    
    echo -e "${YELLOW}This script will:${NC}"
    echo "  1. Approve any pending Service Mesh InstallPlans"
    echo "  2. Create Istio and IstioCNI instances if missing"
    echo "  3. Restart Kuadrant operator to detect Istio"
    echo ""
    
    read -p "$(echo -e ${BLUE}Continue?${NC} [Y/n]: )" confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
    
    approve_servicemesh_installplans
    echo ""
    
    setup_istio_for_kuadrant
    echo ""
    
    restart_kuadrant_operator
    echo ""
    
    verify_fix
    echo ""
    
    print_success "Done!"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
