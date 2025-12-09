#!/bin/bash

################################################################################
# Complete OpenShift + RHOAI + MaaS Setup
################################################################################
# This is a wrapper script that orchestrates the complete setup:
# 1. OpenShift cluster installation
# 2. GPU worker nodes
# 3. RHOAI 3.0 with all features (GenAI Playground, etc.)
# 4. Model as a Service (MaaS) API infrastructure (optional)
# 5. GPU Hardware Profile creation (interactive)
#
# Usage:
#   ./complete-setup.sh                    # Interactive menu mode
#   ./complete-setup.sh --with-maas        # Auto-enable MaaS (non-interactive)
#   ./complete-setup.sh --skip-maas        # Skip MaaS setup (non-interactive)
#   ./complete-setup.sh --maas-only        # Only set up MaaS (assumes RHOAI exists)
#   ./complete-setup.sh --legacy           # Use legacy version (scripts/integrated-workflow.sh)
#
# Interactive Menu Options:
#   1. Complete Setup - Full OpenShift + RHOAI + GPU + MaaS installation
#   2. Deploy Model - Interactive model deployment with llm-d
#   3. Setup MCP Servers - Configure MCP servers for GenAI Playground/AI Agents
#   4. Create GPU Hardware Profile - Interactive hardware profile creation
#   5. Setup MaaS Only - MaaS API infrastructure only
#   6. Exit

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default flags
SETUP_MAAS="ask"
MAAS_ONLY=false
USE_MODULAR=true  # Modular is now the default!
USE_LEGACY=false
SKIP_OPENSHIFT=false
SKIP_GPU=false
SKIP_RHOAI=false
FORCE_NEW_CLUSTER=false  # Track if user explicitly cleared kubeconfig

################################################################################
# Helper Functions
################################################################################

print_banner() {
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                                                                            ║${NC}"
    echo -e "${MAGENTA}║          🚀 Complete OpenShift + RHOAI + MaaS Setup 🚀                    ║${NC}"
    echo -e "${MAGENTA}║                                                                            ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_main_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    Main Menu                                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} Complete Setup (OpenShift + RHOAI + GPU + MaaS)"
    echo -e "${YELLOW}2)${NC} RHOAI Management (configure features, deploy models, etc.)"
    echo -e "${YELLOW}3)${NC} Create GPU MachineSet (add GPU nodes to existing cluster)"
    echo -e "${YELLOW}4)${NC} Help (show scripts and documentation)"
    echo -e "${YELLOW}5)${NC} Exit"
    echo ""
}

show_rhoai_management_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 RHOAI Management Menu                          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} Enable Dashboard Features (Model Registry, GenAI Studio, etc.)"
    echo -e "${YELLOW}2)${NC} Deploy Model (interactive model deployment)"
    echo -e "${YELLOW}3)${NC} Add Model to Playground (test models interactively)"
    echo -e "${YELLOW}4)${NC} Setup MCP Servers (Model Context Protocol for tool calling)"
    echo -e "${YELLOW}5)${NC} Create GPU Hardware Profile (for model deployments)"
    echo -e "${YELLOW}6)${NC} Setup MaaS (Model as a Service API gateway)"
    echo -e "${YELLOW}7)${NC} Quick Start Wizard (run typical post-install workflow) ${MAGENTA}✨${NC}"
    echo -e "${YELLOW}8)${NC} Approve Pending CSRs (Day 2 node management)"
    echo -e "${YELLOW}9)${NC} Back to Main Menu"
    echo ""
}

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

################################################################################
# CSR Approval (Day 2 Operations)
################################################################################

