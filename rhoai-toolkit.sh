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

# Source library functions
source "$SCRIPT_DIR/lib/utils/colors.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/utils/common.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/utils/os-compat.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/utils/rhoai-version.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/rhoai.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/operators.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/workshop-setup.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/mcp.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/llamastack.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/demos.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/commands.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/workshop.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/mcp.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/rhoai-management.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/functions/troubleshooting.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/troubleshooting.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/menus/kubeconfig.sh" 2>/dev/null || true

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
    echo -e "${MAGENTA}Installation:${NC}"
    echo -e "${YELLOW}1)${NC} Complete Setup (OpenShift + RHOAI 3.x + GPU + MaaS) ${MAGENTA}[Full]${NC}"
    echo -e "${YELLOW}2)${NC} Minimal RHOAI 3.x Setup (choose operators) ${GREEN}[Flexible]${NC}"
    echo -e "${YELLOW}3)${NC} Install RHOAI ${GREEN}[auto-detects available versions]${NC}"
    echo -e "${YELLOW}4)${NC} Workshop Demo Setup (RHOAI 2.25 + GenAI Workshop) ${GREEN}[Recommended for Workshops]${NC}"
    echo ""
    echo -e "${MAGENTA}Management & Tools:${NC}"
    echo -e "${YELLOW}5)${NC} RHOAI Management (configure features, deploy models, etc.)"
    echo -e "${YELLOW}6)${NC} Create GPU MachineSet (add GPU nodes to existing cluster)"
    echo -e "${YELLOW}7)${NC} GPU & ClusterPolicy Management ${CYAN}[NVIDIA]${NC}"
    echo -e "${YELLOW}8)${NC} Configure Kubeconfig (login, set, or create kubeconfig) ${CYAN}[Connection]${NC}"
    echo -e "${YELLOW}h)${NC} Help (show scripts and documentation)"
    echo -e "${YELLOW}0)${NC} Exit"
    echo ""
    echo -e "${CYAN}Tip:${NC} Use command mode to skip menus: ${GREEN}./rhoai-toolkit.sh deploy demo webui${NC}"
    echo -e "     Type ${GREEN}./rhoai-toolkit.sh help${NC} for all available commands."
    echo ""
}

show_rhoai_management_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 RHOAI Management Menu                          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} Model Management ${BLUE}→${NC}"
    echo "    Deploy models, test in Playground, create GPU profiles"
    echo ""
    echo -e "${YELLOW}2)${NC} AI Services & Infrastructure ${BLUE}→${NC}"
    echo "    Setup MaaS, LlamaStack, MCP Servers, Feature Store"
    echo ""
    echo -e "${YELLOW}3)${NC} Demos ${GREEN}[Version-Aware]${NC} ${BLUE}→${NC}"
    echo "    Deploy ready-to-use demos (Banking, LlamaStack, GuideLLM)"
    echo ""
    echo -e "${YELLOW}4)${NC} RHOAI 3.2+ Features ${GREEN}[NEW]${NC} ${BLUE}→${NC}"
    echo "    llm-d, MLflow, Observability (per CAI Guide)"
    echo ""
    echo -e "${YELLOW}5)${NC} Dashboard & Configuration"
    echo "    Enable features like Model Registry, GenAI Studio"
    echo ""
    echo -e "${YELLOW}6)${NC} Quick Start Wizard ${MAGENTA}✨${NC}"
    echo "    Run typical post-install workflow"
    echo ""
    echo -e "${YELLOW}7)${NC} Day 2 Operations ${BLUE}→${NC}"
    echo "    Approve CSRs, remove kubeadmin, cluster maintenance"
    echo ""
    echo -e "${YELLOW}8)${NC} Troubleshooting & Fixes ${RED}[Fixes]${NC}"
    echo "    GPU operator issues, CUDA compatibility, common problems"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to Main Menu"
    echo ""
}

show_feast_submenu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 Feature Store (Feast)                          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${MAGENTA}What is Feast?${NC}"
    echo "    A feature store bridges ML training and serving, ensuring"
    echo "    consistent features and eliminating training-serving skew."
    echo ""
    echo -e "${YELLOW}1)${NC} Enable Feast Operator"
    echo "    Enable feastoperator in DataScienceCluster (required first)"
    echo ""
    echo -e "${YELLOW}2)${NC} Setup Custom Feature Store"
    echo "    Create a FeatureStore with custom Git repository"
    echo ""
    echo -e "${YELLOW}3)${NC} Show Feature Store Status"
    echo "    View all FeatureStores and their status"
    echo ""
    echo -e "${YELLOW}4)${NC} Diagnose Feature Store ${GREEN}[Version-Aware]${NC}"
    echo "    Troubleshoot visibility issues (3.2 → 3.3 upgrades)"
    echo ""
    echo -e "${YELLOW}5)${NC} Delete Feature Store"
    echo "    Remove a FeatureStore from a namespace"
    echo ""
    echo -e "${YELLOW}6)${NC} Run feast apply (register features)"
    echo "    Execute feast apply in an existing FeatureStore pod"
    echo ""
    echo -e "${YELLOW}7)${NC} Run feast materialize (populate online store)"
    echo "    Execute feast materialize for real-time serving"
    echo ""
    echo -e "${CYAN}Tip: Deploy demos from: RHOAI Management → Demos${NC}"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to AI Services"
    echo ""
}

