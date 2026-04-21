#!/bin/bash

################################################################################
# Setup Model as a Service (MaaS) for RHOAI
################################################################################
# This script sets up MaaS infrastructure with version-aware configuration:
# - RHOAI 3.3+: Uses integrated MaaS (modelsAsService in DataScienceCluster)
# - RHOAI 3.2 and earlier: Uses legacy kustomize-based setup
#
# Prerequisites:
# - RHOAI installed
# - oc CLI configured and logged in

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Global variables for version detection
RHOAI_VERSION=""
RHOAI_MAJOR_VERSION=""
CLUSTER_DOMAIN=""

################################################################################
# Helper Functions
################################################################################

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

################################################################################
# Service Mesh InstallPlan Approval
################################################################################

approve_servicemesh_installplans() {
    print_step "Checking for pending Service Mesh InstallPlans..."
    
    local pending_ips
    pending_ips=$(oc get installplan -n openshift-operators -o json 2>/dev/null | \
        python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('items', []):
    approved = item.get('spec', {}).get('approved', True)
    names = [n for n in item.get('spec', {}).get('clusterServiceVersionNames', []) if 'servicemesh' in n.lower() or 'istio' in n.lower()]
    if not approved and names:
        print(item['metadata']['name'])
" 2>/dev/null)
    
    if [ -n "$pending_ips" ]; then
        while IFS= read -r ip; do
            [ -z "$ip" ] && continue
            print_step "Approving Service Mesh InstallPlan: $ip"
            oc patch installplan "$ip" -n openshift-operators --type=merge -p '{"spec":{"approved":true}}'
        done <<< "$pending_ips"
        print_success "Service Mesh InstallPlans approved"
        sleep 15
    else
        print_success "No pending Service Mesh InstallPlans found"
    fi
}

################################################################################
# RHOAI Version Detection
################################################################################

detect_rhoai_version() {
    print_step "Detecting RHOAI version..."
    
    # Try to get version from CSV
    local csv_version=$(oc get csv -n redhat-ods-operator -o jsonpath='{.items[?(@.spec.displayName=="Red Hat OpenShift AI")].spec.version}' 2>/dev/null | head -1)
    
    if [ -n "$csv_version" ]; then
        RHOAI_VERSION="$csv_version"
        # Extract major.minor (e.g., "3.3" from "3.3.0")
        RHOAI_MAJOR_VERSION=$(echo "$csv_version" | cut -d. -f1,2)
    else
        # Fallback: detect based on features
        if oc get crd llminferenceservices.serving.kserve.io &>/dev/null; then
            # LLMInferenceService CRD exists - this is 3.x
            # Check if modelsAsService is available in DSC spec
            if oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.kserve.modelsAsService}' &>/dev/null 2>&1; then
                RHOAI_VERSION="3.3.x"
                RHOAI_MAJOR_VERSION="3.3"
            else
                RHOAI_VERSION="3.x"
                RHOAI_MAJOR_VERSION="3.0"
            fi
        elif oc get datasciencecluster &>/dev/null; then
            RHOAI_VERSION="2.x"
            RHOAI_MAJOR_VERSION="2.0"
        else
            RHOAI_VERSION="unknown"
            RHOAI_MAJOR_VERSION="unknown"
        fi
    fi
    
    print_success "Detected RHOAI version: $RHOAI_VERSION (major: $RHOAI_MAJOR_VERSION)"
}

is_rhoai_33_or_higher() {
    case "$RHOAI_MAJOR_VERSION" in
        3.3|3.4|3.5|3.6|3.7|3.8|3.9|4.*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

get_cluster_domain() {
    CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
    if [ -z "$CLUSTER_DOMAIN" ]; then
        print_error "Failed to get cluster domain"
        exit 1
    fi
    print_info "Cluster domain: $CLUSTER_DOMAIN"
}

################################################################################
# Prerequisites Check (Common)
################################################################################

check_common_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check oc
    if ! command -v oc &> /dev/null; then
        print_error "oc command not found. Please install OpenShift CLI."
        exit 1
    fi
    print_success "oc CLI found"
    
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
    
    # Detect version
    detect_rhoai_version
    
    # Get cluster domain
    get_cluster_domain
}

################################################################################
# RHOAI 3.3+ Integrated MaaS Setup
################################################################################

