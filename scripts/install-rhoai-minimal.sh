#!/bin/bash

################################################################################
# Minimal RHOAI Installation (without llm-d or MaaS)
################################################################################
# This script installs RHOAI 3.0 with basic model serving capabilities using
# vLLM, without the llm-d serving runtime or MaaS API infrastructure.
#
# What's installed:
#   ✅ Node Feature Discovery (NFD) - for hardware detection
#   ✅ NVIDIA GPU Operator - for GPU support
#   ✅ Red Hat Build of Kueue - for workload queueing
#   ✅ RHOAI 3.0 Operator - core AI platform
#   ✅ User Workload Monitoring - for KServe metrics
#
# What's NOT installed (not needed for basic vLLM serving):
#   ❌ Leader Worker Set (LWS) - only required for llm-d
#   ❌ Red Hat Connectivity Link (RHCL/Kuadrant) - only for llm-d auth
#   ❌ MaaS API infrastructure - only for Model as a Service
#
# Use cases:
#   - Simple model deployments with vLLM
#   - GenAI Playground (works without llm-d)
#   - Workbenches and notebooks
#   - AI Pipelines
#   - Model Registry
#
# Usage:
#   ./scripts/install-rhoai-minimal.sh
#
# Reference:
#   - CAI's guide to RHOAI 3.0 (Section 0 & 1)
#   - Red Hat OpenShift AI documentation
################################################################################

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source utilities
source "$SCRIPT_DIR/lib/utils/colors.sh"
source "$SCRIPT_DIR/lib/utils/common.sh"

print_banner() {
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                                                                            ║${NC}"
    echo -e "${MAGENTA}║          🚀 Minimal RHOAI 3.0 Installation (vLLM only)                    ║${NC}"
    echo -e "${MAGENTA}║                                                                            ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check oc CLI
    if ! command -v oc &>/dev/null; then
        print_error "oc CLI not found. Please install the OpenShift CLI."
        exit 1
    fi
    print_success "oc CLI found"
    
    # Check cluster connection
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        exit 1
    fi
    print_success "Connected to cluster: $(oc whoami --show-server)"
    
    # Check cluster admin privileges
    if ! oc auth can-i create clusterrole &>/dev/null; then
        print_error "Cluster admin privileges required"
        exit 1
    fi
    print_success "Cluster admin privileges confirmed"
    
    # Check OpenShift version (4.19+ required for RHOAI 3.0)
    local ocp_version=$(oc version -o json 2>/dev/null | jq -r '.openshiftVersion // "unknown"' 2>/dev/null || echo "unknown")
    print_info "OpenShift version: $ocp_version"
    
    echo ""
}

# Enable User Workload Monitoring (required for KServe metrics)
enable_user_workload_monitoring() {
    print_header "Enabling User Workload Monitoring"
    
    # Check if already enabled
    local uwm_enabled=$(oc get configmap cluster-monitoring-config -n openshift-monitoring -o jsonpath='{.data.config\.yaml}' 2>/dev/null | grep -c "enableUserWorkload: true" || echo "0")
    
    if [ "$uwm_enabled" -gt 0 ]; then
        print_success "User Workload Monitoring already enabled"
        return 0
    fi
    
    print_step "Creating cluster-monitoring-config ConfigMap..."
    
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
    
    print_success "User Workload Monitoring enabled"
}