show_model_management_submenu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 Model Management                               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${MAGENTA}Model Deployment:${NC}"
    echo -e "${YELLOW}1)${NC} Deploy GenAI Model"
    echo "    Interactive LLM deployment (vLLM, llm-d, etc.)"
    echo ""
    echo -e "${YELLOW}2)${NC} Deploy Predictive Model ${GREEN}[New]${NC}"
    echo "    Deploy sklearn/xgboost/lightgbm/onnx from S3/MinIO (CPU)"
    echo ""
    echo -e "${YELLOW}3)${NC} Add Model to Playground"
    echo "    Test models interactively in GenAI Studio"
    echo ""
    echo -e "${MAGENTA}Model Storage (HuggingFace → S3):${NC}"
    echo -e "${YELLOW}4)${NC} Setup Model Storage (MinIO) ${GREEN}[New]${NC}"
    echo "    Deploy MinIO S3 storage for HuggingFace models"
    echo ""
    echo -e "${YELLOW}5)${NC} Download Model from HuggingFace ${GREEN}[New]${NC}"
    echo "    Download models to S3 for deployment"
    echo ""
    echo -e "${MAGENTA}Serving Runtimes:${NC}"
    echo -e "${YELLOW}6)${NC} Manage Serving Runtimes ${GREEN}[New]${NC}"
    echo "    Add/export runtimes (vLLM-Omni, Community vLLM, Red Hat vLLM)"
    echo ""
    echo -e "${MAGENTA}Hardware Profiles:${NC}"
    echo -e "${YELLOW}7)${NC} Create GPU Hardware Profile (Custom)"
    echo "    Define custom GPU resources for model deployments"
    echo ""
    echo -e "${YELLOW}8)${NC} Quick GPU Profile Setup ${GREEN}[Recommended]${NC}"
    echo "    Create pre-configured profiles (Small/Medium/Large)"
    echo ""
    echo -e "${MAGENTA}Model Catalog:${NC}"
    echo -e "${YELLOW}9)${NC} Manage Model Catalog ${GREEN}[Add/Remove/List]${NC}"
    echo "    Add, remove, rename entries in the RHOAI Model Catalog"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to RHOAI Management"
    echo ""
}

show_ai_services_submenu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║             AI Services & Infrastructure                       ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${MAGENTA}Model as a Service (MaaS):${NC}"
    echo -e "${YELLOW}1)${NC} Setup MaaS ${GREEN}[Version-Aware]${NC}"
    echo "    API gateway for model serving (auto-configures for RHOAI version)"
    echo ""
    echo -e "${MAGENTA}LlamaStack:${NC}"
    echo -e "${YELLOW}2)${NC} Setup LlamaStack (Generic)"
    echo "    Deploy LlamaStack with vLLM, Azure, OpenAI, Ollama, or Bedrock"
    echo ""
    echo -e "${YELLOW}3)${NC} Enable LlamaStack Operator"
    echo "    Enable LlamaStack operator in DataScienceCluster"
    echo ""
    echo -e "${MAGENTA}Feature Store (Feast):${NC}"
    echo -e "${YELLOW}4)${NC} Feature Store Management ${BLUE}→${NC}"
    echo "    Setup and manage Feature Store for ML features"
    echo ""
    echo -e "${MAGENTA}Model Registry:${NC}"
    echo -e "${YELLOW}5)${NC} Setup Model Registry ${GREEN}[NEW]${NC}"
    echo "    Deploy MySQL + create ModelRegistry instance"
    echo ""
    echo -e "${MAGENTA}AI Pipelines:${NC}"
    echo -e "${YELLOW}6)${NC} Setup Pipeline Server ${GREEN}[NEW]${NC}"
    echo "    Deploy DSPA with S3 storage (reuse existing MinIO or new)"
    echo ""
    echo -e "${MAGENTA}MCP Servers (Tool Calling):${NC}"
    echo -e "${YELLOW}7)${NC} MCP Server Management ${BLUE}→${NC}"
    echo "    Weather MCP, Kubernetes MCP, and other tool servers"
    echo ""
    echo -e "${CYAN}Tip: Deploy demos from: RHOAI Management → Demos${NC}"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to RHOAI Management"
    echo ""
}

show_demos_submenu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    Demos ${GREEN}[Version-Aware]${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${MAGENTA}Feature Store:${NC}"
    echo -e "${YELLOW}1)${NC} Deploy Banking Demo (Feast)"
    echo "    Banking feature store with customer/transaction features"
    echo ""
    echo -e "${MAGENTA}Chat & AI Assistants:${NC}"
    echo -e "${YELLOW}2)${NC} Deploy Open WebUI ${GREEN}[Recommended]${NC}"
    echo "    Web interface for chatting with models (OpenAI-compatible)"
    echo ""
    echo -e "${YELLOW}3)${NC} Deploy LlamaStack Demo"
    echo "    Full demo with Weather MCP Server, MongoDB, and Streamlit UI"
    echo ""
    echo -e "${MAGENTA}Benchmarking & Testing:${NC}"
    echo -e "${YELLOW}4)${NC} Deploy GuideLLM"
    echo "    LLM benchmarking tool (TTFT, ITL, throughput, latency)"
    echo ""
    echo -e "${MAGENTA}AI Safety:${NC}"
    echo -e "${YELLOW}5)${NC} Deploy Guardrails Demo ${GREEN}[TrustyAI]${NC}"
    echo "    PII detection, content filtering with Guardrails Orchestrator"
    echo ""
    echo -e "${MAGENTA}API Gateway:${NC}"
    echo -e "${YELLOW}6)${NC} MaaS Demo ${GREEN}[Interactive]${NC}"
    echo "    Chat with models, compare responses, view metrics"
    echo ""
    echo -e "${MAGENTA}Additional Demos:${NC}"
    echo -e "${YELLOW}7)${NC} Financial Loan Demo ${GREEN}[Predictive + GenAI]${NC}"
    echo "    ML model training + LLM fine-tuning + web app"
    echo ""
    echo -e "${YELLOW}8)${NC} Marketing Assistant Demo ${YELLOW}[3x L40S GPU]${NC}"
    echo "    Multi-agent A2A campaign manager with TrustyAI guardrails"
    echo ""
    echo -e "${YELLOW}9)${NC} AI Pipeline Demo ${GREEN}[KFP + Elyra]${NC}"
    echo "    End-to-end ML pipeline with Model Registry versioning"
    echo ""
    echo -e "${YELLOW}10)${NC} NeMo Guardrails Demo ${GREEN}[RHOAI 3.4]${NC}"
    echo "    CRD-based guardrails with PII detection and self-check rails"
    echo ""
    echo -e "${YELLOW}11)${NC} LMEval Builder Lab ${GREEN}[Benchmarks]${NC}"
    echo "    Korean language benchmarks + GuideLLM + MLflow tracking"
    echo ""
    echo -e "${YELLOW}12)${NC} n8n Workflow Automation"
    echo "    Deploy n8n workflow automation tool"
    echo ""
    echo -e "${YELLOW}13)${NC} MaaS Rate Limiting Demo ${GREEN}[API Keys + 429]${NC}"
    echo "    Workbench with notebook to test API key auth and token rate limits"
    echo ""
    echo -e "${MAGENTA}Technology Preview:${NC}"
    echo -e "${YELLOW}14)${NC} AutoML Demo ${YELLOW}[Tech Preview]${NC}"
    echo "    Automated ML model training via AutoGluon + Kubeflow Pipelines"
    echo ""
    echo -e "${YELLOW}15)${NC} AutoRAG Demo ${YELLOW}[Tech Preview]${NC}"
    echo "    Automated RAG pipeline optimization (requires Llama Stack + Milvus)"
    echo ""
    echo -e "${MAGENTA}Environment:${NC}"
    echo -e "${YELLOW}16)${NC} Deploy Full Demo Environment ${GREEN}[All-in-One]${NC}"
    echo "    Deploy all demos (except Marketing Assistant)"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to RHOAI Management"
    echo ""
}

