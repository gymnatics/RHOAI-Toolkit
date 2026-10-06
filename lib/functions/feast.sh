#!/bin/bash
################################################################################
# feast.sh — Feature Store (Feast) functions
# Extracted from lib/functions/rhoai.sh during the Oct 2026 modularization
# (Priority 3 of the consolidated toolkit plan).
################################################################################

# Use a local variable to avoid overwriting caller's SCRIPT_DIR
_FEAST_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_FEAST_LIB_DIR/lib/utils/colors.sh" 2>/dev/null || true
source "$_FEAST_LIB_DIR/lib/utils/common.sh" 2>/dev/null || true

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

# Deploy Banking Demo - Version-Aware
# Source: https://github.com/RHRolun/banking-feature-store
deploy_banking_demo() {
    local namespace="${1:-}"
    
    print_header "Deploy Banking Demo"
    
    # Detect RHOAI version
    local rhoai_33_plus=false
    if type detect_rhoai_version &>/dev/null; then
        detect_rhoai_version
        echo ""
        if is_rhoai_33_or_higher 2>/dev/null; then
            rhoai_33_plus=true
            echo -e "${GREEN}RHOAI 3.3+ detected${NC} - will apply enhanced dashboard visibility settings"
        else
            echo -e "${CYAN}RHOAI ${RHOAI_VERSION:-<3.3} detected${NC}"
        fi
    else
        # Fallback version detection
        local csv_version=$(oc get csv -n redhat-ods-operator -o jsonpath='{.items[?(@.spec.displayName=="Red Hat OpenShift AI")].spec.version}' 2>/dev/null | head -1)
        if [ -n "$csv_version" ]; then
            echo -e "${CYAN}RHOAI version: $csv_version${NC}"
            local major=$(echo "$csv_version" | cut -d. -f1)
            local minor=$(echo "$csv_version" | cut -d. -f2)
            if [ "$major" -gt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -ge 3 ]); then
                rhoai_33_plus=true
                echo -e "${GREEN}RHOAI 3.3+ detected${NC} - will apply enhanced dashboard visibility settings"
            fi
        fi
    fi
    echo ""
    
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
    else
        print_success "Feast operator is enabled"
    fi
    
    # Get namespace
    if [ -z "$namespace" ]; then
        local current_ns=$(oc project -q 2>/dev/null || echo "banking")
        read -p "Enter namespace for banking demo [$current_ns]: " namespace
        namespace=${namespace:-$current_ns}
    fi
    
    # Check if namespace exists
    if ! oc get namespace "$namespace" &>/dev/null; then
        print_step "Creating namespace $namespace..."
        oc new-project "$namespace" 2>/dev/null || oc create namespace "$namespace"
    fi
    
    # Label namespace for RHOAI dashboard
    print_step "Labeling namespace for RHOAI dashboard..."
    oc label namespace "$namespace" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true
    
    # Banking demo configuration
    local git_url="https://github.com/RHRolun/banking-feature-store"
    local git_ref="rbac"
    local feast_project="banking"
    
    echo ""
    echo -e "${CYAN}Banking Demo Repository:${NC} $git_url"
    echo -e "${CYAN}Branch:${NC} $git_ref"
    echo ""
    
    # RBAC note: the upstream repo's feature_repo/permissions.py hardcodes
    # prod_namespaces = ["banking"] (the Feast *project* name), but Feast's
    # NamespaceBasedPolicy actually checks it against the OpenShift *namespace*
    # you deploy into. Unless that namespace happens to be literally "banking",
    # every DESCRIBE/list call gets denied ("User is not added into the permitted
    # namespaces"), and the FeatureStore silently disappears from the dashboard
    # even though every pod is healthy. We auto-patch this after the pod comes up
    # (see patch_feast_permissions_namespace below) so no manual fork is required.
    print_info "permissions.py will be auto-patched after deploy so RBAC matches namespace '$namespace' (no fork needed)"
    echo ""
    read -p "Enter a custom fork repo URL (or press Enter to use original): " custom_url
    if [ -n "$custom_url" ]; then
        git_url="$custom_url"
    fi
    
    # Check if FeatureStore already exists
    if oc get featurestore "$feast_project" -n "$namespace" &>/dev/null; then
        print_warning "FeatureStore 'banking' already exists in $namespace"
        read -p "Delete and recreate? (y/N): " recreate
        if [[ "$recreate" =~ ^[Yy]$ ]]; then
            print_step "Deleting existing FeatureStore..."
            oc delete featurestore "$feast_project" -n "$namespace"
            sleep 5
        else
            print_info "Keeping existing FeatureStore"
            return 0
        fi
    fi
    
    # Create FeatureStore with version-appropriate configuration
    print_step "Creating FeatureStore 'banking' in namespace '$namespace'..."
    
    # Two-step approach (from CAI guide): create with restAPI: false first,
    # wait for pod, then flip to true. Avoids race condition during startup.
    export FEAST_LABELS="    feature-store-ui: enabled"
    if [ "$rhoai_33_plus" = true ]; then
        export FEAST_LABELS="    feature-store-ui: enabled
    opendatahub.io/dashboard: \"true\""
    fi
    export FEAST_PROJECT="$feast_project"
    export GIT_REF="$git_ref"
    export GIT_URL="$git_url"
    envsubst '${FEAST_LABELS} ${FEAST_PROJECT} ${GIT_REF} ${GIT_URL}' \
        < "$_FEAST_LIB_DIR/lib/manifests/feast/featurestore-restapi-false.yaml" | oc apply -n "$namespace" -f -
    unset FEAST_LABELS FEAST_PROJECT GIT_REF GIT_URL
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create FeatureStore"
        return 1
    fi
    
    print_success "FeatureStore CR created"
    
    # Wait for Feast pod to be ready
    print_step "Waiting for Feast pod to be ready..."
    local timeout=180
    local elapsed=0
    local feast_pod=""
    
    while [ $elapsed -lt $timeout ]; do
        feast_pod=$(oc get pods -n "$namespace" -o name 2>/dev/null | grep "feast-$feast_project" | head -1 | sed 's|pod/||')
        if [ -n "$feast_pod" ]; then
            local pod_status=$(oc get pod "$feast_pod" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
            if [ "$pod_status" = "Running" ]; then
                # Check if containers are ready
                local ready=$(oc get pod "$feast_pod" -n "$namespace" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
                if [ "$ready" = "true" ]; then
                    break
                fi
            fi
        fi
        echo "Waiting for Feast pod... (${elapsed}s elapsed)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    if [ -z "$feast_pod" ]; then
        print_warning "Timeout waiting for Feast pod"
        echo ""
        print_info "You can manually run these commands later:"
        echo "  oc exec -n $namespace \$(oc get pods -n $namespace -o name | grep feast) -c registry -- feast apply"
        return 1
    fi
    
    print_success "Feast pod is running: $feast_pod"

    # Step 2: Now enable restAPI (two-step pattern from CAI guide)
    print_step "Enabling registry REST API (step 2 of 2)..."
    oc patch featurestore "$feast_project" -n "$namespace" --type=merge \
        -p '{"spec":{"services":{"registry":{"local":{"server":{"restAPI":true}}}}}}'
    print_success "Registry REST API enabled"
    sleep 10
    
    # Auto-patch permissions.py so NamespaceBasedPolicy matches the actual
    # OpenShift namespace instead of the upstream repo's hardcoded "banking"
    # project name. Must happen before feast apply so the fix is registered.
    # (See check_featurestore_rbac_namespace/fix_featurestore_rbac_namespace
    # in lib/utils/rhoai-version.sh - also used by the diagnose flow.)
    if type check_featurestore_rbac_namespace &>/dev/null; then
        if ! check_featurestore_rbac_namespace "$namespace" "$feast_project"; then
            fix_featurestore_rbac_namespace "$namespace" "$feast_project"
        else
            print_success "RBAC permissions.py namespace matches (or not in use)"
        fi
    fi
    
    # Run feast apply
    echo ""
    read -p "Run 'feast apply' to register features? (Y/n): " run_apply
    run_apply=${run_apply:-Y}
    
    if [[ "$run_apply" =~ ^[Yy]$ ]]; then
        print_step "Running feast apply (this may take a minute)..."
        if oc exec -n "$namespace" "$feast_pod" -c registry -- feast apply; then
            print_success "Features registered successfully"
            
            # Run feast materialize
            echo ""
            read -p "Run 'feast materialize' to populate online store? (Y/n): " run_materialize
            run_materialize=${run_materialize:-Y}
            
            if [[ "$run_materialize" =~ ^[Yy]$ ]]; then
                print_step "Running feast materialize..."
                if oc exec -n "$namespace" "$feast_pod" -c registry -- bash -c "feast materialize 2025-01-01T00:00:00 \$(date -u +'%Y-%m-%dT%H:%M:%S')"; then
                    print_success "Features materialized successfully"
                else
                    print_warning "Materialization had issues (features may still work)"
                fi
            fi
        else
            print_warning "feast apply had issues - you may need to run it manually"
        fi
    fi
    
    # Verify services
    echo ""
    print_step "Verifying Feature Store services..."
    sleep 5
    
    local registry_svc=$(oc get svc -n "$namespace" -o name 2>/dev/null | grep "feast-$feast_project-registry$" | head -1)
    local rest_svc=$(oc get svc -n "$namespace" -o name 2>/dev/null | grep "feast-$feast_project-registry-rest" | head -1)
    
    if [ -n "$registry_svc" ]; then
        print_success "Registry service exists"
    else
        print_warning "Registry service not found"
    fi
    
    if [ -n "$rest_svc" ]; then
        print_success "Registry REST service exists (required for dashboard)"
    else
        print_warning "Registry REST service not found yet - may take a few minutes"
    fi
    
    # Show final status
    echo ""
    print_header "Banking Demo Deployment Complete"
    echo ""
    oc get featurestore -n "$namespace"
    echo ""
    echo -e "${YELLOW}Services:${NC}"
    oc get svc -n "$namespace" 2>/dev/null | grep feast || echo "  (waiting for services...)"
    echo ""
    
    # Version-specific instructions
    if [ "$rhoai_33_plus" = true ]; then
        echo -e "${CYAN}RHOAI 3.3+ Dashboard Access:${NC}"
        echo "  1. Wait 2-5 minutes for dashboard to discover the Feature Store"
        echo "  2. Go to: Projects → $namespace → Feature Store Integration"
        echo "  3. Select 'feast-banking-client' from the dropdown"
        echo ""
        echo "If Feature Store doesn't appear after 5 minutes:"
        echo "  Run: ./rhoai-toolkit.sh → Feature Store → Diagnose Feature Store"
    else
        echo -e "${CYAN}Dashboard Access:${NC}"
        echo "  Go to: Projects → $namespace → Feature Store Integration"
        echo "  Select 'feast-banking-client' from the dropdown"
    fi
    echo ""
    
    # Create workbench + clone repo
    local _wb_lib="$_FEAST_LIB_DIR/lib/functions/workbench.sh"
    if [ -f "$_wb_lib" ]; then
        source "$_wb_lib"
        ensure_workbench "$namespace" "feature-store"
    fi

    # Retry the repo clone in case the workbench wasn't Running yet when
    # ensure_workbench's wait ran above -- cheap no-op otherwise.
    if type clone_if_missing &>/dev/null; then
        clone_if_missing "$namespace" "feature-store"
    fi

    # Inject notebook environment
    local _nb_env_lib="$_FEAST_LIB_DIR/lib/functions/notebook-env.sh"
    if [ -f "$_nb_env_lib" ]; then
        source "$_nb_env_lib"
        inject_notebook_env "$namespace" \
            "FEAST_PROJECT=$feast_project" \
            "FEAST_NAME=$feast_project"
    fi

    # Demo usage instructions
    echo -e "${CYAN}Demo Usage:${NC}"
    echo "  1. Open the 'feature-store' workbench in the RHOAI dashboard"
    echo "  2. Copy Feature Store client config from dashboard"
    echo "  3. Open RHOAI-Toolkit/demo/feast-demo/notebooks/"
    echo "     feast-online-retrieval.ipynb  -- query features in real time"
    echo "     feast-banking-complex.ipynb   -- advanced feature engineering"
    echo ""
    echo "  Original repo: $git_url"
    echo ""
}

# Setup Feature Store in a namespace (generic/custom)
setup_feature_store() {
    local namespace="${1:-}"
    local git_url="${2:-}"
    local git_ref="${3:-rbac}"
    local feast_project="${4:-banking}"
    
    print_header "Setting up Feature Store (Feast)"
    
    # Detect RHOAI version for version-specific configuration
    if type detect_rhoai_version &>/dev/null; then
        detect_rhoai_version
        echo ""
        if is_rhoai_33_or_higher 2>/dev/null; then
            print_info "RHOAI 3.3+ detected - will apply enhanced dashboard visibility settings"
        else
            print_info "RHOAI ${RHOAI_VERSION:-<3.3} detected"
        fi
    fi
    
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
    
    # Label namespace for RHOAI dashboard (required for all versions, critical for 3.3+)
    print_step "Labeling namespace for RHOAI dashboard..."
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
    
    # Create FeatureStore with version-appropriate configuration
    print_step "Creating FeatureStore '$feast_project' in namespace '$namespace'..."
    
    # Determine labels based on RHOAI version
    export EXTRA_LABELS=""
    if type is_rhoai_33_or_higher &>/dev/null && is_rhoai_33_or_higher; then
        # RHOAI 3.3+ requires additional labels for dashboard visibility
        export EXTRA_LABELS='    opendatahub.io/dashboard: "true"'
        print_info "Adding RHOAI 3.3+ specific labels for dashboard visibility"
    fi
    export FEAST_PROJECT="$feast_project"
    export GIT_REF="$git_ref"
    export GIT_URL="$git_url"
    envsubst '${EXTRA_LABELS} ${FEAST_PROJECT} ${GIT_REF} ${GIT_URL}' \
        < "$_FEAST_LIB_DIR/lib/manifests/feast/featurestore-restapi-true.yaml" | oc apply -n "$namespace" -f -
    unset EXTRA_LABELS FEAST_PROJECT GIT_REF GIT_URL
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create FeatureStore"
        return 1
    fi
    
    print_success "FeatureStore CR created"
    
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
    
    # Verify services exist (important for 3.3+)
    echo ""
    print_step "Verifying Feature Store services..."
    local registry_rest_svc=$(oc get svc -n "$namespace" -o name 2>/dev/null | grep "feast-$feast_project-registry-rest" | head -1)
    if [ -n "$registry_rest_svc" ]; then
        print_success "Registry REST service exists (required for dashboard)"
    else
        print_warning "Registry REST service not found yet - may take a few minutes"
        if type is_rhoai_33_or_higher &>/dev/null && is_rhoai_33_or_higher; then
            echo "  This service is required for RHOAI 3.3+ dashboard visibility"
        fi
    fi
    
    # Show status
    echo ""
    print_header "Feature Store Setup Complete"
    echo ""
    oc get featurestore -n "$namespace"
    echo ""
    echo -e "${YELLOW}Services:${NC}"
    oc get svc -n "$namespace" 2>/dev/null | grep feast || echo "  (waiting for services...)"
    echo ""
    
    # Version-specific instructions
    if type is_rhoai_33_or_higher &>/dev/null && is_rhoai_33_or_higher; then
        print_info "RHOAI 3.3+ Dashboard Access:"
        print_info "  1. Wait 2-5 minutes for dashboard to discover the Feature Store"
        print_info "  2. Go to: Projects → $namespace → Feature Store Integration"
        print_info "  3. Select 'feast-$feast_project-client' from the dropdown"
        echo ""
        print_info "If Feature Store doesn't appear, run:"
        echo "  ./rhoai-toolkit.sh → Feature Store → Diagnose Feature Store"
    else
        print_info "Access Feature Store in RHOAI Dashboard:"
        print_info "  Projects → $namespace → Feature store integration"
    fi
    echo ""
}

# Show Feature Store status
show_feast_status() {
    print_header "Feature Store Status"
    
    # Detect RHOAI version if function is available
    if type detect_rhoai_version &>/dev/null; then
        detect_rhoai_version
        echo ""
        echo -e "RHOAI Version: ${CYAN}$RHOAI_VERSION${NC}"
    fi
    
    # Check if Feast operator is enabled
    local feast_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.feastoperator.managementState}' 2>/dev/null || echo "Unknown")
    echo ""
    echo -e "Feast Operator: ${CYAN}$feast_state${NC}"
    echo ""
    
    # List all FeatureStores with additional info
    echo -e "${YELLOW}FeatureStores across all namespaces:${NC}"
    local featurestores=$(oc get featurestore -A -o json 2>/dev/null)
    
    if [ -n "$featurestores" ] && echo "$featurestores" | jq -e '.items | length > 0' &>/dev/null; then
        echo "$featurestores" | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name) - Labels: \(.metadata.labels // "none")"'
        echo ""
        
        # Check for potential issues
        echo -e "${YELLOW}Checking for potential issues:${NC}"
        echo "$featurestores" | jq -r '.items[] | select(.metadata.labels["feature-store-ui"] != "enabled") | "  ⚠ \(.metadata.namespace)/\(.metadata.name): Missing feature-store-ui label"' 2>/dev/null
        echo "$featurestores" | jq -r '.items[] | select(.spec.services.registry.local.server.restAPI != true) | "  ⚠ \(.metadata.namespace)/\(.metadata.name): restAPI not enabled"' 2>/dev/null
        echo "$featurestores" | jq -r '.items[] | select(.spec.authz.noAuth != true) | "  ⚠ \(.metadata.namespace)/\(.metadata.name): authz.noAuth not set (dashboard cannot query Feast registry)"' 2>/dev/null
        
        local issues_found=$(echo "$featurestores" | jq '[.items[] | select(.metadata.labels["feature-store-ui"] != "enabled" or .spec.services.registry.local.server.restAPI != true or .spec.authz.noAuth != true)] | length')
        if [ "$issues_found" = "0" ]; then
            echo -e "  ${GREEN}✓ No configuration issues detected${NC}"
        else
            echo ""
            echo -e "${CYAN}Run 'Diagnose Feature Store' for detailed analysis and fixes${NC}"
        fi
    else
        echo "No FeatureStores found"
    fi
    echo ""
    
    # Show Feast pods
    echo -e "${YELLOW}Feast pods:${NC}"
    oc get pods -A -l app.kubernetes.io/managed-by=feast-operator 2>/dev/null || \
    oc get pods -A 2>/dev/null | grep -i feast || echo "No Feast pods found"
    echo ""
}

