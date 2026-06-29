#!/bin/bash
################################################################################
# RHOAI Management Menu Functions
# Extracted from rhoai-toolkit.sh — interactive menus that delegate to
# lib/functions/rhoai.sh and scripts/* for actual cluster work.
################################################################################

_RHOAI_MGMT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

enable_dashboard_features_interactive() {
    print_header "Enable Dashboard Features"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        echo "Please login first: oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to OpenShift cluster"
    echo ""
    
    # Check if script exists
    local script="$SCRIPT_DIR/scripts/enable-dashboard-features.sh"
    if [ ! -f "$script" ]; then
        print_error "Script not found at: $script"
        return 1
    fi
    
    # Run the script
    "$script"
    
    return $?
}

add_model_to_playground_interactive() {
    print_header "Add Model to Playground"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        echo "Please login first: oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to OpenShift cluster"
    echo ""
    
    # Check if script exists
    local script="$SCRIPT_DIR/scripts/add-model-to-playground.sh"
    if [ ! -f "$script" ]; then
        print_error "Script not found at: $script"
        return 1
    fi
    
    # Run the script
    "$script"
    
    return $?
}

quick_start_wizard() {
    print_header "🚀 Quick Start Wizard"
    
    echo -e "${CYAN}This wizard will guide you through the typical post-installation workflow:${NC}"
    echo ""
    echo "  1️⃣  Enable Dashboard Features"
    echo "  2️⃣  Deploy a Model"
    echo "  3️⃣  Add Model to Playground"
    echo "  4️⃣  Setup MCP Servers"
    echo ""
    echo -e "${YELLOW}This is recommended after a fresh RHOAI installation.${NC}"
    echo ""
    
    read -p "Continue with Quick Start? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Quick Start cancelled"
        return 0
    fi
    
    echo ""
    
    local overall_success=true
    
    # Step 1: Enable Dashboard Features
    print_header "Step 1/4: Enable Dashboard Features"
    if enable_dashboard_features_interactive; then
        print_success "✓ Dashboard features enabled"
    else
        print_error "✗ Failed to enable dashboard features"
        overall_success=false
        echo ""
        read -p "Continue anyway? (y/N): " continue_prompt
        if [[ ! "$continue_prompt" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    echo ""
    sleep 2
    
    # Step 2: Deploy Model
    print_header "Step 2/4: Deploy Model"
    echo -e "${YELLOW}Would you like to deploy a model now?${NC}"
    read -p "Deploy model? (Y/n): " deploy_prompt
    
    if [[ ! "$deploy_prompt" =~ ^[Nn]$ ]]; then
        if deploy_model_interactive; then
            print_success "✓ Model deployed"
            local model_deployed=true
        else
            print_warning "⚠ Model deployment skipped or failed"
            model_deployed=false
        fi
    else
        print_info "Skipping model deployment"
        model_deployed=false
    fi
    
    echo ""
    sleep 2
    
    # Step 3: Add Model to Playground (only if model was deployed)
    if [ "$model_deployed" = true ]; then
        print_header "Step 3/4: Add Model to Playground"
        echo -e "${YELLOW}Would you like to add the deployed model to the playground?${NC}"
        read -p "Add to playground? (Y/n): " playground_prompt
        
        if [[ ! "$playground_prompt" =~ ^[Nn]$ ]]; then
            if add_model_to_playground_interactive; then
                print_success "✓ Model added to playground"
            else
                print_warning "⚠ Failed to add model to playground"
            fi
        else
            print_info "Skipping playground setup"
        fi
    else
        print_header "Step 3/4: Add Model to Playground"
        print_info "⏭️  Skipped (no model deployed)"
    fi
    
    echo ""
    sleep 2
    
    # Step 4: Setup MCP Servers
    print_header "Step 4/4: Setup MCP Servers"
    echo -e "${YELLOW}Would you like to setup MCP servers for tool calling?${NC}"
    read -p "Setup MCP servers? (Y/n): " mcp_prompt
    
    if [[ ! "$mcp_prompt" =~ ^[Nn]$ ]]; then
        if setup_mcp_servers_interactive; then
            print_success "✓ MCP servers configured"
        else
            print_warning "⚠ MCP servers setup skipped or failed"
        fi
    else
        print_info "Skipping MCP servers setup"
    fi
    
    echo ""
    
    # Final summary
    print_header "✅ Quick Start Complete!"
    
    echo -e "${GREEN}Your RHOAI environment is now fully configured!${NC}"
    echo ""
    
    if [ "$model_deployed" = true ]; then
        echo -e "${CYAN}What you can do now:${NC}"
        echo "  • Access GenAI Playground to test your model"
        echo "  • Use MCP servers for tool calling"
        echo "  • Deploy additional models"
        echo "  • Register models in Model Registry"
    else
        echo -e "${CYAN}Next steps:${NC}"
        echo "  • Deploy a model (Option 2)"
        echo "  • Add it to playground (Option 3)"
        echo "  • Explore GenAI Studio features"
    fi
    
    echo ""
    
    local dashboard_url=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null)
    if [ -n "$dashboard_url" ]; then
        echo -e "${GREEN}📊 RHOAI Dashboard:${NC}"
        echo "   https://$dashboard_url"
        echo ""
    fi
    
    return 0
}

show_help() {
    print_header "📚 Help & Quick Reference"
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Direct Script Access${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}You can run these scripts directly without using the menu:${NC}"
    echo ""
    echo -e "${GREEN}Installation:${NC}"
    echo "  ./scripts/openshift-installer-master.sh"
    echo "  ./scripts/create-gpu-machineset.sh"
    echo ""
    echo -e "${GREEN}RHOAI Configuration:${NC}"
    echo "  ./scripts/enable-dashboard-features.sh"
    echo "  ./scripts/create-hardware-profile.sh <namespace>"
    echo "  ./scripts/fix-gpu-resourceflavor.sh"
    echo ""
    echo -e "${GREEN}Model Deployment:${NC}"
    echo "  ./scripts/deploy-llmd-model.sh"
    echo "  ./scripts/add-model-to-playground.sh"
    echo ""
    echo -e "${GREEN}Services:${NC}"
    echo "  ./scripts/setup-maas.sh"
    echo "  ./scripts/setup-mcp-servers.sh"
    echo ""
    echo -e "${GREEN}Utilities:${NC}"
    echo "  ./scripts/cleanup-all.sh [--local-only]"
    echo "  ./scripts/manage-kubeconfig.sh"
    echo ""
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Command-Line Flags${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Run rhoai-toolkit.sh with options:${NC}"
    echo ""
    echo "  --with-maas          Auto-enable MaaS (non-interactive)"
    echo "  --skip-maas          Skip MaaS setup"
    echo "  --maas-only          Only setup MaaS (assumes RHOAI exists)"
    echo "  --skip-openshift     Skip OpenShift installation"
    echo "  --skip-gpu           Skip GPU node creation"
    echo "  --skip-rhoai         Skip RHOAI installation"
    echo ""
    echo -e "${GREEN}Examples:${NC}"
    echo "  ./rhoai-toolkit.sh --skip-openshift --with-maas"
    echo "  ./rhoai-toolkit.sh --maas-only"
    echo ""
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Documentation${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}Main Documentation:${NC}"
    echo "  README.md                    - Quick start guide"
    echo "  QUICK-REFERENCE.md           - Command cheat sheet"
    echo "  docs/README.md               - Documentation index"
    echo "  docs/TROUBLESHOOTING.md      - Common issues"
    echo ""
    echo -e "${GREEN}Feature Guides:${NC}"
    echo "  docs/guides/MODEL-REGISTRY.md"
    echo "  docs/guides/GENAI-PLAYGROUND-INTEGRATION.md"
    echo "  docs/guides/MCP-SERVERS.md"
    echo "  docs/guides/TOOL-CALLING-GUIDE.md"
    echo "  docs/guides/GPU-TAINTS-RHOAI3.md"
    echo ""
    echo -e "${GREEN}Reference:${NC}"
    echo "  docs/reference/KSERVE-DEPLOYMENT-MODES.md"
    echo "  docs/reference/GPU-RESOURCEFLAVOR-CONFIGURATION.md"
    echo ""
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Common Tasks${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Check cluster status:${NC}"
    echo "  oc get nodes"
    echo "  oc get clusteroperators"
    echo ""
    echo -e "${YELLOW}Check RHOAI status:${NC}"
    echo "  oc get datasciencecluster -n redhat-ods-applications"
    echo "  oc get pods -n redhat-ods-applications"
    echo ""
    echo -e "${YELLOW}Check deployed models:${NC}"
    echo "  oc get inferenceservice -A"
    echo "  oc get llmisvc -A"
    echo ""
    echo -e "${YELLOW}Get dashboard URL:${NC}"
    echo "  oc get route rhods-dashboard -n redhat-ods-applications"
    echo ""
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

model_management_submenu() {
    while true; do
        show_model_management_submenu
        read -p "Select an option (1-9, 0): " model_choice
        
        case $model_choice in
            1)
                deploy_model_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                deploy_predictive_model_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                add_model_to_playground_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                setup_model_storage_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                download_hf_model_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                "$SCRIPT_DIR/scripts/add-serving-runtime.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                create_hardware_profile_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                create_hardware_profile_quick
                echo ""
                read -p "Press Enter to continue..."
                ;;
            9)
                "$SCRIPT_DIR/scripts/manage-model-catalog.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                print_error "Invalid option. Please select 1-9 or 0."
                sleep 1
                ;;
        esac
    done
}

ai_services_submenu() {
    while true; do
        show_ai_services_submenu
        read -p "Select an option (1-7, 0): " ai_choice
        
        case $ai_choice in
            1)
                # Setup MaaS (Version-Aware)
                "$SCRIPT_DIR/scripts/setup-maas.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                setup_llamastack_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                # Enable LlamaStack Operator
                print_header "Enable LlamaStack Operator"
                local llamastack_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.llamastackoperator.managementState}' 2>/dev/null || echo "Unknown")
                echo "Current LlamaStack state: $llamastack_state"
                if [[ "$llamastack_state" == "Managed" ]]; then
                    print_success "LlamaStack operator already enabled"
                else
                    read -p "Enable LlamaStack operator? (Y/n): " enable_ls
                    enable_ls=${enable_ls:-Y}
                    if [[ "$enable_ls" =~ ^[Yy]$ ]]; then
                        oc patch datasciencecluster default-dsc --type='merge' \
                            -p '{"spec":{"components":{"llamastackoperator":{"managementState":"Managed"}}}}'
                        print_success "LlamaStack operator enabled"
                    fi
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                feast_submenu
                ;;
            5)
                setup_model_registry
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                setup_pipeline_server
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                setup_mcp_servers_interactive
                ;;
            0)
                break
                ;;
            *)
                print_error "Invalid option. Please select 1-5 or 0."
                sleep 1
                ;;
        esac
    done
}