show_rhoai32_features_submenu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           RHOAI 3.2+ Features (per CAI Guide)                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${MAGENTA}Model Serving (llm-d):${NC}"
    echo -e "${YELLOW}1)${NC} Setup llm-d Infrastructure ${GREEN}[Required]${NC}"
    echo "    GatewayClass, Gateway, RHCL/Kuadrant for authentication"
    echo ""
    echo -e "${YELLOW}2)${NC} Deploy LLMInferenceService"
    echo "    Deploy a model using llm-d runtime (RHOAI 3.2+, requires OCP 4.20+)"
    echo ""
    echo -e "${MAGENTA}New Operators:${NC}"
    echo -e "${YELLOW}3)${NC} Enable MLflow Operator ${GREEN}[NEW]${NC}"
    echo "    Experiment tracking, model versioning, artifact storage"
    echo ""
    echo -e "${YELLOW}4)${NC} Enable LlamaStack Operator"
    echo "    LlamaStack distribution management"
    echo ""
    echo -e "${MAGENTA}Observability:${NC}"
    echo -e "${YELLOW}5)${NC} Enable Cluster Monitoring for KServe"
    echo "    UserWorkloadMonitoring for KServe metrics"
    echo ""
    echo -e "${YELLOW}6)${NC} Configure DSCInitialization Observability"
    echo "    Metrics storage, distributed tracing with Tempo"
    echo ""
    echo -e "${MAGENTA}Configuration:${NC}"
    echo -e "${YELLOW}7)${NC} Setup MCP Servers ConfigMap (3.2 format)"
    echo "    New JSON format for MCP server configuration"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to RHOAI Management"
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
# Remove kubeadmin (Day 2 Operations)
################################################################################

remove_kubeadmin() {
    print_header "Remove kubeadmin User"

    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi

    local current_user
    current_user=$(oc whoami 2>/dev/null)

    # Safety: don't allow removal while logged in as kube:admin
    if [ "$current_user" = "kube:admin" ]; then
        print_error "You are currently logged in as kube:admin!"
        echo ""
        echo "You must log in as a different cluster-admin user before removing kubeadmin."
        echo "  oc login -u admin -p 'R3dh4t1!' $(oc whoami --show-server 2>/dev/null)"
        return 1
    fi

    # Verify the current user has cluster-admin
    if ! oc auth can-i '*' '*' --all-namespaces &>/dev/null; then
        print_error "Current user '$current_user' does not have cluster-admin privileges"
        return 1
    fi

    # Check if kubeadmin secret exists
    if ! oc get secret kubeadmin -n kube-system &>/dev/null; then
        print_info "kubeadmin has already been removed"
        return 0
    fi

    echo -e "${YELLOW}WARNING: This will permanently remove the kubeadmin user.${NC}"
    echo ""
    echo "  Current user: $current_user"
    echo "  You will no longer be able to log in as kube:admin"
    echo "  Make sure you can log in via htpasswd (admin / R3dh4t1!)"
    echo ""

    read -p "Are you sure you want to remove kubeadmin? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_info "Cancelled"
        return 0
    fi

    print_step "Removing kubeadmin..."
    oc delete secret kubeadmin -n kube-system

    print_success "kubeadmin has been removed"
    print_info "Log in via: oc login -u admin -p 'R3dh4t1!'"
}

################################################################################
# Day 2 Operations Submenu
################################################################################

day2_operations_submenu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                 Day 2 Operations                               ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}1)${NC} Approve Pending CSRs"
        echo "    Approve certificate signing requests for new/rebooted nodes"
        echo ""
        echo -e "${YELLOW}2)${NC} Remove kubeadmin ${RED}[Destructive]${NC}"
        echo "    Permanently remove the kubeadmin user (requires htpasswd admin)"
        echo ""
        echo -e "${YELLOW}3)${NC} Recover Ingress Router"
        echo "    Fix router pod stuck in CrashLoopBackOff"
        echo ""
        echo -e "${YELLOW}0)${NC} Back"
        echo ""

        read -p "Select an option (0-3): " day2_choice
        case $day2_choice in
            1)
                approve_pending_csrs
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                remove_kubeadmin
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                print_header "Router Recovery"
                source "$ROOT_DIR/scripts/install-rhoai-34.sh" --source-only 2>/dev/null || true
                local router_status
                router_status=$(oc get pods -n openshift-ingress \
                    -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default \
                    -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)
                if [ "$router_status" = "CrashLoopBackOff" ]; then
                    print_warning "Router is in CrashLoopBackOff — restarting..."
                    oc delete pod -n openshift-ingress \
                        -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default \
                        --wait=false 2>/dev/null
                    sleep 10
                    oc get pods -n openshift-ingress --no-headers
                    print_success "Router pod restarted"
                else
                    local phase
                    phase=$(oc get pods -n openshift-ingress \
                        -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default \
                        -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
                    print_success "Router is healthy (status: $phase)"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                return 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
    done
}


