#!/bin/bash
################################################################################
# Enable All Dashboard Features in RHOAI 3.0
################################################################################
# This script enables all dashboard features including:
# - Model Registry
# - Model Catalog
# - KServe Metrics
# - GenAI Studio / Playground
# - Model as a Service (MaaS)
# - LM Eval
#
# NOTE: In RHOAI 3.0, disableKueue and disableHardwareProfiles are DEPRECATED
# and must NOT be included in the OdhDashboardConfig. Kueue is managed via the
# Red Hat Build of Kueue Operator and DataScienceCluster settings.
################################################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "$SCRIPT_DIR/../lib/utils/colors.sh"
source "$SCRIPT_DIR/../lib/utils/common.sh"

################################################################################
# Functions
################################################################################

check_connection() {
    print_header "Checking OpenShift Connection"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        echo "Please login first: oc login <cluster-url>"
        return 1
    fi
    
    local cluster_url=$(oc whoami --show-server 2>/dev/null)
    local cluster_user=$(oc whoami 2>/dev/null)
    
    print_success "Connected to OpenShift cluster"
    echo "  Cluster: $cluster_url"
    echo "  User: $cluster_user"
    echo ""
    
    return 0
}

enable_dashboard_features() {
    print_header "Enabling Dashboard Features"
    
    print_step "Patching OdhDashboardConfig..."
    
    # NOTE: In RHOAI 3.0, disableKueue and disableHardwareProfiles are DEPRECATED
    # and must NOT be included in the spec. See CAI's guide to RHOAI 3.0.
    cat <<EOF | oc apply -f -
apiVersion: opendatahub.io/v1alpha
kind: OdhDashboardConfig
metadata:
  name: odh-dashboard-config
  namespace: redhat-ods-applications
spec:
  dashboardConfig:
    disableTracking: false
    disableModelRegistry: false      # ✓ Enable Model Registry
    disableModelCatalog: false       # ✓ Enable Model Catalog
    disableKServeMetrics: false      # ✓ Enable KServe Metrics
    genAiStudio: true                # ✓ Enable GenAI Studio/Playground
    modelAsService: true             # ✓ Enable Model as a Service (MaaS)
    disableLMEval: false             # ✓ Enable LM Eval
  hardwareProfileOrder: []
  notebookController:
    enabled: true
    notebookNamespace: rhods-notebooks
    pvcSize: 20Gi
  templateDisablement: []
  templateOrder: []
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Dashboard configuration updated"
    else
        print_error "Failed to update dashboard configuration"
        return 1
    fi
    
    echo ""
    print_info "Waiting for changes to take effect..."
    sleep 5
    
    return 0
}

verify_features() {
    print_header "Verifying Enabled Features"
    
    print_step "Checking dashboard configuration..."
    
    local config=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications -o yaml 2>/dev/null)
    
    if [ -z "$config" ]; then
        print_error "Could not retrieve dashboard configuration"
        return 1
    fi
    
    echo ""
    print_info "Feature Status:"
    
    # Check each feature
    # NOTE: disableKueue and disableHardwareProfiles are deprecated in RHOAI 3.0
    local features=(
        "disableModelRegistry:Model Registry"
        "disableModelCatalog:Model Catalog"
        "disableKServeMetrics:KServe Metrics"
        "genAiStudio:GenAI Studio"
        "modelAsService:Model as a Service"
        "disableLMEval:LM Eval"
    )
    
    for feature_pair in "${features[@]}"; do
        IFS=: read -r key name <<< "$feature_pair"
        local value=$(echo "$config" | grep "$key" | awk '{print $2}')
        
        if [[ "$key" == disable* ]]; then
            # For disable* keys, false means enabled
            if [[ "$value" == "false" ]]; then
                echo "  ✓ $name: Enabled"
            else
                echo "  ✗ $name: Disabled"
            fi
        else
            # For regular keys, true means enabled
            if [[ "$value" == "true" ]]; then
                echo "  ✓ $name: Enabled"
            else
                echo "  ✗ $name: Disabled"
            fi
        fi
    done
    
    echo ""
    return 0
}

get_dashboard_url() {
    print_header "Accessing the Dashboard"
    
    local dashboard_url=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null)
    
    if [ -n "$dashboard_url" ]; then
        print_success "Dashboard URL:"
        echo "  https://$dashboard_url"
        echo ""
        print_info "All features are now enabled in the dashboard!"
    else
        print_warning "Could not retrieve dashboard URL"
        echo "  Check manually: oc get route rhods-dashboard -n redhat-ods-applications"
    fi
    
    echo ""
}

show_next_steps() {
    print_header "Next Steps"
    
    echo "Now that all features are enabled, you can:"
    echo ""
    echo "1. 📊 Model Registry"
    echo "   - Create model registries for version tracking"
    echo "   - Register and manage model versions"
    echo "   - Navigate to: Settings → Model Registry"
    echo ""
    echo "2. 🎮 GenAI Playground"
    echo "   - Deploy a model (./scripts/quick-deploy-model.sh)"
    echo "   - Add it to playground (GenAI Studio → AI Assets → Add to Playground)"
    echo "   - Test prompts interactively"
    echo ""
    echo "3. 🔌 MCP Servers"
    echo "   - Configure MCP servers for tool calling"
    echo "   - Run: ./scripts/setup-mcp-servers.sh"
    echo "   - Connect in Playground"
    echo ""
    echo "4. ⚙️ Hardware Profiles"
    echo "   - Create GPU hardware profiles"
    echo "   - Associate with Kueue LocalQueues"
    echo "   - Use for model deployments"
    echo ""
    echo "5. 📈 Model as a Service (MaaS)"
    echo "   - Set up API gateway with authentication"
    echo "   - Run: ./scripts/setup-maas.sh"
    echo "   - Configure rate limiting"
    echo ""
    echo "For detailed guides, see:"
    echo "  - docs/guides/MODEL-REGISTRY.md"
    echo "  - docs/guides/GENAI-PLAYGROUND-INTEGRATION.md"
    echo "  - docs/guides/MCP-SERVERS.md"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    clear
    
    print_header "Enable All Dashboard Features - RHOAI 3.0"
    
    echo "This script will enable all dashboard features including:"
    echo "  ✓ Model Registry"
    echo "  ✓ Model Catalog"
    echo "  ✓ KServe Metrics"
    echo "  ✓ GenAI Studio / Playground"
    echo "  ✓ Model as a Service (MaaS)"
    echo "  ✓ LM Eval"
    echo ""
    echo "Note: Kueue/Hardware Profiles are managed via Red Hat Build of Kueue Operator"
    echo "      and DataScienceCluster settings (not OdhDashboardConfig in RHOAI 3.0)"
    echo ""
    
    read -p "Continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        exit 0
    fi
    
    echo ""
    
    # Check connection
    if ! check_connection; then
        exit 1
    fi
    
    # Enable features
    if ! enable_dashboard_features; then
        print_error "Failed to enable dashboard features"
        exit 1
    fi
    
    # Verify
    verify_features
    
    # Get dashboard URL
    get_dashboard_url
    
    # Show next steps
    show_next_steps
    
    print_success "All dashboard features have been enabled!"
    echo ""
}

# Run main function
main "$@"