demos_submenu() {
    while true; do
        show_demos_submenu
        read -p "Select an option (1-16, 0): " demo_choice
        
        case $demo_choice in
            1)
                deploy_banking_demo
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                deploy_open_webui
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                deploy_llamastack_demo_menu
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                deploy_guidellm
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                deploy_guardrails_demo
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                run_maas_demo
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                bash "$SCRIPT_DIR/demo/financial-loan-demo/deploy.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                bash "$SCRIPT_DIR/demo/marketing-assistant-demo/deploy.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            9)
                bash "$SCRIPT_DIR/demo/pipeline-demo/deploy.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            10)
                bash "$SCRIPT_DIR/demo/nemo-guardrails-demo/deploy.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            11)
                bash "$SCRIPT_DIR/demo/lmeval-demo/deploy.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            12)
                bash "$SCRIPT_DIR/demo/n8n-demo/deploy.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            13)
                bash "$SCRIPT_DIR/demo/maas-ratelimit-demo/deploy.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            14)
                bash "$SCRIPT_DIR/demo/automl-demo/deploy.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            15)
                bash "$SCRIPT_DIR/demo/autorag-demo/deploy.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            16)
                bash "$SCRIPT_DIR/scripts/deploy-demo-environment.sh" --skip-core
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                print_error "Invalid option. Please select 1-16 or 0."
                sleep 1
                ;;
        esac
    done
}

