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
#   ./rhoai-toolkit.sh                    # Interactive menu mode
#   ./rhoai-toolkit.sh --with-maas        # Auto-enable MaaS (non-interactive)
#   ./rhoai-toolkit.sh --skip-maas        # Skip MaaS setup (non-interactive)
#   ./rhoai-toolkit.sh --maas-only        # Only set up MaaS (assumes RHOAI exists)
#
# Interactive Menu Options:
#   1. Complete Setup - Full OpenShift + RHOAI + GPU + MaaS installation
#   2. Minimal RHOAI Setup - Choose which operators to install (flexible)
#   3. RHOAI Management - Configure features, deploy models, etc.
#   4. Create GPU MachineSet - Add GPU nodes to existing cluster
#   5. Help - Show scripts and documentation
#   6. Exit
#
# RHOAI 3.0 Operator Requirements:
#   REQUIRED: NFD, GPU Operator
#   OPTIONAL: Kueue (distributed workloads), LWS (llm-d), RHCL (auth)

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

# Source utility libraries
source "$SCRIPT_DIR/lib/utils/colors.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/utils/common.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/utils/os-compat.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/utils/rhoai-version.sh" 2>/dev/null || true

# Source function libraries
source "$SCRIPT_DIR/lib/functions/rhoai.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/operators.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/workshop-setup.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/mcp.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/llamastack.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/demos.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/day2-ops.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/setup-workflow.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/troubleshooting.sh" 2>/dev/null || true

# Source menu libraries
source "$SCRIPT_DIR/lib/menus/display.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/commands.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/workshop.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/mcp.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/rhoai-management.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/troubleshooting.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/kubeconfig.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/day2.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/models.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/gpu.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/install.sh" 2>/dev/null || true

# Command mode: if first arg doesn't start with -- and isn't a known flag,
# route it through the command registry (bypasses interactive menus)
if [ $# -gt 0 ] && [[ "$1" != --* ]] && [[ "$1" != -* ]]; then
    if route_command "$@"; then
        exit 0
    fi
    # route_command returns 1 for "menu" command or errors — fall through to interactive
fi

# Default flags
SETUP_MAAS="ask"
MAAS_ONLY=false
SKIP_OPENSHIFT=false
SKIP_GPU=false
SKIP_RHOAI=false
FORCE_NEW_CLUSTER=false

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
        read -p "Select an option (1-8, a, h, 0): " choice
        
        case $choice in
            1)
                install_rhoai_menu
                ;;
            2)
                workshop_setup_menu
                ;;
            3)
                run_complete_setup
                ;;
            4)
                run_minimal_setup
                ;;
            5)
                rhoai_management_menu
                ;;
            6)
                create_gpu_machineset_interactive
                echo ""
                read -p "Press Enter to return to main menu..."
                ;;
            7)
                gpu_clusterpolicy_menu
                ;;
            8)
                configure_kubeconfig_interactive
                ;;
            a|A)
                if [ -f "$ROOT_DIR/scripts/setup-letsencrypt-tls.sh" ]; then
                    "$ROOT_DIR/scripts/setup-letsencrypt-tls.sh"
                else
                    print_error "scripts/setup-letsencrypt-tls.sh not found"
                fi
                echo ""
                read -p "Press Enter to return to main menu..."
                ;;
            h|H)
                show_cli_help
                echo ""
                read -p "Press Enter to return to main menu..."
                ;;
            0)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-8, a, h, or 0."
                sleep 2
                ;;
        esac
    done
}

run_non_interactive_mode() {
    check_prerequisites
    
    display_setup_plan
    
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
    
    local overall_success=true
    local maas_status="not_attempted"
    
    if [ "$MAAS_ONLY" = false ]; then
        if ! run_integrated_workflow; then
            overall_success=false
            print_error "Integrated workflow failed. Stopping."
            exit 1
        fi
        
        ask_about_maas
    fi
    
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
    
    display_final_summary "$maas_status"
    
    if [ "$overall_success" = true ]; then
        exit 0
    else
        exit 1
    fi
}

run_complete_setup() {
    print_header "Complete Setup"
    
    check_prerequisites
    
    display_setup_plan
    
    echo -e "${YELLOW}This will install OpenShift and RHOAI. This takes 45-60 minutes.${NC}"
    echo ""
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Setup cancelled by user"
        return 0
    fi
    
    echo ""
    
    local overall_success=true
    local maas_status="not_attempted"
    
    if ! run_integrated_workflow; then
        overall_success=false
        print_error "Integrated workflow failed."
        return 1
    fi
    
    ask_about_maas
    
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
    
    display_final_summary "$maas_status"
    
    return 0
}

run_minimal_setup() {
    print_header "Minimal RHOAI Setup (Choose Operators)"
    
    echo -e "${CYAN}This mode lets you choose which operators to install.${NC}"
    echo ""
    echo -e "${GREEN}REQUIRED (always installed):${NC}"
    echo "  • Node Feature Discovery (NFD)"
    echo "  • NVIDIA GPU Operator"
    echo "  • Red Hat OpenShift AI 3.0"
    echo ""
    echo -e "${YELLOW}OPTIONAL (you choose):${NC}"
    echo "  • Kueue - for distributed workloads, scheduling"
    echo "  • LWS - for llm-d serving runtime"
    echo "  • RHCL - for llm-d authentication"
    echo ""
    
    local minimal_script="$SCRIPT_DIR/scripts/install-rhoai-minimal.sh"
    if [ ! -f "$minimal_script" ]; then
        print_error "Minimal setup script not found at: $minimal_script"
        return 1
    fi
    
    chmod +x "$minimal_script"
    
    echo -e "${CYAN}Select installation mode:${NC}"
    echo "  1) Interactive - choose each operator"
    echo "  2) Minimal - only required operators"
    echo "  3) Full - all operators"
    echo ""
    read -p "Enter choice [1-3] (default: 1): " mode_choice
    mode_choice=${mode_choice:-1}
    
    local mode_flag=""
    case $mode_choice in
        1) mode_flag="" ;;
        2) mode_flag="--minimal" ;;
        3) mode_flag="--full" ;;
        *) mode_flag="" ;;
    esac
    
    echo ""
    print_step "Running minimal RHOAI setup script..."
    echo ""
    
    if "$minimal_script" $mode_flag; then
        print_success "Minimal RHOAI setup completed"
    else
        print_error "Minimal RHOAI setup failed"
        return 1
    fi
    
    echo ""
    read -p "Press Enter to return to main menu..."
    return 0
}

# Run main function
main "$@"
