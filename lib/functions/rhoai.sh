#!/bin/bash
################################################################################
# RHOAI installation and configuration functions
################################################################################

# Source required utilities
# Use a local variable to avoid overwriting caller's SCRIPT_DIR
_RHOAI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_RHOAI_LIB_DIR/lib/utils/colors.sh"
source "$_RHOAI_LIB_DIR/lib/utils/common.sh"

# Get RHOAI channel based on version
get_rhoai_channel() {
    local version="$1"
    
    case "$version" in
        2.17|2.18) echo "stable-2.18" ;;
        2.19|2.20) echo "stable-2.20" ;;
        2.21) echo "stable-2.21" ;;
        2.22) echo "stable-2.22" ;;
        2.23) echo "stable-2.23" ;;
        2.24|2.25) echo "stable" ;;
        3.0|3.1|3.2|3.3) echo "fast-3.x" ;;
        *) echo "stable" ;;
    esac
}

# Install RHOAI Operator
install_rhoai_operator() {
    local rhoai_version="$1"
    local channel=$(get_rhoai_channel "$rhoai_version")
    
    print_header "Installing Red Hat OpenShift AI Operator (version $rhoai_version)"
    
    # Check if already installed
    if check_operator_installed "rhods-operator" "redhat-ods-operator"; then
        print_success "RHOAI Operator already installed"
        return 0
    fi
    
    print_step "Installing RHOAI Operator (channel: $channel)..."
    
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
  channel: $channel
  installPlanApproval: Automatic
  name: rhods-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
    
    # Wait for operator to be ready
    print_step "Waiting for RHOAI operator to be ready (this may take 2-3 minutes)..."
    sleep 30
    
    local timeout=300
    local elapsed=0
    until oc get crd datascienceclusters.datasciencecluster.opendatahub.io &>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Timeout waiting for RHOAI operator CRDs (continuing anyway)"
            break
        fi
        echo "Waiting for DataScienceCluster CRD... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_success "RHOAI Operator is ready"
}

# Initialize RHOAI (DSCInitialization)
initialize_rhoai() {
    print_header "Initializing RHOAI"
    
    if oc get dscinitializations.dscinitialization.opendatahub.io default-dsci &>/dev/null; then
        print_success "RHOAI already initialized"
        return 0
    fi
    
    # Wait for RHOAI operator webhook service to be ready
    print_step "Waiting for RHOAI operator webhook service to be ready..."
    local webhook_timeout=180
    local webhook_elapsed=0
    
    until oc get svc -n redhat-ods-operator | grep -q "rhods-operator"; do
        if [ $webhook_elapsed -ge $webhook_timeout ]; then
            print_error "Timeout waiting for RHOAI operator webhook service"
            return 1
        fi
        echo "Waiting for webhook service... (${webhook_elapsed}s elapsed)"
        sleep 10
        webhook_elapsed=$((webhook_elapsed + 10))
    done
    
    # Additional wait for webhook to be fully functional
    print_step "Waiting for webhook to be fully registered..."
    sleep 30
    
    # Verify webhook endpoints are ready
    local endpoint_check=0
    until oc get endpoints -n redhat-ods-operator rhods-operator-service &>/dev/null && \
          [ "$(oc get endpoints -n redhat-ods-operator rhods-operator-service -o jsonpath='{.subsets[*].addresses}' 2>/dev/null)" != "" ]; do
        if [ $endpoint_check -ge 60 ]; then
            print_warning "Webhook endpoints not fully ready, proceeding anyway"
            break
        fi
        echo "Waiting for webhook endpoints... (${endpoint_check}s elapsed)"
        sleep 10
        endpoint_check=$((endpoint_check + 10))
    done
    
    print_success "RHOAI operator webhook is ready"
    
    print_step "Creating DSCInitialization..."
    
    # Use replace if exists, apply if not (handles conversion webhook issues better)
    if oc get dscinitialization default-dsci &>/dev/null 2>&1; then
        print_step "DSCInitialization exists but may be in wrong version, replacing..."
        cat <<EOF | oc replace -f -
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
    auth:
      audiences:
        - 'https://kubernetes.default.svc'
    controlPlane:
      metricsCollection: Istio
      name: data-science-smcp
      namespace: istio-system
    managementState: Managed
  trustedCABundle:
    customCABundle: ''
    managementState: Managed
EOF
    else
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
    auth:
      audiences:
        - 'https://kubernetes.default.svc'
    controlPlane:
      metricsCollection: Istio
      name: data-science-smcp
      namespace: istio-system
    managementState: Managed
  trustedCABundle:
    customCABundle: ''
    managementState: Managed
EOF
    fi
    
    if [ $? -eq 0 ]; then
        print_success "RHOAI initialized"
    else
        print_error "Failed to initialize RHOAI"
        print_info "This may be due to webhook timing. Check:"
        print_info "  oc get pods -n redhat-ods-operator"
        print_info "  oc get svc -n redhat-ods-operator"
        return 1
    fi
}