rhoai_management_menu() {
    while true; do
        show_rhoai_management_menu
        read -p "Select an option (1-8, 0): " rhoai_choice
        
        case $rhoai_choice in
            1)
                model_management_submenu
                ;;
            2)
                ai_services_submenu
                ;;
            3)
                demos_submenu
                ;;
            4)
                rhoai32_features_submenu
                ;;
            5)
                enable_dashboard_features_interactive
                echo ""
                read -p "Press Enter to return to RHOAI Management menu..."
                ;;
            6)
                quick_start_wizard
                echo ""
                read -p "Press Enter to return to RHOAI Management menu..."
                ;;
            7)
                day2_operations_submenu
                ;;
            8)
                troubleshooting_submenu
                ;;
            0)
                print_info "Returning to main menu..."
                break
                ;;
            *)
                print_error "Invalid option. Please select 1-8 or 0."
                sleep 2
                ;;
        esac
    done
}

rhoai32_features_submenu() {
    while true; do
        show_rhoai32_features_submenu
        read -p "Select an option (1-7, 0): " rhoai32_choice
        
        case $rhoai32_choice in
            1)
                setup_llmd_infrastructure
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                deploy_llminferenceservice
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                enable_mlflow_operator
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                # Enable LlamaStack operator
                print_header "Enable LlamaStack Operator"
                local llamastack_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.llamastackoperator.managementState}' 2>/dev/null || echo "Unknown")
                echo "Current LlamaStack state: $llamastack_state"
                if [[ "$llamastack_state" == "Managed" ]]; then
                    print_success "LlamaStack operator already enabled"
                else
                    read -p "Enable LlamaStack operator? (Y/n): " enable_ls
                    enable_ls=${enable_ls:-Y}
                    if [[ "$enable_ls" =~ ^[Yy]$ ]]; then
                        oc patch datasciencecluster default-dsc --type='merge' \
                            -p '{"spec":{"components":{"llamastackoperator":{"managementState":"Managed"}}}}'
                        print_success "LlamaStack operator enabled"
                    fi
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                enable_cluster_monitoring_for_kserve
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                configure_dsci_observability
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                setup_mcp_servers_configmap
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                print_error "Invalid option. Please select 1-7 or 0."
                sleep 1
                ;;
        esac
    done
}

