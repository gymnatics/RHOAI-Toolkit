#!/bin/bash
################################################################################
# RHOAI installation and configuration functions
################################################################################

# Source required utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/lib/utils/colors.sh"
source "$SCRIPT_DIR/lib/utils/common.sh"

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
        3.0) echo "fast-3.x" ;;
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
    
    print_success "RHOAI initialized"
}

# Create DataScienceCluster (RHOAI 2.x)
create_datasciencecluster_v1() {
    print_header "Creating DataScienceCluster (v1)"
    
    if oc get datascienceclusters.datasciencecluster.opendatahub.io default-dsc &>/dev/null; then
        print_success "DataScienceCluster already exists"
        return 0
    fi
    
    print_step "Creating DataScienceCluster..."
    apply_manifest "$SCRIPT_DIR/lib/manifests/rhoai/datasciencecluster-v1.yaml" "DataScienceCluster v1"
    
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
    apply_manifest "$SCRIPT_DIR/lib/manifests/rhoai/datasciencecluster-v2.yaml" "DataScienceCluster v2"
    
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
    
    # Function to create hardware profile in a namespace
    create_profile_in_namespace() {
        local namespace=$1
        
        if oc get hardwareprofile gpu-profile -n "$namespace" &>/dev/null; then
            print_success "GPU hardware profile already exists in $namespace"
            return 0
        fi
        
        print_step "Creating GPU hardware profile in $namespace..."
        
        # Create hardware profile WITHOUT scheduling constraints
        # This makes it visible in the UI regardless of GPU node availability
        cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: gpu-profile
  namespace: $namespace
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: GPU Profile
    opendatahub.io/description: 'GPU hardware profile for NVIDIA GPU workloads'
    opendatahub.io/managed: 'false'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
    app.kubernetes.io/part-of: hardwareprofile
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
    kueue:
      localQueueName: default
      priorityClass: None
    type: Queue
EOF
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
    
    # Check if nvidia-gpu-flavor exists
    if ! oc get resourceflavor nvidia-gpu-flavor &>/dev/null; then
        print_warning "ResourceFlavor 'nvidia-gpu-flavor' not found"
        print_info "This will be created automatically by RHOAI when Kueue is enabled"
        print_info "Skipping ResourceFlavor configuration for now"
        return 0
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


