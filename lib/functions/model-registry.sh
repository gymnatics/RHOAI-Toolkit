#!/bin/bash
################################################################################
# model-registry.sh — Model Registry setup functions
# Extracted from lib/functions/rhoai.sh during the Oct 2026 modularization
# (Priority 3 of the consolidated toolkit plan).
################################################################################

# Use a local variable to avoid overwriting caller's SCRIPT_DIR
_MODEL_REGISTRY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_MODEL_REGISTRY_LIB_DIR/lib/utils/colors.sh" 2>/dev/null || true
source "$_MODEL_REGISTRY_LIB_DIR/lib/utils/common.sh" 2>/dev/null || true

################################################################################
# Model Registry Setup
################################################################################

# Full idempotent Model Registry setup workflow.
# Per RHAIE 3.3 Guide: enables the component, creates namespace, deploys MySQL,
# creates ModelRegistry CR, enables dashboard visibility, verifies.
# Skips any step that is already completed.
# Usage: setup_model_registry [registry-name]
setup_model_registry() {
    local registry_name="${1:-}"
    local registry_ns="rhoai-model-registries"
    
    print_header "Setup Model Registry"
    echo "  Full workflow per RHAIE 3.3 Guide Chapter 2-3"
    echo "  (Steps already completed will be skipped)"
    echo ""
    
    ############################################################################
    # Step 1: Enable modelregistry component in DSC
    ############################################################################
    print_step "Step 1: Checking modelregistry component in DataScienceCluster..."
    
    local mr_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.modelregistry.managementState}' 2>/dev/null || echo "")
    
    if [ "$mr_state" = "Managed" ]; then
        print_success "modelregistry already Managed in DSC [SKIP]"
    else
        print_step "Enabling modelregistry in DataScienceCluster..."
        oc patch datasciencecluster default-dsc --type=merge -p '{
            "spec": {
                "components": {
                    "modelregistry": {
                        "managementState": "Managed",
                        "registriesNamespace": "rhoai-model-registries"
                    }
                }
            }
        }'
        print_success "modelregistry enabled in DSC"
        
        # Wait for operator to reconcile
        print_step "Waiting for Model Registry operator to be ready..."
        local elapsed=0
        while [ $elapsed -lt 90 ]; do
            if oc get modelregistry default-modelregistry -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Ready"; then
                print_success "Model Registry operator is ready"
                break
            fi
            sleep 5
            elapsed=$((elapsed + 5))
        done
    fi
    
    ############################################################################
    # Step 2: Enable Model Registry in dashboard
    ############################################################################
    print_step "Step 2: Checking dashboard configuration..."
    
    local mr_disabled=$(oc get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications -o jsonpath='{.spec.dashboardConfig.disableModelRegistry}' 2>/dev/null || echo "true")
    
    if [ "$mr_disabled" = "false" ]; then
        print_success "Model Registry enabled in dashboard [SKIP]"
    else
        print_step "Enabling Model Registry in dashboard..."
        oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications \
            --type=merge -p '{"spec":{"dashboardConfig":{"disableModelRegistry":false}}}'
        print_success "Model Registry enabled in dashboard"
    fi
    
    ############################################################################
    # Step 3: Ensure registries namespace exists
    ############################################################################
    print_step "Step 3: Checking namespace '$registry_ns'..."
    
    if oc get namespace "$registry_ns" &>/dev/null; then
        print_success "Namespace '$registry_ns' exists [SKIP]"
    else
        oc create namespace "$registry_ns"
        print_success "Namespace '$registry_ns' created"
    fi
    
    ############################################################################
    # Step 4: Get registry name (interactive or argument)
    ############################################################################
    if [ -z "$registry_name" ]; then
        echo ""
        # Show existing registries if any
        local existing=$(oc get modelregistry.modelregistry.opendatahub.io -n "$registry_ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        if [ -n "$existing" ]; then
            print_info "Existing registries: $existing"
        fi
        
        echo -e "${BLUE}Enter a name for the Model Registry:${NC}"
        echo "  Examples: team-models, production-registry, shared-registry"
        echo ""
        read -p "Registry name [model-registry]: " registry_name
        registry_name="${registry_name:-model-registry}"
    fi
    
    # Sanitize name (lowercase, alphanumeric + hyphens only)
    registry_name=$(echo "$registry_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/^-//;s/-$//')
    
    ############################################################################
    # Step 5: Check if this registry already exists and is ready
    ############################################################################
    print_step "Step 5: Checking if registry '$registry_name' exists..."
    
    local mr_exists=$(oc get modelregistry.modelregistry.opendatahub.io "$registry_name" -n "$registry_ns" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
    
    if [ "$mr_exists" = "True" ]; then
        print_success "Model Registry '$registry_name' already exists and is ready [SKIP]"
        _show_model_registry_summary "$registry_name" "$registry_ns"
        return 0
    fi
    
    ############################################################################
    # Step 6: Deploy MySQL database (if not already running for this registry)
    ############################################################################
    local mysql_deploy_name="${registry_name}-mysql"
    local mysql_svc_name="${registry_name}-mysql"
    local mysql_db="mlmddb"
    local mysql_user="mlmd"
    local mysql_password=""
    local mysql_root_password=""
    local password_source="generated"
    
    print_step "Step 6: Deploying MySQL 8.0 database..."
    
    # Check if MySQL is already running for this registry
    if oc get deployment "$mysql_deploy_name" -n "$registry_ns" &>/dev/null; then
        local mysql_ready=$(oc get pods -n "$registry_ns" -l app="$mysql_deploy_name" -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$mysql_ready" = "True" ]; then
            print_success "MySQL '$mysql_deploy_name' already running [SKIP]"
        else
            print_info "MySQL deployment exists but not ready, waiting..."
            local elapsed=0
            while [ $elapsed -lt 90 ]; do
                mysql_ready=$(oc get pods -n "$registry_ns" -l app="$mysql_deploy_name" -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
                if [ "$mysql_ready" = "True" ]; then
                    print_success "MySQL is ready"
                    break
                fi
                sleep 5
                elapsed=$((elapsed + 5))
            done
        fi
    else
        # Check if credentials secret already exists (re-use if so)
        if oc get secret "${mysql_deploy_name}-credentials" -n "$registry_ns" &>/dev/null; then
            print_info "Re-using existing MySQL credentials secret"
            password_source="existing-secret"
        else
            # Prompt for password or generate random
            echo ""
            local default_pw=$(head -c 16 /dev/urandom 2>/dev/null | base64 | tr -dc 'a-zA-Z0-9' | head -c 16 || echo "mlmd$(date +%s | tail -c 8)")
            echo -e "${BLUE}MySQL password configuration:${NC}"
            echo "  User: $mysql_user | Database: $mysql_db"
            echo ""
            read -p "MySQL password (leave empty for auto-generated): " user_password
            
            if [ -n "$user_password" ]; then
                mysql_password="$user_password"
                password_source="user-provided"
            else
                mysql_password="$default_pw"
                password_source="generated"
            fi
            
            local default_root_pw=$(head -c 16 /dev/urandom 2>/dev/null | base64 | tr -dc 'a-zA-Z0-9' | head -c 16 || echo "root$(date +%s | tail -c 8)")
            read -p "MySQL root password (leave empty for auto-generated): " user_root_password
            
            if [ -n "$user_root_password" ]; then
                mysql_root_password="$user_root_password"
            else
                mysql_root_password="$default_root_pw"
            fi
            
            export MYSQL_DEPLOY_NAME="$mysql_deploy_name"
            export REGISTRY_NS="$registry_ns"
            export MYSQL_DB="$mysql_db"
            export MYSQL_USER="$mysql_user"
            export MYSQL_PASSWORD="$mysql_password"
            export MYSQL_ROOT_PASSWORD="$mysql_root_password"
            if ! envsubst '${MYSQL_DEPLOY_NAME} ${REGISTRY_NS} ${MYSQL_DB} ${MYSQL_USER} ${MYSQL_PASSWORD} ${MYSQL_ROOT_PASSWORD}' \
                < "$_MODEL_REGISTRY_LIB_DIR/lib/manifests/model-registry/mysql-secret.yaml" | oc apply -f -; then
                unset MYSQL_DEPLOY_NAME REGISTRY_NS MYSQL_DB MYSQL_USER MYSQL_PASSWORD MYSQL_ROOT_PASSWORD
                print_error "Failed to create MySQL credentials secret '${mysql_deploy_name}-credentials' -- aborting before creating the ModelRegistry CR (a CR referencing a missing secret would be permanently broken)"
                return 1
            fi
            unset MYSQL_DEPLOY_NAME REGISTRY_NS MYSQL_DB MYSQL_USER MYSQL_PASSWORD MYSQL_ROOT_PASSWORD
            print_success "MySQL credentials secret created"
        fi

        # Hard gate: the secret must actually exist before we proceed, whether
        # it was just created above or the "existing-secret" branch was taken.
        if ! oc get secret "${mysql_deploy_name}-credentials" -n "$registry_ns" &>/dev/null; then
            print_error "MySQL credentials secret '${mysql_deploy_name}-credentials' still not found -- aborting before creating the ModelRegistry CR"
            return 1
        fi

        export MYSQL_DEPLOY_NAME="$mysql_deploy_name"
        export REGISTRY_NS="$registry_ns"
        export MYSQL_SVC_NAME="$mysql_svc_name"
        if ! envsubst '${MYSQL_DEPLOY_NAME} ${REGISTRY_NS} ${MYSQL_SVC_NAME}' \
            < "$_MODEL_REGISTRY_LIB_DIR/lib/manifests/model-registry/mysql-deploy.yaml" | oc apply -f -; then
            unset MYSQL_DEPLOY_NAME REGISTRY_NS MYSQL_SVC_NAME
            print_error "Failed to create MySQL Deployment/Service -- aborting before creating the ModelRegistry CR"
            return 1
        fi
        unset MYSQL_DEPLOY_NAME REGISTRY_NS MYSQL_SVC_NAME
        
        print_step "Waiting for MySQL to be ready..."
        local elapsed=0
        while [ $elapsed -lt 120 ]; do
            if oc get pods -n "$registry_ns" -l app="$mysql_deploy_name" -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
                print_success "MySQL is ready"
                break
            fi
            sleep 5
            elapsed=$((elapsed + 5))
            echo "  Waiting for MySQL... (${elapsed}s elapsed)"
        done
        
        if [ $elapsed -ge 120 ]; then
            print_warning "MySQL did not report Ready within 120s"
        fi

        # Hard gate: never proceed to create the ModelRegistry CR unless the
        # secret AND Deployment actually exist -- a CR created against a
        # missing/failed MySQL setup reconciles into a permanently-broken
        # CreateContainerConfigError state (secret not found) with no
        # automatic recovery, since nothing re-triggers Step 6 once the CR
        # exists (Step 5's "already exists" check only skips on Available=True,
        # but a broken CR sitting there forever also blocks a clean re-run
        # from ever getting back here to retry MySQL). Fail loudly instead.
        if ! oc get secret "${mysql_deploy_name}-credentials" -n "$registry_ns" &>/dev/null; then
            print_error "MySQL credentials secret missing after setup -- aborting before creating the ModelRegistry CR. Fix MySQL manually, then re-run this function."
            return 1
        fi
        if ! oc get deployment "$mysql_deploy_name" -n "$registry_ns" &>/dev/null; then
            print_error "MySQL Deployment '$mysql_deploy_name' missing after setup -- aborting before creating the ModelRegistry CR. Fix MySQL manually, then re-run this function."
            return 1
        fi
    fi
    
    ############################################################################
    # Step 7: Create ModelRegistry CR
    ############################################################################
    print_step "Step 7: Creating ModelRegistry '$registry_name'..."
    
    if oc get modelregistry.modelregistry.opendatahub.io "$registry_name" -n "$registry_ns" &>/dev/null; then
        print_info "ModelRegistry CR already exists, checking status..."
    else
        export REGISTRY_NAME="$registry_name"
        export REGISTRY_NS="$registry_ns"
        export MYSQL_SVC_NAME="$mysql_svc_name"
        export MYSQL_DB="$mysql_db"
        export MYSQL_USER="$mysql_user"
        export MYSQL_DEPLOY_NAME="$mysql_deploy_name"
        envsubst '${REGISTRY_NAME} ${REGISTRY_NS} ${MYSQL_SVC_NAME} ${MYSQL_DB} ${MYSQL_USER} ${MYSQL_DEPLOY_NAME}' \
            < "$_MODEL_REGISTRY_LIB_DIR/lib/manifests/model-registry/modelregistry-cr.yaml" | oc apply -f -
        unset REGISTRY_NAME REGISTRY_NS MYSQL_SVC_NAME MYSQL_DB MYSQL_USER MYSQL_DEPLOY_NAME
    fi
    
    # Wait for ModelRegistry to be ready
    print_step "Waiting for Model Registry to be ready..."
    local elapsed=0
    while [ $elapsed -lt 120 ]; do
        local mr_ready=$(oc get modelregistry.modelregistry.opendatahub.io "$registry_name" -n "$registry_ns" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$mr_ready" = "True" ]; then
            print_success "Model Registry '$registry_name' is ready!"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo "  Waiting for Model Registry... (${elapsed}s elapsed)"
    done
    
    ############################################################################
    # Step 8: Verify and show summary
    ############################################################################
    _show_model_registry_summary "$registry_name" "$registry_ns" "$mysql_svc_name" "$mysql_db" "$mysql_user" "$mysql_password" "$mysql_root_password" "$password_source"
}

# Internal helper: display model registry summary
_show_model_registry_summary() {
    local registry_name="$1"
    local registry_ns="$2"
    local mysql_svc="${3:-}"
    local mysql_db="${4:-}"
    local mysql_user="${5:-}"
    local mysql_password="${6:-}"
    local mysql_root_password="${7:-}"
    local password_source="${8:-}"
    
    echo ""
    print_header "Model Registry Setup Complete"
    echo ""
    echo -e "${BLUE}Registry Name:${NC}  $registry_name"
    echo -e "${BLUE}Namespace:${NC}      $registry_ns"
    echo ""
    
    # Show pods
    echo -e "${BLUE}Pods:${NC}"
    oc get pods -n "$registry_ns" -l "app.kubernetes.io/instance=$registry_name" --no-headers 2>/dev/null | sed 's/^/  /'
    oc get pods -n "$registry_ns" -l "app=${registry_name}-mysql" --no-headers 2>/dev/null | sed 's/^/  /'
    echo ""
    
    # Show REST route
    local rest_route=$(oc get route -n "$registry_ns" --no-headers 2>/dev/null | grep "$registry_name" | awk '{print $2}' | head -1)
    if [ -n "$rest_route" ]; then
        echo -e "${BLUE}REST API:${NC}       https://$rest_route"
        echo ""
    fi
    
    # MySQL connection details
    if [ -n "$mysql_svc" ]; then
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${MAGENTA}MySQL Connection Details${NC}"
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BLUE}Host:${NC}          ${mysql_svc}.${registry_ns}.svc.cluster.local"
        echo -e "  ${BLUE}Port:${NC}          3306"
        echo -e "  ${BLUE}Database:${NC}      $mysql_db"
        echo -e "  ${BLUE}User:${NC}          $mysql_user"
        if [ -n "$mysql_password" ] && [ "$password_source" != "existing-secret" ]; then
            echo -e "  ${BLUE}Password:${NC}      $mysql_password"
            echo -e "  ${BLUE}Root Password:${NC} $mysql_root_password"
            echo ""
            echo -e "  ${YELLOW}⚠ Save these credentials! They are stored in:${NC}"
            echo "    oc get secret ${registry_name}-mysql-credentials -n $registry_ns -o yaml"
        else
            echo -e "  ${BLUE}Password:${NC}      (stored in secret ${registry_name}-mysql-credentials)"
            echo ""
            echo -e "  ${CYAN}Retrieve credentials:${NC}"
            echo "    oc get secret ${registry_name}-mysql-credentials -n $registry_ns -o jsonpath='{.data.MYSQL_PASSWORD}' | base64 -d"
            echo "    oc get secret ${registry_name}-mysql-credentials -n $registry_ns -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d"
        fi
        echo ""
        echo -e "  ${CYAN}Connect from a pod:${NC}"
        echo "    mysql -h ${mysql_svc}.${registry_ns}.svc.cluster.local -u $mysql_user -p $mysql_db"
        echo ""
        echo -e "  ${CYAN}Port-forward for local access:${NC}"
        echo "    oc port-forward svc/${mysql_svc} 3306:3306 -n $registry_ns"
        echo "    mysql -h 127.0.0.1 -u $mysql_user -p $mysql_db"
        echo ""
    fi
    
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Dashboard Access:${NC}"
    echo "  Settings → Model resources and operations → AI registry settings"
    echo ""
    echo -e "${YELLOW}CLI:${NC}"
    echo "  oc get modelregistry.modelregistry.opendatahub.io -n $registry_ns"
    echo ""
    echo -e "${YELLOW}Python SDK:${NC}"
    if [ -n "$rest_route" ]; then
        echo "  from model_registry import ModelRegistry"
        echo "  registry = ModelRegistry(server_address=\"https://$rest_route\", author=\"user@example.com\")"
    else
        echo "  # Get route: oc get route -n $registry_ns | grep $registry_name"
    fi
    echo ""
    echo -e "${YELLOW}Permissions:${NC}"
    echo "  # Add users to auto-created group:"
    echo "  oc adm groups add-users ${registry_name}-users <username>"
    echo ""
}