feast_submenu() {
    while true; do
        show_feast_submenu
        read -p "Select an option (1-7, 0): " feast_choice
        
        case $feast_choice in
            1)
                enable_feast_operator
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                setup_feature_store
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                show_feast_status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                diagnose_feature_store_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                delete_feature_store
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                print_header "Run feast apply"
                echo ""
                read -p "Enter namespace: " ns
                local pod=$(oc get pods -n "$ns" -o name 2>/dev/null | grep feast | head -1 | sed 's|pod/||')
                if [ -n "$pod" ]; then
                    print_step "Running feast apply in $pod..."
                    oc exec -n "$ns" "$pod" -c registry -- feast apply
                else
                    print_error "No Feast pod found in namespace $ns"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                print_header "Run feast materialize"
                echo ""
                read -p "Enter namespace: " ns
                local pod=$(oc get pods -n "$ns" -o name 2>/dev/null | grep feast | head -1 | sed 's|pod/||')
                if [ -n "$pod" ]; then
                    print_step "Running feast materialize in $pod..."
                    oc exec -n "$ns" "$pod" -c registry -- bash -c "feast materialize 2025-01-01T00:00:00 \$(date -u +'%Y-%m-%dT%H:%M:%S')"
                else
                    print_error "No Feast pod found in namespace $ns"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                print_error "Invalid option. Please select 1-7 or 0."
                sleep 1
                ;;
        esac
    done
}
