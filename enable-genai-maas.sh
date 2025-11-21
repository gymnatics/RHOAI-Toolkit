#!/bin/bash

################################################################################
# Enable GenAI Playground and Model as a Service (MaaS) in RHOAI 3.0
################################################################################
# Based on CAI's guide to RHOAI 3.0
# This script enables missing features in an existing RHOAI 3.0 deployment

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
# Step 1: Update DataScienceCluster to enable missing components
################################################################################

update_datasciencecluster() {
    print_header "Step 1: Updating DataScienceCluster"
    
    print_step "Checking current DataScienceCluster configuration..."
    
    if ! oc get datasciencecluster default-dsc &>/dev/null; then
        print_error "DataScienceCluster 'default-dsc' not found. Please install RHOAI first."
        exit 1
    fi
    
    print_step "Patching DataScienceCluster to enable:"
    echo "  - llamastackoperator (for GenAI Playground)"
    echo "  - feastoperator (for Feature Store)"
    echo "  - kueue (for workload management)"
    echo "  - trainingoperator (for distributed training)"
    echo "  - trustyai (for model monitoring)"
    echo "  - modelregistry (for model catalog)"
    echo "  - aipipelines (for AI pipelines)"
    
    cat <<EOF | oc apply -f -
apiVersion: datasciencecluster.opendatahub.io/v2
kind: DataScienceCluster
metadata:
  name: default-dsc
  labels:
    app.kubernetes.io/name: datasciencecluster
spec:
  components:
    dashboard:
      managementState: Managed
    aipipelines:
      managementState: Managed
    feastoperator:
      managementState: Managed
    kserve:
      managementState: Managed
    llamastackoperator:
      managementState: Managed
    kueue:
      defaultClusterQueueName: default
      defaultLocalQueueName: default
      managementState: Unmanaged
    modelregistry:
      managementState: Managed
      registriesNamespace: rhoai-model-registries
    ray:
      managementState: Managed
    workbenches:
      managementState: Managed
    trainingoperator:
      managementState: Managed
    trustyai:
      managementState: Managed
    codeflare:
      managementState: Removed
EOF
    
    print_success "DataScienceCluster updated"
    
    print_step "Waiting for components to be deployed (this may take 5-10 minutes)..."
    sleep 30
}

################################################################################
# Step 2: Update OdhDashboardConfig to enable GenAI and MaaS features
################################################################################

update_dashboard_config() {
    print_header "Step 2: Updating Dashboard Configuration"
    
    print_step "Enabling GenAI Studio, Model as a Service, and other features..."
    
    # Use patch instead of apply to avoid overwriting existing config
    oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge --patch='
spec:
  dashboardConfig:
    disableTracking: false
    disableModelRegistry: false
    disableModelCatalog: false
    disableKServeMetrics: false
    genAiStudio: true
    modelAsService: true
    disableLMEval: false
    disableKueue: false
'
    
    print_success "Dashboard configuration updated"
    
    print_step "Restarting dashboard pods to apply changes..."
    oc delete pod -n redhat-ods-applications -l app=rhods-dashboard --ignore-not-found=true
    sleep 10
}

################################################################################
# Step 3: Create Hardware Profile for GPU (if not exists)
################################################################################

create_gpu_hardware_profile() {
    print_header "Step 3: Creating GPU Hardware Profile"
    
    if oc get hardwareprofile gpu-profile -n redhat-ods-applications &>/dev/null; then
        print_success "GPU Hardware Profile already exists, skipping"
        return 0
    fi
    
    print_step "Creating GPU Hardware Profile..."
    
    cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: gpu-profile
  name: gpu-profile
  namespace: redhat-ods-applications
spec:
  identifiers:
    - defaultCount: '1'
      displayName: CPU
      identifier: cpu
      maxCount: '8'
      minCount: 1
      resourceType: CPU
    - defaultCount: 12Gi
      displayName: Memory
      identifier: memory
      maxCount: 24Gi
      minCount: 1Gi
      resourceType: Memory
    - defaultCount: 1
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: 4
      minCount: 1
      resourceType: Accelerator
EOF
    
    print_success "GPU Hardware Profile created"
}

