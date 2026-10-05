#!/bin/bash
################################################################################
# maas-verify.sh — MaaS TLS configuration, verification, status listing, and
# telemetry/subscription-metadata functions
# Extracted from lib/functions/rhoai.sh during the Oct 2026 modularization
# (Priority 3 of the consolidated toolkit plan).
################################################################################

# Use a local variable to avoid overwriting caller's SCRIPT_DIR
_MAAS_VERIFY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_MAAS_VERIFY_LIB_DIR/lib/utils/colors.sh" 2>/dev/null || true
source "$_MAAS_VERIFY_LIB_DIR/lib/utils/common.sh" 2>/dev/null || true

################################################################################
# MaaS 3.4+ Management Functions
# RHOAI 3.4 uses subscription-based MaaS (replaces 3.3 tier-based model)
# New CRDs: MaaSSubscription, MaaSAuthPolicy, MaaSModelRef, Tenant, ExternalModel
# RHOAI 3.5 reuses the same TLS/verification mechanics unchanged; external OIDC
# auth and body-based routing are additive/opt-in and don't change this flow.
################################################################################

# Configure MaaS TLS using OpenShift service-ca (RHOAI 3.4+ method)
# This replaces the cert-manager Certificate approach used in 3.3
configure_maas_tls_34() {
    print_header "Configuring MaaS TLS (RHOAI 3.4+ service-ca method)"

    print_step "Step 1: Annotating Authorino service for service-ca cert generation..."
    oc annotate service authorino-authorino-authorization \
        -n kuadrant-system \
        service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert \
        --overwrite

    print_step "Step 2: Waiting for authorino-server-cert secret..."
    local elapsed=0
    while [ $elapsed -lt 60 ]; do
        if oc get secret authorino-server-cert -n kuadrant-system &>/dev/null; then
            print_success "authorino-server-cert secret generated"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    print_step "Step 3: Patching Authorino CR for TLS listener..."
    oc patch authorino authorino -n kuadrant-system --type=merge --patch '{
      "spec": {
        "listener": {
          "tls": {
            "enabled": true,
            "certSecretRef": {
              "name": "authorino-server-cert"
            }
          }
        }
      }
    }'

    print_step "Step 4: Setting TLS cert validation env vars on Authorino deployment..."
    oc -n kuadrant-system set env deployment/authorino \
        SSL_CERT_FILE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt \
        REQUESTS_CA_BUNDLE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt

    print_step "Step 5: Annotating maas-default-gateway for TLS bootstrap..."
    oc annotate gateway maas-default-gateway \
        -n openshift-ingress \
        security.opendatahub.io/authorino-tls-bootstrap="true" \
        --overwrite

    print_success "MaaS TLS configuration complete (service-ca method)"
}

# Alias for RHOAI 3.5 — TLS mechanics are unchanged from 3.4
configure_maas_tls_35() {
    configure_maas_tls_34
}