# Install NFD Operator
install_nfd() {
    print_header "Installing Node Feature Discovery (NFD) Operator"
    
    # Check if already installed
    if oc get csv -n openshift-nfd 2>/dev/null | grep -q "nfd.*Succeeded"; then
        print_success "NFD Operator already installed"
        
        # Check for NFD instance
        if oc get nodefeaturediscovery nfd-instance -n openshift-nfd &>/dev/null; then
            print_success "NFD instance already exists"
            return 0
        fi
    else
        print_step "Creating NFD namespace and operator..."
        
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-nfd
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-nfd
  namespace: openshift-nfd
spec:
  targetNamespaces:
    - openshift-nfd
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nfd
  namespace: openshift-nfd
spec:
  channel: stable
  name: nfd
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
        
        # Wait for operator
        print_step "Waiting for NFD operator to be ready..."
        local timeout=180
        local elapsed=0
        until oc get csv -n openshift-nfd 2>/dev/null | grep -q "nfd.*Succeeded"; do
            if [ $elapsed -ge $timeout ]; then
                print_warning "NFD operator not ready yet (continuing anyway)"
                break
            fi
            sleep 10
            elapsed=$((elapsed + 10))
        done
    fi
    
    # Create NFD instance
    if ! oc get nodefeaturediscovery nfd-instance -n openshift-nfd &>/dev/null; then
        print_step "Creating NFD instance..."
        
        cat <<EOF | oc apply -f -
apiVersion: nfd.openshift.io/v1
kind: NodeFeatureDiscovery
metadata:
  name: nfd-instance
  namespace: openshift-nfd
spec:
  operand:
    image: registry.redhat.io/openshift4/ose-node-feature-discovery-rhel9:v4.19
    servicePort: 12000
  workerConfig:
    configData: |
      core:
        sleepInterval: 60s
EOF
        
        print_success "NFD instance created"
    fi
    
    print_success "NFD installation complete"
}