setup_maas_33() {
    print_header "Setting up MaaS for RHOAI 3.3+ (Integrated)"
    
    echo -e "${CYAN}RHOAI 3.3+ uses integrated MaaS via the DataScienceCluster.${NC}"
    echo -e "${CYAN}This is simpler than the legacy setup and requires fewer components.${NC}"
    echo ""
    
    # Step 0: Approve pending Service Mesh InstallPlans (auto-installed by RHOAI, may need manual approval)
    approve_servicemesh_installplans
    
    # Step 1: Install RHCL Operator (still required for auth)
    install_rhcl_operator_33
    
    # Step 2: Enable MaaS in DataScienceCluster
    enable_maas_in_dsc
    
    # Step 3: Create GatewayClass and Gateway for inference
    create_inference_gateway_33
    
    # Step 4: Enable dashboard features
    enable_dashboard_maas_features
    
    # Step 5: Restart controllers
    restart_controllers_33
    
    # Step 6: Display instructions
    display_usage_instructions_33
}

install_rhcl_operator_33() {
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
    if oc get csv -n kuadrant-system 2>/dev/null | grep -q "rhcl-operator"; then
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
        
        # Wait for RHCL operator to be ready
        print_step "Waiting for RHCL operator to be ready (this may take 2-3 minutes)..."
        
        local timeout=300
        local elapsed=0
        until oc get crd kuadrants.kuadrant.io &>/dev/null; do
            if [ $elapsed -ge $timeout ]; then
                print_error "Timeout waiting for RHCL operator CRDs"
                return 1
            fi
            echo -n "."
            sleep 10
            elapsed=$((elapsed + 10))
        done
        echo ""
        print_success "RHCL Operator is ready"
    fi
    
    # Create Kuadrant instance
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
        
        # Wait for Authorino
        print_step "Waiting for Authorino service..."
        local auth_timeout=120
        local auth_elapsed=0
        until oc get svc/authorino-authorino-authorization -n kuadrant-system &>/dev/null; do
            if [ $auth_elapsed -ge $auth_timeout ]; then
                print_warning "Timeout waiting for Authorino service - continuing anyway"
                break
            fi
            sleep 10
            auth_elapsed=$((auth_elapsed + 10))
        done
    fi
    
    # Create TLS certificate BEFORE Authorino CR to avoid deadlock
    print_step "Creating Authorino TLS certificate..."
    if ! oc get secret authorino-server-cert -n kuadrant-system &>/dev/null; then
        cat <<'CERTEOF' | oc apply -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: authorino-selfsigned
  namespace: kuadrant-system
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: authorino-server-cert
  namespace: kuadrant-system
spec:
  secretName: authorino-server-cert
  isCA: false
  duration: 8760h
  renewBefore: 720h
  issuerRef:
    name: authorino-selfsigned
    kind: Issuer
  commonName: authorino-authorino
  dnsNames:
    - authorino-authorino
    - authorino-authorino.kuadrant-system
    - authorino-authorino.kuadrant-system.svc
    - authorino-authorino.kuadrant-system.svc.cluster.local
  usages:
    - server auth
CERTEOF
        local cert_wait=0
        while [ $cert_wait -lt 30 ]; do
            if oc get secret authorino-server-cert -n kuadrant-system &>/dev/null; then
                print_success "Authorino TLS certificate created"
                break
            fi
            sleep 3
            cert_wait=$((cert_wait + 3))
        done
    else
        print_info "Authorino TLS secret already exists"
    fi
    
    # Configure Authorino TLS
    print_step "Configuring Authorino TLS..."
    
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
    
    # Annotate service if it exists (for cert rotation)
    oc annotate svc/authorino-authorino-authorization \
        service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
        -n kuadrant-system --overwrite 2>/dev/null || true
    
    print_success "Authorino configured with TLS"
}

enable_maas_in_dsc() {
    print_header "Step 2: Enabling MaaS in DataScienceCluster"
    
    # Check current state
    local current_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.kserve.modelsAsService.managementState}' 2>/dev/null || echo "")
    
    if [ "$current_state" = "Managed" ]; then
        print_success "MaaS already enabled in DataScienceCluster"
    else
        print_step "Enabling modelsAsService in DataScienceCluster..."
        
        oc patch datasciencecluster default-dsc --type=merge -p '{
            "spec": {
                "components": {
                    "kserve": {
                        "modelsAsService": {
                            "managementState": "Managed"
                        }
                    }
                }
            }
        }'
        
        print_success "MaaS enabled in DataScienceCluster"
        
        # Wait for reconciliation
        print_step "Waiting for DataScienceCluster to reconcile..."
        sleep 30
    fi
}

