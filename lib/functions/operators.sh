#!/bin/bash
################################################################################
# Operator installation functions
################################################################################

# Source required utilities
# Use a local variable to avoid overwriting caller's SCRIPT_DIR
_OPERATORS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_OPERATORS_LIB_DIR/lib/utils/colors.sh"
source "$_OPERATORS_LIB_DIR/lib/utils/common.sh"

# Install NFD Operator
install_nfd_operator() {
    print_header "Installing Node Feature Discovery Operator"
    
    # Check if already installed
    if check_operator_installed "nfd" "openshift-nfd"; then
        print_success "NFD Operator already installed"
        return 0
    fi
    
    # Apply operator manifest
    apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/operators/nfd-operator.yaml" "NFD Operator"
    
    # Wait for operator to be ready
    wait_for_operator_ready "nfd" "openshift-nfd"
    
    # Create NFD instance if not exists
    if ! oc get nodefeaturediscovery nfd-instance -n openshift-nfd &>/dev/null; then
        print_step "Creating NFD instance..."
        apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/operators/nfd-instance.yaml" "NFD instance"
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
        apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/operators/gpu-operator.yaml" "GPU Operator"
        
        # Wait for operator to be ready
        print_step "Waiting for GPU operator to be ready..."
        sleep 10
        
        until oc get crd clusterpolicies.nvidia.com &>/dev/null; do
            echo "Waiting for GPU operator CRD to be available..."
            sleep 5
        done
    fi
    
    # Check if GPU nodes exist before creating ClusterPolicy
    local gpu_nodes=$(oc get nodes -l feature.node.kubernetes.io/pci-10de.present=true --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    if ! oc get clusterpolicy gpu-cluster-policy &>/dev/null; then
        if [ "$gpu_nodes" -gt 0 ]; then
            print_step "GPU nodes detected, creating GPU ClusterPolicy..."
            apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/operators/gpu-clusterpolicy.yaml" "GPU ClusterPolicy"
            print_success "GPU ClusterPolicy created"
        else
            print_warning "No GPU nodes detected yet"
            print_info "GPU ClusterPolicy will be created when GPU nodes are added"
            print_info "To create it manually later, run:"
            echo "  oc apply -f $_OPERATORS_LIB_DIR/lib/manifests/operators/gpu-clusterpolicy.yaml"
            echo ""
            print_info "Or the ClusterPolicy will be auto-created when you run:"
            echo "  ./scripts/create-gpu-machineset.sh"
        fi
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
        apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/rhcl/rhcl-operator.yaml" "RHCL Operator"
        
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
        apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/rhcl/kuadrant-instance.yaml" "Kuadrant instance"
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
    
    # LWS requires its own namespace (doesn't support AllNamespaces mode)
    local lws_namespace="openshift-lws-operator"
    
    # Check if already installed
    if oc get csv -n "$lws_namespace" 2>/dev/null | grep -q leader-worker-set; then
        print_success "LWS Operator already installed"
        return 0
    fi
    
    print_step "Creating LWS namespace..."
    apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/operators/lws-namespace.yaml" "LWS namespace"
    
    # Clean up any duplicate OperatorGroups (prevents "Multiple OperatorGroup" error)
    print_step "Ensuring clean OperatorGroup configuration..."
    local existing_ogs=$(oc get operatorgroup -n "$lws_namespace" -o name 2>/dev/null | wc -l)
    if [ "$existing_ogs" -gt 1 ]; then
        print_step "Removing duplicate OperatorGroups..."
        oc delete operatorgroup --all -n "$lws_namespace"
        sleep 2
    fi
    
    # Create OperatorGroup (name matches namespace to avoid conflicts)
    print_step "Creating OperatorGroup..."
    apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/operators/lws-operatorgroup.yaml" "LWS OperatorGroup"
    
    print_step "Installing LWS Operator subscription..."
    apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/operators/lws-subscription.yaml" "LWS Subscription"
    
    # Wait for operator to be ready
    print_step "Waiting for LWS operator to be ready..."
    local timeout=180
    local elapsed=0
    until oc get csv -n "$lws_namespace" 2>/dev/null | grep -q "leader-worker-set.*Succeeded"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "LWS operator not ready yet (continuing anyway)"
            return 1
        fi
        echo "Waiting for LWS operator... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_success "LWS operator installation complete"
}

# Install cert-manager Operator (required by Kueue)
install_certmanager_operator() {
    print_header "Installing cert-manager Operator"
    
    local cm_namespace="cert-manager-operator"
    
    # Check if already installed
    if check_operator_installed "cert-manager-operator" "$cm_namespace"; then
        print_success "cert-manager Operator already installed"
        return 0
    fi
    
    print_step "Creating cert-manager-operator namespace..."
    apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/operators/certmanager-namespace.yaml" "cert-manager namespace"
    
    # Check for existing OperatorGroup
    local existing_ogs=$(oc get operatorgroup -n "$cm_namespace" -o name 2>/dev/null | wc -l)
    if [ "$existing_ogs" -eq 0 ]; then
        print_step "Creating OperatorGroup..."
        apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/operators/certmanager-operatorgroup.yaml" "cert-manager OperatorGroup"
    fi
    
    print_step "Installing cert-manager Operator subscription..."
    apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/operators/certmanager-subscription.yaml" "cert-manager Subscription"
    
    # Wait for operator to be ready
    print_step "Waiting for cert-manager operator to be ready..."
    local timeout=180
    local elapsed=0
    until oc get csv -n "$cm_namespace" 2>/dev/null | grep -q "cert-manager-operator.*Succeeded"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "cert-manager operator not ready yet (continuing anyway)"
            return 1
        fi
        echo "Waiting for cert-manager operator... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_success "cert-manager operator installation complete"
}

# Install Kueue Operator
install_kueue_operator() {
    print_header "Installing Kueue Operator"
    
    # Check if already installed
    if check_operator_installed "kueue-operator" "openshift-operators"; then
        print_success "Kueue Operator already installed"
        return 0
    fi
    
    # Ensure cert-manager is installed first (required dependency)
    print_step "Checking cert-manager dependency..."
    if ! check_operator_installed "cert-manager-operator" "cert-manager-operator"; then
        print_step "cert-manager not found, installing..."
        install_certmanager_operator
    else
        print_success "cert-manager already installed"
    fi
    
    # Clean up any duplicate Kueue subscriptions
    print_step "Checking for duplicate Kueue subscriptions..."
    if oc get subscription kueue-operator -n openshift-kueue-system &>/dev/null; then
        print_step "Removing duplicate Kueue subscription in openshift-kueue-system..."
        oc delete subscription kueue-operator -n openshift-kueue-system 2>/dev/null || true
        oc delete csv -n openshift-kueue-system -l operators.coreos.com/kueue-operator.openshift-kueue-system 2>/dev/null || true
    fi
    
    print_step "Installing Kueue Operator..."
    apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/operators/kueue-subscription.yaml" "Kueue Subscription"
    
    # Wait for operator to be ready
    print_step "Waiting for Kueue operator to be ready..."
    local timeout=180
    local elapsed=0
    until oc get csv -n openshift-operators 2>/dev/null | grep -q "kueue-operator.*Succeeded"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Kueue operator not ready yet (continuing anyway)"
            return 1
        fi
        echo "Waiting for Kueue operator... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    print_success "Kueue operator installation complete"
}

# Wait for Authorino service to be created
wait_for_authorino_service() {
    print_step "Waiting for Kuadrant components to be ready..."
    
    local auth_timeout=120
    local auth_elapsed=0
    local restart_attempted=false
    
    until oc get svc/authorino-authorino-authorization -n kuadrant-system &>/dev/null; do
        if [ $auth_elapsed -ge $auth_timeout ]; then
            # On fresh clusters, CRD registration may not be complete
            # Restart Kuadrant operator to trigger reconciliation
            if [ "$restart_attempted" = false ]; then
                print_warning "Authorino service not ready yet"
                print_step "Applying fix for fresh cluster CRD registration issue..."
                print_step "Restarting Kuadrant operator to trigger reconciliation..."
                
                # Find and restart the kuadrant operator pod
                local operator_pod=$(oc get pods -n kuadrant-system -l control-plane=controller-manager -o name 2>/dev/null | grep kuadrant-operator | head -n 1)
                if [ -n "$operator_pod" ]; then
                    oc delete "$operator_pod" -n kuadrant-system &>/dev/null
                    print_step "Kuadrant operator restarted, waiting for reconciliation..."
                    sleep 30
                    restart_attempted=true
                    auth_timeout=180  # Extend timeout after restart
                    auth_elapsed=0     # Reset counter
                else
                    print_warning "Could not find Kuadrant operator pod (continuing anyway)"
                    return 1
                fi
            else
                print_warning "Authorino service still not ready after restart (continuing anyway)"
                return 1
            fi
        else
            echo "Waiting for Authorino service... (${auth_elapsed}s elapsed)"
            sleep 10
            auth_elapsed=$((auth_elapsed + 10))
        fi
    done
    
    print_success "Kuadrant is ready"
    return 0
}

# Configure Authorino with TLS
configure_authorino_tls() {
    print_step "Configuring Authorino with TLS..."
    
    # Create the TLS certificate BEFORE applying Authorino CR to avoid deadlock:
    # Authorino needs the cert to start, but the service annotation approach needs
    # Authorino's service to exist first (which requires Authorino to be running).
    if ! oc get secret authorino-server-cert -n kuadrant-system &>/dev/null; then
        print_step "Creating Authorino TLS certificate via cert-manager..."
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
        
        # Wait for cert-manager to issue the certificate
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
    
    # Apply the Authorino CR with TLS enabled
    apply_manifest "$_OPERATORS_LIB_DIR/lib/manifests/rhcl/authorino-tls.yaml" "Authorino TLS configuration"
    
    # Annotate the service if it exists (for cert rotation via OpenShift serving-cert)
    if oc get svc/authorino-authorino-authorization -n kuadrant-system &>/dev/null; then
        oc annotate svc/authorino-authorino-authorization \
            service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
            -n kuadrant-system --overwrite 2>/dev/null || true
    fi
    
    print_success "Authorino configured with TLS"
}