# Install GPU Operator
install_gpu_operator() {
    print_header "Installing NVIDIA GPU Operator"
    
    # Check if already installed
    if oc get csv -n nvidia-gpu-operator 2>/dev/null | grep -q "gpu-operator.*Succeeded"; then
        print_success "GPU Operator already installed"
    else
        print_step "Creating GPU operator namespace and subscription..."
        
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: nvidia-gpu-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: nvidia-gpu-operator
  namespace: nvidia-gpu-operator
spec:
  targetNamespaces:
    - nvidia-gpu-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: gpu-operator-certified
  namespace: nvidia-gpu-operator
spec:
  channel: v24.9
  name: gpu-operator-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
EOF
        
        # Wait for operator
        print_step "Waiting for GPU operator to be ready..."
        local timeout=180
        local elapsed=0
        until oc get crd clusterpolicies.nvidia.com &>/dev/null; do
            if [ $elapsed -ge $timeout ]; then
                print_warning "GPU operator CRD not ready yet (continuing anyway)"
                break
            fi
            sleep 10
            elapsed=$((elapsed + 10))
        done
    fi
    
    # Check for GPU nodes
    local gpu_nodes=$(oc get nodes -l feature.node.kubernetes.io/pci-10de.present=true --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    if ! oc get clusterpolicy gpu-cluster-policy &>/dev/null; then
        if [ "$gpu_nodes" -gt 0 ]; then
            print_step "GPU nodes detected, creating ClusterPolicy..."
            
            cat <<EOF | oc apply -f -
apiVersion: nvidia.com/v1
kind: ClusterPolicy
metadata:
  name: gpu-cluster-policy
spec:
  operator:
    defaultRuntime: crio
    use_ocp_driver_toolkit: true
  driver:
    enabled: true
  dcgm:
    enabled: true
  dcgmExporter:
    enabled: true
  devicePlugin:
    enabled: true
  gfd:
    enabled: true
  migManager:
    enabled: true
  nodeStatusExporter:
    enabled: true
  toolkit:
    enabled: true
  validator:
    plugin:
      env:
        - name: WITH_WORKLOAD
          value: "false"
EOF
            
            print_success "GPU ClusterPolicy created"
        else
            print_info "No GPU nodes detected yet"
            print_info "ClusterPolicy will be created when GPU nodes are added"
        fi
    else
        print_success "GPU ClusterPolicy already exists"
    fi
    
    print_success "GPU operator installation complete"
}

# Install cert-manager (required by Kueue)
install_certmanager() {
    print_header "Installing cert-manager Operator"
    
    local ns="cert-manager-operator"
    
    if oc get csv -n "$ns" 2>/dev/null | grep -q "cert-manager.*Succeeded"; then
        print_success "cert-manager already installed"
        return 0
    fi
    
    print_step "Creating cert-manager namespace and subscription..."
    
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cert-manager-operator
  namespace: cert-manager-operator
spec:
  targetNamespaces:
    - cert-manager-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cert-manager-operator
  namespace: cert-manager-operator
spec:
  channel: stable-v1
  name: openshift-cert-manager-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
    
    # Wait for operator
    print_step "Waiting for cert-manager operator to be ready..."
    local timeout=180
    local elapsed=0
    until oc get csv -n "$ns" 2>/dev/null | grep -q "cert-manager.*Succeeded"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "cert-manager not ready yet (continuing anyway)"
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_success "cert-manager installation complete"
}

# Install Kueue Operator
install_kueue() {
    print_header "Installing Red Hat Build of Kueue Operator"
    
    if oc get csv -n openshift-operators 2>/dev/null | grep -q "kueue.*Succeeded"; then
        print_success "Kueue Operator already installed"
        return 0
    fi
    
    # Install cert-manager first (dependency)
    install_certmanager
    
    print_step "Installing Kueue subscription..."
    
    cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kueue-operator
  namespace: openshift-operators
spec:
  channel: stable
  name: kueue-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
    
    # Wait for operator
    print_step "Waiting for Kueue operator to be ready..."
    local timeout=180
    local elapsed=0
    until oc get csv -n openshift-operators 2>/dev/null | grep -q "kueue.*Succeeded"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Kueue not ready yet (continuing anyway)"
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_success "Kueue installation complete"
}

# Install RHOAI Operator
install_rhoai_operator() {
    print_header "Installing Red Hat OpenShift AI Operator"
    
    local ns="redhat-ods-operator"
    
    if oc get csv -n "$ns" 2>/dev/null | grep -q "rhods-operator.*Succeeded"; then
        print_success "RHOAI Operator already installed"
        return 0
    fi
    
    print_step "Creating RHOAI operator namespace and subscription..."
    
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: redhat-ods-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: redhat-ods-operator
  namespace: redhat-ods-operator
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  channel: fast
  name: rhods-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
    
    # Wait for operator
    print_step "Waiting for RHOAI operator to be ready (this may take 3-5 minutes)..."
    local timeout=300
    local elapsed=0
    until oc get csv -n "$ns" 2>/dev/null | grep -q "rhods-operator.*Succeeded"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "RHOAI operator not ready yet (continuing anyway)"
            break
        fi
        echo "Waiting for RHOAI operator... (${elapsed}s elapsed)"
        sleep 15
        elapsed=$((elapsed + 15))
    done
    
    print_success "RHOAI operator installation complete"
}

# Wait for RHOAI webhook service
wait_for_rhoai_webhook() {
    print_step "Waiting for RHOAI webhook service to be ready..."
    
    local timeout=180
    local elapsed=0
    
    until oc get svc rhods-operator-webhook-service -n redhat-ods-operator &>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Webhook service not found (continuing anyway)"
            return 1
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    # Wait for endpoints
    elapsed=0
    until [ "$(oc get endpoints rhods-operator-webhook-service -n redhat-ods-operator -o jsonpath='{.subsets[0].addresses}' 2>/dev/null)" != "" ]; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Webhook endpoints not ready (continuing anyway)"
            return 1
        fi
        echo "Waiting for webhook endpoints... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_success "RHOAI webhook service is ready"
    return 0
}

# Create DSCInitialization
create_dsci() {
    print_header "Creating DSCInitialization"
    
    if oc get dscinitializations default-dsci &>/dev/null; then
        print_success "DSCInitialization already exists"
        return 0
    fi
    
    # Wait for webhook first
    wait_for_rhoai_webhook
    
    print_step "Creating DSCInitialization..."
    
    cat <<EOF | oc apply -f -
apiVersion: dscinitialization.opendatahub.io/v1
kind: DSCInitialization
metadata:
  name: default-dsci
spec:
  applicationsNamespace: redhat-ods-applications
  monitoring:
    managementState: Managed
    namespace: redhat-ods-monitoring
  serviceMesh:
    controlPlane:
      metricsCollection: Istio
      name: data-science-smcp
      namespace: istio-system
    managementState: Managed
  trustedCABundle:
    customCABundle: ''
    managementState: Managed
EOF
    
    print_success "DSCInitialization created"
}

# Create DataScienceCluster (minimal - without llm-d components)
create_dsc() {
    print_header "Creating DataScienceCluster (Minimal Configuration)"
    
    if oc get datasciencecluster default-dsc &>/dev/null; then
        print_success "DataScienceCluster already exists"
        return 0
    fi
    
    print_step "Creating DataScienceCluster..."
    print_info "This configuration includes vLLM serving but NOT llm-d"
    
    # Based on CAI guide Section 1, but without llm-d specific components
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
    workbenches:
      managementState: Managed
    datasciencepipelines:
      managementState: Managed
    aipipelines:
      managementState: Managed
    kserve:
      managementState: Managed
    modelmeshserving:
      managementState: Managed
    modelregistry:
      managementState: Managed
      registriesNamespace: rhoai-model-registries
    ray:
      managementState: Managed
    trainingoperator:
      managementState: Managed
    trustyai:
      managementState: Managed
    feastoperator:
      managementState: Managed
    llamastackoperator:
      managementState: Managed
    kueue:
      defaultClusterQueueName: default
      defaultLocalQueueName: default
      managementState: Unmanaged
EOF
    
    print_success "DataScienceCluster created"
}

# Wait for RHOAI dashboard
wait_for_dashboard() {
    print_header "Waiting for RHOAI Dashboard"
    
    local timeout=600
    local elapsed=0
    
    print_step "Waiting for RHOAI dashboard deployment..."
    
    until oc get deployment rhods-dashboard -n redhat-ods-applications &>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Dashboard deployment not found yet"
            return 1
        fi
        echo "Waiting for dashboard deployment... (${elapsed}s elapsed)"
        sleep 15
        elapsed=$((elapsed + 15))
    done
    
    # Wait for pods to be ready
    print_step "Waiting for dashboard pods to be ready..."
    elapsed=0
    until oc get deployment rhods-dashboard -n redhat-ods-applications -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -q "[1-9]"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Dashboard pods not ready yet"
            break
        fi
        echo "Waiting for dashboard pods... (${elapsed}s elapsed)"
        sleep 15
        elapsed=$((elapsed + 15))
    done
    
    # Create route if missing
    if ! oc get route rhods-dashboard -n redhat-ods-applications &>/dev/null; then
        print_step "Creating dashboard route..."
        oc create route passthrough rhods-dashboard --service=rhods-dashboard --port=https -n redhat-ods-applications 2>/dev/null || true
    fi
    
    local dashboard_url=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null)
    if [ -n "$dashboard_url" ]; then
        print_success "RHOAI Dashboard is ready!"
        print_info "Dashboard URL: https://$dashboard_url"
    fi
}