# Create DataScienceCluster (RHOAI 2.x)
create_datasciencecluster_v1() {
    print_header "Creating DataScienceCluster (v1)"
    
    if oc get datascienceclusters.datasciencecluster.opendatahub.io default-dsc &>/dev/null; then
        print_success "DataScienceCluster already exists"
        return 0
    fi
    
    print_step "Creating DataScienceCluster..."
    apply_manifest "$_RHOAI_LIB_DIR/lib/manifests/rhoai/datasciencecluster-v1.yaml" "DataScienceCluster v1"
    
    print_success "DataScienceCluster created"
}

# Create DataScienceCluster (RHOAI 3.x with GenAI/MaaS)
create_datasciencecluster_v2() {
    print_header "Creating DataScienceCluster (v2 - with GenAI/MaaS)"
    
    if oc get datascienceclusters.datasciencecluster.opendatahub.io default-dsc &>/dev/null; then
        print_success "DataScienceCluster already exists"
        return 0
    fi
    
    print_step "Creating DataScienceCluster with GenAI and MaaS components..."
    apply_manifest "$_RHOAI_LIB_DIR/lib/manifests/rhoai/datasciencecluster-v2.yaml" "DataScienceCluster v2"
    
    print_success "DataScienceCluster created with GenAI and MaaS support"
}

# Configure RHOAI Dashboard
configure_rhoai_dashboard() {
    print_header "Configuring RHOAI Dashboard"
    
    print_step "Enabling GenAI Studio and Model as a Service..."
    
    cat <<EOF | oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge --patch-file=/dev/stdin
spec:
  dashboardConfig:
    genAiStudio: true
    modelAsService: true
    disableModelRegistry: false
    disableModelCatalog: false
    disableKServeMetrics: false
    disableLMEval: false
    disableKueue: false
EOF
    
    print_success "Dashboard configured"
}