create_inference_gateway_33() {
    print_header "Step 3: Creating Inference Gateway"
    
    # Create GatewayClass
    if oc get gatewayclass openshift-ai-inference &>/dev/null; then
        print_success "GatewayClass 'openshift-ai-inference' already exists"
    else
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
    fi
    
    # Create Gateway
    local gateway_hostname="inference-gateway.${CLUSTER_DOMAIN}"
    
    if oc get gateway openshift-ai-inference -n openshift-ingress &>/dev/null; then
        print_success "Gateway 'openshift-ai-inference' already exists"
    else
        print_step "Creating Gateway with hostname: $gateway_hostname"
        
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
          from: All
      hostname: ${gateway_hostname}
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
    fi
}

enable_dashboard_maas_features() {
    print_header "Step 4: Enabling Dashboard MaaS Features"
    
    print_step "Updating OdhDashboardConfig..."
    
    oc patch odhdashboardconfig odh-dashboard-config \
        -n redhat-ods-applications \
        --type=merge \
        -p '{
            "spec": {
                "dashboardConfig": {
                    "disableModelRegistry": false,
                    "disableModelCatalog": false,
                    "disableKServeMetrics": false,
                    "genAiStudio": true,
                    "modelAsService": true,
                    "disableLMEval": false
                }
            }
        }' 2>/dev/null || print_warning "Could not patch dashboard config - may already be configured"
    
    print_success "Dashboard features enabled"
}

restart_controllers_33() {
    print_header "Step 5: Restarting Controllers"
    
    print_step "Restarting odh-model-controller..."
    oc delete pod -n redhat-ods-applications -l app=odh-model-controller --ignore-not-found=true
    
    print_step "Restarting kserve-controller..."
    oc delete pod -n redhat-ods-applications -l control-plane=kserve-controller-manager --ignore-not-found=true
    
    sleep 10
    print_success "Controllers restarted"
}

display_usage_instructions_33() {
    print_header "MaaS Setup Complete! (RHOAI 3.3+)"
    
    echo -e "${GREEN}✓ Model as a Service (MaaS) has been enabled!${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}RHOAI 3.3+ MaaS Configuration:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "MaaS endpoint:     https://maas.${CLUSTER_DOMAIN}"
    echo "Inference Gateway: https://inference-gateway.${CLUSTER_DOMAIN}"
    echo "Dashboard URL:     https://data-science-gateway.${CLUSTER_DOMAIN}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}How to Deploy a Model with MaaS:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Option 1: Via Dashboard"
    echo "  1. Go to RHOAI Dashboard → Models → Deploy Model"
    echo "  2. Select a model and choose 'llm-d' serving runtime"
    echo "  3. ✅ Check 'Enable Model as a Service'"
    echo "  4. ✅ Check 'Require authentication' (CRITICAL for security!)"
    echo "  5. Deploy and wait for Running status"
    echo ""
    echo "Option 2: Via CLI (LLMInferenceService)"
    echo ""
    cat <<'YAML'
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: my-model
  namespace: my-namespace
  annotations:
    security.opendatahub.io/enable-auth: "true"
spec:
  replicas: 1
  model:
    uri: oci://registry.redhat.io/rhelai1/modelcar-qwen3-8b-fp8-dynamic:latest
    name: RedHatAI/Qwen3-8B-FP8-dynamic
  router:
    route: {}
    gateway: {}
  template:
    tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
    containers:
    - name: main
      resources:
        limits:
          nvidia.com/gpu: "1"
YAML
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Testing MaaS API:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "# Generate a token"
    echo "TOKEN=\$(oc create token default -n my-namespace --duration=1h)"
    echo ""
    echo "# List available models"
    echo "curl -s \"https://maas.${CLUSTER_DOMAIN}/v1/models\" -H \"Authorization: Bearer \$TOKEN\""
    echo ""
    echo "# Call a model (replace <model-name> with your deployed model)"
    echo "curl -X POST \"https://maas.${CLUSTER_DOMAIN}/llm/<model-name>/v1/chat/completions\" \\"
    echo "  -H \"Authorization: Bearer \$TOKEN\" \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -d '{"
    echo "    \"model\": \"<model-name>\","
    echo "    \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]"
    echo "  }'"
    echo ""
    echo -e "${GREEN}✓ MaaS setup complete for RHOAI 3.3+!${NC}"
    echo ""
}