# Verify the full MaaS 3.4+ deployment
verify_maas_34() {
    print_header "Verifying MaaS 3.4+ Deployment"

    local all_ok=true

    # PostgreSQL DB secret
    print_step "Checking maas-db-config secret..."
    if oc get secret maas-db-config -n redhat-ods-applications &>/dev/null; then
        local has_url=$(oc get secret maas-db-config -n redhat-ods-applications \
            -o jsonpath='{.data.DB_CONNECTION_URL}' 2>/dev/null)
        if [ -n "$has_url" ]; then
            print_success "  maas-db-config secret with DB_CONNECTION_URL"
        else
            print_warning "  maas-db-config exists but missing DB_CONNECTION_URL key"
            all_ok=false
        fi
    else
        print_warning "  maas-db-config secret not found (MaaS Tenant will be Degraded)"
        all_ok=false
    fi

    # CRDs
    print_step "Checking MaaS CRDs..."
    local expected_crds=("maassubscriptions.maas.opendatahub.io" "maasauthpolicies.maas.opendatahub.io" "maasmodelrefs.maas.opendatahub.io" "externalmodels.maas.opendatahub.io" "tenants.maas.opendatahub.io")
    for crd in "${expected_crds[@]}"; do
        if oc get crd "$crd" &>/dev/null; then
            print_success "  CRD: $crd"
        else
            print_warning "  CRD missing: $crd"
            all_ok=false
        fi
    done

    # User Workload Monitoring
    print_step "Checking User Workload Monitoring..."
    local uwm=$(oc get configmap cluster-monitoring-config -n openshift-monitoring \
        -o jsonpath='{.data.config\.yaml}' 2>/dev/null | grep -c "enableUserWorkload: true" || echo "0")
    if [ "$uwm" -gt 0 ]; then
        print_success "  User Workload Monitoring enabled"
    else
        print_warning "  User Workload Monitoring not enabled (MaaS Tenant may show Degraded)"
        all_ok=false
    fi

    # Tenant
    print_step "Checking Tenant CR..."
    local tenant_ready=$(oc get tenant default-tenant -n models-as-a-service \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$tenant_ready" = "True" ]; then
        print_success "  Tenant default-tenant is Ready"
    else
        local tenant_msg=$(oc get tenant default-tenant -n models-as-a-service \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
        print_warning "  Tenant status: ${tenant_ready:-not found} - ${tenant_msg:-no message}"
        all_ok=false
    fi

    # Gateway annotations
    print_step "Checking maas-default-gateway annotations..."
    local gw_managed=$(oc get gateway maas-default-gateway -n openshift-ingress \
        -o jsonpath='{.metadata.annotations.opendatahub\.io/managed}' 2>/dev/null)
    local gw_tls=$(oc get gateway maas-default-gateway -n openshift-ingress \
        -o jsonpath='{.metadata.annotations.security\.opendatahub\.io/authorino-tls-bootstrap}' 2>/dev/null)
    if [ "$gw_managed" = "false" ] && [ "$gw_tls" = "true" ]; then
        print_success "  Gateway annotations correct"
    else
        print_warning "  Gateway annotations incorrect or missing"
        all_ok=false
    fi

    # Authorino TLS
    print_step "Checking Authorino TLS..."
    local auth_tls=$(oc get authorino authorino -n kuadrant-system \
        -o jsonpath='{.spec.listener.tls.enabled}' 2>/dev/null)
    if [ "$auth_tls" = "true" ]; then
        print_success "  Authorino TLS listener enabled"
    else
        print_warning "  Authorino TLS listener not enabled"
        all_ok=false
    fi

    local auth_cert=$(oc get secret authorino-server-cert -n kuadrant-system &>/dev/null && echo "yes" || echo "no")
    if [ "$auth_cert" = "yes" ]; then
        print_success "  authorino-server-cert secret exists"
    else
        print_warning "  authorino-server-cert secret not found"
        all_ok=false
    fi

    # Dashboard flags
    print_step "Checking dashboard MaaS flags..."
    local maas_flag=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
        -o jsonpath='{.spec.dashboardConfig.modelAsService}' 2>/dev/null)
    local auth_policies_flag=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
        -o jsonpath='{.spec.dashboardConfig.maasAuthPolicies}' 2>/dev/null)
    if [ "$maas_flag" = "true" ] && [ "$auth_policies_flag" = "true" ]; then
        print_success "  Dashboard: modelAsService=true, maasAuthPolicies=true"
    else
        print_warning "  Dashboard MaaS flags: modelAsService=$maas_flag, maasAuthPolicies=$auth_policies_flag"
        all_ok=false
    fi

    echo ""
    if [ "$all_ok" = true ]; then
        print_success "MaaS 3.4+ deployment fully verified"
    else
        print_warning "MaaS 3.4+ deployment has issues - check warnings above"
    fi
}