# Create GPU Hardware Profile
create_gpu_hardware_profile() {
    print_header "Creating GPU Hardware Profile"
    
    # Get current namespace or use default
    local current_ns=$(oc project -q 2>/dev/null || echo "default")
    
    # Template file location
    local template_file="$_RHOAI_LIB_DIR/lib/manifests/templates/hardwareprofile-gpu.yaml.tmpl"
    
    # Function to create hardware profile in a namespace
    create_profile_in_namespace() {
        local namespace=$1
        
        if oc get hardwareprofile gpu-profile -n "$namespace" &>/dev/null; then
            print_success "GPU hardware profile already exists in $namespace"
            return 0
        fi
        
        print_step "Creating GPU hardware profile in $namespace..."
        
        # Apply template with namespace substitution
        if [ -f "$template_file" ]; then
            # Export all variables with defaults (envsubst doesn't support bash default syntax)
            export NAMESPACE="$namespace"
            export PROFILE_NAME="gpu-profile"
            export DISPLAY_NAME="GPU Profile"
            export DEFAULT_CPU="2"
            export MAX_CPU="16"
            export DEFAULT_MEM="16Gi"
            export MAX_MEM="64Gi"
            export DEFAULT_GPU="1"
            export MAX_GPU="8"
            
            # Use envsubst with explicit variable list to avoid issues
            envsubst '${NAMESPACE} ${PROFILE_NAME} ${DISPLAY_NAME} ${DEFAULT_CPU} ${MAX_CPU} ${DEFAULT_MEM} ${MAX_MEM} ${DEFAULT_GPU} ${MAX_GPU}' < "$template_file" | oc apply -f -
            
            # Unset variables
            unset NAMESPACE PROFILE_NAME DISPLAY_NAME DEFAULT_CPU MAX_CPU DEFAULT_MEM MAX_MEM DEFAULT_GPU MAX_GPU
        else
            print_warning "Template not found at $template_file, using inline YAML"
            # Fallback to inline YAML if template not found
            # IMPORTANT: nodeSelector and tolerations must be inside scheduling.node
            cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: gpu-profile
  namespace: $namespace
  annotations:
    opendatahub.io/display-name: GPU Profile
    opendatahub.io/description: 'GPU hardware profile for NVIDIA GPU workloads'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
spec:
  identifiers:
    - defaultCount: '2'
      displayName: CPU
      identifier: cpu
      maxCount: '16'
      minCount: 1
      resourceType: CPU
    - defaultCount: 16Gi
      displayName: Memory
      identifier: memory
      maxCount: 64Gi
      minCount: 1Gi
      resourceType: Memory
    - defaultCount: 1
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: 8
      minCount: 1
      resourceType: Accelerator
  scheduling:
    type: Node
    node:
      nodeSelector:
        nvidia.com/gpu.present: 'true'
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
EOF
        fi
        print_success "GPU hardware profile created in $namespace"
    }
    
    # Create in redhat-ods-applications (for reference)
    create_profile_in_namespace "redhat-ods-applications"
    
    # Also create in current namespace if it's different and not a system namespace
    if [[ "$current_ns" != "redhat-ods-applications" ]] && \
       [[ "$current_ns" != "default" ]] && \
       [[ "$current_ns" != "openshift-"* ]]; then
        print_info "Also creating profile in current namespace: $current_ns"
        create_profile_in_namespace "$current_ns"
    fi
    
    print_success "GPU hardware profile setup complete"
    print_info "Note: Hardware profiles in RHOAI 3.0 are namespace-scoped for model deployment"
    print_info "Use './scripts/create-hardware-profile.sh <namespace>' to create in other namespaces"
}

# Configure Kueue ResourceFlavor for GPU nodes with taints
configure_gpu_resourceflavor() {
    print_header "Configuring Kueue ResourceFlavor for GPU Nodes"
    
    # Check if nvidia-gpu-flavor exists, create it if not
    if ! oc get resourceflavor nvidia-gpu-flavor &>/dev/null; then
        print_warning "ResourceFlavor 'nvidia-gpu-flavor' not found"
        
        # Check if Kueue is Unmanaged (won't auto-create resources)
        local kueue_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.kueue.managementState}' 2>/dev/null || echo "Unknown")
        
        if [[ "$kueue_state" == "Unmanaged" ]]; then
            print_info "Kueue is 'Unmanaged' - creating ResourceFlavor manually..."
            
            cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
EOF
            
            if oc get resourceflavor nvidia-gpu-flavor &>/dev/null; then
                print_success "ResourceFlavor created"
            else
                print_error "Failed to create ResourceFlavor"
                return 1
            fi
        else
            print_info "Kueue managementState: $kueue_state"
            print_info "This will be created automatically by RHOAI when Kueue is enabled"
            print_info "Skipping ResourceFlavor configuration for now"
            return 0
        fi
    else
        print_success "ResourceFlavor 'nvidia-gpu-flavor' already exists"
    fi
    
    print_step "Checking for GPU nodes..."
    
    # Check if GPU nodes exist
    local gpu_nodes=$(oc get nodes -l nvidia.com/gpu.present=true -o name 2>/dev/null)
    if [ -z "$gpu_nodes" ]; then
        print_warning "No GPU nodes found with label nvidia.com/gpu.present=true"
        echo ""
        echo -e "${YELLOW}GPU nodes will be detected when they are added.${NC}"
        echo -e "${YELLOW}Run this configuration again after adding GPU nodes.${NC}"
        echo ""
        
        # Configure with node selector only for now
        print_step "Configuring ResourceFlavor with node selector..."
        cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