################################################################################
# RHOAI 3.2 and Earlier - Legacy MaaS Setup
################################################################################

setup_maas_legacy() {
    print_header "Setting up MaaS for RHOAI 3.2 and Earlier (Legacy)"
    
    echo -e "${CYAN}RHOAI 3.2 and earlier uses the legacy MaaS setup with kustomize.${NC}"
    echo -e "${CYAN}This creates a separate 'maas-api' namespace with the MaaS components.${NC}"
    echo ""
    
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
    
    # Check if dashboard config has MaaS enabled
    local maas_enabled=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications -o jsonpath='{.spec.dashboardConfig.modelAsService}' 2>/dev/null)
    if [ "$maas_enabled" != "true" ]; then
        print_warning "MaaS not enabled in dashboard config. Enabling now..."
        oc patch odhdashboardconfig odh-dashboard-config \
            -n redhat-ods-applications \
            --type=merge \
            -p '{"spec": {"dashboardConfig": {"modelAsService": true, "genAiStudio": true}}}' 2>/dev/null || true
    else
        print_success "MaaS enabled in dashboard config"
    fi
    
    # Execute legacy steps
    install_rhcl_operator_legacy
    create_kuadrant_instance_legacy
    configure_authorino_legacy
    create_gateway_class_legacy
    create_maas_namespace_legacy
    deploy_maas_api_legacy
    configure_audience_policy_legacy
    restart_controllers_legacy
    test_maas_configuration_legacy
    verify_security_configuration_legacy
    display_usage_instructions_legacy
}