# Verify the full MaaS 3.5+ deployment. NOT an alias of verify_maas_34 --
# 3.5 changes the infra namespace (redhat-ai-gateway-infra, not
# redhat-ods-applications), the tenant CRD (MaasTenantConfig, not Tenant),
# and removes the maasAuthPolicies dashboard flag entirely (the admission
# webhook rejects it if present).
verify_maas_35() {
    print_header "Verifying MaaS 3.5+ Deployment"

    local all_ok=true
    local infra_ns
    infra_ns=$(get_maas_infra_namespace 2>/dev/null || echo "redhat-ai-gateway-infra")

    # PostgreSQL DB secret -- lives in the infra namespace, not always redhat-ods-applications
    print_step "Checking maas-db-config secret in $infra_ns..."
    if oc get secret maas-db-config -n "$infra_ns" &>/dev/null; then
        local has_url=$(oc get secret maas-db-config -n "$infra_ns" \
            -o jsonpath='{.data.DB_CONNECTION_URL}' 2>/dev/null)
        if [ -n "$has_url" ]; then
            print_success "  maas-db-config secret with DB_CONNECTION_URL"
        else
            print_warning "  maas-db-config exists but missing DB_CONNECTION_URL key"
            all_ok=false
        fi
    else
        print_warning "  maas-db-config secret not found in $infra_ns (MaaS Tenant will be Degraded)"
        all_ok=false
    fi

    # CRDs -- 3.5 adds aitenants, configs, maastenantconfigs on top of the 3.4 set
    print_step "Checking MaaS CRDs..."
    local expected_crds=("maassubscriptions.maas.opendatahub.io" "maasauthpolicies.maas.opendatahub.io" "maasmodelrefs.maas.opendatahub.io" "maastenantconfigs.maas.opendatahub.io" "aitenants.maas.opendatahub.io" "configs.maas.opendatahub.io")
    for crd in "${expected_crds[@]}"; do
        if oc get crd "$crd" &>/dev/null; then
            print_success "  CRD: $crd"
        else
            print_warning "  CRD missing: $crd"
            all_ok=false
        fi
    done

    # User Workload Monitoring
    print_step "Checking User Workload Monitoring..."
    local uwm=$(oc get configmap cluster-monitoring-config -n openshift-monitoring \
        -o jsonpath='{.data.config\.yaml}' 2>/dev/null | grep -c "enableUserWorkload: true" || echo "0")
    if [ "$uwm" -gt 0 ]; then
        print_success "  User Workload Monitoring enabled"
    else
        print_warning "  User Workload Monitoring not enabled (MaaS Tenant may show Degraded)"
        all_ok=false
    fi

    # MaasTenantConfig -- replaces the 3.4-only Tenant CRD
    print_step "Checking MaasTenantConfig CR..."
    local tenant_ready=$(oc get maastenantconfig default-tenant -n models-as-a-service \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$tenant_ready" = "True" ]; then
        print_success "  MaasTenantConfig default-tenant is Ready"
    else
        local tenant_msg=$(oc get maastenantconfig default-tenant -n models-as-a-service \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
        print_warning "  MaasTenantConfig status: ${tenant_ready:-not found} - ${tenant_msg:-no message}"
        all_ok=false
    fi

    # Gateway annotations
    print_step "Checking maas-default-gateway annotations..."
    local gw_managed=$(oc get gateway maas-default-gateway -n openshift-ingress \
        -o jsonpath='{.metadata.annotations.opendatahub\.io/managed}' 2>/dev/null)
    local gw_tls=$(oc get gateway maas-default-gateway -n openshift-ingress \
        -o jsonpath='{.metadata.annotations.security\.opendatahub\.io/authorino-tls-bootstrap}' 2>/dev/null)
    if [ "$gw_managed" = "false" ] && [ "$gw_tls" = "true" ]; then
        print_success "  Gateway annotations correct"
    else
        print_warning "  Gateway annotations incorrect or missing"
        all_ok=false
    fi

    # Authorino TLS
    print_step "Checking Authorino TLS..."
    local auth_tls=$(oc get authorino authorino -n kuadrant-system \
        -o jsonpath='{.spec.listener.tls.enabled}' 2>/dev/null)
    if [ "$auth_tls" = "true" ]; then
        print_success "  Authorino TLS listener enabled"
    else
        print_warning "  Authorino TLS listener not enabled"
        all_ok=false
    fi

    local auth_cert=$(oc get secret authorino-server-cert -n kuadrant-system &>/dev/null && echo "yes" || echo "no")
    if [ "$auth_cert" = "yes" ]; then
        print_success "  authorino-server-cert secret exists"
    else
        print_warning "  authorino-server-cert secret not found"
        all_ok=false
    fi

    # Dashboard flags -- maasAuthPolicies is REMOVED in 3.5; the admission
    # webhook rejects the manifest entirely if it's present, so we must NOT check for it.
    print_step "Checking dashboard MaaS flags..."
    local maas_flag=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
        -o jsonpath='{.spec.dashboardConfig.modelAsService}' 2>/dev/null)
    if [ "$maas_flag" = "true" ]; then
        print_success "  Dashboard: modelAsService=true"
    else
        print_warning "  Dashboard MaaS flag modelAsService=$maas_flag"
        all_ok=false
    fi
    local stale_auth_policies_flag=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
        -o jsonpath='{.spec.dashboardConfig.maasAuthPolicies}' 2>/dev/null)
    if [ -n "$stale_auth_policies_flag" ]; then
        print_warning "  maasAuthPolicies flag is set but REMOVED in 3.5 -- the admission webhook should reject this; verify manifests don't set it"
    fi

    echo ""
    if [ "$all_ok" = true ]; then
        print_success "MaaS 3.5+ deployment fully verified"
    else
        print_warning "MaaS 3.5+ deployment has issues - check warnings above"
    fi
}