################################################################################
# Model Storage (MinIO + HuggingFace)
################################################################################

setup_model_storage_interactive() {
    print_header "Setup Model Storage (MinIO)"
    
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
    
    # Check if MinIO already exists
    local existing_ns=""
    for ns in model-storage demo; do
        if oc get deployment minio -n "$ns" &>/dev/null 2>&1; then
            existing_ns="$ns"
            break
        fi
    done
    
    if [ -n "$existing_ns" ]; then
        print_info "MinIO already deployed in namespace: $existing_ns"
        echo ""
        local minio_route=$(oc get route minio-console -n "$existing_ns" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
        if [ -n "$minio_route" ]; then
            echo -e "${CYAN}MinIO Console:${NC} https://$minio_route"
        fi
        echo ""
        read -p "Deploy MinIO in a different namespace? (y/N): " deploy_new
        if [[ ! "$deploy_new" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    # Get namespace
    echo ""
    read -p "Namespace for MinIO [model-storage]: " namespace
    namespace=${namespace:-model-storage}
    
    # Get storage size
    read -p "Storage size [200Gi]: " storage_size
    storage_size=${storage_size:-200Gi}
    
    # Get bucket name
    read -p "Bucket name [models]: " bucket_name
    bucket_name=${bucket_name:-models}
    
    # Data connection namespace
    echo ""
    echo -e "${CYAN}Data connections allow RHOAI workbenches and model servers to access MinIO.${NC}"
    read -p "Create data connection in namespace [$namespace]: " dc_ns
    dc_ns=${dc_ns:-$namespace}
    
    echo ""
    print_step "Running setup-model-storage.sh..."
    echo ""
    
    "$SCRIPT_DIR/scripts/setup-model-storage.sh" \
        --namespace "$namespace" \
        --bucket "$bucket_name" \
        --storage-size "$storage_size" \
        --data-connection-ns "$dc_ns"
    
    return $?
}

download_hf_model_interactive() {
    print_header "Download Model from HuggingFace"
    
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
    
    # Check if MinIO exists
    local minio_ns=""
    for ns in model-storage demo; do
        if oc get deployment minio -n "$ns" &>/dev/null 2>&1; then
            minio_ns="$ns"
            break
        fi
    done
    
    if [ -z "$minio_ns" ]; then
        print_warning "MinIO not found. Please set up model storage first."
        echo ""
        echo "Run option 3 (Setup Model Storage) to deploy MinIO."
        return 1
    fi
    
    print_info "Found MinIO in namespace: $minio_ns"
    echo ""
    
    # Get model name
    echo -e "${CYAN}Popular models:${NC}"
    echo "  - Qwen/Qwen3-8B"
    echo "  - Qwen/Qwen2.5-7B-Instruct"
    echo "  - meta-llama/Llama-3.1-8B-Instruct (requires HF token)"
    echo "  - mistralai/Mistral-7B-Instruct-v0.3"
    echo ""
    read -p "Model name (e.g., Qwen/Qwen3-8B): " model_name
    
    if [ -z "$model_name" ]; then
        print_error "Model name is required"
        return 1
    fi
    
    # Check if model requires authentication
    local needs_token=false
    if [[ "$model_name" == *"llama"* ]] || [[ "$model_name" == *"Llama"* ]]; then
        needs_token=true
    fi
    
    # Get HF token if needed
    local hf_token=""
    if [ "$needs_token" = true ]; then
        echo ""
        print_warning "This model may require a HuggingFace token."
        echo "Get your token from: https://huggingface.co/settings/tokens"
        read -p "HuggingFace token (leave empty to skip): " hf_token
    else
        echo ""
        read -p "HuggingFace token (optional, for gated models): " hf_token
    fi
    
    # Get namespace for download job
    echo ""
    read -p "Namespace for download job [$minio_ns]: " job_ns
    job_ns=${job_ns:-$minio_ns}
    
    # Check for data connection
    if ! oc get secret aws-connection-my-storage -n "$job_ns" &>/dev/null && \
       ! oc get secret aws-connection-minio -n "$job_ns" &>/dev/null; then
        print_warning "No data connection found in namespace '$job_ns'"
        echo ""
        echo "Creating data connection..."
        "$SCRIPT_DIR/scripts/setup-model-storage.sh" \
            --namespace "$minio_ns" \
            --skip-data-connection \
            --data-connection-ns "$job_ns" 2>/dev/null || true
    fi
    
    echo ""
    print_step "Starting download..."
    echo ""
    echo -e "${CYAN}This may take a while depending on model size.${NC}"
    echo "You can monitor progress with:"
    echo "  oc logs -f job/download-models-s3 -n $job_ns"
    echo ""
    
    # Run download
    NAMESPACE="$job_ns" MINIO_NAMESPACE="$minio_ns" HF_TOKEN="$hf_token" \
        "$SCRIPT_DIR/scripts/download-model.sh" s3 "$model_name"
    
    local result=$?
    
    if [ $result -eq 0 ]; then
        echo ""
        print_success "Model downloaded successfully!"
        echo ""
        echo -e "${CYAN}To deploy this model:${NC}"
        echo "  1. Go to RHOAI Dashboard → Data Science Projects"
        echo "  2. Create/select a project"
        echo "  3. Deploy model with:"
        echo "     - Data connection: MinIO Model Storage"
        echo "     - Path: $model_name"
        echo ""
        echo "  Or use CLI:"
        echo "     storageUri: s3://models/$model_name/"
    fi
    
    return $result
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
# Predictive Model Deployment (interactive wrapper)
################################################################################

deploy_predictive_model_interactive() {
    print_header "Deploy Predictive Model (CPU)"

    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo "  oc login <cluster-url>"
        return 1
    fi

    source "$SCRIPT_DIR/lib/utils/colors.sh"
    source "$SCRIPT_DIR/lib/functions/model-deployment.sh"

    # Select namespace
    echo -e "${YELLOW}Available data science projects:${NC}"
    oc get projects -l opendatahub.io/dashboard=true --no-headers 2>/dev/null | awk '{print "  " $1}'
    echo ""
    read -rp "Namespace to deploy in: " target_ns
    if [ -z "$target_ns" ]; then
        print_error "Namespace is required"
        return 1
    fi
    if ! oc get project "$target_ns" &>/dev/null; then
        print_error "Project '$target_ns' does not exist"
        return 1
    fi

    # Select model format
    echo ""
    echo -e "${YELLOW}Model format:${NC}"
    echo "  1) sklearn"
    echo "  2) xgboost"
    echo "  3) lightgbm"
    echo "  4) onnx"
    echo "  5) mlflow"
    read -rp "Select format [1]: " fmt_choice
    local model_format
    case "${fmt_choice:-1}" in
        1) model_format="sklearn" ;;
        2) model_format="xgboost" ;;
        3) model_format="lightgbm" ;;
        4) model_format="onnx" ;;
        5) model_format="mlflow" ;;
        *) model_format="sklearn" ;;
    esac

    # Model name
    echo ""
    read -rp "Model name (InferenceService name) [my-model]: " model_name
    model_name="${model_name:-my-model}"

    # S3 storage path
    echo ""
    echo -e "${YELLOW}S3 path to model artifacts (e.g. s3://models/my-model/):${NC}"

    # List available buckets from MinIO if possible
    local minio_pod
    minio_pod=$(oc get pod -n "$target_ns" -l app=minio --no-headers 2>/dev/null | awk 'NR==1{print $1}')
    if [ -n "$minio_pod" ]; then
        echo -e "${CYAN}Available paths in MinIO:${NC}"
        oc exec -n "$target_ns" "$minio_pod" -- sh -c 'ls /data/ 2>/dev/null' | while read -r bucket; do
            echo "  s3://$bucket/"
            oc exec -n "$target_ns" "$minio_pod" -- sh -c "ls /data/$bucket/ 2>/dev/null" | while read -r prefix; do
                echo "    s3://$bucket/$prefix/"
            done
        done
        echo ""
    fi

    read -rp "Storage URI: " storage_uri
    if [ -z "$storage_uri" ]; then
        print_error "Storage URI is required (e.g. s3://models/my-model/)"
        return 1
    fi

    # Data connection
    echo ""
    echo -e "${YELLOW}Available data connections in $target_ns:${NC}"
    oc get secret -n "$target_ns" -l opendatahub.io/dashboard=true --no-headers 2>/dev/null | awk '{print "  " $1}' || true
    local default_dc="aws-connection-minio"
    if oc get secret aws-connection-minio -n "$target_ns" &>/dev/null; then
        echo ""
        echo -e "${CYAN}Default: $default_dc${NC}"
    fi
    read -rp "Data connection secret [$default_dc]: " data_conn
    data_conn="${data_conn:-$default_dc}"

    # Confirm and deploy
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  Deployment Summary                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "  ${BLUE}Name:${NC}            $model_name"
    echo -e "  ${BLUE}Namespace:${NC}       $target_ns"
    echo -e "  ${BLUE}Format:${NC}          $model_format"
    echo -e "  ${BLUE}Storage URI:${NC}     $storage_uri"
    echo -e "  ${BLUE}Data Connection:${NC} $data_conn"
    echo ""
    read -rp "Deploy? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Cancelled"
        return 0
    fi

    deploy_predictive_model "$model_name" "$target_ns" "$storage_uri" \
        --format "$model_format" \
        --data-connection "$data_conn"
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

