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
#   2. Create GPU Hardware Profile - Interactive hardware profile creation
#   3. Setup MaaS Only - MaaS API infrastructure only
#   4. Exit

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

show_main_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    Main Menu                                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} Complete Setup (OpenShift + RHOAI + GPU + MaaS)"
    echo -e "${YELLOW}2)${NC} Create GPU Hardware Profile (for existing cluster)"
    echo -e "${YELLOW}3)${NC} Setup MaaS Only (assumes RHOAI exists)"
    echo -e "${YELLOW}4)${NC} Exit"
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
        
        read -p "$(echo -e ${BLUE}Enter choice [1-4]${NC} (default: 1): )" cluster_choice
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
                    read -p "$(echo -e ${BLUE}Remove this kubeconfig file?${NC} [y/N]: )" remove_file
                    
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
                
                echo ""
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
        read -p "Select an option (1-4): " choice
        
        case $choice in
            1)
                run_complete_setup
                ;;
            2)
                create_hardware_profile_interactive
                echo ""
                read -p "Press Enter to return to main menu..."
                ;;
            3)
                MAAS_ONLY=true
                run_maas_only_setup
                echo ""
                read -p "Press Enter to return to main menu..."
                ;;
            4)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-4."
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

