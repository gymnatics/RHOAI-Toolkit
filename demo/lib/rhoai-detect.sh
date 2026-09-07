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
RHOAI_MINOR_VERSION=""
MAAS_ENDPOINT=""
MAAS_NAMESPACE=""
# "body"  -> RHOAI 3.5+: single shared /v1/chat/completions endpoint, model id
#            (publishers/<ns>/models/<name>) goes in the request body
# "path"  -> RHOAI 3.3/3.4: per-model URL /<ns>/<model>/v1/chat/completions
MAAS_ROUTING=""
INFERENCE_GATEWAY=""
DASHBOARD_URL=""

################################################################################
# Detect RHOAI Version
# Sets: RHOAI_VERSION, RHOAI_MAJOR_VERSION, RHOAI_MINOR_VERSION
################################################################################
detect_rhoai_version() {
    # Skip if already detected
    if [ -n "$RHOAI_VERSION" ] && [ "$RHOAI_VERSION" != "unknown" ]; then
        return 0
    fi

    # Try to get version from CSV
    local csv_version=$(oc get csv -n redhat-ods-operator -o jsonpath='{.items[?(@.spec.displayName=="Red Hat OpenShift AI")].spec.version}' 2>/dev/null | head -1)

    if [ -n "$csv_version" ]; then
        RHOAI_VERSION="$csv_version"
        # Extract major.minor (e.g., "3.3" from "3.3.0")
        RHOAI_MAJOR_VERSION=$(echo "$csv_version" | cut -d. -f1)
        RHOAI_MINOR_VERSION=$(echo "$csv_version" | cut -d. -f2)
    else
        # Fallback: detect based on features/CRDs (no CSV visible, e.g. limited RBAC)
        if oc get crd llminferenceservices.serving.kserve.io &>/dev/null; then
            local dsc_spec=$(oc get datasciencecluster default-dsc -o json 2>/dev/null)

            if echo "$dsc_spec" | grep -q '"aigateway"' 2>/dev/null || \
               oc get crd maastenantconfigs.maas.opendatahub.io &>/dev/null 2>&1; then
                # aigateway.modelsAsAService / MaasTenantConfig CRD only exist on 3.5+
                RHOAI_VERSION="3.5.x"
                RHOAI_MAJOR_VERSION="3"
                RHOAI_MINOR_VERSION="5"
            elif oc get crd maassubscriptions.maas.opendatahub.io &>/dev/null 2>&1; then
                # MaaSSubscription CRD (subscription-based MaaS) only exists on 3.4+
                RHOAI_VERSION="3.4.x"
                RHOAI_MAJOR_VERSION="3"
                RHOAI_MINOR_VERSION="4"
            elif echo "$dsc_spec" | grep -q "modelsAsService" 2>/dev/null; then
                RHOAI_VERSION="3.3.x"
                RHOAI_MAJOR_VERSION="3"
                RHOAI_MINOR_VERSION="3"
            else
                RHOAI_VERSION="3.x"
                RHOAI_MAJOR_VERSION="3"
                RHOAI_MINOR_VERSION="0"
            fi
        elif oc get datasciencecluster &>/dev/null; then
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

################################################################################
# Version comparison helpers
################################################################################

# Check if RHOAI version is 3.3 or higher
is_rhoai_33_or_higher() {
    detect_rhoai_version
    [ "$RHOAI_MAJOR_VERSION" -gt 3 ] 2>/dev/null && return 0
    [ "$RHOAI_MAJOR_VERSION" -eq 3 ] 2>/dev/null && [ "$RHOAI_MINOR_VERSION" -ge 3 ] 2>/dev/null && return 0
    return 1
}

# Check if RHOAI version is 3.4 or higher (MaaS subscription CRDs, sk-oai-* keys)
is_rhoai_34_or_higher() {
    detect_rhoai_version
    [ "$RHOAI_MAJOR_VERSION" -gt 3 ] 2>/dev/null && return 0
    [ "$RHOAI_MAJOR_VERSION" -eq 3 ] 2>/dev/null && [ "$RHOAI_MINOR_VERSION" -ge 4 ] 2>/dev/null && return 0
    return 1
}

# Check if RHOAI version is 3.5 or higher (aigateway.modelsAsAService, body-based routing)
is_rhoai_35_or_higher() {
    detect_rhoai_version
    [ "$RHOAI_MAJOR_VERSION" -gt 3 ] 2>/dev/null && return 0
    [ "$RHOAI_MAJOR_VERSION" -eq 3 ] 2>/dev/null && [ "$RHOAI_MINOR_VERSION" -ge 5 ] 2>/dev/null && return 0
    return 1
}

################################################################################
# Check if RHOAI version is 3.x
################################################################################
is_rhoai_3x() {
    detect_rhoai_version
    [ "$RHOAI_MAJOR_VERSION" = "3" ]
}

################################################################################
# Get MaaS Endpoint based on RHOAI version
# Sets: MAAS_ENDPOINT (bare hostname, no scheme), MAAS_NAMESPACE, MAAS_ROUTING
# Returns: 0 if found, 1 if not found
################################################################################
get_maas_endpoint() {
    detect_rhoai_version

    MAAS_ENDPOINT=""
    MAAS_NAMESPACE=""
    MAAS_ROUTING=""

    if is_rhoai_35_or_higher; then
        # RHOAI 3.5+: aigateway.modelsAsAService, maas-default-gateway,
        # body-based routing (single shared /v1/chat/completions endpoint).
        echo -e "${BLUE}Checking RHOAI 3.5+ MaaS (aigateway.modelsAsAService, body-based routing)...${NC}"

        local maas_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.aigateway.modelsAsAService.managementState}' 2>/dev/null)

        if [ "$maas_state" = "Managed" ]; then
            MAAS_NAMESPACE="models-as-a-service"
            MAAS_ROUTING="body"

            local gateway_host=$(oc get gateway maas-default-gateway -n openshift-ingress -o jsonpath='{.spec.listeners[0].hostname}' 2>/dev/null)
            if [ -n "$gateway_host" ]; then
                MAAS_ENDPOINT="$gateway_host"
            else
                local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
                [ -n "$cluster_domain" ] && MAAS_ENDPOINT="maas.${cluster_domain}"
            fi

            if [ -n "$MAAS_ENDPOINT" ]; then
                echo -e "${GREEN}✓ MaaS endpoint (3.5+ body-based routing): $MAAS_ENDPOINT${NC}"
                return 0
            fi
        else
            echo -e "${YELLOW}MaaS not enabled in RHOAI 3.5+${NC}"
            echo "Enable with: aigateway.modelsAsAService.managementState: Managed in DataScienceCluster"
        fi
    elif is_rhoai_34_or_higher; then
        # RHOAI 3.4: kserve.modelsAsService, maas-default-gateway,
        # per-model URL routing.
        echo -e "${BLUE}Checking RHOAI 3.4 MaaS (subscription-based)...${NC}"

        local maas_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.kserve.modelsAsService.managementState}' 2>/dev/null)

        if [ "$maas_state" = "Managed" ]; then
            MAAS_NAMESPACE="models-as-a-service"
            MAAS_ROUTING="path"

            local gateway_host=$(oc get gateway maas-default-gateway -n openshift-ingress -o jsonpath='{.spec.listeners[0].hostname}' 2>/dev/null)
            if [ -n "$gateway_host" ]; then
                MAAS_ENDPOINT="$gateway_host"
            else
                local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
                [ -n "$cluster_domain" ] && MAAS_ENDPOINT="maas.${cluster_domain}"
            fi

            if [ -n "$MAAS_ENDPOINT" ]; then
                echo -e "${GREEN}✓ MaaS endpoint (3.4 per-model routing): $MAAS_ENDPOINT${NC}"
                return 0
            fi
        else
            echo -e "${YELLOW}MaaS not enabled in RHOAI 3.4${NC}"
            echo "Enable with: modelsAsService.managementState: Managed in DataScienceCluster"
        fi
    elif is_rhoai_33_or_higher; then
        # RHOAI 3.3: Tech Preview, tier-based, uses inference gateway.
        echo -e "${BLUE}Checking RHOAI 3.3 integrated MaaS (tier-based)...${NC}"

        if oc get pods -n redhat-ods-applications -l app=maas-api 2>/dev/null | grep -q Running; then
            MAAS_NAMESPACE="redhat-ods-applications"
            MAAS_ROUTING="path"

            INFERENCE_GATEWAY=$(oc get gateway openshift-ai-inference -n openshift-ingress -o jsonpath='{.spec.listeners[0].hostname}' 2>/dev/null || echo "")

            if [ -n "$INFERENCE_GATEWAY" ]; then
                MAAS_ENDPOINT="$INFERENCE_GATEWAY"
            else
                local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
                [ -n "$cluster_domain" ] && MAAS_ENDPOINT="inference-gateway.${cluster_domain}"
            fi

            if [ -n "$MAAS_ENDPOINT" ]; then
                echo -e "${GREEN}✓ MaaS endpoint (3.3 tier-based): $MAAS_ENDPOINT${NC}"
                return 0
            fi
        else
            echo -e "${YELLOW}MaaS not enabled in RHOAI 3.3${NC}"
            echo "Enable with: modelsAsService.managementState: Managed in DataScienceCluster"
        fi
    else
        # RHOAI 3.2 and earlier: Check for legacy MaaS namespace
        echo -e "${BLUE}Checking legacy MaaS setup...${NC}"

        if oc get namespace maas-api &>/dev/null; then
            MAAS_NAMESPACE="maas-api"
            MAAS_ROUTING="path"
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
# Get the MaaS API key/token for the detected RHOAI version.
#
# RHOAI 3.4+: mints a sk-oai-* API key via POST /maas-api/v1/api-keys
#   Args: $1 = subscription name (e.g. "simulator-free"), $2 = expiresIn (default "1h")
# RHOAI 3.3-: mints an OpenShift SA token via `oc create token`
#   Args: $1 = ServiceAccount name (default "default"), $2 = namespace (default current)
#
# Echoes the token/key on success, returns 1 on failure.
################################################################################
get_maas_api_key() {
    detect_rhoai_version

    if is_rhoai_34_or_higher; then
        local subscription="${1:?subscription name required (e.g. simulator-free)}"
        local expires_in="${2:-1h}"

        if [ -z "$MAAS_ENDPOINT" ]; then
            get_maas_endpoint >/dev/null 2>&1 || return 1
        fi

        local key
        key=$(curl -sk -X POST "https://${MAAS_ENDPOINT}/maas-api/v1/api-keys" \
            -H "Authorization: Bearer $(oc whoami -t)" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"demo-$(date +%s)\",\"subscription\":\"${subscription}\",\"expiresIn\":\"${expires_in}\"}" \
            | jq -r '.key // empty' 2>/dev/null)

        if [ -z "$key" ]; then
            return 1
        fi
        echo "$key"
    else
        local sa_name="${1:-default}"
        local sa_namespace="${2:-$(oc project -q 2>/dev/null)}"

        local token
        if is_rhoai_33_or_higher; then
            token=$(oc create token "$sa_name" -n "$sa_namespace" --duration=1h --audience=https://kubernetes.default.svc 2>/dev/null)
        else
            token=$(oc create token "$sa_name" -n "$sa_namespace" --duration=1h 2>/dev/null)
        fi

        if [ -z "$token" ]; then
            return 1
        fi
        echo "$token"
    fi
}

################################################################################
# Look up the model id to send in chat completion requests.
#
# IMPORTANT (3.5+): the body-based routing id is "publishers/<ns>/models/<name>"
# where <name> is the LLMInferenceService's spec.model.name field (e.g.
# "facebook/opt-125m"), which is often DIFFERENT from the k8s resource name
# (e.g. "simulator"). The only reliable way to get it is to query GET
# /v1/models with a valid API key -- do NOT construct it by guessing.
#
# Args: $1 = api_key, $2 = optional owner filter substring
#       (matches the "owned_by" field, typically "<k8s-ns>/<k8s-name>")
# Echoes the first matching model id, or empty string if none found.
################################################################################
get_maas_model_id_from_api() {
    local api_key="$1"
    local owner_filter="${2:-}"

    if [ -z "$MAAS_ENDPOINT" ]; then
        get_maas_endpoint >/dev/null 2>&1 || return 1
    fi

    local models_json
    models_json=$(curl -sk "https://${MAAS_ENDPOINT}/v1/models" -H "Authorization: Bearer ${api_key}" 2>/dev/null)

    if [ -n "$owner_filter" ]; then
        echo "$models_json" | jq -r --arg f "$owner_filter" \
            '.data[] | select(.owned_by | contains($f)) | .id' 2>/dev/null | head -1
    else
        echo "$models_json" | jq -r '.data[0].id // empty' 2>/dev/null
    fi
}

################################################################################
# Build the model id used in the request body.
#   3.5+: body-based routing id ("publishers/<ns>/models/<spec.model.name>") --
#         looked up via the API (requires an api_key); falls back to a best-
#         effort guess of "publishers/<ns>/models/<name>" if no api_key given.
#   3.4-: the bare k8s resource name (used verbatim in both the URL path and body).
# Args: $1 = model_namespace, $2 = model_name (k8s resource name), $3 = optional api_key
################################################################################
get_maas_model_id() {
    local model_namespace="$1"
    local model_name="$2"
    local api_key="${3:-}"

    detect_rhoai_version
    if is_rhoai_35_or_higher; then
        if [ -n "$api_key" ]; then
            local looked_up
            looked_up=$(get_maas_model_id_from_api "$api_key" "${model_namespace}/${model_name}")
            if [ -n "$looked_up" ]; then
                echo "$looked_up"
                return 0
            fi
        fi
        echo -e "${YELLOW}⚠ Could not look up exact model id via /v1/models -- guessing (may be wrong if spec.model.name != resource name)${NC}" >&2
        echo "publishers/${model_namespace}/models/${model_name}"
    else
        echo "$model_name"
    fi
}

################################################################################
# Build the full chat completions URL for the detected RHOAI version.
#   3.5+: https://${MAAS_ENDPOINT}/v1/chat/completions (model id goes in body)
#   3.4-: https://${MAAS_ENDPOINT}/${ns}/${model}/v1/chat/completions
################################################################################
get_maas_chat_url() {
    local model_namespace="$1"
    local model_name="$2"

    if [ -z "$MAAS_ENDPOINT" ]; then
        get_maas_endpoint >/dev/null 2>&1 || return 1
    fi

    if [ "$MAAS_ROUTING" = "body" ]; then
        echo "https://${MAAS_ENDPOINT}/v1/chat/completions"
    else
        echo "https://${MAAS_ENDPOINT}/${model_namespace}/${model_name}/v1/chat/completions"
    fi
}

################################################################################
# Get Dashboard URL based on RHOAI version
# Sets: DASHBOARD_URL
################################################################################
get_dashboard_url() {
    detect_rhoai_version

    DASHBOARD_URL=""

    if is_rhoai_34_or_higher; then
        # RHOAI 3.4+: rh-ai.* (legacy data-science-gateway.* auto-redirects)
        local cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
        DASHBOARD_URL="https://rh-ai.${cluster_domain}"
    elif is_rhoai_33_or_higher; then
        # RHOAI 3.3: data-science-gateway.* URL format
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
# Get the appropriate namespace to check for MaaS infra pods (maas-api, etc)
#   3.5+: redhat-ai-gateway-infra (falls back to MaasTenantConfig discovery)
#   3.4:  redhat-ods-applications
#   3.3-: redhat-ods-applications / maas-api (legacy)
################################################################################
get_maas_pod_namespace() {
    detect_rhoai_version

    if is_rhoai_35_or_higher; then
        local infra_ns
        infra_ns=$(oc get maastenantconfig default-tenant -n models-as-a-service \
            -o jsonpath='{.status.infraNamespace}' 2>/dev/null)
        echo "${infra_ns:-redhat-ai-gateway-infra}"
    elif is_rhoai_33_or_higher; then
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
    echo -e "  Major Version:    ${GREEN}${RHOAI_MAJOR_VERSION}.${RHOAI_MINOR_VERSION}${NC}"

    get_dashboard_url
    echo -e "  Dashboard URL:    ${GREEN}$DASHBOARD_URL${NC}"

    if get_maas_endpoint; then
        echo -e "  MaaS Endpoint:    ${GREEN}$MAAS_ENDPOINT${NC}"
        echo -e "  MaaS Namespace:   ${GREEN}$MAAS_NAMESPACE${NC}"
        echo -e "  MaaS Routing:     ${GREEN}$([ "$MAAS_ROUTING" = "body" ] && echo "body-based (single /v1/chat/completions)" || echo "per-model URL")${NC}"
    else
        echo -e "  MaaS:             ${YELLOW}Not configured${NC}"
    fi

    # Check Feast operator status
    local feast_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.feastoperator.managementState}' 2>/dev/null || echo "Unknown")
    echo -e "  Feast Operator:   $([ "$feast_state" = "Managed" ] && echo "${GREEN}$feast_state${NC}" || echo "${YELLOW}$feast_state${NC}")"

    echo ""
}
