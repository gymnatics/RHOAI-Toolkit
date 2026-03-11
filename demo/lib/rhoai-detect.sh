#!/bin/bash
################################################################################
# RHOAI Version Detection Utility
################################################################################
# This script provides functions to detect RHOAI version and configure
# endpoints accordingly. Source this file in your demo scripts.
#
# Usage:
#   source "$(dirname "$0")/lib/rhoai-detect.sh"
#   detect_rhoai_version
#   get_maas_endpoint
################################################################################

# Colors (if not already defined)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
CYAN="${CYAN:-\033[0;36m}"
NC="${NC:-\033[0m}"

# Global variables set by detection functions
RHOAI_VERSION=""
RHOAI_MAJOR_VERSION=""
MAAS_ENDPOINT=""
MAAS_NAMESPACE=""
INFERENCE_GATEWAY=""
DASHBOARD_URL=""

################################################################################
# Detect RHOAI Version
# Sets: RHOAI_VERSION, RHOAI_MAJOR_VERSION
################################################################################
detect_rhoai_version() {
    # Try to get version from CSV
    local csv_version=$(oc get csv -n redhat-ods-operator -o jsonpath='{.items[?(@.spec.displayName=="Red Hat OpenShift AI")].spec.version}' 2>/dev/null | head -1)
    
    if [ -n "$csv_version" ]; then
        RHOAI_VERSION="$csv_version"
        # Extract major.minor (e.g., "3.3" from "3.3.0")
        RHOAI_MAJOR_VERSION=$(echo "$csv_version" | cut -d. -f1,2)
    else
        # Fallback: detect based on features
        if oc get crd llminferenceservices.serving.kserve.io &>/dev/null; then
            # LLMInferenceService CRD exists - this is 3.x
            if oc get pods -n redhat-ods-applications -l app=maas-api &>/dev/null 2>&1; then
                # Integrated MaaS - likely 3.3+
                RHOAI_VERSION="3.3.x"
                RHOAI_MAJOR_VERSION="3.3"
            else
                RHOAI_VERSION="3.x"
                RHOAI_MAJOR_VERSION="3.0"
            fi
        elif oc get datasciencecluster &>/dev/null; then
            # DSC exists but no LLMInferenceService - likely 2.x
            RHOAI_VERSION="2.x"
            RHOAI_MAJOR_VERSION="2.0"
        else
            RHOAI_VERSION="unknown"
            RHOAI_MAJOR_VERSION="unknown"
        fi
    fi
    
    echo -e "${CYAN}Detected RHOAI version: $RHOAI_VERSION${NC}"
}