approve_pending_csrs() {
    print_header "Approve Pending Certificate Signing Requests (CSRs)"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    echo ""
    
    # Check for pending CSRs
    print_step "Checking for pending CSRs..."
    local pending_csrs
    pending_csrs=$(oc get csr 2>/dev/null | grep -i pending || true)
    
    if [ -z "$pending_csrs" ]; then
        print_success "No pending CSRs found - all certificates are approved!"
        echo ""
        echo "Current CSR status:"
        oc get csr 2>/dev/null | head -20 || echo "  No CSRs found"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}Found pending CSRs:${NC}"
    echo "$pending_csrs"
    echo ""
    
    local pending_count
    pending_count=$(echo "$pending_csrs" | wc -l | tr -d ' ')
    
    echo -e "${CYAN}Found ${pending_count} pending CSR(s).${NC}"
    echo ""
    echo "CSRs are typically generated when:"
    echo "  • New nodes join the cluster"
    echo "  • Nodes are rebooted"
    echo "  • Kubelet certificates need renewal"
    echo ""
    
    read -p "Approve all pending CSRs? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "CSR approval cancelled"
        return 0
    fi
    
    echo ""
    print_step "Approving all pending CSRs..."
    
    # Get list of pending CSR names and approve them
    local approved_count=0
    local failed_count=0
    
    while IFS= read -r csr_name; do
        if [ -n "$csr_name" ]; then
            if oc adm certificate approve "$csr_name" &>/dev/null; then
                print_success "Approved: $csr_name"
                ((approved_count++))
            else
                print_error "Failed to approve: $csr_name"
                ((failed_count++))
            fi
        fi
    done < <(oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' 2>/dev/null)
    
    echo ""
    if [ $approved_count -gt 0 ]; then
        print_success "Approved $approved_count CSR(s)"
    fi
    if [ $failed_count -gt 0 ]; then
        print_warning "Failed to approve $failed_count CSR(s)"
    fi
    
    # Check if there are more pending (sometimes CSRs come in waves)
    echo ""
    print_step "Checking for additional pending CSRs..."
    sleep 3
    
    local more_pending
    more_pending=$(oc get csr 2>/dev/null | grep -i pending || true)
    
    if [ -n "$more_pending" ]; then
        echo ""
        print_warning "More pending CSRs detected (nodes may generate multiple CSRs):"
        echo "$more_pending"
        echo ""
        read -p "Approve these as well? (y/N): " confirm_more
        if [[ "$confirm_more" =~ ^[Yy]$ ]]; then
            while IFS= read -r csr_name; do
                if [ -n "$csr_name" ]; then
                    if oc adm certificate approve "$csr_name" &>/dev/null; then
                        print_success "Approved: $csr_name"
                    fi
                fi
            done < <(oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' 2>/dev/null)
        fi
    else
        print_success "No more pending CSRs"
    fi
    
    echo ""
    echo -e "${GREEN}CSR approval complete!${NC}"
    echo ""
    echo "Current node status:"
    oc get nodes 2>/dev/null || echo "  Unable to get node status"
    
    return 0
}

################################################################################
# MCP Server Setup
################################################################################

setup_mcp_servers_interactive() {
    print_header "Setup MCP Servers"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    
    # Check if MCP setup script exists
    if [ ! -f "$SCRIPT_DIR/scripts/setup-mcp-servers.sh" ]; then
        print_error "MCP server setup script not found"
        echo ""
        echo "Expected: $SCRIPT_DIR/scripts/setup-mcp-servers.sh"
        return 1
    fi
    
    # Run the MCP setup script
    echo ""
    "$SCRIPT_DIR/scripts/setup-mcp-servers.sh"
    
    return $?
}

################################################################################
# Model Deployment
################################################################################

deploy_model_interactive() {
    print_header "Deploy Model"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    
    # Check if model-deployment.sh exists
    if [ ! -f "$SCRIPT_DIR/lib/functions/model-deployment.sh" ]; then
        print_error "Model deployment library not found"
        echo ""
        echo "Expected: $SCRIPT_DIR/lib/functions/model-deployment.sh"
        return 1
    fi
    
    # Source required libraries
    if [ ! -f "$SCRIPT_DIR/lib/utils/colors.sh" ]; then
        print_error "Colors library not found"
        return 1
    fi
    
    source "$SCRIPT_DIR/lib/utils/colors.sh"
    source "$SCRIPT_DIR/lib/functions/model-deployment.sh"
    
    # Run the interactive deployment
    echo ""
    deploy_model_interactive
    
    return $?
}

################################################################################
# RHOAI Management Functions
################################################################################

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
    echo "  ./scripts/quick-deploy-model.sh"
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
    echo -e "${YELLOW}Run complete-setup.sh with options:${NC}"
    echo ""
    echo "  --with-maas          Auto-enable MaaS (non-interactive)"
    echo "  --skip-maas          Skip MaaS setup"
    echo "  --maas-only          Only setup MaaS (assumes RHOAI exists)"
    echo "  --skip-openshift     Skip OpenShift installation"
    echo "  --skip-gpu           Skip GPU node creation"
    echo "  --skip-rhoai         Skip RHOAI installation"
    echo ""
    echo -e "${GREEN}Examples:${NC}"
    echo "  ./complete-setup.sh --skip-openshift --with-maas"
    echo "  ./complete-setup.sh --maas-only"
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

rhoai_management_menu() {
    while true; do
        show_rhoai_management_menu
        read -p "Select an option (1-9): " rhoai_choice
        
        case $rhoai_choice in
            1)
                enable_dashboard_features_interactive
                echo ""
                read -p "Press Enter to return to RHOAI Management menu..."
                ;;
            2)
                deploy_model_interactive
                echo ""
                read -p "Press Enter to return to RHOAI Management menu..."
                ;;
            3)
                add_model_to_playground_interactive
                echo ""
                read -p "Press Enter to return to RHOAI Management menu..."
                ;;
            4)
                setup_mcp_servers_interactive
                echo ""
                read -p "Press Enter to return to RHOAI Management menu..."
                ;;
            5)
                create_hardware_profile_interactive
                echo ""
                read -p "Press Enter to return to RHOAI Management menu..."
                ;;
            6)
                MAAS_ONLY=true
                run_maas_only_setup
                echo ""
                read -p "Press Enter to return to RHOAI Management menu..."
                ;;
            7)
                quick_start_wizard
                echo ""
                read -p "Press Enter to return to RHOAI Management menu..."
                ;;
            8)
                approve_pending_csrs
                echo ""
                read -p "Press Enter to return to RHOAI Management menu..."
                ;;
            9)
                print_info "Returning to main menu..."
                break
                ;;
            *)
                print_error "Invalid option. Please select 1-9."
                sleep 2
                ;;
        esac
    done
}

################################################################################
# GPU MachineSet Creation
################################################################################

