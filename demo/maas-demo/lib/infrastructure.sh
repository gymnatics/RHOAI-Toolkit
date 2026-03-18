#!/bin/bash
################################################################################
# Infrastructure setup functions for MaaS Demo
################################################################################

# Ensure LeaderWorkerSet CRD is available
ensure_lws_crd() {
    local manifests_dir="$1"
    
    # Check if LWS CRD exists
    if oc get crd leaderworkersets.leaderworkerset.x-k8s.io &>/dev/null; then
        print_success "LeaderWorkerSet CRD already available"
        return 0
    fi
    
    # Check if LWS operator is installed
    if ! oc get crd leaderworkersetoperators.operator.openshift.io &>/dev/null; then
        print_warning "LWS operator not installed"
        echo "Install 'Red Hat build of Leader Worker Set' from OperatorHub"
        return 1
    fi
    
    # Create operator instance
    print_info "LWS operator installed, creating instance..."
    
    if ! oc get leaderworkersetoperator cluster &>/dev/null 2>&1; then
        oc apply -f "$manifests_dir/lws-operator.yaml"
        
        print_info "Waiting for LeaderWorkerSet CRD..."
        for i in {1..30}; do
            if oc get crd leaderworkersets.leaderworkerset.x-k8s.io &>/dev/null; then
                print_success "LeaderWorkerSet CRD is ready"
                return 0
            fi
            sleep 2
        done
        
        print_error "Timeout waiting for LWS CRD"
        return 1
    fi
    
    print_success "LeaderWorkerSetOperator instance exists"
    return 0
}