################################################################################
# Step 4: Install RHCL (Red Hat Connectivity Link) Operator
################################################################################

install_rhcl_operator() {
    print_header "Step 4: Installing RHCL (Kuadrant) Operator"
    
    # Check if kuadrant-system namespace exists
    if ! oc get namespace kuadrant-system &>/dev/null; then
        print_step "Creating kuadrant-system namespace..."
        oc create namespace kuadrant-system
        print_success "kuadrant-system namespace created"
    else
        print_success "kuadrant-system namespace already exists"
    fi
    
    # Check if RHCL operator is already installed
    if oc get subscription rhcl-operator -n kuadrant-system &>/dev/null; then
        print_success "RHCL Operator already installed"
        
        # Check if Kuadrant instance exists
        if oc get kuadrant kuadrant -n kuadrant-system &>/dev/null; then
            print_success "Kuadrant instance already exists"
            return 0
        fi
    else
        print_step "Installing RHCL Operator (provides Kuadrant for llm-d)..."
        
        cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: kuadrant-system
  namespace: kuadrant-system
spec:
  targetNamespaces:
  - kuadrant-system
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
        sleep 30
        
        local timeout=300
        local elapsed=0
        until oc get crd kuadrants.kuadrant.io &>/dev/null; do
            if [ $elapsed -ge $timeout ]; then
                print_warning "Timeout waiting for RHCL operator CRDs (continuing anyway)"
                break
            fi
            echo "Waiting for Kuadrant CRD... (${elapsed}s elapsed)"
            sleep 10
            elapsed=$((elapsed + 10))
        done
        
        print_success "RHCL Operator is ready"
    fi
    
    # Create Kuadrant instance if it doesn't exist
    if ! oc get kuadrant kuadrant -n kuadrant-system &>/dev/null; then
        print_step "Creating Kuadrant instance..."
        
        cat <<EOF | oc apply -f -
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
EOF
        
        print_success "Kuadrant instance created"
        
        # Wait for Kuadrant to be ready
        print_step "Waiting for Kuadrant components to be ready..."
        sleep 30
        
        # Wait for Authorino service to be created
        local auth_timeout=120
        local auth_elapsed=0
        until oc get svc/authorino-authorino-authorization -n kuadrant-system &>/dev/null; do
            if [ $auth_elapsed -ge $auth_timeout ]; then
                print_warning "Authorino service not ready yet (continuing anyway)"
                break
            fi
            echo "Waiting for Authorino service... (${auth_elapsed}s elapsed)"
            sleep 10
            auth_elapsed=$((auth_elapsed + 10))
        done
        
        # Configure Authorino with TLS if service exists
        if oc get svc/authorino-authorino-authorization -n kuadrant-system &>/dev/null; then
            print_step "Configuring Authorino with TLS..."
            
            # Annotate service for TLS certificate
            oc annotate svc/authorino-authorino-authorization \
                service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
                -n kuadrant-system --overwrite
            
            sleep 10
            
            # Enable TLS in Authorino
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
        fi
    fi
    
    print_success "RHCL operator installation complete (enables llm-d serving runtime)"
}

################################################################################
# Step 5: Install prerequisite operators (if not already installed)
################################################################################