# Quick GPU Hardware Profile Creation with pre-configured defaults
create_hardware_profile_quick() {
    print_header "Quick GPU Hardware Profile Setup"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift"
        return 1
    fi
    
    local template_dir="$SCRIPT_DIR/lib/manifests/templates"
    
    # Get namespace
    echo -e "${CYAN}Enter the namespace for hardware profiles${NC}"
    echo -e "${YELLOW}Default: redhat-ods-applications (global - visible in all projects)${NC}"
    echo ""
    read -p "Namespace [redhat-ods-applications]: " input_ns
    local target_ns="${input_ns:-redhat-ods-applications}"
    
    # Validate namespace
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_error "Namespace '$target_ns' does not exist"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}Select GPU Hardware Profile Size:${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} Small  - For 4B-8B models (Qwen3-4B, Llama-3-8B)"
    echo "         CPU: 2 (max 8) | Memory: 8Gi (max 24Gi) | GPU: 1"
    echo "         Best for: g6e.xlarge, g6e.2xlarge"
    echo ""
    echo -e "${YELLOW}2)${NC} Medium - For 8B-30B models (Qwen-14B, quantized 70B)"
    echo "         CPU: 4 (max 16) | Memory: 32Gi (max 64Gi) | GPU: 1"
    echo "         Best for: g6e.4xlarge, g6e.8xlarge"
    echo ""
    echo -e "${YELLOW}3)${NC} Large  - For 70B+ models, multi-GPU"
    echo "         CPU: 16 (max 96) | Memory: 128Gi (max 512Gi) | GPU: 4-8"
    echo "         Best for: p5.48xlarge, g6e.48xlarge"
    echo ""
    echo -e "${YELLOW}4)${NC} All    - Create all three profiles ${GREEN}[Recommended]${NC}"
    echo ""
    
    read -p "Select option (1-4): " choice
    
    export NAMESPACE="$target_ns"
    
    case $choice in
        1)
            if [ -f "$template_dir/hardwareprofile-gpu-small.yaml.tmpl" ]; then
                envsubst < "$template_dir/hardwareprofile-gpu-small.yaml.tmpl" | oc apply -f -
                print_success "Created gpu-small profile"
            else
                print_error "Template not found"
                return 1
            fi
            ;;
        2)
            if [ -f "$template_dir/hardwareprofile-gpu-medium.yaml.tmpl" ]; then
                envsubst < "$template_dir/hardwareprofile-gpu-medium.yaml.tmpl" | oc apply -f -
                print_success "Created gpu-medium profile"
            else
                print_error "Template not found"
                return 1
            fi
            ;;
        3)
            if [ -f "$template_dir/hardwareprofile-gpu-large.yaml.tmpl" ]; then
                envsubst < "$template_dir/hardwareprofile-gpu-large.yaml.tmpl" | oc apply -f -
                print_success "Created gpu-large profile"
            else
                print_error "Template not found"
                return 1
            fi
            ;;
        4)
            for size in small medium large; do
                local template="$template_dir/hardwareprofile-gpu-${size}.yaml.tmpl"
                if [ -f "$template" ]; then
                    envsubst < "$template" | oc apply -f -
                    print_success "Created gpu-${size} profile"
                fi
            done
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    unset NAMESPACE
    
    echo ""
    print_header "Hardware Profiles in $target_ns"
    oc get hardwareprofile -n "$target_ns" 2>/dev/null || echo "No profiles found"
    
    echo ""
    print_info "These profiles include:"
    print_info "  • Node selector: nvidia.com/gpu.present=true"
    print_info "  • Toleration: nvidia.com/gpu:NoSchedule"
    print_info "  • Kueue scheduling with default queue"
    echo ""
    print_info "Use these when deploying models in the RHOAI dashboard"
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
    --skip-openshift    Skip OpenShift installation (use existing cluster)
    --skip-gpu          Skip GPU worker node creation
    --skip-rhoai        Skip RHOAI installation
    -h, --help          Show this help message

