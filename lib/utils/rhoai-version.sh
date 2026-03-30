#!/bin/bash
################################################################################
# RHOAI Version Detection and Compatibility Utility
################################################################################
# This script provides functions to detect RHOAI version and configure
# components appropriately based on version differences.
#
# Usage:
#   source "$SCRIPT_DIR/lib/utils/rhoai-version.sh"
#   detect_rhoai_version
#   if is_rhoai_33_or_higher; then
#       # Use 3.3+ specific configuration
#   fi
################################################################################

# Colors (use existing if defined)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
CYAN="${CYAN:-\033[0;36m}"
MAGENTA="${MAGENTA:-\033[0;35m}"
NC="${NC:-\033[0m}"

# Global variables set by detection functions
RHOAI_VERSION=""
RHOAI_MAJOR_VERSION=""
RHOAI_MINOR_VERSION=""

################################################################################
# Version Detection
################################################################################

# Detect RHOAI version from cluster
# Sets: RHOAI_VERSION, RHOAI_MAJOR_VERSION, RHOAI_MINOR_VERSION
detect_rhoai_version() {
    # Skip if already detected
    if [ -n "$RHOAI_VERSION" ] && [ "$RHOAI_VERSION" != "unknown" ]; then
        return 0
    fi
    
    # Try to get version from CSV
    local csv_version=$(oc get csv -n redhat-ods-operator -o jsonpath='{.items[?(@.spec.displayName=="Red Hat OpenShift AI")].spec.version}' 2>/dev/null | head -1)
    
    if [ -n "$csv_version" ]; then
        RHOAI_VERSION="$csv_version"
        RHOAI_MAJOR_VERSION=$(echo "$csv_version" | cut -d. -f1)
        RHOAI_MINOR_VERSION=$(echo "$csv_version" | cut -d. -f2)
    else
        # Fallback: detect based on features
        if oc get crd llminferenceservices.serving.kserve.io &>/dev/null 2>&1; then
            # LLMInferenceService CRD exists - this is 3.x
            # Check for 3.3+ features
            local dsc_spec=$(oc get datasciencecluster default-dsc -o json 2>/dev/null)
            if echo "$dsc_spec" | grep -q "modelsAsService" 2>/dev/null; then
                RHOAI_VERSION="3.3.x"
                RHOAI_MAJOR_VERSION="3"
                RHOAI_MINOR_VERSION="3"
            else
                RHOAI_VERSION="3.x"
                RHOAI_MAJOR_VERSION="3"
                RHOAI_MINOR_VERSION="0"
            fi
        elif oc get datasciencecluster &>/dev/null 2>&1; then
            # DSC exists but no LLMInferenceService - likely 2.x
            RHOAI_VERSION="2.x"
            RHOAI_MAJOR_VERSION="2"
            RHOAI_MINOR_VERSION="0"
        else
            RHOAI_VERSION="unknown"
            RHOAI_MAJOR_VERSION="0"
            RHOAI_MINOR_VERSION="0"
        fi
    fi
    
    echo -e "${CYAN}Detected RHOAI version: $RHOAI_VERSION${NC}"
}

# Get full version string
get_rhoai_version() {
    detect_rhoai_version
    echo "$RHOAI_VERSION"
}

# Get major.minor version (e.g., "3.3")
get_rhoai_major_minor() {
    detect_rhoai_version
    echo "${RHOAI_MAJOR_VERSION}.${RHOAI_MINOR_VERSION}"
}

################################################################################
# Version Comparison Functions
################################################################################

# Check if RHOAI version is 3.3 or higher
# Returns: 0 if >= 3.3, 1 otherwise
is_rhoai_33_or_higher() {
    detect_rhoai_version
    
    if [ "$RHOAI_MAJOR_VERSION" -gt 3 ]; then
        return 0
    elif [ "$RHOAI_MAJOR_VERSION" -eq 3 ] && [ "$RHOAI_MINOR_VERSION" -ge 3 ]; then
        return 0
    fi
    return 1
}

# Check if RHOAI version is 3.2 or higher
# Returns: 0 if >= 3.2, 1 otherwise
is_rhoai_32_or_higher() {
    detect_rhoai_version
    
    if [ "$RHOAI_MAJOR_VERSION" -gt 3 ]; then
        return 0
    elif [ "$RHOAI_MAJOR_VERSION" -eq 3 ] && [ "$RHOAI_MINOR_VERSION" -ge 2 ]; then
        return 0
    fi
    return 1
}

# Check if RHOAI version is 3.x
# Returns: 0 if 3.x, 1 otherwise
is_rhoai_3x() {
    detect_rhoai_version
    [ "$RHOAI_MAJOR_VERSION" -eq 3 ]
}