create_gpu_machineset_interactive() {
    print_header "Create GPU MachineSet"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        echo "Please login first: oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to OpenShift cluster"
    
    # Show cluster info
    local cluster_url=$(oc whoami --show-server 2>/dev/null)
    echo "Cluster: $cluster_url"
    echo ""
    
    # Check for existing GPU nodes
    local gpu_nodes=$(oc get nodes -l node-role.kubernetes.io/gpu-worker --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local gpu_machinesets=$(oc get machineset -n openshift-machine-api -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | contains("gpu")) | .metadata.name' 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$gpu_nodes" -gt 0 ] || [ "$gpu_machinesets" -gt 0 ]; then
        print_info "Existing GPU resources found:"
        if [ "$gpu_nodes" -gt 0 ]; then
            echo "  GPU Nodes: $gpu_nodes"
            oc get nodes -l node-role.kubernetes.io/gpu-worker --no-headers 2>/dev/null | awk '{print "    - " $1}'
        fi
        if [ "$gpu_machinesets" -gt 0 ]; then
            echo "  GPU MachineSets: $gpu_machinesets"
            oc get machineset -n openshift-machine-api -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | contains("gpu")) | "    - " + .metadata.name' 2>/dev/null
        fi
        echo ""
    else
        print_info "No existing GPU resources found"
        echo ""
    fi
    
    # Check if script exists
    local gpu_script="$SCRIPT_DIR/scripts/create-gpu-machineset.sh"
    if [ ! -f "$gpu_script" ]; then
        print_error "GPU MachineSet script not found at: $gpu_script"
        return 1
    fi
    
    # Run the GPU MachineSet script
    print_step "Launching GPU MachineSet creation script..."
    echo ""
    
    "$gpu_script"
    
    local result=$?
    echo ""
    
    if [ $result -eq 0 ]; then
        print_success "GPU MachineSet creation completed"
    else
        print_warning "GPU MachineSet creation returned with code: $result"
    fi
    
    return $result
}

################################################################################
# Hardware Profile Creation
################################################################################

create_hardware_profile_interactive() {
    print_header "Create GPU Hardware Profile"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        echo "Please login first: oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to OpenShift cluster"
    echo ""
    
    # Default to redhat-ods-applications for global profiles
    local default_ns="redhat-ods-applications"
    
    # Prompt for namespace
    echo -e "${CYAN}Enter the namespace where you want to create the hardware profile${NC}"
    echo -e "${YELLOW}Default: ${GREEN}redhat-ods-applications${YELLOW} (global scope - visible in all projects)${NC}"
    echo -e "${YELLOW}Or specify a project namespace for project-scoped profiles${NC}"
    echo ""
    read -p "Namespace [default: redhat-ods-applications]: " input_ns
    local target_ns="${input_ns:-$default_ns}"
    
    # Validate namespace exists
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_error "Namespace '$target_ns' does not exist"
        read -p "Do you want to create it? (y/n): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc create namespace "$target_ns"
            print_success "Namespace created"
        else
            return 1
        fi
    fi
    
    echo ""
    print_step "Configuring hardware profile resources..."
    echo ""
    
    # Prompt for CPU
    echo -e "${CYAN}CPU Configuration:${NC}"
    read -p "Default CPU count [2]: " cpu_default
    cpu_default="${cpu_default:-2}"
    read -p "Minimum CPU count [1]: " cpu_min
    cpu_min="${cpu_min:-1}"
    read -p "Maximum CPU count [16]: " cpu_max
    cpu_max="${cpu_max:-16}"
    
    echo ""
    
    # Prompt for Memory
    echo -e "${CYAN}Memory Configuration:${NC}"
    read -p "Default Memory (e.g., 16Gi) [16Gi]: " mem_default
    mem_default="${mem_default:-16Gi}"
    read -p "Minimum Memory (e.g., 1Gi) [1Gi]: " mem_min
    mem_min="${mem_min:-1Gi}"
    read -p "Maximum Memory (e.g., 64Gi) [64Gi]: " mem_max
    mem_max="${mem_max:-64Gi}"
    
    echo ""
    
    # Prompt for GPU
    echo -e "${CYAN}GPU Configuration:${NC}"
    read -p "Default GPU count [1]: " gpu_default
    gpu_default="${gpu_default:-1}"
    read -p "Minimum GPU count [1]: " gpu_min
    gpu_min="${gpu_min:-1}"
    read -p "Maximum GPU count [8]: " gpu_max
    gpu_max="${gpu_max:-8}"
    
    echo ""
    
    # Prompt for profile name and display name
    read -p "Hardware profile name [gpu-profile]: " profile_name
    profile_name="${profile_name:-gpu-profile}"
    read -p "Display name [GPU Profile]: " display_name
    display_name="${display_name:-GPU Profile}"
    
    echo ""
    print_step "Creating hardware profile '$profile_name' in namespace '$target_ns'..."
    echo ""
    
    # Create the hardware profile
    cat <<EOF | oc apply -f -
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  name: $profile_name
  namespace: $target_ns
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: '$display_name'
    opendatahub.io/description: 'GPU hardware profile for NVIDIA GPU workloads'
    opendatahub.io/managed: 'false'
  labels:
    app.opendatahub.io/hardwareprofile: 'true'
    app.kubernetes.io/part-of: hardwareprofile
spec:
  identifiers:
    - defaultCount: '$cpu_default'
      displayName: CPU
      identifier: cpu
      maxCount: '$cpu_max'
      minCount: $cpu_min
      resourceType: CPU
    - defaultCount: $mem_default
      displayName: Memory
      identifier: memory
      maxCount: $mem_max
      minCount: $mem_min
      resourceType: Memory
    - defaultCount: $gpu_default
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: $gpu_max
      minCount: $gpu_min
      resourceType: Accelerator
  scheduling:
    kueue:
      localQueueName: default
      priorityClass: None
    type: Queue
EOF
    
    if [ $? -eq 0 ]; then
        echo ""
        print_success "Hardware profile '$profile_name' created successfully in namespace '$target_ns'"
        echo ""
        
        # Verify
        print_step "Verifying..."
        oc get hardwareprofile "$profile_name" -n "$target_ns" -o custom-columns=NAME:.metadata.name,DISPLAY:.metadata.annotations.'opendatahub\.io/display-name',DISABLED:.metadata.annotations.'opendatahub\.io/disabled'
        
        echo ""
        if [ "$target_ns" == "redhat-ods-applications" ]; then
            print_info "✓ Global profile created - visible in ALL data science projects"
            print_info "The hardware profile should now appear in the RHOAI dashboard"
            print_info "when deploying models in any project."
        else
            print_info "✓ Project-scoped profile created - visible only in '$target_ns'"
            print_info "The hardware profile will appear in the RHOAI dashboard"
            print_info "when deploying models in the '$target_ns' project."
            echo ""
            print_warning "To create a global profile visible in all projects,"
            print_warning "create it in the 'redhat-ods-applications' namespace."
        fi
        echo ""
        
        return 0
    else
        print_error "Failed to create hardware profile"
        return 1
    fi
}

