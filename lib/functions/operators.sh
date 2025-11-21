#!/bin/bash
################################################################################
# Operator installation functions
################################################################################

# Source required utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/lib/utils/colors.sh"
source "$SCRIPT_DIR/lib/utils/common.sh"

# Install NFD Operator
install_nfd_operator() {
    print_header "Installing Node Feature Discovery Operator"
    
    # Check if already installed
    if check_operator_installed "nfd" "openshift-nfd"; then
        print_success "NFD Operator already installed"
        return 0
    fi
    
    # Apply operator manifest
    apply_manifest "$SCRIPT_DIR/lib/manifests/operators/nfd-operator.yaml" "NFD Operator"
    
    # Wait for operator to be ready
    wait_for_operator_ready "nfd" "openshift-nfd"
    
    # Create NFD instance if not exists
    if ! oc get nodefeaturediscovery nfd-instance -n openshift-nfd &>/dev/null; then
        print_step "Creating NFD instance..."
        apply_manifest "$SCRIPT_DIR/lib/manifests/operators/nfd-instance.yaml" "NFD instance"
        print_success "NFD instance created"
    else
        print_success "NFD instance already exists"
    fi
    
    print_success "NFD operator installation complete"
}

# Install GPU Operator
install_gpu_operator() {
    print_header "Installing NVIDIA GPU Operator"
    
    # Check if already installed
    if check_operator_installed "gpu-operator-certified" "nvidia-gpu-operator"; then
        print_success "GPU Operator already installed"
    else
        # Apply operator manifest
        apply_manifest "$SCRIPT_DIR/lib/manifests/operators/gpu-operator.yaml" "GPU Operator"
        
        # Wait for operator to be ready
        print_step "Waiting for GPU operator to be ready..."
        sleep 10
        
        until oc get crd clusterpolicies.nvidia.com &>/dev/null; do
            echo "Waiting for GPU operator CRD to be available..."
            sleep 5
        done
    fi
    
    # Create ClusterPolicy if not exists
    if ! oc get clusterpolicy gpu-cluster-policy &>/dev/null; then
        print_step "Creating GPU ClusterPolicy..."
        apply_manifest "$SCRIPT_DIR/lib/manifests/operators/gpu-clusterpolicy.yaml" "GPU ClusterPolicy"
        print_success "GPU ClusterPolicy created"
    else
        print_success "GPU ClusterPolicy already exists"
    fi
    
    print_success "GPU operator installation complete"
}

# Install RHCL Operator
install_rhcl_operator() {
    print_header "Installing RHCL (Red Hat Connectivity Link) Operator"
    
    # Ensure namespace exists
    ensure_namespace "kuadrant-system"
    
    # Check if already installed
    if check_operator_installed "rhcl-operator" "kuadrant-system"; then
        print_success "RHCL Operator already installed"
        
        # Check if Kuadrant instance exists
        if oc get kuadrant kuadrant -n kuadrant-system &>/dev/null; then
            print_success "Kuadrant instance already exists"
            
            # Still need to wait for Authorino service
            wait_for_authorino_service
            configure_authorino_tls
            return 0
        fi
    else
        # Apply operator manifest
        apply_manifest "$SCRIPT_DIR/lib/manifests/rhcl/rhcl-operator.yaml" "RHCL Operator"
        
        # Wait for operator to be ready
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
    
    # Create Kuadrant instance if not exists
    if oc get kuadrant kuadrant -n kuadrant-system &>/dev/null; then
        print_success "Kuadrant instance already exists"
    else
        print_step "Creating Kuadrant instance..."
        apply_manifest "$SCRIPT_DIR/lib/manifests/rhcl/kuadrant-instance.yaml" "Kuadrant instance"
        print_success "Kuadrant instance created"
    fi
    
    # Wait for Authorino service
    wait_for_authorino_service
    
    # Configure Authorino with TLS
    configure_authorino_tls
    
    print_success "RHCL operator installation complete (enables llm-d serving runtime)"
}

# Install Leader Worker Set (LWS) Operator
install_lws_operator() {
    print_header "Installing Leader Worker Set (LWS) Operator"
    
    # Check if already installed
    if check_operator_installed "lws-operator" "openshift-operators"; then
        print_success "LWS Operator already installed"
        return 0
    fi
    
    print_step "Installing LWS Operator..."
    
    cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: lws-operator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: lws-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
    
    # Wait for operator to be ready
    wait_for_operator_ready "lws" "openshift-operators"
    
    print_success "LWS operator installation complete"
}

# Install Kueue Operator
install_kueue_operator() {
    print_header "Installing Kueue Operator"
    
    # Check if already installed
    if check_operator_installed "kueue-operator" "openshift-operators"; then
        print_success "Kueue Operator already installed"
        return 0
    fi
    
    print_step "Installing Kueue Operator..."
    
    cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kueue-operator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: kueue-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
    
    # Wait for operator to be ready
    wait_for_operator_ready "kueue" "openshift-operators"
    
    print_success "Kueue operator installation complete"
}

# Wait for Authorino service to be created
wait_for_authorino_service() {
    print_step "Waiting for Kuadrant components to be ready..."
    
    local auth_timeout=120
    local auth_elapsed=0
    until oc get svc/authorino-authorino-authorization -n kuadrant-system &>/dev/null; do
        if [ $auth_elapsed -ge $auth_timeout ]; then
            print_warning "Authorino service not ready yet (continuing anyway)"
            return 1
        fi
        echo "Waiting for Authorino service... (${auth_elapsed}s elapsed)"
        sleep 10
        auth_elapsed=$((auth_elapsed + 10))
    done
    
    print_success "Kuadrant is ready"
    return 0
}

# Configure Authorino with TLS
configure_authorino_tls() {
    if oc get svc/authorino-authorino-authorization -n kuadrant-system &>/dev/null; then
        print_step "Configuring Authorino with TLS..."
        
        # Annotate service for TLS certificate
        oc annotate svc/authorino-authorino-authorization \
            service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
            -n kuadrant-system --overwrite
        
        sleep 10
        
        # Enable TLS in Authorino
        apply_manifest "$SCRIPT_DIR/lib/manifests/rhcl/authorino-tls.yaml" "Authorino TLS configuration"
        
        print_success "Authorino configured with TLS"
    fi
}