# Check if RHOAI version is 2.x
# Returns: 0 if 2.x, 1 otherwise
is_rhoai_2x() {
    detect_rhoai_version
    [ "$RHOAI_MAJOR_VERSION" -eq 2 ]
}

################################################################################
# MaaS Configuration (Version-Aware)
################################################################################

# Get MaaS endpoint based on RHOAI version
# Sets: MAAS_ENDPOINT, MAAS_NAMESPACE
# Returns: 0 if found, 1 if not found
get_maas_endpoint() {
    detect_rhoai_version
    
    MAAS_ENDPOINT=""
    MAAS_NAMESPACE=""
    
    if is_rhoai_33_or_higher; then
        # RHOAI 3.3+: MaaS is integrated, uses inference gateway
        echo -e "${BLUE}Checking RHOAI 3.3+ integrated MaaS...${NC}"
        
        # Check if MaaS is enabled in DSC
        local maas_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.kserve.modelsAsService.managementState}' 2>/dev/null)
        
        if [ "$maas_state" = "Managed" ]; then
            MAAS_NAMESPACE="redhat-ods-applications"
            
            # Get inference gateway hostname
            local gateway_host=$(oc get gateway openshift-ai-inference -n openshift-ingress -o jsonpath='{.spec.listeners[0].hostname}' 2>/dev/null)
            
            if [ -n "$gateway_host" ]; then
                MAAS_ENDPOINT="$gateway_host"
            else
                # Construct from cluster domain
                local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
                if [ -n "$cluster_domain" ]; then
                    MAAS_ENDPOINT="inference-gateway.${cluster_domain}"
                fi
            fi
            
            if [ -n "$MAAS_ENDPOINT" ]; then
                echo -e "${GREEN}✓ MaaS endpoint (3.3+ integrated): $MAAS_ENDPOINT${NC}"
                return 0
            fi
        else
            echo -e "${YELLOW}MaaS not enabled in RHOAI 3.3+${NC}"
            echo "Enable with: modelsAsService.managementState: Managed in DataScienceCluster"
        fi
    else
        # RHOAI 3.2 and earlier: Check for legacy MaaS namespace
        echo -e "${BLUE}Checking legacy MaaS setup...${NC}"
        
        if oc get namespace maas-api &>/dev/null; then
            MAAS_NAMESPACE="maas-api"
            MAAS_ENDPOINT=$(oc get route maas-api -n maas-api -o jsonpath='{.spec.host}' 2>/dev/null)
            
            if [ -n "$MAAS_ENDPOINT" ]; then
                echo -e "${GREEN}✓ MaaS endpoint (legacy): $MAAS_ENDPOINT${NC}"
                return 0
            fi
        else
            echo -e "${YELLOW}Legacy MaaS namespace not found${NC}"
            echo "Setup with: ./scripts/setup-maas.sh"
        fi
    fi
    
    echo -e "${RED}✗ MaaS endpoint not found${NC}"
    return 1
}

################################################################################
# Dashboard URL (Version-Aware)
################################################################################

# Get Dashboard URL based on RHOAI version
get_dashboard_url() {
    detect_rhoai_version
    
    local dashboard_url=""
    
    if is_rhoai_33_or_higher; then
        # RHOAI 3.3+: New dashboard URL format
        local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
        dashboard_url="https://data-science-gateway.${cluster_domain}"
    else
        # RHOAI 3.2 and earlier: Legacy dashboard URL
        dashboard_url=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='https://{.spec.host}' 2>/dev/null)
        
        if [ -z "$dashboard_url" ]; then
            local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
            dashboard_url="https://rhods-dashboard-redhat-ods-applications.${cluster_domain}"
        fi
    fi
    
    echo "$dashboard_url"
}

################################################################################
# Feast/Feature Store Configuration (Version-Aware)
################################################################################

# Get the correct FeatureStore CR configuration based on RHOAI version
# RHOAI 3.3 requires additional labels and annotations for UI visibility
get_featurestore_labels() {
    detect_rhoai_version
    
    # Base label required for all versions
    echo "feature-store-ui: enabled"
    
    if is_rhoai_33_or_higher; then
        # RHOAI 3.3+ may require additional labels for dashboard discovery
        echo "opendatahub.io/dashboard: \"true\""
    fi
}

# Check if FeatureStore has correct labels for dashboard visibility
check_featurestore_labels() {
    local namespace="$1"
    local name="$2"
    
    detect_rhoai_version
    
    local labels=$(oc get featurestore "$name" -n "$namespace" -o jsonpath='{.metadata.labels}' 2>/dev/null)
    
    # Check for required label
    if ! echo "$labels" | grep -q "feature-store-ui"; then
        echo -e "${YELLOW}⚠ FeatureStore '$name' is missing 'feature-store-ui: enabled' label${NC}"
        echo "This may prevent it from appearing in the RHOAI dashboard."
        return 1
    fi
    
    return 0
}