EOF
        
        if [ $? -eq 0 ]; then
            print_success "ResourceFlavor configured (will auto-detect GPU nodes when added)"
        fi
        return 0
    fi
    
    # Show GPU nodes found
    local node_count=$(echo "$gpu_nodes" | wc -l | tr -d ' ')
    print_success "Found $node_count GPU node(s):"
    echo "$gpu_nodes" | sed 's/node\//  - /'
    echo ""
    
    # Check if GPU nodes have taints
    print_step "Checking GPU node taints..."
    local has_taint=$(oc get nodes -l nvidia.com/gpu.present=true -o json | jq -r '.items[].spec.taints[]? | select(.key=="nvidia.com/gpu") | .key' | head -1)
    
    if [ -n "$has_taint" ]; then
        print_info "✓ GPU nodes are tainted with nvidia.com/gpu:NoSchedule"
        echo ""
        echo -e "${CYAN}GPU nodes are tainted to prevent non-GPU workloads.${NC}"
        echo -e "${CYAN}ResourceFlavor needs toleration to schedule GPU workloads.${NC}"
        echo ""
        
        read -p "Configure ResourceFlavor with GPU toleration? (Y/n): " add_toleration
        add_toleration=${add_toleration:-Y}
        
        if [[ "$add_toleration" =~ ^[Yy]$ ]]; then
            print_step "Updating nvidia-gpu-flavor ResourceFlavor with toleration..."
            
            cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
EOF
            
            if [ $? -eq 0 ]; then
                print_success "ResourceFlavor configured with GPU toleration"
                echo ""
                print_info "✓ Node selector: nvidia.com/gpu.present=true"
                print_info "✓ Toleration: nvidia.com/gpu:NoSchedule"
            else
                print_error "Failed to configure ResourceFlavor"
                return 1
            fi
        else
            print_warning "Skipping toleration configuration"
            print_warning "GPU workloads may fail with 'untolerated taint' error"
        fi
    else
        print_info "✓ GPU nodes are NOT tainted"
        echo ""
        echo -e "${YELLOW}GPU nodes are not tainted.${NC}"
        echo -e "${YELLOW}This means any workload can be scheduled on GPU nodes.${NC}"
        echo ""
        echo -e "${CYAN}Recommendation: Taint GPU nodes to reserve them for GPU workloads only.${NC}"
        echo -e "${CYAN}Command: oc adm taint nodes -l nvidia.com/gpu.present=true nvidia.com/gpu=:NoSchedule${NC}"
        echo ""
        
        read -p "Do you want to taint GPU nodes now? (y/N): " taint_nodes
        taint_nodes=${taint_nodes:-N}
        
        if [[ "$taint_nodes" =~ ^[Yy]$ ]]; then
            print_step "Tainting GPU nodes..."
            oc adm taint nodes -l nvidia.com/gpu.present=true nvidia.com/gpu=:NoSchedule --overwrite
            
            if [ $? -eq 0 ]; then
                print_success "GPU nodes tainted successfully"
                echo ""
                print_step "Updating ResourceFlavor with toleration..."
                
                cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
EOF
                
                if [ $? -eq 0 ]; then
                    print_success "ResourceFlavor configured with GPU toleration"
                    echo ""
                    print_info "✓ Node selector: nvidia.com/gpu.present=true"
                    print_info "✓ Toleration: nvidia.com/gpu:NoSchedule"
                fi
            else
                print_error "Failed to taint GPU nodes"
                return 1
            fi
        else
            print_step "Configuring ResourceFlavor without toleration..."
            
            cat <<'EOF' | oc apply -f -
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu-flavor
  labels:
    platform.opendatahub.io/part-of: kueue
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
EOF
            
            if [ $? -eq 0 ]; then
                print_success "ResourceFlavor configured with node selector only"
                echo ""
                print_info "✓ Node selector: nvidia.com/gpu.present=true"
                print_info "✓ No tolerations (GPU nodes not tainted)"
            else
                print_error "Failed to configure ResourceFlavor"
                return 1
            fi
        fi
    fi
}