EXAMPLES:
    $0                              # Interactive mode
    $0 --with-maas                  # Full setup including MaaS
    $0 --skip-maas                  # Setup without MaaS
    $0 --skip-openshift             # Install RHOAI on existing cluster
    $0 --skip-openshift --skip-gpu  # Install only RHOAI (no OpenShift, no GPU)
    $0 --maas-only                  # Only set up MaaS infrastructure

WHAT THIS SCRIPT DOES:
    1. Runs scripts/integrated-workflow-v2.sh for OpenShift + RHOAI installation
    2. Optionally runs scripts/setup-maas.sh (MaaS API infrastructure)
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
    
    # Check for required workflow script
    if [ ! -f "$SCRIPT_DIR/scripts/integrated-workflow-v2.sh" ]; then
        print_error "scripts/integrated-workflow-v2.sh not found"
        all_good=false
    else
        print_success "scripts/integrated-workflow-v2.sh found"
    fi
    
    # Make executable if needed
    if [ ! -x "$SCRIPT_DIR/scripts/integrated-workflow-v2.sh" ]; then
        print_warning "Making scripts/integrated-workflow-v2.sh executable..."
        chmod +x "$SCRIPT_DIR/scripts/integrated-workflow-v2.sh"
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
    
    workflow_script="$SCRIPT_DIR/scripts/integrated-workflow-v2.sh"
    print_step "Running scripts/integrated-workflow-v2.sh..."
    
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
        read -p "Select an option (1-8, h, 0): " choice
        
        case $choice in
            1)
                run_complete_setup
                ;;
            2)
                run_minimal_setup
                ;;
            3)
                install_rhoai_menu
                ;;
            4)
                workshop_setup_menu
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
            h|H)
                show_help
                echo ""
                read -p "Press Enter to return to main menu..."
                ;;
            0)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-8, h, or 0."
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
    
    # Check if script exists
    local minimal_script="$SCRIPT_DIR/scripts/install-rhoai-minimal.sh"
    if [ ! -f "$minimal_script" ]; then
        print_error "Minimal setup script not found at: $minimal_script"
        return 1
    fi
    
    # Make executable
    chmod +x "$minimal_script"
    
    # Ask for installation mode
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

################################################################################
# Unified RHOAI Installation (dynamic channel selection)
################################################################################