################################################################################
# Parse Arguments
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --with-maas)
                SETUP_MAAS="yes"
                shift
                ;;
            --skip-maas)
                SETUP_MAAS="no"
                shift
                ;;
            --maas-only)
                MAAS_ONLY=true
                SETUP_MAAS="yes"
                shift
                ;;
            --modular)
                USE_MODULAR=true
                USE_LEGACY=false
                shift
                ;;
            --legacy)
                USE_MODULAR=false
                USE_LEGACY=true
                shift
                ;;
            --skip-openshift)
                SKIP_OPENSHIFT=true
                shift
                ;;
            --skip-gpu)
                SKIP_GPU=true
                shift
                ;;
            --skip-rhoai)
                SKIP_RHOAI=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Complete setup script for OpenShift + RHOAI + MaaS

OPTIONS:
    --with-maas         Automatically set up MaaS (no prompt)
    --skip-maas         Skip MaaS setup (no prompt)
    --maas-only         Only set up MaaS (assumes RHOAI already installed)
    --legacy            Use legacy version (scripts/integrated-workflow.sh)
    --modular           Use modular version (default, integrated-workflow-v2.sh)
    --skip-openshift    Skip OpenShift installation (use existing cluster)
    --skip-gpu          Skip GPU worker node creation
    --skip-rhoai        Skip RHOAI installation
    -h, --help          Show this help message

EXAMPLES:
    $0                              # Interactive mode (uses modular by default)
    $0 --with-maas                  # Full setup including MaaS
    $0 --skip-maas                  # Setup without MaaS
    $0 --skip-openshift             # Install RHOAI on existing cluster
    $0 --skip-openshift --skip-gpu  # Install only RHOAI (no OpenShift, no GPU)
    $0 --legacy                     # Use legacy/original version
    $0 --maas-only                  # Only set up MaaS infrastructure

NOTE:
    Modular version is now the default. Use --legacy for the original version.
    $0 --maas-only          # Only add MaaS to existing RHOAI

WHAT THIS SCRIPT DOES:
    1. Runs integrated-workflow-v2.sh by default (modular version)
       Or scripts/integrated-workflow.sh with --legacy flag
    2. Optionally runs scripts/setup-maas.sh (MaaS API infrastructure)
    
    Note: Modular version is now the default! Use --legacy for the original version.
    3. Provides final summary and next steps

EOF
}