# Configure dashboard features
configure_dashboard() {
    print_header "Configuring Dashboard Features"
    
    print_step "Enabling Model Registry, GenAI Studio, and other features..."
    
    # Wait for OdhDashboardConfig to exist
    local timeout=120
    local elapsed=0
    until oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications &>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "OdhDashboardConfig not found yet (skipping configuration)"
            return 1
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    # Patch dashboard config
    oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
        --type merge \
        -p '{
            "spec": {
                "dashboardConfig": {
                    "disableModelRegistry": false,
                    "disableModelCatalog": false,
                    "disableKServeMetrics": false,
                    "genAiStudio": true,
                    "disableLMEval": false,
                    "disableKueue": false,
                    "disableHardwareProfiles": false
                }
            }
        }' 2>/dev/null || print_warning "Could not patch dashboard config (may need manual configuration)"
    
    print_success "Dashboard features configured"
}

# Create Kueue resources
create_kueue_resources() {
    print_header "Creating Kueue Resources"
    
    # Check if ClusterQueue exists
    if oc get clusterqueue default &>/dev/null; then
        print_success "ClusterQueue 'default' already exists"
    else
        print_step "Creating default ClusterQueue..."
        
        cat <<EOF | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: default
spec:
  namespaceSelector: {}
  resourceGroups:
    - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]
      flavors:
        - name: default-flavor
          resources:
            - name: "cpu"
              nominalQuota: 100
            - name: "memory"
              nominalQuota: 200Gi
            - name: "nvidia.com/gpu"
              nominalQuota: 10