# Enable User Workload Monitoring
enable_user_workload_monitoring() {
    print_header "Enabling User Workload Monitoring"
    
    if oc get configmap user-workload-monitoring-config -n openshift-user-workload-monitoring &>/dev/null; then
        print_success "User workload monitoring already enabled"
        return 0
    fi
    
    print_step "Creating user workload monitoring ConfigMap..."
    
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-workload-monitoring-config
  namespace: openshift-user-workload-monitoring
data:
  config.yaml: |
    prometheus:
      retention: 24h
      resources:
        requests:
          cpu: 200m
          memory: 2Gi
EOF
    
    print_success "User workload monitoring enabled"
}

# Setup llm-d infrastructure (per CAI Guide Section 3)
setup_llmd_infrastructure() {
    print_header "Setting up llm-d Infrastructure (per CAI Guide)"
    
    # Step 1: Create GatewayClass
    print_step "Creating GatewayClass 'openshift-ai-inference'..."
    if oc get gatewayclass openshift-ai-inference &>/dev/null; then
        print_success "GatewayClass already exists"
    else
        cat <<'EOF' | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-ai-inference
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
        print_success "GatewayClass created"
    fi
    
    # Step 2: Create Gateway
    print_step "Creating Gateway 'openshift-ai-inference'..."
    if oc get gateway openshift-ai-inference -n openshift-ingress &>/dev/null; then
        print_success "Gateway already exists"
    else
        local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
        print_info "Cluster domain: $cluster_domain"
        
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
        print_success "Gateway created"
        print_info "Gateway hostname: inference-gateway.apps.$cluster_domain"
    fi
    
    # Step 3: Create LeaderWorkerSetOperator instance
    print_step "Creating LeaderWorkerSetOperator instance..."
    if oc get leaderworkersetoperator cluster -n openshift-lws-operator &>/dev/null; then
        print_success "LeaderWorkerSetOperator instance already exists"
    else
        cat <<'EOF' | oc apply -f -
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
                print_warning "Timeout waiting for LeaderWorkerSetOperator"
                break
            fi
            sleep 5
            elapsed=$((elapsed + 5))
        done
    fi
    
    print_success "llm-d infrastructure setup complete"
    echo ""
    print_info "You can now deploy models using llm-d serving runtime"
    print_info "Remember to check 'Require authentication' checkbox in the UI"
}

################################################################################
# Feature Store (Feast) Functions
################################################################################

# Check if Feast operator is enabled
check_feast_operator() {
    local feast_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.feastoperator.managementState}' 2>/dev/null || echo "Unknown")
    
    if [[ "$feast_state" == "Managed" ]]; then
        return 0
    else
        return 1
    fi
}

# Enable Feast operator in DSC
enable_feast_operator() {
    print_header "Enabling Feast Operator"
    
    if check_feast_operator; then
        print_success "Feast operator already enabled"
        return 0
    fi
    
    print_step "Patching DataScienceCluster to enable feastoperator..."
    oc patch datasciencecluster default-dsc --type='merge' \
        -p '{"spec":{"components":{"feastoperator":{"managementState":"Managed"}}}}'
    
    if [ $? -eq 0 ]; then
        print_success "Feast operator enabled"
        
        # Wait for Feast operator to be ready
        print_step "Waiting for Feast operator to be ready..."
        local timeout=120
        local elapsed=0
        until oc get crd featurestores.feast.dev &>/dev/null; do
            if [ $elapsed -ge $timeout ]; then
                print_warning "Timeout waiting for Feast CRD (continuing anyway)"
                break
            fi
            echo "Waiting for FeatureStore CRD... (${elapsed}s elapsed)"
            sleep 10
            elapsed=$((elapsed + 10))
        done
        
        print_success "Feast operator is ready"
    else
        print_error "Failed to enable Feast operator"
        return 1
    fi
}

