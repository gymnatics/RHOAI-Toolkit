#!/bin/bash

################################################################################
# Complete OpenShift + RHOAI + MaaS Setup
################################################################################
# This is a wrapper script that orchestrates the complete setup:
# 1. OpenShift cluster installation
# 2. GPU worker nodes
# 3. RHOAI 3.0 with all features (GenAI Playground, etc.)
# 4. Model as a Service (MaaS) API infrastructure (optional)
#
# Usage:
#   ./complete-setup.sh                    # Interactive mode
#   ./complete-setup.sh --with-maas        # Auto-enable MaaS
#   ./complete-setup.sh --skip-maas        # Skip MaaS setup
#   ./complete-setup.sh --maas-only        # Only set up MaaS (assumes RHOAI exists)
#   ./complete-setup.sh --modular          # Use modular version (integrated-workflow-v2.sh)

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
    
    print_success "All prerequisites met"
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
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ "$MAAS_ONLY" = false ]; then
        echo "1. Access your OpenShift cluster:"
        echo "   ${YELLOW}cat cluster-info.txt${NC}"
        echo ""
        echo "2. Log in to the RHOAI dashboard:"
        echo "   - URL will be shown in cluster-info.txt"
        echo "   - Use kubeadmin credentials"
        echo ""
        echo "3. Create GPU MachineSets (if needed):"
        echo "   ${YELLOW}./create-gpu-machineset.sh${NC}"
        echo ""
    fi
    
    echo "4. Deploy a model to GenAI Playground:"
    echo "   a) Dashboard → Models → Deploy Model"
    echo "   b) Select model (e.g., Llama 3.2-3B)"
    echo "   c) Choose vLLM runtime"
    echo "   d) Select gpu-profile"
    echo "   e) Wait for Running status"
    echo "   f) Go to AI Assets Endpoints"
    echo "   g) Click 'Add to Playground'"
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
        echo "   ${YELLOW}./scripts/setup-maas.sh${NC}"
        echo ""
    fi
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Documentation:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  • README.md - Complete documentation"
    echo "  • TROUBLESHOOTING.md - Common issues and solutions"
    echo "  • CAI's guide to RHOAI 3.0.txt - Detailed RHOAI guide"
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

# Run main function
main "$@"