EOF
        
        print_success "ClusterQueue created"
    fi
    
    # Check if ResourceFlavor exists
    if oc get resourceflavor default-flavor &>/dev/null; then
        print_success "ResourceFlavor 'default-flavor' already exists"
    else
        print_step "Creating default ResourceFlavor..."
        
        cat <<EOF | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: default-flavor
spec: {}
EOF
        
        print_success "ResourceFlavor created"
    fi
}

# Print summary
print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Installation Complete!                                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}What was installed:${NC}"
    echo "  ✅ Node Feature Discovery (NFD)"
    echo "  ✅ NVIDIA GPU Operator"
    echo "  ✅ Red Hat Build of Kueue"
    echo "  ✅ Red Hat OpenShift AI 3.0"
    echo "  ✅ User Workload Monitoring"
    echo ""
    echo -e "${CYAN}What was NOT installed (not needed for basic vLLM):${NC}"
    echo "  ⏭️  Leader Worker Set (LWS) - only for llm-d"
    echo "  ⏭️  Red Hat Connectivity Link (RHCL) - only for llm-d auth"
    echo "  ⏭️  MaaS API infrastructure - only for Model as a Service"
    echo ""
    echo -e "${CYAN}Available features:${NC}"
    echo "  • Model deployment with vLLM serving runtime"
    echo "  • GenAI Playground (for testing models)"
    echo "  • Workbenches and Notebooks"
    echo "  • AI Pipelines"
    echo "  • Model Registry"
    echo "  • Kueue workload queueing"
    echo ""
    
    local dashboard_url=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null)
    if [ -n "$dashboard_url" ]; then
        echo -e "${CYAN}RHOAI Dashboard:${NC}"
        echo "  https://$dashboard_url"
        echo ""
    fi
    
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Access the RHOAI Dashboard"
    echo "  2. Create a Data Science project"
    echo "  3. Deploy a model using vLLM serving runtime"
    echo "  4. (Optional) Add GPU nodes: ./scripts/create-gpu-machineset.sh"
    echo ""
    echo -e "${YELLOW}To add llm-d and MaaS later:${NC}"
    echo "  Run: ./complete-setup.sh --skip-openshift"
    echo "  Or manually install RHCL and LWS operators"
    echo ""
}

# Main function
main() {
    print_banner
    
    echo -e "${CYAN}This will install RHOAI 3.0 with basic vLLM model serving.${NC}"
    echo ""
    echo "Components to be installed:"
    echo "  • Node Feature Discovery (NFD)"
    echo "  • NVIDIA GPU Operator"
    echo "  • Red Hat Build of Kueue"
    echo "  • Red Hat OpenShift AI 3.0"
    echo ""
    echo -e "${YELLOW}Note: llm-d and MaaS will NOT be installed.${NC}"
    echo "      You can add them later if needed."
    echo ""
    
    read -p "Continue with minimal RHOAI installation? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    echo ""
    
    # Run installation steps
    check_prerequisites
    enable_user_workload_monitoring
    install_nfd
    install_gpu_operator
    install_kueue
    install_rhoai_operator
    create_dsci
    create_dsc
    wait_for_dashboard
    configure_dashboard
    create_kueue_resources
    
    print_summary
}

# Run main
main "$@"