# List MaaS subscriptions
list_maas_subscriptions() {
    print_header "MaaS Subscriptions"
    oc get maassubscriptions -n models-as-a-service -o wide 2>/dev/null || \
        print_info "No subscriptions found or MaaS namespace not created yet"
}

# List MaaS authorization policies
list_maas_auth_policies() {
    print_header "MaaS Authorization Policies"
    oc get maasauthpolicies -n models-as-a-service -o wide 2>/dev/null || \
        print_info "No authorization policies found"
}

# List MaaS model references
list_maas_models() {
    print_header "MaaS Model References"
    oc get maasmodelrefs -A -o wide 2>/dev/null || \
        print_info "No model references found"
}

# Show MaaS Tenant status
show_maas_tenant() {
    print_header "MaaS Tenant Status"
    oc get tenant -n models-as-a-service -o wide 2>/dev/null || \
        print_info "No tenant found"
    echo ""
    oc get tenant default-tenant -n models-as-a-service -o yaml 2>/dev/null | \
        grep -A 20 "status:" || true
}

################################################################################
# MaaS Telemetry & Subscription Metadata (Interactive)
################################################################################

# Interactive wrapper for enabling MaaS telemetry metrics
# Shows current state, explains the 4 metrics, and patches MaasTenantConfig
configure_maas_telemetry_interactive() {
    print_header "Configure MaaS Telemetry"

    if ! oc get maastenantconfig default-tenant -n models-as-a-service &>/dev/null; then
        print_error "MaasTenantConfig not found — MaaS may not be configured yet"
        return 1
    fi

    # Show current state
    local current=$(oc get maastenantconfig default-tenant -n models-as-a-service \
        -o jsonpath='{.spec.telemetry}' 2>/dev/null)
    echo -e "${CYAN}Current telemetry configuration:${NC}"
    if [ -n "$current" ] && [ "$current" != "{}" ]; then
        echo "$current" | python3 -m json.tool 2>/dev/null || echo "  $current"
    else
        echo "  Not configured"
    fi
    echo ""

    echo -e "${CYAN}Available telemetry metrics:${NC}"
    echo "  captureGroup         — Track usage by OpenShift group"
    echo "  captureModelUsage    — Track per-model token consumption"
    echo "  captureOrganization  — Track usage by organization"
    echo "  captureUser          — Track usage by individual user"
    echo ""

    read -p "Enable all telemetry metrics? (Y/n): " enable_all
    if [[ "$enable_all" =~ ^[Nn]$ ]]; then
        print_info "Telemetry unchanged"
        return 0
    fi

    # Reuse the same patch logic as the install script
    local telemetry_enabled=$(oc get maastenantconfig default-tenant -n models-as-a-service \
        -o jsonpath='{.spec.telemetry.enabled}' 2>/dev/null)
    if [ "$telemetry_enabled" = "true" ]; then
        print_success "MaaS telemetry already enabled"
        return 0
    fi

    if oc patch maastenantconfig default-tenant -n models-as-a-service --type=merge -p '{
        "spec": {
            "telemetry": {
                "enabled": true,
                "metrics": {
                    "captureGroup": true,
                    "captureModelUsage": true,
                    "captureOrganization": true,
                    "captureUser": true
                }
            }
        }
    }' 2>/dev/null; then
        print_success "MaaS telemetry enabled (group, model usage, organization, user metrics)"
    else
        print_warning "Could not enable MaaS telemetry — apply manually:"
        echo "  oc patch maastenantconfig default-tenant -n models-as-a-service --type=merge \\"
        echo "    -p '{\"spec\":{\"telemetry\":{\"enabled\":true,\"metrics\":{\"captureGroup\":true,\"captureModelUsage\":true,\"captureOrganization\":true,\"captureUser\":true}}}}'"
    fi
}