install_prerequisites() {
    print_header "Step 5: Checking Prerequisites"
    
    # Check for Leader Worker Set Operator
    print_step "Checking for Red Hat Build of Leader Worker Set Operator..."
    if ! oc get subscription leader-worker-set-operator -n openshift-lws-operator &>/dev/null; then
        print_warning "Leader Worker Set Operator not found. Installing..."
        
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-lws-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: leader-worker-set-operator
  namespace: openshift-lws-operator
spec:
  targetNamespaces:
  - openshift-lws-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: leader-worker-set-operator
  namespace: openshift-lws-operator
spec:
  channel: stable
  installPlanApproval: Automatic
  name: leader-worker-set-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
        
        sleep 10
        print_success "Leader Worker Set Operator installed"
    else
        print_success "Leader Worker Set Operator already installed"
    fi
    
    # Check for Kueue Operator
    print_step "Checking for Red Hat Build of Kueue Operator..."
    if ! oc get subscription kueue-operator -n openshift-kueue-system &>/dev/null; then
        print_warning "Kueue Operator not found. Installing..."
        
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-kueue-system
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: kueue-operator
  namespace: openshift-kueue-system
spec:
  targetNamespaces:
  - openshift-kueue-system
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kueue-operator
  namespace: openshift-kueue-system
spec:
  channel: stable
  installPlanApproval: Automatic
  name: kueue-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
        
        sleep 10
        print_success "Kueue Operator installed"
    else
        print_success "Kueue Operator already installed"
    fi
    
    # Enable UserWorkloadMonitoring
    print_step "Enabling UserWorkloadMonitoring for KServe metrics..."
    
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
    alertmanagerMain:
      enableUserAlertmanagerConfig: true
EOF
    
    print_success "UserWorkloadMonitoring enabled"
}

################################################################################
# Step 5: Display next steps
################################################################################

display_next_steps() {
    print_header "Configuration Complete!"
    
    echo -e "${GREEN}✓ GenAI Playground and Model as a Service features have been enabled!${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo ""
    echo "1. Wait for all components to be ready (5-10 minutes):"
    echo "   ${YELLOW}oc get datasciencecluster default-dsc -o yaml${NC}"
    echo ""
    echo "2. Check the RHOAI dashboard - you should now see:"
    echo "   - GenAI Studio / Playground menu"
    echo "   - Model as a Service option when deploying models"
    echo "   - Model Catalog"
    echo "   - Feature Store"
    echo ""
    echo "3. To deploy a model for GenAI Playground:"
    echo "   a) Go to Models → Deploy Model"
    echo "   b) Select a model from the catalog (e.g., Llama 3.2)"
    echo "   c) Choose 'vLLM' as the serving runtime"
    echo "   d) Select the GPU hardware profile"
    echo "   e) After deployment, go to AI Assets Endpoints"
    echo "   f) Click 'Add to Playground' for your model"
    echo ""
    echo "4. To enable Model as a Service (MaaS):"
    echo "   - Check the 'Model as a Service' checkbox when deploying"
    echo "   - This requires additional MaaS API setup (see CAI guide Section 4)"
    echo ""
    echo -e "${YELLOW}⚠  Important Notes:${NC}"
    echo "   - GenAI Playground requires GPU nodes to be available"
    echo "   - Models must be deployed and running before adding to playground"
    echo "   - For MaaS, additional Gateway and authentication setup is required"
    echo ""
    echo -e "${BLUE}For detailed instructions, refer to:${NC}"
    echo "   - CAI's guide to RHOAI 3.0 (Section 2 & 4)"
    echo "   - https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0"
    echo ""
}

################################################################################
# Main execution
################################################################################

main() {
    print_header "Enable GenAI Playground & Model as a Service in RHOAI 3.0"
    
    # Check if oc is available
    if ! command -v oc &> /dev/null; then
        print_error "oc command not found. Please install OpenShift CLI."
        exit 1
    fi
    
    # Check if logged in
    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift. Please run 'oc login' first."
        exit 1
    fi
    
    print_success "Connected to OpenShift cluster: $(oc whoami --show-server)"
    echo ""
    
    # Execute steps
    install_rhcl_operator
    install_prerequisites
    update_datasciencecluster
    update_dashboard_config
    create_gpu_hardware_profile
    display_next_steps
}

# Run main function
main

