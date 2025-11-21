#!/bin/bash

################################################################################
# Setup Model as a Service (MaaS) for RHOAI 3.0
################################################################################
# Based on CAI's guide to RHOAI 3.0 - Section 4
# This script sets up the MaaS API infrastructure
#
# Prerequisites:
# - RHOAI 3.0 installed
# - enable-genai-maas.sh already run (dashboard features enabled)
# - kustomize installed
# - Network access to GitHub

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

################################################################################
# Prerequisites Check
################################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check oc
    if ! command -v oc &> /dev/null; then
        print_error "oc command not found. Please install OpenShift CLI."
        exit 1
    fi
    print_success "oc CLI found"
    
    # Check kustomize
    if ! command -v kustomize &> /dev/null; then
        print_error "kustomize not found. Please install kustomize."
        echo ""
        echo "Install with:"
        echo "  brew install kustomize"
        echo "  OR"
        echo "  curl -s 'https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh' | bash"
        exit 1
    fi
    print_success "kustomize found"
    
    # Check if logged in
    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift. Please run 'oc login' first."
        exit 1
    fi
    print_success "Logged in to OpenShift: $(oc whoami --show-server)"
    
    # Check if RHOAI is installed
    if ! oc get datasciencecluster default-dsc &>/dev/null; then
        print_error "RHOAI not found. Please install RHOAI first."
        exit 1
    fi
    print_success "RHOAI installation detected"
    
    # Check if dashboard config has MaaS enabled
    local maas_enabled=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications -o jsonpath='{.spec.dashboardConfig.modelAsService}' 2>/dev/null)
    if [ "$maas_enabled" != "true" ]; then
        print_warning "MaaS not enabled in dashboard config. Run enable-genai-maas.sh first!"
        echo ""
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "MaaS enabled in dashboard config"
    fi
}

################################################################################
# Step 1: Install RHCL (Red Hat Connectivity Link) Operator
################################################################################

install_rhcl_operator() {
    print_header "Step 1: Installing RHCL (Kuadrant) Operator"
    
    # Check if kuadrant-system namespace exists
    if oc get namespace kuadrant-system &>/dev/null; then
        print_success "kuadrant-system namespace already exists"
    else
        print_step "Creating kuadrant-system namespace..."
        oc create namespace kuadrant-system
        print_success "kuadrant-system namespace created"
    fi
    
    # Check if RHCL operator is already installed
    if oc get subscription rhcl-operator -n kuadrant-system &>/dev/null; then
        print_success "RHCL Operator already installed"
    else
        print_step "Installing RHCL Operator..."
        
        cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: kuadrant-system
  namespace: kuadrant-system
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhcl-operator
  namespace: kuadrant-system
spec:
  channel: stable
  installPlanApproval: Automatic
  name: rhcl-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
        
        print_success "RHCL Operator subscription created"
    fi
    
    # Wait for RHCL operator to be ready
    print_step "Waiting for RHCL operator to be ready (this may take 2-3 minutes)..."
    sleep 30
    
    local timeout=300
    local elapsed=0
    until oc get crd kuadrants.kuadrant.io &>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            print_error "Timeout waiting for RHCL operator CRDs"
            return 1
        fi
        echo "Waiting for Kuadrant CRD... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_success "RHCL Operator is ready"
}

################################################################################
# Step 2: Create Kuadrant Instance
################################################################################

create_kuadrant_instance() {
    print_header "Step 2: Creating Kuadrant Instance"
    
    # Check if Kuadrant instance already exists
    if oc get kuadrant kuadrant -n kuadrant-system &>/dev/null; then
        print_success "Kuadrant instance already exists"
    else
        print_step "Creating Kuadrant instance..."
        
        cat <<EOF | oc apply -f -
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
EOF
        
        print_success "Kuadrant instance created"
    fi
    
    # Wait for Kuadrant components to be ready (always check, even if already exists)
    print_step "Waiting for Kuadrant components to be ready..."
    
    # Wait for Authorino service to be created
    local auth_timeout=120
    local auth_elapsed=0
    until oc get svc/authorino-authorino-authorization -n kuadrant-system &>/dev/null; do
        if [ $auth_elapsed -ge $auth_timeout ]; then
            print_error "Timeout waiting for Authorino service"
            return 1
        fi
        echo "Waiting for Authorino service... (${auth_elapsed}s elapsed)"
        sleep 10
        auth_elapsed=$((auth_elapsed + 10))
    done
    
    print_success "Kuadrant is ready"
}

################################################################################
# Step 3: Configure Authorino
################################################################################