# Interactive function to tag a MaaS subscription with cost attribution metadata
# Lists all subscriptions, lets user pick one, and applies costCenter/organizationId
configure_maas_subscription_metadata_interactive() {
    print_header "Tag MaaS Subscription Metadata"

    # List all subscriptions
    local subs
    subs=$(oc get maassubscription -n models-as-a-service --no-headers \
        -o custom-columns='NAME:.metadata.name' 2>/dev/null)

    if [ -z "$subs" ]; then
        print_error "No MaaS subscriptions found in models-as-a-service"
        print_info "Deploy a model and publish to MaaS first"
        return 1
    fi

    echo -e "${CYAN}Available MaaS Subscriptions:${NC}"
    echo ""
    local idx=1
    local sub_array=()
    while IFS= read -r sub; do
        [ -z "$sub" ] && continue
        local current_meta=$(oc get maassubscription "$sub" -n models-as-a-service \
            -o jsonpath='{.spec.tokenMetadata}' 2>/dev/null)
        local meta_display="(no metadata)"
        if [ -n "$current_meta" ] && [ "$current_meta" != "{}" ]; then
            meta_display="$current_meta"
        fi
        echo -e "  ${YELLOW}$idx)${NC} $sub  $meta_display"
        sub_array+=("$sub")
        ((idx++))
    done <<< "$subs"
    echo ""

    read -p "Select subscription (1-${#sub_array[@]}): " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#sub_array[@]}" ]; then
        print_error "Invalid selection"
        return 1
    fi

    local selected="${sub_array[$((choice - 1))]}"
    echo ""
    print_info "Selected: $selected"
    echo ""

    read -p "Cost Center (e.g., 101, leave empty to skip): " cost_center
    read -p "Organization ID (e.g., APAC AI, leave empty to skip): " org_id

    if [ -z "$cost_center" ] && [ -z "$org_id" ]; then
        print_info "No metadata provided — skipping"
        return 0
    fi

    local patch='{"spec":{"tokenMetadata":{'
    local fields=()
    [ -n "$cost_center" ] && fields+=("\"costCenter\":\"$cost_center\"")
    [ -n "$org_id" ] && fields+=("\"organizationId\":\"$org_id\"")
    patch+=$(IFS=,; echo "${fields[*]}")
    patch+='}}}'

    if oc patch maassubscription "$selected" -n models-as-a-service \
        --type=merge -p "$patch" 2>/dev/null; then
        print_success "Subscription '$selected' tagged"
        echo "  costCenter: ${cost_center:-<not set>}"
        echo "  organizationId: ${org_id:-<not set>}"
    else
        print_error "Failed to patch subscription"
    fi
}