# Ensure gateway TLS certificate exists
ensure_gateway_tls() {
    local gateway_ns="openshift-ingress"
    local secret_name="default-gateway-tls"
    
    # Check if secret exists
    if oc get secret "$secret_name" -n "$gateway_ns" &>/dev/null; then
        print_success "Gateway TLS certificate exists"
        return 0
    fi
    
    # Check if gateway exists
    if ! oc get gateway openshift-ai-inference -n "$gateway_ns" &>/dev/null; then
        print_info "Gateway not found, skipping TLS setup"
        return 0
    fi
    
    print_info "Creating TLS certificate for inference gateway..."
    
    local cluster_domain
    cluster_domain=$(get_cluster_domain)
    local gateway_hostname="inference-gateway.${cluster_domain}"
    
    # Create temp directory
    local tmpdir
    tmpdir=$(mktemp -d)
    
    # Create OpenSSL config
    cat > "$tmpdir/openssl.cnf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext
x509_extensions = v3_ext

[dn]
CN = inference-gateway

[req_ext]
subjectAltName = @alt_names

[v3_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${gateway_hostname}
DNS.2 = *.${cluster_domain}
EOF
    
    # Generate certificate
    openssl req -x509 -newkey rsa:2048 \
        -keyout "$tmpdir/tls.key" \
        -out "$tmpdir/tls.crt" \
        -days 365 -nodes \
        -config "$tmpdir/openssl.cnf" 2>/dev/null
    
    # Create secret
    oc create secret tls "$secret_name" -n "$gateway_ns" \
        --cert="$tmpdir/tls.crt" \
        --key="$tmpdir/tls.key" 2>/dev/null
    
    # Cleanup
    rm -rf "$tmpdir"
    
    if oc get secret "$secret_name" -n "$gateway_ns" &>/dev/null; then
        print_success "TLS certificate created"
        
        # Restart gateway pod
        print_info "Restarting gateway pod..."
        local gateway_pod
        gateway_pod=$(oc get pods -n "$gateway_ns" -l app=openshift-ai-inference -o name 2>/dev/null | head -1)
        if [ -n "$gateway_pod" ]; then
            oc delete "$gateway_pod" -n "$gateway_ns" 2>/dev/null || true
            sleep 5
        fi
        return 0
    else
        print_warning "Failed to create TLS certificate"
        return 1
    fi
}

# Check MaaS gateway status
check_maas_gateway() {
    local gateway_ns="openshift-ingress"
    
    if oc get gateway openshift-ai-inference -n "$gateway_ns" &>/dev/null; then
        local programmed
        programmed=$(oc get gateway openshift-ai-inference -n "$gateway_ns" \
            -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
        
        if [ "$programmed" = "True" ]; then
            print_success "MaaS gateway is ready"
            return 0
        else
            print_warning "MaaS gateway exists but not programmed"
            return 1
        fi
    else
        print_warning "MaaS gateway not found"
        echo "Enable MaaS: modelsAsService.managementState: Managed in DataScienceCluster"
        return 1
    fi
}

# Check for GPU nodes
check_gpu_nodes() {
    local gpu_count
    gpu_count=$(oc get nodes -l nvidia.com/gpu.present=true --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$gpu_count" -eq 0 ]; then
        print_warning "No GPU nodes detected"
        return 1
    else
        print_success "Found $gpu_count GPU node(s)"
        return 0
    fi
}

# Check RHOAI installation
check_rhoai() {
    if ! oc get datasciencecluster default-dsc &>/dev/null; then
        print_error "RHOAI not installed"
        return 1
    fi
    print_success "RHOAI is installed"
    
    local version
    version=$(get_rhoai_version)
    if [ -n "$version" ]; then
        print_info "RHOAI version: $version"
    fi
    return 0
}

# Check LLMInferenceService CRD
check_llmisvc_crd() {
    if ! oc get crd llminferenceservices.serving.kserve.io &>/dev/null; then
        print_error "LLMInferenceService CRD not found"
        echo "llm-d requires RHOAI 3.2 or higher"
        return 1
    fi
    print_success "LLMInferenceService CRD available"
    return 0
}

# Apply AuthPolicy fix for tier-based rate limiting
# The odh-model-controller creates an AuthPolicy that overrides the tier lookup.
# This function patches it to include tier resolution.
apply_authpolicy_tier_fix() {
    local manifests_dir="$1"
    local gateway_ns="openshift-ingress"
    local policy_name="maas-default-gateway-authn"
    
    # Check if AuthPolicy exists
    if ! oc get authpolicy "$policy_name" -n "$gateway_ns" &>/dev/null; then
        print_info "AuthPolicy $policy_name not found - will be created after model deployment"
        return 0
    fi
    
    # Check if it already has tier lookup (metadata.matchedTier)
    local has_tier_lookup
    has_tier_lookup=$(oc get authpolicy "$policy_name" -n "$gateway_ns" \
        -o jsonpath='{.spec.rules.metadata.matchedTier}' 2>/dev/null)
    
    if [ -n "$has_tier_lookup" ]; then
        print_success "AuthPolicy already has tier lookup configured"
        return 0
    fi
    
    print_step "Applying AuthPolicy fix for tier-based rate limiting..."
    
    # Apply the patched AuthPolicy
    if [ -f "$manifests_dir/authpolicy-with-tier-lookup.yaml" ]; then
        oc apply -f "$manifests_dir/authpolicy-with-tier-lookup.yaml"
        
        # Verify it was applied
        sleep 2
        has_tier_lookup=$(oc get authpolicy "$policy_name" -n "$gateway_ns" \
            -o jsonpath='{.spec.rules.metadata.matchedTier}' 2>/dev/null)
        
        if [ -n "$has_tier_lookup" ]; then
            print_success "AuthPolicy patched with tier lookup"
            return 0
        else
            print_warning "AuthPolicy patch may not have applied correctly"
            return 1
        fi
    else
        print_warning "AuthPolicy manifest not found: $manifests_dir/authpolicy-with-tier-lookup.yaml"
        return 1
    fi
}

# Check if AuthPolicy needs tier fix
check_authpolicy_tier_fix_needed() {
    local gateway_ns="openshift-ingress"
    local policy_name="maas-default-gateway-authn"
    
    # Check if AuthPolicy exists
    if ! oc get authpolicy "$policy_name" -n "$gateway_ns" &>/dev/null; then
        return 1  # Not needed yet
    fi
    
    # Check if it has tier lookup
    local has_tier_lookup
    has_tier_lookup=$(oc get authpolicy "$policy_name" -n "$gateway_ns" \
        -o jsonpath='{.spec.rules.metadata.matchedTier}' 2>/dev/null)
    
    if [ -z "$has_tier_lookup" ]; then
        return 0  # Fix needed
    else
        return 1  # Already fixed
    fi
}