# Fix FeatureStore labels for dashboard visibility
fix_featurestore_labels() {
    local namespace="$1"
    local name="$2"
    
    detect_rhoai_version
    
    echo -e "${BLUE}Fixing FeatureStore labels for $name in $namespace...${NC}"
    
    # Add required label
    oc label featurestore "$name" -n "$namespace" feature-store-ui=enabled --overwrite
    
    if is_rhoai_33_or_higher; then
        # Add additional labels for 3.3+
        oc label featurestore "$name" -n "$namespace" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Labels updated${NC}"
}

# Check and fix FeatureStore registry configuration
# RHOAI 3.3 requires restAPI: true for dashboard integration
check_featurestore_registry() {
    local namespace="$1"
    local name="$2"
    
    detect_rhoai_version
    
    local rest_api=$(oc get featurestore "$name" -n "$namespace" -o jsonpath='{.spec.services.registry.local.server.restAPI}' 2>/dev/null)
    
    if [ "$rest_api" != "true" ]; then
        echo -e "${YELLOW}⚠ FeatureStore '$name' has restAPI disabled${NC}"
        echo "This prevents the Feature Store from appearing in the RHOAI dashboard."
        return 1
    fi
    
    return 0
}

# Fix FeatureStore registry configuration
fix_featurestore_registry() {
    local namespace="$1"
    local name="$2"
    
    echo -e "${BLUE}Enabling restAPI for FeatureStore $name in $namespace...${NC}"
    
    oc patch featurestore "$name" -n "$namespace" --type=merge -p '{
        "spec": {
            "services": {
                "registry": {
                    "local": {
                        "server": {
                            "restAPI": true
                        }
                    }
                }
            }
        }
    }'
    
    echo -e "${GREEN}✓ Registry restAPI enabled${NC}"
}

# Diagnose FeatureStore visibility issues
diagnose_featurestore() {
    local namespace="$1"
    local name="$2"
    
    detect_rhoai_version
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  FeatureStore Diagnostic: $name                               ${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BLUE}RHOAI Version:${NC} $RHOAI_VERSION"
    echo ""
    
    # Check if FeatureStore exists
    if ! oc get featurestore "$name" -n "$namespace" &>/dev/null; then
        echo -e "${RED}✗ FeatureStore '$name' not found in namespace '$namespace'${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ FeatureStore exists${NC}"
    
    # Check labels
    local issues=0
    if ! check_featurestore_labels "$namespace" "$name"; then
        issues=$((issues + 1))
    else
        echo -e "${GREEN}✓ Labels are correct${NC}"
    fi
    
    # Check registry configuration
    if ! check_featurestore_registry "$namespace" "$name"; then
        issues=$((issues + 1))
    else
        echo -e "${GREEN}✓ Registry restAPI is enabled${NC}"
    fi
    
    # Check for Feast pod
    local feast_pod=$(oc get pods -n "$namespace" -o name 2>/dev/null | grep "feast-$name" | head -1)
    if [ -z "$feast_pod" ]; then
        echo -e "${YELLOW}⚠ No Feast pod found for '$name'${NC}"
        issues=$((issues + 1))
    else
        local pod_status=$(oc get "$feast_pod" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
        if [ "$pod_status" = "Running" ]; then
            echo -e "${GREEN}✓ Feast pod is running${NC}"
        else
            echo -e "${YELLOW}⚠ Feast pod status: $pod_status${NC}"
            issues=$((issues + 1))
        fi
    fi
    
    # Check for services
    local registry_svc=$(oc get svc -n "$namespace" -o name 2>/dev/null | grep "feast-$name-registry" | head -1)
    if [ -z "$registry_svc" ]; then
        echo -e "${YELLOW}⚠ Registry service not found${NC}"
        issues=$((issues + 1))
    else
        echo -e "${GREEN}✓ Registry service exists${NC}"
    fi
    
    local rest_svc=$(oc get svc -n "$namespace" -o name 2>/dev/null | grep "feast-$name-registry-rest" | head -1)
    if [ -z "$rest_svc" ]; then
        echo -e "${YELLOW}⚠ Registry REST service not found (required for dashboard)${NC}"
        issues=$((issues + 1))
    else
        echo -e "${GREEN}✓ Registry REST service exists${NC}"
    fi
    
    # Summary
    echo ""
    if [ $issues -eq 0 ]; then
        echo -e "${GREEN}✓ No issues detected${NC}"
        echo ""
        echo "If FeatureStore still doesn't appear in dashboard:"
        echo "  1. Wait a few minutes for the dashboard to refresh"
        echo "  2. Check namespace permissions in RHOAI dashboard"
        echo "  3. Verify feast apply was run successfully"
    else
        echo -e "${YELLOW}⚠ Found $issues issue(s)${NC}"
        echo ""
        read -p "Would you like to attempt automatic fixes? (y/N): " fix_issues
        if [[ "$fix_issues" =~ ^[Yy]$ ]]; then
            fix_featurestore_labels "$namespace" "$name"
            fix_featurestore_registry "$namespace" "$name"
            echo ""
            echo -e "${GREEN}Fixes applied. Wait a few minutes for changes to take effect.${NC}"
        fi
    fi
    
    return $issues
}

################################################################################
# Model Serving CRD Detection
################################################################################
#
# RHOAI 3.3 Model Serving CR Reference:
#   - LLMInferenceService (v1alpha1): ONLY for llm-d runtime, required for MaaS
#   - InferenceService (v1beta1): All other runtimes (vLLM, OpenVINO, Caikit-TGIS, NIM, etc.)
#
# The CR type is determined by the RUNTIME choice, not the RHOAI version.
# When deploying, the script/user chooses the runtime and uses the appropriate CR.
# See lib/functions/model-deployment.sh for the actual deployment logic.
################################################################################

# Check if llm-d runtime is available on the cluster (LLMInferenceService CRD exists)
is_llmd_available() {
    oc get crd llminferenceservices.serving.kserve.io &>/dev/null
}

# Check if standard KServe is available (InferenceService CRD exists)
is_kserve_available() {
    oc get crd inferenceservices.serving.kserve.io &>/dev/null
}

# List all deployed models (both InferenceService and LLMInferenceService)
# Returns: namespace/name/kind for each deployed model
list_deployed_models() {
    local ns="${1:-}"
    local ns_flag=""
    [ -n "$ns" ] && ns_flag="-n $ns" || ns_flag="-A"
    
    # Get InferenceServices
    if is_kserve_available; then
        oc get inferenceservice $ns_flag -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}/InferenceService{"\n"}{end}' 2>/dev/null
    fi
    
    # Get LLMInferenceServices
    if is_llmd_available; then
        oc get llminferenceservice $ns_flag -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}/LLMInferenceService{"\n"}{end}' 2>/dev/null
    fi
}