################################################################################
# Check Prerequisites
################################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local all_good=true
    
    # Source AWS checks if installing OpenShift
    if [ "$SKIP_OPENSHIFT" = false ] && [ "$MAAS_ONLY" = false ]; then
        if [ -f "$SCRIPT_DIR/lib/utils/aws-checks.sh" ]; then
            source "$SCRIPT_DIR/lib/utils/aws-checks.sh"
            
            echo ""
            echo -e "${CYAN}Would you like to run AWS prerequisites check?${NC}"
            echo "This will verify:"
            echo "  • AWS credentials and permissions"
            echo "  • Route53 hosted zones"
            echo "  • Service quotas"
            echo "  • Existing resources"
            echo "  • SSH keys"
            echo ""
            read -p "Run AWS checks? [Y/n]: " run_aws_checks
            
            if [[ ! "$run_aws_checks" =~ ^[Nn]$ ]]; then
                if ! check_aws_prerequisites; then
                    echo ""
                    echo -e "${RED}AWS prerequisites check failed.${NC}"
                    echo ""
                    read -p "Press Enter to return to menu..."
                    return 1
                fi
            fi
        fi
    fi
    
    # Check for KUBECONFIG environment variable
    if [ -n "$KUBECONFIG" ]; then
        print_info "KUBECONFIG environment variable is set:"
        echo "  $KUBECONFIG"
        echo ""
        
        if [ -f "$KUBECONFIG" ]; then
            print_success "Kubeconfig file exists"
        else
            print_warning "Kubeconfig file does not exist at that path"
        fi
        echo ""
    fi
    
    # Check if already logged in (existing cluster)
    if oc whoami &>/dev/null; then
        print_success "Already logged in to an OpenShift cluster"
        
        # Get cluster info
        local cluster_url=$(oc whoami --show-server 2>/dev/null || echo "unknown")
        local cluster_user=$(oc whoami 2>/dev/null || echo "unknown")
        echo ""
        echo "  Cluster: $cluster_url"
        echo "  User: $cluster_user"
        
        if [ -n "$KUBECONFIG" ]; then
            echo "  Kubeconfig: $KUBECONFIG"
        fi
        echo ""
        
        echo -e "${YELLOW}What would you like to do?${NC}"
        echo ""
        echo "  1) Use this existing cluster (skip OpenShift installation)"
        echo "  2) Logout and install a new cluster"
        echo "  3) Clear kubeconfig and install a new cluster"
        echo "  4) Back to menu / Cancel"
        echo ""
        
        echo -e -n "${BLUE}Enter choice [1-4]${NC} (default: 1): "
        read cluster_choice
        cluster_choice="${cluster_choice:-1}"
        
        case $cluster_choice in
            1)
                print_info "Will use existing cluster (skip OpenShift installation)"
                SKIP_OPENSHIFT=true
                ;;
            2)
                print_warning "You'll need to logout and install a new cluster"
                read -p "Press Enter to continue..."
                ;;
            3)
                print_warning "Clearing kubeconfig..."
                
                # Unset KUBECONFIG
                if [ -n "$KUBECONFIG" ]; then
                    echo ""
                    print_info "Current KUBECONFIG: $KUBECONFIG"
                    echo ""
                    echo -e -n "${BLUE}Remove this kubeconfig file?${NC} [y/N]: "
                    read remove_file
                    
                    if [[ "$remove_file" =~ ^[Yy]$ ]]; then
                        if [ -f "$KUBECONFIG" ]; then
                            rm -f "$KUBECONFIG"
                            print_success "Removed kubeconfig file: $KUBECONFIG"
                        fi
                    fi
                    
                    export KUBECONFIG=""
                    unset KUBECONFIG
                    print_success "KUBECONFIG environment variable cleared"
                    echo ""
                    print_warning "Note: This only clears for the current session"
                    print_info "To persist, remove KUBECONFIG from your shell profile (~/.bashrc, ~/.zshrc, etc.)"
                fi
                
                # Also clear default kubeconfig
                if [ -f "$HOME/.kube/config" ]; then
                    echo ""
                    echo -e -n "${BLUE}Also remove default kubeconfig (~/.kube/config)?${NC} [y/N]: "
                    read remove_default
                    
                    if [[ "$remove_default" =~ ^[Yy]$ ]]; then
                        # Backup first
                        cp "$HOME/.kube/config" "$HOME/.kube/config.backup.$(date +%Y%m%d-%H%M%S)"
                        print_info "Created backup: ~/.kube/config.backup.$(date +%Y%m%d-%H%M%S)"
                        rm -f "$HOME/.kube/config"
                        print_success "Removed ~/.kube/config"
                    fi
                fi
                
                echo ""
                print_success "Kubeconfig cleared - ready for fresh installation"
                # Force skip of existing cluster check since we just cleared it
                SKIP_OPENSHIFT=false
                FORCE_NEW_CLUSTER=true  # Flag to skip cluster detection in integrated workflow
                read -p "Press Enter to continue..."
                ;;
            4)
                print_info "Cancelled"
                return 1
                ;;
            *)
                print_error "Invalid choice"
                return 1
                ;;
        esac
    fi
    
    # Check for required scripts based on USE_MODULAR flag
    if [ "$USE_MODULAR" = true ]; then
        if [ ! -f "$SCRIPT_DIR/integrated-workflow-v2.sh" ]; then
            print_error "integrated-workflow-v2.sh not found"
            all_good=false
        else
            print_success "integrated-workflow-v2.sh found"
        fi
        
        # Make executable if needed
        if [ ! -x "$SCRIPT_DIR/integrated-workflow-v2.sh" ]; then
            print_warning "Making integrated-workflow-v2.sh executable..."
            chmod +x "$SCRIPT_DIR/integrated-workflow-v2.sh"
        fi
    else
        if [ ! -f "$SCRIPT_DIR/scripts/integrated-workflow.sh" ]; then
            print_error "scripts/integrated-workflow.sh not found"
            all_good=false
        else
            print_success "scripts/integrated-workflow.sh found"
        fi
        
        # Make executable if needed
        if [ ! -x "$SCRIPT_DIR/scripts/integrated-workflow.sh" ]; then
            print_warning "Making scripts/integrated-workflow.sh executable..."
            chmod +x "$SCRIPT_DIR/scripts/integrated-workflow.sh"
        fi
    fi
    
    # Check for setup-maas.sh
    if [ ! -f "$SCRIPT_DIR/scripts/setup-maas.sh" ]; then
        print_error "scripts/setup-maas.sh not found"
        all_good=false
    else
        print_success "scripts/setup-maas.sh found"
    fi
    
    # Make setup-maas.sh executable if needed
    if [ ! -x "$SCRIPT_DIR/scripts/setup-maas.sh" ]; then
        print_warning "Making scripts/setup-maas.sh executable..."
        chmod +x "$SCRIPT_DIR/scripts/setup-maas.sh"
    fi
    
    if [ "$all_good" = false ]; then
        print_error "Prerequisites check failed. Please ensure all required scripts are present."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