install_rhoai_menu() {
    print_header "Install Red Hat OpenShift AI"

    print_step "Fetching available RHOAI channels from cluster..."

    local channel_data
    channel_data=$(oc get packagemanifest rhods-operator -n openshift-marketplace \
        -o jsonpath='{range .status.channels[*]}{.name}|{.currentCSV}{"\n"}{end}' 2>/dev/null)

    if [ -z "$channel_data" ]; then
        print_error "Unable to fetch RHOAI channels from cluster"
        print_info "Make sure you are connected to an OpenShift cluster with access to redhat-operators"
        echo ""
        read -p "Press Enter to return to main menu..."
        return 1
    fi

    local default_channel
    default_channel=$(oc get packagemanifest rhods-operator -n openshift-marketplace \
        -o jsonpath='{.status.defaultChannel}' 2>/dev/null)

    # Parse channel names and extract version from currentCSV (e.g. rhods-operator.3.4.1 -> 3.4.1)
    local -a channel_list
    local -a channel_versions
    while IFS='|' read -r ch_name ch_csv; do
        [ -z "$ch_name" ] && continue
        local ver="${ch_csv##*.}"
        # CSV format: rhods-operator.X.Y.Z — grab last 3 dot-segments
        if [[ "$ch_csv" =~ ([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
            ver="${BASH_REMATCH[1]}"
        fi
        channel_list+=("$ch_name")
        channel_versions+=("$ver")
    done < <(echo "$channel_data" | sort -t'|' -k2 -rV)

    echo ""
    echo -e "${CYAN}Available RHOAI channels on this cluster:${NC}"
    echo ""
    local i=1
    for idx in "${!channel_list[@]}"; do
        local ch="${channel_list[$idx]}"
        local ver="${channel_versions[$idx]}"
        local label=""
        if [ "$ch" = "$default_channel" ]; then
            label=" ${GREEN}[default]${NC}"
        fi
        printf "  ${YELLOW}%d)${NC} %-16s — v%s%b\n" "$i" "$ch" "$ver" "$label"
        i=$((i + 1))
    done
    echo ""
    echo -e "  ${YELLOW}0)${NC} Back to main menu"
    echo ""

    read -p "Select channel (1-${#channel_list[@]}, 0): " ch_choice

    if [ "$ch_choice" = "0" ] || [ -z "$ch_choice" ]; then
        return 0
    fi

    if ! [[ "$ch_choice" =~ ^[0-9]+$ ]] || [ "$ch_choice" -lt 1 ] || [ "$ch_choice" -gt "${#channel_list[@]}" ]; then
        print_warning "Invalid selection"
        echo ""
        read -p "Press Enter to return to main menu..."
        return 0
    fi

    local selected_channel="${channel_list[$((ch_choice - 1))]}"
    echo ""
    print_info "Selected channel: $selected_channel"
    echo ""

    case "$selected_channel" in
        *3.4*|fast-3.x)
            echo -e "${CYAN}Launching RHOAI 3.4 installer (channel: $selected_channel)...${NC}"
            echo ""
            read -p "Proceed? (Y/n): " confirm
            if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
                "$SCRIPT_DIR/scripts/install-rhoai-34.sh" --channel "$selected_channel"
            fi
            ;;
        *3.3*)
            echo -e "${CYAN}Launching RHOAI 3.3 installer (channel: $selected_channel)...${NC}"
            echo ""
            read -p "Proceed? (Y/n): " confirm
            if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
                "$SCRIPT_DIR/scripts/install-rhoai-33.sh" --channel "$selected_channel"
            fi
            ;;
        stable-2.*|stable)
            local version="${selected_channel#stable-}"
            [ "$version" = "stable" ] && version="2.25"
            echo -e "${CYAN}Launching RHOAI 2.x installer (version $version)...${NC}"
            echo ""
            read -p "Proceed? (Y/n): " confirm
            if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
                install_rhoai_2x "$version" "$selected_channel"
            fi
            ;;
        *)
            print_info "No dedicated installer for channel '$selected_channel'"
            print_info "Using interactive operator installer..."
            echo ""
            read -p "Proceed? (Y/n): " confirm
            if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
                SELECTED_RHOAI_CHANNEL="$selected_channel"
                install_rhoai_operator_interactive
            fi
            ;;
    esac

    echo ""
    read -p "Press Enter to return to main menu..."
}

################################################################################
# RHOAI 2.x Installation (Older Versions)
################################################################################

show_rhoai_2x_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           RHOAI 2.x Installation (Older Versions)              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} RHOAI 2.x uses different APIs and dependencies than 3.x"
    echo ""
    echo -e "${YELLOW}1)${NC} Install RHOAI 2.25 (Latest 2.x) ${GREEN}[Recommended]${NC}"
    echo "    Channel: stable-2.25"
    echo ""
    echo -e "${YELLOW}2)${NC} Install RHOAI 2.22"
    echo "    Channel: stable-2.22"
    echo ""
    echo -e "${YELLOW}3)${NC} Install RHOAI 2.19"
    echo "    Channel: stable-2.19"
    echo ""
    echo -e "${YELLOW}4)${NC} Check Current RHOAI Version"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to Main Menu"
    echo ""
}