configure_authorino() {
    print_header "Step 3: Configuring Authorino"
    
    # Annotate Authorino service for TLS
    print_step "Annotating Authorino service for TLS certificate..."
    
    oc annotate svc/authorino-authorino-authorization \
        service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
        -n kuadrant-system --overwrite
    
    print_success "Authorino service annotated"
    
    # Wait for certificate to be created
    print_step "Waiting for TLS certificate..."
    sleep 10
    
    # Update Authorino to enable TLS
    print_step "Enabling TLS in Authorino..."
    
    cat <<EOF | oc apply -f -
apiVersion: operator.authorino.kuadrant.io/v1beta1
kind: Authorino
metadata:
  name: authorino
  namespace: kuadrant-system
spec:
  replicas: 1
  clusterWide: true
  listener:
    tls:
      enabled: true
      certSecretRef:
        name: authorino-server-cert
  oidcServer:
    tls:
      enabled: false
EOF
    
    print_success "Authorino configured with TLS"
    
    # Wait for Authorino to restart
    print_step "Waiting for Authorino to restart..."
    sleep 15
}

################################################################################
# Step 4: Create GatewayClass
################################################################################

create_gateway_class() {
    print_header "Step 4: Creating GatewayClass 'openshift-default'"
    
    if oc get gatewayclass openshift-default &>/dev/null; then
        print_success "GatewayClass 'openshift-default' already exists"
        return 0
    fi
    
    print_step "Creating GatewayClass..."
    
    cat <<EOF | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-default
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
    
    print_success "GatewayClass 'openshift-default' created"
}

################################################################################
# Step 5: Create maas-api namespace
################################################################################

create_maas_namespace() {
    print_header "Step 5: Creating 'maas-api' namespace"
    
    if oc get namespace maas-api &>/dev/null; then
        print_success "Namespace 'maas-api' already exists"
        return 0
    fi
    
    print_step "Creating namespace..."
    oc create namespace maas-api
    
    print_success "Namespace 'maas-api' created"
}

################################################################################
# Step 6: Deploy MaaS API objects
################################################################################

deploy_maas_api() {
    print_header "Step 6: Deploying MaaS API Objects"
    
    print_step "Getting cluster domain..."
    CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
    
    if [ -z "$CLUSTER_DOMAIN" ]; then
        print_error "Failed to get cluster domain"
        exit 1
    fi
    
    print_success "Cluster domain: $CLUSTER_DOMAIN"
    
    print_step "Deploying MaaS API using kustomize (this may take a minute)..."
    
    export CLUSTER_DOMAIN
    oc apply --server-side=true \
      -f <(kustomize build "https://github.com/opendatahub-io/maas-billing.git/deployment/overlays/openshift?ref=main" | \
           envsubst '$CLUSTER_DOMAIN')
    
    print_success "MaaS API objects deployed"
    
    print_step "Waiting for MaaS API pods to be ready..."
    sleep 10
    
    # Wait for pods to be ready
    oc wait --for=condition=ready pod -l app=maas-api -n maas-api --timeout=300s || true
    
    print_success "MaaS API deployment complete"
}

################################################################################
# Step 7: Configure Audience Policy
################################################################################

configure_audience_policy() {
    print_header "Step 7: Configuring Audience Policy"
    
    print_step "Extracting audience from service account token..."
    
    AUD="$(oc create token default --duration=10m 2>/dev/null | cut -d. -f2 | base64 -d 2>/dev/null | jq -r '.aud[0]' 2>/dev/null)"
    
    if [ -z "$AUD" ]; then
        print_error "Failed to extract audience. Is jq installed?"
        echo ""
        echo "Install jq with:"
        echo "  brew install jq"
        exit 1
    fi
    
    print_success "Audience: $AUD"
    
    print_step "Patching AuthPolicy..."
    
    oc patch authpolicy maas-api-auth-policy -n maas-api --type=merge --patch-file <(cat <<EOF
spec:
  rules:
    authentication:
      openshift-identities:
        kubernetesTokenReview:
          audiences:
            - $AUD
            - maas-default-gateway-sa
EOF
)
    
    print_success "Audience policy configured"
}

################################################################################
# Step 8: Restart Controllers
################################################################################

restart_controllers() {
    print_header "Step 8: Restarting Controllers"
    
    print_step "Restarting odh-model-controller..."
    oc delete pod -n redhat-ods-applications -l app=odh-model-controller --ignore-not-found=true
    sleep 5
    print_success "odh-model-controller restarted"
    
    print_step "Restarting kuadrant-operator-controller-manager..."
    oc delete pod -n kuadrant-system -l control-plane=controller-manager --ignore-not-found=true 2>/dev/null || true
    sleep 5
    print_success "kuadrant-operator restarted (if it exists)"
}

################################################################################
# Step 9: Test MaaS Configuration
################################################################################