# Setup Feature Store in a namespace
setup_feature_store() {
    local namespace="${1:-}"
    local git_url="${2:-}"
    local git_ref="${3:-rbac}"
    local feast_project="${4:-banking}"
    
    print_header "Setting up Feature Store (Feast)"
    
    # Check if Feast operator is enabled
    if ! check_feast_operator; then
        print_warning "Feast operator is not enabled"
        read -p "Enable Feast operator now? (Y/n): " enable_feast
        enable_feast=${enable_feast:-Y}
        
        if [[ "$enable_feast" =~ ^[Yy]$ ]]; then
            enable_feast_operator
        else
            print_error "Feast operator must be enabled first"
            return 1
        fi
    fi
    
    # Get namespace if not provided
    if [ -z "$namespace" ]; then
        local current_ns=$(oc project -q 2>/dev/null || echo "default")
        read -p "Enter namespace for Feature Store [$current_ns]: " namespace
        namespace=${namespace:-$current_ns}
    fi
    
    # Check if namespace exists
    if ! oc get namespace "$namespace" &>/dev/null; then
        print_step "Creating namespace $namespace..."
        oc new-project "$namespace" || oc create namespace "$namespace"
    fi
    
    # Label namespace for RHOAI dashboard
    oc label namespace "$namespace" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true
    
    # Get git URL if not provided
    if [ -z "$git_url" ]; then
        echo ""
        echo -e "${CYAN}Feature Store requires a Git repository with feature definitions.${NC}"
        echo ""
        echo -e "${YELLOW}Options:${NC}"
        echo "  1) Use banking demo (https://github.com/RHRolun/banking-feature-store)"
        echo "  2) Enter custom Git URL"
        echo ""
        read -p "Choose option [1]: " git_option
        git_option=${git_option:-1}
        
        if [[ "$git_option" == "1" ]]; then
            git_url="https://github.com/RHRolun/banking-feature-store"
            feast_project="banking"
            
            echo ""
            print_warning "For RBAC to work correctly, you should fork this repo and update permissions.py"
            echo -e "${CYAN}In feature_repo/permissions.py, change line 47 to: prod_namespaces = [\"$namespace\"]${NC}"
            echo ""
            read -p "Enter your forked repo URL (or press Enter to use original): " custom_url
            if [ -n "$custom_url" ]; then
                git_url="$custom_url"
            fi
        else
            read -p "Enter Git repository URL: " git_url
            read -p "Enter Feast project name [banking]: " feast_project
            feast_project=${feast_project:-banking}
        fi
    fi
    
    # Get git ref
    read -p "Enter Git branch/ref [$git_ref]: " input_ref
    git_ref=${input_ref:-$git_ref}
    
    # Check if FeatureStore already exists
    if oc get featurestore "$feast_project" -n "$namespace" &>/dev/null; then
        print_warning "FeatureStore '$feast_project' already exists in $namespace"
        read -p "Delete and recreate? (y/N): " recreate
        if [[ "$recreate" =~ ^[Yy]$ ]]; then
            oc delete featurestore "$feast_project" -n "$namespace"
            sleep 5
        else
            print_info "Keeping existing FeatureStore"
            return 0
        fi
    fi
    
    # Create FeatureStore
    print_step "Creating FeatureStore '$feast_project' in namespace '$namespace'..."
    
    cat <<EOF | oc apply -n "$namespace" -f -
apiVersion: feast.dev/v1alpha1
kind: FeatureStore
metadata:
  labels:
    feature-store-ui: enabled
  name: $feast_project
spec:
  feastProject: $feast_project
  feastProjectDir:
    git:
      ref: $git_ref
      url: '$git_url'
  services:
    offlineStore:
      server:
        logLevel: debug
    onlineStore:
      server:
        logLevel: debug
    registry:
      local:
        server:
          restAPI: true
EOF
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create FeatureStore"
        return 1
    fi
    
    # Wait for Feast pod to be ready
    print_step "Waiting for Feast pod to be ready..."
    local timeout=120
    local elapsed=0
    until oc get pods -n "$namespace" -l "app=feast-$feast_project" -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Timeout waiting for Feast pod"
            break
        fi
        echo "Waiting for Feast pod... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    # Get pod name
    local feast_pod=$(oc get pods -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep "feast-$feast_project" || oc get pods -n "$namespace" -o name 2>/dev/null | grep "feast-$feast_project" | head -1 | sed 's|pod/||')
    
    if [ -z "$feast_pod" ]; then
        feast_pod=$(oc get pods -n "$namespace" -o name 2>/dev/null | grep feast | head -1 | sed 's|pod/||')
    fi
    
    if [ -n "$feast_pod" ]; then
        print_success "Feast pod is running: $feast_pod"
        
        # Run feast apply
        echo ""
        read -p "Run 'feast apply' to register features? (Y/n): " run_apply
        run_apply=${run_apply:-Y}
        
        if [[ "$run_apply" =~ ^[Yy]$ ]]; then
            print_step "Running feast apply..."
            oc exec -n "$namespace" "$feast_pod" -c registry -- feast apply
            
            if [ $? -eq 0 ]; then
                print_success "Features registered successfully"
                
                # Run feast materialize
                read -p "Run 'feast materialize' to populate online store? (Y/n): " run_materialize
                run_materialize=${run_materialize:-Y}
                
                if [[ "$run_materialize" =~ ^[Yy]$ ]]; then
                    print_step "Running feast materialize..."
                    oc exec -n "$namespace" "$feast_pod" -c registry -- bash -c "feast materialize 2025-01-01T00:00:00 \$(date -u +'%Y-%m-%dT%H:%M:%S')"
                    
                    if [ $? -eq 0 ]; then
                        print_success "Features materialized successfully"
                    else
                        print_warning "Materialization had issues (features may still work)"
                    fi
                fi
            else
                print_warning "feast apply had issues"
            fi
        fi
    else
        print_warning "Could not find Feast pod"
        echo ""
        print_info "You can manually run these commands later:"
        echo "  oc exec -n $namespace <feast-pod> -c registry -- feast apply"
        echo "  oc exec -n $namespace <feast-pod> -c registry -- feast materialize 2025-01-01T00:00:00 \$(date -u +'%Y-%m-%dT%H:%M:%S')"
    fi
    
    # Show status
    echo ""
    print_header "Feature Store Setup Complete"
    echo ""
    oc get featurestore -n "$namespace"
    echo ""
    oc get svc -n "$namespace" | grep feast
    echo ""
    print_info "Access Feature Store in RHOAI Dashboard:"
    print_info "  Projects → $namespace → Feature store integration"
    echo ""
}