################################################################################
# Display Setup Plan
################################################################################

display_setup_plan() {
    print_header "Setup Plan"
    
    if [ "$MAAS_ONLY" = true ]; then
        echo -e "${CYAN}This script will:${NC}"
        echo ""
        echo "  1. ✅ Set up MaaS API infrastructure"
        echo ""
        echo -e "${YELLOW}Note: Assumes RHOAI is already installed${NC}"
    else
        echo -e "${CYAN}This script will:${NC}"
        echo ""
        
        # Show version being used
        if [ "$USE_MODULAR" = true ]; then
            echo -e "${GREEN}Using: Modular version (integrated-workflow-v2.sh)${NC}"
        else
            echo -e "${YELLOW}Using: Legacy version (scripts/integrated-workflow.sh)${NC}"
        fi
        echo ""
        
        local step=1
        
        # OpenShift installation
        if [ "$SKIP_OPENSHIFT" = true ]; then
            echo "  $step. ⏭️  Skip OpenShift installation (use existing cluster)"
        else
            echo "  $step. ✅ Install OpenShift cluster on AWS (or use existing)"
        fi
        step=$((step + 1))
        
        # GPU nodes
        if [ "$SKIP_GPU" = true ]; then
            echo "  $step. ⏭️  Skip GPU worker node creation"
        else
            echo "  $step. ✅ Create GPU worker nodes (or use existing)"
        fi
        step=$((step + 1))
        
        # RHOAI installation
        if [ "$SKIP_RHOAI" = true ]; then
            echo "  $step. ⏭️  Skip RHOAI installation"
        else
            echo "  $step. ✅ Install RHOAI with all features:"
            echo "      - GenAI Playground"
            echo "      - Model Catalog"
            echo "      - Feature Store"
            echo "      - AI Pipelines"
            echo "      - Model Registry"
            echo "      - Distributed Training"
            echo "      - TrustyAI"
            echo "      - Required operators (NFD, GPU, RHCL, LWS, Kueue)"
        fi
        step=$((step + 1))
        
        # MaaS setup
        if [ "$SETUP_MAAS" = "yes" ]; then
            echo "  $step. ✅ Set up MaaS API infrastructure"
        elif [ "$SETUP_MAAS" = "no" ]; then
            echo "  $step. ⏭️  Skip MaaS setup"
        else
            echo "  $step. ❓ Prompt for MaaS setup"
        fi
    fi
    
    echo ""
    
    # Estimate time based on what's being done
    local estimated_time="5-10 minutes"
    if [ "$MAAS_ONLY" = false ]; then
        if [ "$SKIP_OPENSHIFT" = false ] && [ "$SKIP_RHOAI" = false ]; then
            estimated_time="45-60 minutes"
        elif [ "$SKIP_OPENSHIFT" = true ] && [ "$SKIP_RHOAI" = false ]; then
            estimated_time="20-30 minutes"
        elif [ "$SKIP_RHOAI" = true ]; then
            estimated_time="30-40 minutes"
        fi
    fi
    
    echo -e "${BLUE}Estimated time: $estimated_time${NC}"
    echo ""
}

################################################################################
# Run Integrated Workflow
################################################################################

run_integrated_workflow() {
    print_header "Phase 1: OpenShift + RHOAI + GenAI Playground"
    
    # Choose which workflow to run
    local workflow_script
    local workflow_args=""
    
    # Build arguments to pass to workflow script
    if [ "$SKIP_OPENSHIFT" = true ]; then
        workflow_args="$workflow_args --skip-openshift"
    fi
    if [ "$SKIP_GPU" = true ]; then
        workflow_args="$workflow_args --skip-gpu"
    fi
    if [ "$SKIP_RHOAI" = true ]; then
        workflow_args="$workflow_args --skip-rhoai"
    fi
    
    if [ "$USE_MODULAR" = true ]; then
        workflow_script="$SCRIPT_DIR/integrated-workflow-v2.sh"
        print_step "Running integrated-workflow-v2.sh (modular version)..."
    else
        workflow_script="$SCRIPT_DIR/scripts/integrated-workflow.sh"
        print_step "Running scripts/integrated-workflow.sh..."
    fi
    
    if [ -n "$workflow_args" ]; then
        print_info "Flags: $workflow_args"
    fi
    echo ""
    
    # Export flag for integrated workflow to detect
    if [ "$FORCE_NEW_CLUSTER" = true ]; then
        export FORCE_NEW_CLUSTER=true
    fi
    
    if $workflow_script $workflow_args; then
        print_success "Integrated workflow completed successfully!"
        return 0
    else
        print_error "Integrated workflow failed!"
        return 1
    fi
}

################################################################################
# Ask About MaaS
################################################################################