install_rhoai_2x() {
    local version="$1"
    local channel="$2"
    
    print_header "Installing RHOAI $version (Channel: $channel)"
    
    local manifests_dir="$SCRIPT_DIR/lib/manifests/rhoai-2x"
    
    if [ ! -d "$manifests_dir" ]; then
        print_error "RHOAI 2.x manifests not found at: $manifests_dir"
        return 1
    fi
    
    # Step 1: Install NFD Operator
    print_step "Installing Node Feature Discovery (NFD) Operator..."
    if oc get subscription nfd -n openshift-nfd &>/dev/null; then
        print_success "NFD Operator already installed"
    else
        oc apply -f "$manifests_dir/nfd.yaml"
        print_success "NFD Operator subscription created"
    fi
    
    # Wait for NFD CRD
    print_step "Waiting for NFD CRD..."
    local timeout=120
    local elapsed=0
    until oc get crd nodefeaturediscoveries.nfd.openshift.io &>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Timeout waiting for NFD CRD, continuing..."
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    # Apply NFD CR
    if oc get crd nodefeaturediscoveries.nfd.openshift.io &>/dev/null; then
        print_step "Creating NFD instance..."
        oc apply -f "$manifests_dir/nfd-cr.yaml" || true
        print_success "NFD instance created"
    fi
    
    # Step 2: Install NVIDIA GPU Operator
    print_step "Installing NVIDIA GPU Operator..."
    if oc get subscription gpu-operator-certified -n nvidia-gpu-operator &>/dev/null; then
        print_success "GPU Operator already installed"
    else
        oc apply -f "$manifests_dir/nvidia.yaml"
        print_success "GPU Operator subscription created (Automatic approval)"
    fi
    
    # Wait for GPU Operator CRD
    print_step "Waiting for ClusterPolicy CRD..."
    timeout=180
    elapsed=0
    until oc get crd clusterpolicies.nvidia.com &>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Timeout waiting for GPU Operator CRD, continuing..."
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    # Apply ClusterPolicy
    if oc get crd clusterpolicies.nvidia.com &>/dev/null; then
        print_step "Creating ClusterPolicy..."
        oc apply -f "$manifests_dir/nvidia-cr.yaml" || true
        print_success "ClusterPolicy created"
    fi
    
    # Step 3: Install dependency operators
    print_step "Installing Authorino Operator..."
    oc apply -f "$manifests_dir/authorino.yaml" || true
    
    print_step "Installing Serverless Operator..."
    oc apply -f "$manifests_dir/serverless.yaml" || true
    
    print_step "Installing Service Mesh Operator..."
    oc apply -f "$manifests_dir/servicemesh.yaml" || true
    
    # Step 4: Install RHOAI Operator with specified channel
    print_step "Installing RHOAI Operator (channel: $channel)..."
    
    # Create namespace and operator group
    oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: redhat-ods-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: redhat-ods-operator
  namespace: redhat-ods-operator
spec:
  upgradeStrategy: Default
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  channel: $channel
  installPlanApproval: Automatic
  name: rhods-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
    
    print_success "RHOAI Operator subscription created"
    
    # Wait for DSCInitialization
    print_step "Waiting for RHOAI Operator to initialize (this may take 2-3 minutes)..."
    timeout=300
    elapsed=0
    until oc get DSCInitialization/default-dsci -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null | grep -q "True"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Timeout waiting for DSCInitialization"
            break
        fi
        echo "  Waiting for DSCInitialization... (${elapsed}s elapsed)"
        sleep 15
        elapsed=$((elapsed + 15))
    done
    
    if oc get DSCInitialization/default-dsci -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null | grep -q "True"; then
        print_success "DSCInitialization is ready"
    fi
    
    # Step 5: Create DataScienceCluster
    print_step "Creating DataScienceCluster..."
    oc apply -f "$manifests_dir/datasciencecluster.yaml"
    
    # Wait for DSC to be ready
    print_step "Waiting for DataScienceCluster to be ready..."
    timeout=600
    elapsed=0
    until oc get DataScienceCluster/default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; do
        if [ $elapsed -ge $timeout ]; then
            print_warning "Timeout waiting for DataScienceCluster"
            break
        fi
        echo "  Waiting for DataScienceCluster... (${elapsed}s elapsed)"
        sleep 15
        elapsed=$((elapsed + 15))
    done
    
    if oc get DataScienceCluster/default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
        print_success "DataScienceCluster is ready"
    fi
    
    # Step 6: Set operator to manual upgrades
    print_step "Setting RHOAI operator to manual upgrades..."
    oc patch subscription rhods-operator -n redhat-ods-operator --type=merge -p '{"spec": {"installPlanApproval": "Manual"}}' || true
    
    # Step 7: Apply additional configurations
    print_step "Applying dashboard configuration..."
    oc apply -f "$manifests_dir/odhdashboardconfig.yaml" || true
    
    print_step "Creating admin group with kube:admin..."
    oc apply -f "$manifests_dir/group.yaml" || true
    
    # Configure dashboard admin groups
    print_step "Configuring RHOAI dashboard admin groups..."
    oc patch odhdashboardconfig odh-dashboard-config -n redhat-ods-applications --type=merge -p '{
      "spec": {
        "groupsConfig": {
          "adminGroups": "rhods-admins,dedicated-admins,cluster-admins",
          "allowedGroups": "system:authenticated"
        }
      }
    }' 2>/dev/null || true
    
    print_step "Creating serving runtime template..."
    oc apply -f "$manifests_dir/template-rhaiis.yaml" || true
    
    print_step "Creating GPU hardware profile..."
    oc apply -f "$manifests_dir/hardwareprofile.yaml" || true
    
    print_step "Enabling user workload monitoring..."
    oc apply -f "$manifests_dir/uwm.yaml" || true
    
    # Restart dashboard
    print_step "Restarting dashboard pods..."
    oc delete pods -l app=rhods-dashboard -n redhat-ods-applications 2>/dev/null || true
    sleep 5
    
    # Display summary
    echo ""
    print_header "RHOAI $version Installation Summary"
    
    local installed_version=$(oc get csv -n redhat-ods-operator 2>/dev/null | grep rhods | awk '{print $2}' || echo "Unknown")
    local dsc_status=$(oc get DataScienceCluster/default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    local dashboard_url=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='https://{.spec.host}' 2>/dev/null || echo "Not available")
    
    echo -e "${GREEN}Installed Version:${NC} $installed_version"
    echo -e "${GREEN}DSC Status:${NC} $dsc_status"
    echo -e "${GREEN}Dashboard URL:${NC} $dashboard_url"
    echo ""
    
    # Show installed components
    print_step "Installed Components:"
    oc get DataScienceCluster/default-dsc -o jsonpath='{.status.installedComponents}' 2>/dev/null | jq . || true
    
    print_success "RHOAI $version installation complete!"
    return 0
}

check_rhoai_version() {
    print_header "Current RHOAI Installation"
    
    echo -e "${CYAN}Checking RHOAI operator...${NC}"
    echo ""
    
    local csv_info=$(oc get csv -n redhat-ods-operator 2>/dev/null | grep rhods || true)
    
    if [ -z "$csv_info" ]; then
        print_warning "RHOAI is not installed on this cluster"
        return 0
    fi
    
    echo -e "${GREEN}Operator:${NC}"
    echo "$csv_info"
    echo ""
    
    local subscription_channel=$(oc get subscription rhods-operator -n redhat-ods-operator -o jsonpath='{.spec.channel}' 2>/dev/null || echo "Unknown")
    echo -e "${GREEN}Subscription Channel:${NC} $subscription_channel"
    echo ""
    
    local dsc_status=$(oc get DataScienceCluster/default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Not found")
    echo -e "${GREEN}DataScienceCluster Status:${NC} $dsc_status"
    echo ""
    
    echo -e "${GREEN}Installed Components:${NC}"
    oc get DataScienceCluster/default-dsc -o jsonpath='{.status.installedComponents}' 2>/dev/null | jq . || echo "  Not available"
    echo ""
    
    local dashboard_url=$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='https://{.spec.host}' 2>/dev/null || echo "Not available")
    echo -e "${GREEN}Dashboard URL:${NC} $dashboard_url"
    
    return 0
}

rhoai_2x_menu() {
    while true; do
        show_rhoai_2x_menu
        read -p "Select an option (0-4): " choice
        
        case $choice in
            1)
                install_rhoai_2x "2.25" "stable-2.25"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                install_rhoai_2x "2.22" "stable-2.22"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                install_rhoai_2x "2.19" "stable-2.19"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                check_rhoai_version
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                return 0
                ;;
            *)
                print_warning "Invalid option. Please try again."
                sleep 1
                ;;
        esac
    done
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