################################################################################
# Print RHOAI Environment Info
################################################################################

print_rhoai_info() {
    detect_rhoai_version
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  RHOAI Environment Info                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  RHOAI Version:    ${GREEN}$RHOAI_VERSION${NC}"
    echo -e "  Major.Minor:      ${GREEN}${RHOAI_MAJOR_VERSION}.${RHOAI_MINOR_VERSION}${NC}"
    
    local dashboard_url=$(get_dashboard_url)
    echo -e "  Dashboard URL:    ${GREEN}$dashboard_url${NC}"
    
    if get_maas_endpoint >/dev/null 2>&1; then
        echo -e "  MaaS Endpoint:    ${GREEN}$MAAS_ENDPOINT${NC}"
    else
        echo -e "  MaaS:             ${YELLOW}Not configured${NC}"
    fi
    
    # Check key components
    local feast_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.feastoperator.managementState}' 2>/dev/null || echo "Unknown")
    local llamastack_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.llamastackoperator.managementState}' 2>/dev/null || echo "Unknown")
    local kserve_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.kserve.managementState}' 2>/dev/null || echo "Unknown")
    
    echo ""
    echo -e "  ${BLUE}Component Status:${NC}"
    echo -e "    KServe:         $([ "$kserve_state" = "Managed" ] && echo "${GREEN}$kserve_state${NC}" || echo "${YELLOW}$kserve_state${NC}")"
    echo -e "    Feast:          $([ "$feast_state" = "Managed" ] && echo "${GREEN}$feast_state${NC}" || echo "${YELLOW}$feast_state${NC}")"
    echo -e "    LlamaStack:     $([ "$llamastack_state" = "Managed" ] && echo "${GREEN}$llamastack_state${NC}" || echo "${YELLOW}$llamastack_state${NC}")"
    
    if is_rhoai_33_or_higher; then
        local maas_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.kserve.modelsAsService.managementState}' 2>/dev/null || echo "Unknown")
        echo -e "    MaaS:           $([ "$maas_state" = "Managed" ] && echo "${GREEN}$maas_state${NC}" || echo "${YELLOW}$maas_state${NC}")"
    fi
    
    echo ""
}