ask_about_maas() {
    if [ "$SETUP_MAAS" = "ask" ]; then
        print_header "Model as a Service (MaaS) Setup"
        
        echo -e "${CYAN}Would you like to set up Model as a Service (MaaS)?${NC}"
        echo ""
        echo "MaaS provides:"
        echo "  • API gateway for model serving"
        echo "  • Token-based authentication"
        echo "  • Usage tracking and billing"
        echo "  • Unified endpoint for all models"
        echo ""
        echo "Requirements:"
        echo "  • kustomize (will check if installed)"
        echo "  • jq (will check if installed)"
        echo "  • Network access to GitHub"
        echo ""
        echo -e "${YELLOW}Note: MaaS is optional. GenAI Playground works without it.${NC}"
        echo ""
        
        while true; do
            read -p "Set up MaaS? (y/n): " -n 1 -r
            echo
            case $REPLY in
                [Yy]*)
                    SETUP_MAAS="yes"
                    break
                    ;;
                [Nn]*)
                    SETUP_MAAS="no"
                    break
                    ;;
                *)
                    echo "Please answer y or n."
                    ;;
            esac
        done
    fi
}

################################################################################
# Run MaaS Setup
################################################################################

run_maas_setup() {
    print_header "Phase 2: Model as a Service (MaaS) Setup"
    
    # Check for kustomize
    if ! command -v kustomize &> /dev/null; then
        print_error "kustomize not found. Please install it first:"
        echo ""
        echo "  brew install kustomize"
        echo "  OR"
        echo "  curl -s 'https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh' | bash"
        echo ""
        return 1
    fi
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        print_error "jq not found. Please install it first:"
        echo ""
        echo "  brew install jq"
        echo ""
        return 1
    fi
    
    print_step "Running scripts/setup-maas.sh..."
    echo ""
    
    if "$SCRIPT_DIR/scripts/setup-maas.sh"; then
        print_success "MaaS setup completed successfully!"
        return 0
    else
        print_error "MaaS setup failed!"
        return 1
    fi
}

################################################################################
# Display Final Summary
################################################################################

display_final_summary() {
    local maas_status=$1
    
    print_header "🎉 Setup Complete!"
    
    echo -e "${GREEN}✓ Your OpenShift + RHOAI environment is ready!${NC}"
    echo ""
    
    if [ "$MAAS_ONLY" = true ]; then
        echo -e "${CYAN}What was set up:${NC}"
        echo "  ✅ MaaS API infrastructure"
    else
        echo -e "${CYAN}What was set up:${NC}"
        echo "  ✅ OpenShift cluster"
        echo "  ✅ GPU worker nodes"
        echo "  ✅ RHOAI 3.0 with all features"
        echo "  ✅ GenAI Playground"
        
        if [ "$maas_status" = "success" ]; then
            echo "  ✅ Model as a Service (MaaS)"
        elif [ "$maas_status" = "skipped" ]; then
            echo "  ⏭️  Model as a Service (skipped)"
        else
            echo "  ❌ Model as a Service (failed)"
        fi
    fi
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🚀 Recommended Next Steps:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}From the main menu, select:${NC}"
    echo -e "  ${CYAN}2${NC} → RHOAI Management"
    echo ""
    echo -e "${YELLOW}Then follow this typical workflow:${NC}"
    echo ""
    echo -e "  ${CYAN}1${NC}. Enable Dashboard Features"
    echo "     └─ Enables Model Registry, GenAI Studio, Kueue, etc."
    echo ""
    echo -e "  ${CYAN}2${NC}. Deploy Model"
    echo "     └─ Interactive deployment with vLLM or llm-d runtime"
    echo ""
    echo -e "  ${CYAN}3${NC}. Add Model to Playground"
    echo "     └─ Test your model interactively in GenAI Studio"
    echo ""
    echo -e "  ${CYAN}4${NC}. Setup MCP Servers"
    echo "     └─ Enable tool calling with external services"
    echo ""
    echo -e "${YELLOW}💡 Tip:${NC} Use option ${CYAN}8${NC} (Quick Start) to run all steps automatically!"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Show dashboard URL
    local dashboard_url=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}' 2>/dev/null)
    if [ -n "$dashboard_url" ]; then
        echo -e "${GREEN}📊 RHOAI Dashboard:${NC}"
        echo "   https://$dashboard_url"
        echo ""
    fi
    
    echo -e "${CYAN}📚 Documentation:${NC}"
    echo "   • Model Registry: docs/guides/MODEL-REGISTRY.md"
    echo "   • GenAI Playground: docs/guides/GENAI-PLAYGROUND-INTEGRATION.md"
    echo "   • MCP Servers: docs/guides/MCP-SERVERS.md"
    echo ""
    
    read -p "Press Enter to return to main menu..."
    echo ""
    echo ""
    
    if [ "$MAAS_ONLY" = false ]; then
        echo "1. Access your OpenShift cluster:"
        echo -e "   ${YELLOW}cat cluster-info.txt${NC}"
        echo ""
        echo "2. Log in to the RHOAI dashboard:"
        echo "   - URL will be shown in cluster-info.txt"
        echo "   - Use kubeadmin credentials"
        echo ""
        echo "3. Create GPU MachineSets (if needed):"
        echo -e "   ${YELLOW}./scripts/create-gpu-machineset.sh${NC}"
        echo ""
    fi
    
    echo "4. Deploy a model:"
    echo -e "   ${YELLOW}./scripts/deploy-llmd-model.sh${NC}  # Interactive deployment with llm-d"
    echo ""
    echo "5. Or deploy via GenAI Playground UI:"
    echo "   a) Dashboard → Models → Deploy Model"
    echo "   b) Select model (e.g., Qwen3-4B)"
    echo "   c) Choose llm-d runtime"
    echo "   d) Select gpu-profile"
    echo "   e) Check 'Require authentication' checkbox"
    echo "   f) Wait for Running status"
    echo "   g) Go to AI Assets Endpoints"
    echo "   h) Click 'Add to Playground'"
    echo ""
    
    if [ "$maas_status" = "success" ]; then
        echo "5. Use Model as a Service:"
        echo "   a) Deploy model with MaaS checkbox"
        echo "   b) Go to Models as a Service"
        echo "   c) Generate token"
        echo "   d) Use MaaS API endpoint"
        echo ""
    elif [ "$maas_status" = "skipped" ]; then
        echo "5. To add MaaS later:"
        echo -e "   ${YELLOW}./scripts/setup-maas.sh${NC}"
        echo ""
    fi
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Documentation:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  • README.md - Complete documentation"
    echo "  • docs/TROUBLESHOOTING.md - Common issues and solutions"
    echo "  • lib/README.md - Modular functions documentation"
    echo "  • scripts/README.md - Utility scripts documentation"
    echo ""
    
    if [ "$MAAS_ONLY" = false ]; then
        echo -e "${GREEN}🎉 Happy model serving! 🚀${NC}"
    else
        echo -e "${GREEN}🎉 MaaS is ready to use! 🚀${NC}"
    fi
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    print_banner
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # If command line arguments were provided, run in non-interactive mode
    if [ "$#" -gt 0 ]; then
        run_non_interactive_mode
        return $?
    fi
    
    # Interactive menu mode
    while true; do
        show_main_menu
        read -p "Select an option (1-5): " choice
        
        case $choice in
            1)
                run_complete_setup
                ;;
            2)
                rhoai_management_menu
                ;;
            3)
                create_gpu_machineset_interactive
                echo ""
                read -p "Press Enter to return to main menu..."
                ;;
            4)
                show_help
                echo ""
                read -p "Press Enter to return to main menu..."
                ;;
            5)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-5."
                sleep 2
                ;;
        esac
    done
}