################################################################################
# Check if RHOAI version is 3.3 or higher
# Returns: 0 if >= 3.3, 1 otherwise
################################################################################
is_rhoai_33_or_higher() {
    detect_rhoai_version
    
    case "$RHOAI_MAJOR_VERSION" in
        3.3|3.4|3.5|3.6|3.7|3.8|3.9|4.*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

################################################################################
# Check if RHOAI version is 3.x
# Returns: 0 if 3.x, 1 otherwise
################################################################################
is_rhoai_3x() {
    detect_rhoai_version
    
    case "$RHOAI_MAJOR_VERSION" in
        3.*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

################################################################################
# Get MaaS Endpoint based on RHOAI version
# Sets: MAAS_ENDPOINT, MAAS_NAMESPACE
# Returns: 0 if found, 1 if not found
################################################################################
get_maas_endpoint() {
    detect_rhoai_version
    
    MAAS_ENDPOINT=""
    MAAS_NAMESPACE=""
    
    if is_rhoai_33_or_higher; then
        # RHOAI 3.3+: MaaS is integrated, uses inference gateway
        echo -e "${BLUE}Checking RHOAI 3.3+ integrated MaaS...${NC}"
        
        # Check if MaaS is enabled
        if oc get pods -n redhat-ods-applications -l app=maas-api 2>/dev/null | grep -q Running; then
            MAAS_NAMESPACE="redhat-ods-applications"
            
            # Get inference gateway hostname
            INFERENCE_GATEWAY=$(oc get gateway openshift-ai-inference -n openshift-ingress -o jsonpath='{.spec.listeners[0].hostname}' 2>/dev/null || echo "")
            
            if [ -n "$INFERENCE_GATEWAY" ]; then
                MAAS_ENDPOINT="$INFERENCE_GATEWAY"
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
            MAAS_ENDPOINT=$(oc get route maas-api -n maas-api -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
            
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
# Get Dashboard URL based on RHOAI version
# Sets: DASHBOARD_URL
################################################################################
get_dashboard_url() {
    detect_rhoai_version
    
    DASHBOARD_URL=""
    
    if is_rhoai_33_or_higher; then
        # RHOAI 3.3+: New dashboard URL format
        local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
        DASHBOARD_URL="https://data-science-gateway.${cluster_domain}"
    else
        # RHOAI 3.2 and earlier: Legacy dashboard URL
        DASHBOARD_URL=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='https://{.spec.host}' 2>/dev/null || echo "")
        
        if [ -z "$DASHBOARD_URL" ]; then
            local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
            DASHBOARD_URL="https://rhods-dashboard-redhat-ods-applications.${cluster_domain}"
        fi
    fi
    
    echo -e "${CYAN}Dashboard URL: $DASHBOARD_URL${NC}"
}

################################################################################
# Get the appropriate namespace to check for MaaS pods
################################################################################
get_maas_pod_namespace() {
    if is_rhoai_33_or_higher; then
        echo "redhat-ods-applications"
    else
        echo "maas-api"
    fi
}

################################################################################
# Feast/Feature Store Configuration (Version-Aware)
################################################################################

# Check if FeatureStore has correct labels for dashboard visibility
# RHOAI 3.3+ has stricter requirements for Feature Store dashboard visibility
check_featurestore_visibility() {
    local namespace="$1"
    local name="$2"
    
    detect_rhoai_version
    
    local issues=0
    
    # Check for required label
    local labels=$(oc get featurestore "$name" -n "$namespace" -o jsonpath='{.metadata.labels}' 2>/dev/null)
    if ! echo "$labels" | grep -q "feature-store-ui"; then
        echo -e "${YELLOW}⚠ FeatureStore '$name' is missing 'feature-store-ui: enabled' label${NC}"
        issues=$((issues + 1))
    fi
    
    # Check restAPI configuration
    local rest_api=$(oc get featurestore "$name" -n "$namespace" -o jsonpath='{.spec.services.registry.local.server.restAPI}' 2>/dev/null)
    if [ "$rest_api" != "true" ]; then
        echo -e "${YELLOW}⚠ FeatureStore '$name' has restAPI disabled${NC}"
        issues=$((issues + 1))
    fi
    
    return $issues
}

# Fix FeatureStore labels and configuration for dashboard visibility
fix_featurestore_visibility() {
    local namespace="$1"
    local name="$2"
    
    echo -e "${BLUE}Fixing FeatureStore visibility for $name in $namespace...${NC}"
    
    # Add required label
    oc label featurestore "$name" -n "$namespace" feature-store-ui=enabled --overwrite
    
    # Enable restAPI if not set
    local rest_api=$(oc get featurestore "$name" -n "$namespace" -o jsonpath='{.spec.services.registry.local.server.restAPI}' 2>/dev/null)
    if [ "$rest_api" != "true" ]; then
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
    fi
    
    echo -e "${GREEN}✓ FeatureStore visibility fixes applied${NC}"
}

################################################################################
# Print RHOAI environment info
################################################################################
print_rhoai_info() {
    detect_rhoai_version
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  RHOAI Environment Info                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  RHOAI Version:    ${GREEN}$RHOAI_VERSION${NC}"
    echo -e "  Major Version:    ${GREEN}$RHOAI_MAJOR_VERSION${NC}"
    
    get_dashboard_url
    echo -e "  Dashboard URL:    ${GREEN}$DASHBOARD_URL${NC}"
    
    if get_maas_endpoint; then
        echo -e "  MaaS Endpoint:    ${GREEN}$MAAS_ENDPOINT${NC}"
        echo -e "  MaaS Namespace:   ${GREEN}$MAAS_NAMESPACE${NC}"
    else
        echo -e "  MaaS:             ${YELLOW}Not configured${NC}"
    fi
    
    # Check Feast operator status
    local feast_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.feastoperator.managementState}' 2>/dev/null || echo "Unknown")
    echo -e "  Feast Operator:   $([ "$feast_state" = "Managed" ] && echo "${GREEN}$feast_state${NC}" || echo "${YELLOW}$feast_state${NC}")"
    
    echo ""
}