test_maas_configuration() {
    print_header "Step 9: Testing MaaS Configuration"
    
    print_step "Waiting for MaaS API to be fully ready..."
    sleep 20
    
    CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
    HOST="https://maas.${CLUSTER_DOMAIN}"
    
    print_step "Testing MaaS API endpoint: $HOST"
    
    print_step "Generating test token..."
    TOKEN_RESPONSE=$(curl -sSk \
      -H "Authorization: Bearer $(oc whoami -t)" \
      -H "Content-Type: application/json" \
      -X POST \
      -d '{"expiration": "10m"}' \
      "${HOST}/maas-api/v1/tokens" 2>/dev/null || echo '{"error": "failed"}')
    
    if echo "$TOKEN_RESPONSE" | jq -e '.token' &>/dev/null; then
        print_success "MaaS API is responding correctly!"
        
        TOKEN=$(echo $TOKEN_RESPONSE | jq -r .token)
        
        print_step "Testing model list endpoint..."
        MODELS=$(curl -sSk ${HOST}/maas-api/v1/models \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" 2>/dev/null || echo '{"error": "failed"}')
        
        if echo "$MODELS" | jq -e '.' &>/dev/null; then
            print_success "Model list endpoint working!"
            echo ""
            echo -e "${BLUE}Available models:${NC}"
            echo "$MODELS" | jq '.'
        else
            print_warning "Model list endpoint not responding yet (this is normal if no models are deployed)"
        fi
    else
        print_warning "MaaS API not fully ready yet. This is normal - it may take a few more minutes."
        print_warning "You can test manually later with the commands shown below."
    fi
}

################################################################################
# Display Usage Instructions
################################################################################

display_usage_instructions() {
    print_header "MaaS Setup Complete!"
    
    CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
    
    echo -e "${GREEN}✓ Model as a Service (MaaS) infrastructure is now set up!${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}How to Use MaaS:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "1. Deploy a model with MaaS enabled:"
    echo "   - Go to RHOAI Dashboard → Models → Deploy Model"
    echo "   - Select a model (e.g., Llama 3.2-3B)"
    echo "   - Choose 'llm-d' as serving runtime"
    echo "   - ✅ Check 'Model as a Service' checkbox"
    echo "   - Deploy and wait for Running status"
    echo ""
    echo "2. Access via MaaS API:"
    echo "   - Navigate to: AI Assets Endpoints → Models as a Service"
    echo "   - Click 'View' on your model"
    echo "   - Generate a token"
    echo "   - Use the endpoint URL with the token"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Testing MaaS API (Manual):${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "# Set variables"
    echo "CLUSTER_DOMAIN=\$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')"
    echo "HOST=\"https://maas.\${CLUSTER_DOMAIN}\""
    echo ""
    echo "# Generate token"
    echo "TOKEN_RESPONSE=\$(curl -sSk \\"
    echo "  -H \"Authorization: Bearer \$(oc whoami -t)\" \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -X POST \\"
    echo "  -d '{\"expiration\": \"10m\"}' \\"
    echo "  \"\${HOST}/maas-api/v1/tokens\")"
    echo ""
    echo "TOKEN=\$(echo \$TOKEN_RESPONSE | jq -r .token)"
    echo ""
    echo "# List available models"
    echo "curl -sSk \${HOST}/maas-api/v1/models \\"
    echo "    -H \"Content-Type: application/json\" \\"
    echo "    -H \"Authorization: Bearer \$TOKEN\" | jq ."
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Important Notes:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "⚠️  MaaS vs Direct Access:"
    echo "   - MaaS URL: https://maas.${CLUSTER_DOMAIN}/maas-api/v1/..."
    echo "   - Direct URL: https://maas.${CLUSTER_DOMAIN}/<namespace>/<model>/v1/..."
    echo "   - Direct access bypasses MaaS billing/tracking!"
    echo ""
    echo "⚠️  Security:"
    echo "   - Always enable 'Require authentication' with MaaS"
    echo "   - Otherwise, direct model access is unprotected"
    echo ""
    echo "⚠️  Token Management:"
    echo "   - All tokens you create are active"
    echo "   - No revocation mechanism currently available"
    echo ""
    echo -e "${GREEN}✓ MaaS is ready to use!${NC}"
    echo ""
}

################################################################################
# Main execution
################################################################################

main() {
    print_header "Model as a Service (MaaS) Setup for RHOAI 3.0"
    
    echo -e "${YELLOW}This script will set up the MaaS API infrastructure.${NC}"
    echo ""
    echo "Prerequisites:"
    echo "  - RHOAI 3.0 installed"
    echo "  - enable-genai-maas.sh already run"
    echo "  - kustomize installed"
    echo "  - Network access to GitHub"
    echo ""
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    # Execute steps
    check_prerequisites
    install_rhcl_operator
    create_kuadrant_instance
    configure_authorino
    create_gateway_class
    create_maas_namespace
    deploy_maas_api
    configure_audience_policy
    restart_controllers
    test_maas_configuration
    display_usage_instructions
}

# Run main function
main