run_non_interactive_mode() {
    # Check prerequisites
    check_prerequisites
    
    # Display setup plan
    display_setup_plan
    
    # Confirm before proceeding
    if [ "$MAAS_ONLY" = false ]; then
        echo -e "${YELLOW}This will install OpenShift and RHOAI. This takes 45-60 minutes.${NC}"
    else
        echo -e "${YELLOW}This will set up MaaS API infrastructure.${NC}"
    fi
    echo ""
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Setup cancelled by user"
        exit 0
    fi
    
    echo ""
    
    # Track overall status
    local overall_success=true
    local maas_status="not_attempted"
    
    # Run integrated workflow (unless MaaS-only mode)
    if [ "$MAAS_ONLY" = false ]; then
        if ! run_integrated_workflow; then
            overall_success=false
            print_error "Integrated workflow failed. Stopping."
            exit 1
        fi
        
        # Ask about MaaS setup
        ask_about_maas
    fi
    
    # Run MaaS setup if requested
    if [ "$SETUP_MAAS" = "yes" ]; then
        if run_maas_setup; then
            maas_status="success"
        else
            maas_status="failed"
            overall_success=false
            print_warning "MaaS setup failed, but RHOAI is still functional"
        fi
    elif [ "$SETUP_MAAS" = "no" ]; then
        maas_status="skipped"
    fi
    
    # Display final summary
    display_final_summary "$maas_status"
    
    # Exit with appropriate code
    if [ "$overall_success" = true ]; then
        exit 0
    else
        exit 1
    fi
}

run_complete_setup() {
    print_header "Complete Setup"
    
    # Check prerequisites
    check_prerequisites
    
    # Display setup plan
    display_setup_plan
    
    # Confirm before proceeding
    echo -e "${YELLOW}This will install OpenShift and RHOAI. This takes 45-60 minutes.${NC}"
    echo ""
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Setup cancelled by user"
        return 0
    fi
    
    echo ""
    
    # Track overall status
    local overall_success=true
    local maas_status="not_attempted"
    
    # Run integrated workflow
    if ! run_integrated_workflow; then
        overall_success=false
        print_error "Integrated workflow failed."
        return 1
    fi
    
    # Ask about MaaS setup
    ask_about_maas
    
    # Run MaaS setup if requested
    if [ "$SETUP_MAAS" = "yes" ]; then
        if run_maas_setup; then
            maas_status="success"
        else
            maas_status="failed"
            overall_success=false
            print_warning "MaaS setup failed, but RHOAI is still functional"
        fi
    elif [ "$SETUP_MAAS" = "no" ]; then
        maas_status="skipped"
    fi
    
    # Display final summary
    display_final_summary "$maas_status"
    
    return 0
}

run_maas_only_setup() {
    print_header "MaaS Setup Only"
    
    echo -e "${YELLOW}This will set up MaaS API infrastructure.${NC}"
    echo -e "${YELLOW}Assumes RHOAI is already installed.${NC}"
    echo ""
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Setup cancelled by user"
        return 0
    fi
    
    echo ""
    
    if run_maas_setup; then
        print_success "MaaS setup completed successfully"
    else
        print_error "MaaS setup failed"
        return 1
    fi
    
    return 0
}

# Run main function
main "$@"