# Show Feature Store status
show_feast_status() {
    print_header "Feature Store Status"
    
    # Check if Feast operator is enabled
    local feast_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.feastoperator.managementState}' 2>/dev/null || echo "Unknown")
    echo ""
    echo -e "Feast Operator: ${CYAN}$feast_state${NC}"
    echo ""
    
    # List all FeatureStores
    echo -e "${YELLOW}FeatureStores across all namespaces:${NC}"
    oc get featurestore -A 2>/dev/null || echo "No FeatureStores found"
    echo ""
    
    # Show Feast pods
    echo -e "${YELLOW}Feast pods:${NC}"
    oc get pods -A -l app.kubernetes.io/managed-by=feast-operator 2>/dev/null || \
    oc get pods -A 2>/dev/null | grep -i feast || echo "No Feast pods found"
    echo ""
}

# Delete Feature Store
delete_feature_store() {
    local namespace="${1:-}"
    local feast_project="${2:-}"
    
    print_header "Delete Feature Store"
    
    # List existing FeatureStores
    echo ""
    echo -e "${YELLOW}Existing FeatureStores:${NC}"
    oc get featurestore -A 2>/dev/null || echo "No FeatureStores found"
    echo ""
    
    if [ -z "$namespace" ]; then
        read -p "Enter namespace: " namespace
    fi
    
    if [ -z "$feast_project" ]; then
        read -p "Enter FeatureStore name: " feast_project
    fi
    
    if oc get featurestore "$feast_project" -n "$namespace" &>/dev/null; then
        read -p "Delete FeatureStore '$feast_project' in namespace '$namespace'? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            oc delete featurestore "$feast_project" -n "$namespace"
            print_success "FeatureStore deleted"
        else
            print_info "Cancelled"
        fi
    else
        print_warning "FeatureStore '$feast_project' not found in namespace '$namespace'"
    fi
}