install_rhcl_operator_legacy() {
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

create_kuadrant_instance_legacy() {
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
    
    # Wait for Kuadrant components to be ready
    print_step "Waiting for Kuadrant components to be ready..."
    
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

configure_authorino_legacy() {
    print_header "Step 3: Configuring Authorino"
    
    print_step "Annotating Authorino service for TLS certificate..."
    
    oc annotate svc/authorino-authorino-authorization \
        service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
        -n kuadrant-system --overwrite
    
    print_success "Authorino service annotated"
    
    print_step "Waiting for TLS certificate..."
    sleep 10
    
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
    
    print_step "Waiting for Authorino to restart..."
    sleep 15
}

create_gateway_class_legacy() {
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

create_maas_namespace_legacy() {
    print_header "Step 5: Creating 'maas-api' namespace"
    
    if oc get namespace maas-api &>/dev/null; then
        print_success "Namespace 'maas-api' already exists"
        return 0
    fi
    
    print_step "Creating namespace..."
    oc create namespace maas-api
    
    print_success "Namespace 'maas-api' created"
}

deploy_maas_api_legacy() {
    print_header "Step 6: Deploying MaaS API Objects"
    
    print_step "Deploying MaaS API using kustomize (this may take a minute)..."
    
    export CLUSTER_DOMAIN
    oc apply --server-side=true \
      -f <(kustomize build "https://github.com/opendatahub-io/maas-billing.git/deployment/overlays/openshift?ref=main" | \
           envsubst '$CLUSTER_DOMAIN')
    
    print_success "MaaS API objects deployed"
    
    print_step "Waiting for MaaS API pods to be ready..."
    sleep 10
    
    oc wait --for=condition=ready pod -l app=maas-api -n maas-api --timeout=300s || true
    
    print_success "MaaS API deployment complete"
}

configure_audience_policy_legacy() {
    print_header "Step 7: Configuring Audience Policy"
    
    print_step "Extracting audience from service account token..."
    
    TOKEN=$(oc create token default --duration=10m 2>/dev/null)
    PAYLOAD=$(echo "$TOKEN" | cut -d. -f2)
    
    while [ $((${#PAYLOAD} % 4)) -ne 0 ]; do
        PAYLOAD="${PAYLOAD}="
    done
    
    DECODED=$(echo "$PAYLOAD" | base64 -d 2>/dev/null)
    AUD=$(echo "$DECODED" | jq -r '.aud[0]' 2>/dev/null)
    
    if [ -z "$AUD" ]; then
        print_warning "jq extraction failed, trying manual extraction..."
        AUD=$(echo "$DECODED" | grep -o '"aud":\["[^"]*"' | sed 's/"aud":\["\([^"]*\)"/\1/')
    fi
    
    if [ -z "$AUD" ]; then
        print_error "Failed to extract audience from token"
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

restart_controllers_legacy() {
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

test_maas_configuration_legacy() {
    print_header "Step 9: Testing MaaS Configuration"
    
    print_step "Waiting for MaaS API to be fully ready..."
    sleep 20
    
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

verify_security_configuration_legacy() {
    print_header "Step 10: Verifying Security Configuration"
    
    print_step "Checking for models with MaaS enabled but no authentication..."
    
    local insecure_models=0
    local namespaces=$(oc get ns -o name | grep -v "openshift\|kube\|default" | sed 's/namespace\///')
    
    for ns in $namespaces; do
        local models=$(oc get llmisvc -n "$ns" -o json 2>/dev/null | jq -r '.items[] | select(.metadata.annotations."security.opendatahub.io/enable-auth" == "false") | .metadata.name' 2>/dev/null || echo "")
        
        if [ -n "$models" ]; then
            for model in $models; do
                local has_maas=$(oc get httproute -n "$ns" -l serving.kserve.io/inferenceservice="$model" -o json 2>/dev/null | jq -r '.items[] | select(.spec.parentRefs[]?.name == "maas-default-gateway") | .metadata.name' 2>/dev/null || echo "")
                
                if [ -n "$has_maas" ]; then
                    print_warning "SECURITY RISK: Model '$model' in namespace '$ns' has MaaS enabled but authentication disabled!"
                    echo "   Direct route is unprotected: https://maas.${CLUSTER_DOMAIN}/${ns}/${model}/v1/..."
                    echo "   Fix: oc annotate llmisvc/$model -n $ns security.opendatahub.io/enable-auth=true"
                    insecure_models=$((insecure_models + 1))
                fi
            done
        fi
    done
    
    if [ $insecure_models -eq 0 ]; then
        print_success "No security issues detected"
    else
        echo ""
        print_error "Found $insecure_models model(s) with potential security issues"
        print_warning "Please enable authentication on these models to secure direct routes"
    fi
}

display_usage_instructions_legacy() {
    print_header "MaaS Setup Complete! (Legacy)"
    
    echo -e "${GREEN}✓ Model as a Service (MaaS) infrastructure has been deployed!${NC}"
    echo ""
    echo -e "${YELLOW}Note: The MaaS API may take 2-3 minutes to be fully ready after deployment.${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}MaaS API Endpoint:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "MaaS URL: https://maas.${CLUSTER_DOMAIN}/maas-api/v1/..."
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}How to Use MaaS:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "1. Deploy a model with MaaS enabled:"
    echo "   - Go to RHOAI Dashboard → Models → Deploy Model"
    echo "   - Select a model (e.g., Llama 3.2-3B)"
    echo "   - Choose 'llm-d' as serving runtime (REQUIRED - vLLM does NOT work with MaaS)"
    echo "   - ✅ Check 'Enable Model as a Service' checkbox"
    echo "   - ✅ Check 'Require authentication' checkbox (CRITICAL for security!)"
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
    echo "HOST=\"https://maas.${CLUSTER_DOMAIN}\""
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
    echo -e "${GREEN}✓ MaaS infrastructure deployment complete!${NC}"
    echo ""
}

################################################################################
# Main execution
################################################################################

main() {
    print_header "Model as a Service (MaaS) Setup"
    
    echo -e "${CYAN}This script will set up MaaS infrastructure for your RHOAI installation.${NC}"
    echo -e "${CYAN}It will automatically detect your RHOAI version and use the appropriate setup.${NC}"
    echo ""
    
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    # Check common prerequisites and detect version
    check_common_prerequisites
    
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Choose setup path based on version
    if is_rhoai_33_or_higher; then
        echo -e "${GREEN}Using RHOAI 3.3+ integrated MaaS setup${NC}"
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        setup_maas_33
    else
        echo -e "${YELLOW}Using legacy MaaS setup (RHOAI 3.2 and earlier)${NC}"
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        setup_maas_legacy
    fi
}

# Run main function
main