# Diagnose Feature Store visibility issues (version-aware)
diagnose_feature_store_interactive() {
    print_header "Diagnose Feature Store"
    
    # Detect RHOAI version
    if type detect_rhoai_version &>/dev/null; then
        detect_rhoai_version
        echo ""
        echo -e "RHOAI Version: ${CYAN}$RHOAI_VERSION${NC}"
        
        if is_rhoai_33_or_higher; then
            echo -e "${YELLOW}Note: RHOAI 3.3+ has stricter requirements for Feature Store dashboard visibility${NC}"
            echo ""
        fi
    fi
    
    # List existing FeatureStores
    echo ""
    echo -e "${YELLOW}Existing FeatureStores:${NC}"
    oc get featurestore -A 2>/dev/null || echo "No FeatureStores found"
    echo ""
    
    read -p "Enter namespace: " namespace
    read -p "Enter FeatureStore name: " name
    
    if [ -z "$namespace" ] || [ -z "$name" ]; then
        print_error "Namespace and name are required"
        return 1
    fi
    
    # Use the diagnose function from rhoai-version.sh if available
    if type diagnose_featurestore &>/dev/null; then
        diagnose_featurestore "$namespace" "$name"
    else
        # Fallback to basic checks
        echo ""
        echo -e "${CYAN}Checking FeatureStore '$name' in namespace '$namespace'...${NC}"
        echo ""
        
        if ! oc get featurestore "$name" -n "$namespace" &>/dev/null; then
            print_error "FeatureStore '$name' not found in namespace '$namespace'"
            return 1
        fi
        
        # Check labels
        local labels=$(oc get featurestore "$name" -n "$namespace" -o jsonpath='{.metadata.labels}' 2>/dev/null)
        if echo "$labels" | grep -q "feature-store-ui"; then
            echo -e "${GREEN}✓ feature-store-ui label present${NC}"
        else
            echo -e "${RED}✗ feature-store-ui label missing${NC}"
            echo "  Fix: oc label featurestore $name -n $namespace feature-store-ui=enabled"
        fi
        
        # Check restAPI
        local rest_api=$(oc get featurestore "$name" -n "$namespace" -o jsonpath='{.spec.services.registry.local.server.restAPI}' 2>/dev/null)
        if [ "$rest_api" = "true" ]; then
            echo -e "${GREEN}✓ Registry restAPI enabled${NC}"
        else
            echo -e "${RED}✗ Registry restAPI not enabled${NC}"
            echo "  This is required for dashboard visibility"
        fi
        
        # Check pod status
        local feast_pod=$(oc get pods -n "$namespace" -o name 2>/dev/null | grep "feast-$name" | head -1)
        if [ -n "$feast_pod" ]; then
            local pod_status=$(oc get "$feast_pod" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
            echo -e "Feast pod status: ${CYAN}$pod_status${NC}"
        else
            echo -e "${YELLOW}⚠ No Feast pod found${NC}"
        fi
        
        # Check services
        echo ""
        echo -e "${YELLOW}Services:${NC}"
        oc get svc -n "$namespace" 2>/dev/null | grep feast || echo "No Feast services found"
    fi
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
