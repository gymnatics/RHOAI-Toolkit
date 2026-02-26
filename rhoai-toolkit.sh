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
#   ./rhoai-toolkit.sh --legacy           # Use legacy version (scripts/integrated-workflow.sh)
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
    echo -e "${YELLOW}1)${NC} Complete Setup (OpenShift + RHOAI + GPU + MaaS) ${MAGENTA}[Full]${NC}"
    echo -e "${YELLOW}2)${NC} Minimal RHOAI Setup (choose operators) ${GREEN}[Flexible]${NC}"
    echo -e "${YELLOW}3)${NC} RHOAI Management (configure features, deploy models, etc.)"
    echo -e "${YELLOW}4)${NC} Create GPU MachineSet (add GPU nodes to existing cluster)"
    echo -e "${YELLOW}5)${NC} Configure Kubeconfig (login, set, or create kubeconfig) ${CYAN}[Connection]${NC}"
    echo -e "${YELLOW}6)${NC} Help (show scripts and documentation)"
    echo -e "${YELLOW}7)${NC} Exit"
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
    echo -e "${YELLOW}2)${NC} AI Services ${BLUE}→${NC}"
    echo "    LlamaStack, MCP Servers, Model as a Service (MaaS)"
    echo ""
    echo -e "${YELLOW}3)${NC} Dashboard & Configuration"
    echo "    Enable features like Model Registry, GenAI Studio"
    echo ""
    echo -e "${YELLOW}4)${NC} Quick Start Wizard ${MAGENTA}✨${NC}"
    echo "    Run typical post-install workflow"
    echo ""
    echo -e "${YELLOW}5)${NC} Day 2 Operations"
    echo "    Approve CSRs, cluster maintenance"
    echo ""
    echo -e "${YELLOW}6)${NC} Troubleshooting & Fixes ${RED}[Fixes]${NC}"
    echo "    GPU operator issues, CUDA compatibility, common problems"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to Main Menu"
    echo ""
}

show_model_management_submenu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 Model Management                               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} Deploy Model"
    echo "    Interactive model deployment to OpenShift AI"
    echo ""
    echo -e "${YELLOW}2)${NC} Add Model to Playground"
    echo "    Test models interactively in GenAI Studio"
    echo ""
    echo -e "${YELLOW}3)${NC} Create GPU Hardware Profile (Custom)"
    echo "    Define custom GPU resources for model deployments"
    echo ""
    echo -e "${YELLOW}4)${NC} Quick GPU Profile Setup ${GREEN}[Recommended]${NC}"
    echo "    Create pre-configured profiles (Small/Medium/Large)"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to RHOAI Management"
    echo ""
}

show_ai_services_submenu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 AI Services                                    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${MAGENTA}Demo UIs:${NC}"
    echo -e "${YELLOW}1)${NC} Deploy Open WebUI ${GREEN}[Recommended]${NC}"
    echo "    Web interface for chatting with models (OpenAI-compatible)"
    echo ""
    echo -e "${YELLOW}2)${NC} Deploy LlamaStack Demo ${CYAN}[Demo]${NC}"
    echo "    Full demo with Weather MCP Server, MongoDB, and UI"
    echo ""
    echo -e "${MAGENTA}MCP Servers (Tool Calling):${NC}"
    echo -e "${YELLOW}3)${NC} Setup MCP Servers"
    echo "    Weather MCP, Kubernetes MCP, and other tool servers"
    echo ""
    echo -e "${MAGENTA}Other Services:${NC}"
    echo -e "${YELLOW}4)${NC} Setup LlamaStack (Generic)"
    echo "    Deploy LlamaStack with vLLM, Azure, OpenAI, Ollama, or Bedrock"
    echo ""
    echo -e "${YELLOW}5)${NC} Setup MaaS (Model as a Service)"
    echo "    API gateway for model serving"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to RHOAI Management"
    echo ""
}

show_troubleshooting_submenu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 Troubleshooting & Fixes                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}GPU / CUDA Issues:${NC}"
    echo -e "${YELLOW}1)${NC} Fix GPU Operator CUDA Compatibility ${GREEN}[Common Fix]${NC}"
    echo "    Downgrade GPU Operator to v24.6.x for vLLM compatibility"
    echo "    (Fixes: 'NVIDIA driver too old' error with CUDA 13)"
    echo ""
    echo -e "${YELLOW}2)${NC} Check GPU Operator Status"
    echo "    View current version, driver, and CUDA compatibility"
    echo ""
    echo -e "${YELLOW}3)${NC} Uncordon GPU Nodes"
    echo "    Re-enable scheduling on GPU nodes after maintenance"
    echo ""
    echo -e "${RED}Operator Issues:${NC}"
    echo -e "${YELLOW}4)${NC} Fix Operator Channel Issues"
    echo "    Re-sync operators with correct channels (Kueue, LWS, etc.)"
    echo ""
    echo -e "${YELLOW}5)${NC} Check All Operator Status"
    echo "    View status of all RHOAI-related operators"
    echo ""
    echo -e "${RED}Model Serving Issues:${NC}"
    echo -e "${YELLOW}6)${NC} Restart Failed Model Pods"
    echo "    Delete and recreate pods for stuck InferenceServices"
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
# Troubleshooting & Fixes Functions
################################################################################

# Fix GPU Operator CUDA Compatibility
# Downgrades GPU Operator to v24.6.x which uses CUDA 12.x (compatible with vLLM)
fix_gpu_operator_cuda_compatibility() {
    print_header "Fix GPU Operator CUDA Compatibility"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    echo -e "${YELLOW}Issue:${NC} GPU Operator v24.9.x ships with CUDA 13, but vLLM in RHOAI"
    echo "       requires CUDA 12.x. This causes 'NVIDIA driver too old' errors."
    echo ""
    echo -e "${GREEN}Solution:${NC} Downgrade GPU Operator to v24.6.x (CUDA 12.x compatible)"
    echo "          and set InstallPlanApproval to Manual to prevent auto-upgrades."
    echo ""
    
    # Check current version
    local current_version=$(oc get csv -n nvidia-gpu-operator 2>/dev/null | grep gpu-operator | awk '{print $1}' | sed 's/gpu-operator-certified.//')
    local current_channel=$(oc get subscription gpu-operator-certified -n nvidia-gpu-operator -o jsonpath='{.spec.channel}' 2>/dev/null)
    
    if [ -z "$current_version" ]; then
        print_error "GPU Operator not found. Please install it first."
        return 1
    fi
    
    echo -e "${CYAN}Current Status:${NC}"
    echo "  Version: $current_version"
    echo "  Channel: $current_channel"
    echo ""
    
    # Check CUDA version
    local cuda_version=$(oc exec -n nvidia-gpu-operator $(oc get pods -n nvidia-gpu-operator -o name 2>/dev/null | grep driver | head -1) -c nvidia-driver-ctr -- nvidia-smi 2>/dev/null | grep "CUDA Version" | awk '{print $9}' || echo "unknown")
    echo "  CUDA Version: $cuda_version"
    echo ""
    
    if [[ "$current_channel" == "v24.6" ]]; then
        print_success "GPU Operator is already on v24.6 channel (CUDA 12.x compatible)"
        echo ""
        read -p "Do you want to check/fix InstallPlanApproval to Manual? (y/N): " fix_approval
        if [[ "$fix_approval" =~ ^[Yy]$ ]]; then
            oc patch subscription gpu-operator-certified -n nvidia-gpu-operator --type=merge -p '{"spec":{"installPlanApproval":"Manual"}}'
            print_success "InstallPlanApproval set to Manual"
        fi
        return 0
    fi
    
    echo -e "${YELLOW}Available channels:${NC}"
    oc get packagemanifest gpu-operator-certified -n openshift-marketplace -o jsonpath='{.status.channels[*].name}' 2>/dev/null | tr ' ' '\n' | grep -E "^v24\.|^v23\." | sort -V | tail -5
    echo ""
    
    echo -e "${RED}Warning:${NC} This will:"
    echo "  1. Delete the current GPU Operator subscription and CSV"
    echo "  2. Install GPU Operator v24.6.x"
    echo "  3. Set InstallPlanApproval to Manual (prevents auto-upgrades)"
    echo "  4. The driver pods will be recreated (may take a few minutes)"
    echo ""
    
    read -p "Proceed with downgrade to v24.6? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    echo ""
    print_step "Deleting current GPU Operator..."
    oc delete subscription gpu-operator-certified -n nvidia-gpu-operator 2>/dev/null || true
    oc delete csv -n nvidia-gpu-operator -l operators.coreos.com/gpu-operator-certified.nvidia-gpu-operator 2>/dev/null || true
    sleep 5
    
    print_step "Creating new subscription with v24.6 channel..."
    cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: gpu-operator-certified
  namespace: nvidia-gpu-operator
spec:
  channel: v24.6
  installPlanApproval: Manual
  name: gpu-operator-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
EOF
    
    print_step "Waiting for InstallPlan..."
    sleep 10
    
    # Find and approve the InstallPlan
    local installplan=$(oc get installplan -n nvidia-gpu-operator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$installplan" ]; then
        print_step "Approving InstallPlan: $installplan"
        oc patch installplan "$installplan" -n nvidia-gpu-operator --type merge -p '{"spec":{"approved":true}}'
    else
        print_warning "InstallPlan not found yet. You may need to approve it manually:"
        echo "  oc get installplan -n nvidia-gpu-operator"
        echo "  oc patch installplan <name> -n nvidia-gpu-operator --type merge -p '{\"spec\":{\"approved\":true}}'"
    fi
    
    print_step "Waiting for GPU Operator to be ready..."
    local timeout=180
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if oc get csv -n nvidia-gpu-operator 2>/dev/null | grep -q "gpu-operator.*Succeeded"; then
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        echo "  Waiting... (${elapsed}s)"
    done
    
    # Check final status
    echo ""
    local new_version=$(oc get csv -n nvidia-gpu-operator 2>/dev/null | grep gpu-operator | awk '{print $1}')
    if [ -n "$new_version" ]; then
        print_success "GPU Operator installed: $new_version"
    else
        print_warning "GPU Operator installation in progress. Check status with:"
        echo "  oc get csv -n nvidia-gpu-operator"
    fi
    
    echo ""
    print_info "Note: Driver pods will be recreated. This may take a few minutes."
    print_info "Check driver status with: oc get pods -n nvidia-gpu-operator | grep driver"
    echo ""
    print_info "After drivers are ready, restart your model pods to use the new CUDA version."
}

# Check GPU Operator Status
check_gpu_operator_status() {
    print_header "GPU Operator Status"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    echo -e "${CYAN}GPU Operator:${NC}"
    local csv_info=$(oc get csv -n nvidia-gpu-operator 2>/dev/null | grep gpu-operator)
    if [ -n "$csv_info" ]; then
        echo "$csv_info"
    else
        print_warning "GPU Operator not installed"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}Subscription:${NC}"
    oc get subscription gpu-operator-certified -n nvidia-gpu-operator -o custom-columns=NAME:.metadata.name,CHANNEL:.spec.channel,APPROVAL:.spec.installPlanApproval 2>/dev/null || echo "  Not found"
    
    echo ""
    echo -e "${CYAN}ClusterPolicy:${NC}"
    oc get clusterpolicy gpu-cluster-policy -o custom-columns=NAME:.metadata.name,STATE:.status.state 2>/dev/null || echo "  Not found"
    
    echo ""
    echo -e "${CYAN}Driver Pods:${NC}"
    oc get pods -n nvidia-gpu-operator 2>/dev/null | grep driver || echo "  No driver pods found"
    
    echo ""
    echo -e "${CYAN}NVIDIA Driver & CUDA Version:${NC}"
    local driver_pod=$(oc get pods -n nvidia-gpu-operator -o name 2>/dev/null | grep driver | head -1)
    if [ -n "$driver_pod" ]; then
        oc exec -n nvidia-gpu-operator $driver_pod -c nvidia-driver-ctr -- nvidia-smi 2>/dev/null | head -10 || echo "  Unable to get nvidia-smi output"
    else
        echo "  No driver pod running"
    fi
    
    echo ""
    echo -e "${CYAN}GPU Nodes:${NC}"
    oc get nodes -l feature.node.kubernetes.io/pci-10de.present=true -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,SCHEDULABLE:.spec.unschedulable 2>/dev/null || echo "  No GPU nodes found"
}

# Uncordon GPU Nodes
uncordon_gpu_nodes() {
    print_header "Uncordon GPU Nodes"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    echo -e "${CYAN}Checking for cordoned GPU nodes...${NC}"
    echo ""
    
    local cordoned_nodes=$(oc get nodes -l feature.node.kubernetes.io/pci-10de.present=true -o json 2>/dev/null | jq -r '.items[] | select(.spec.unschedulable == true) | .metadata.name')
    
    if [ -z "$cordoned_nodes" ]; then
        print_success "No cordoned GPU nodes found. All GPU nodes are schedulable."
        echo ""
        echo "GPU Node Status:"
        oc get nodes -l feature.node.kubernetes.io/pci-10de.present=true 2>/dev/null || echo "  No GPU nodes found"
        return 0
    fi
    
    echo -e "${YELLOW}Found cordoned GPU nodes:${NC}"
    echo "$cordoned_nodes"
    echo ""
    
    read -p "Uncordon all these nodes? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    echo ""
    for node in $cordoned_nodes; do
        print_step "Uncordoning $node..."
        if oc adm uncordon "$node"; then
            print_success "Uncordoned: $node"
        else
            print_error "Failed to uncordon: $node"
        fi
    done
    
    echo ""
    print_success "Done! GPU nodes are now schedulable."
    echo ""
    echo "GPU Node Status:"
    oc get nodes -l feature.node.kubernetes.io/pci-10de.present=true 2>/dev/null
}

# Check All Operator Status
check_all_operator_status() {
    print_header "RHOAI-Related Operator Status"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    echo -e "${CYAN}Core Operators:${NC}"
    echo ""
    
    # NFD
    echo -e "${YELLOW}NFD (Node Feature Discovery):${NC}"
    oc get csv -n openshift-nfd 2>/dev/null | grep -E "NAME|nfd" || echo "  Not installed"
    echo ""
    
    # GPU Operator
    echo -e "${YELLOW}NVIDIA GPU Operator:${NC}"
    oc get csv -n nvidia-gpu-operator 2>/dev/null | grep -E "NAME|gpu" || echo "  Not installed"
    echo ""
    
    # RHOAI
    echo -e "${YELLOW}Red Hat OpenShift AI:${NC}"
    oc get csv -n redhat-ods-operator 2>/dev/null | grep -E "NAME|rhods" || echo "  Not installed"
    echo ""
    
    # Kueue
    echo -e "${YELLOW}Kueue:${NC}"
    oc get csv -n openshift-operators 2>/dev/null | grep -E "NAME|kueue" || echo "  Not installed"
    echo ""
    
    # LWS
    echo -e "${YELLOW}Leader Worker Set (LWS):${NC}"
    oc get csv -n openshift-lws-operator 2>/dev/null | grep -E "NAME|leader-worker" || echo "  Not installed"
    echo ""
    
    # RHCL
    echo -e "${YELLOW}Red Hat Connectivity Link (RHCL):${NC}"
    oc get csv -n kuadrant-system 2>/dev/null | grep -E "NAME|rhcl" || echo "  Not installed"
    echo ""
    
    # DataScienceCluster
    echo -e "${CYAN}DataScienceCluster Status:${NC}"
    oc get datasciencecluster 2>/dev/null || echo "  Not found"
}

# Restart Failed Model Pods
restart_failed_model_pods() {
    print_header "Restart Failed Model Pods"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    echo -e "${CYAN}Checking for InferenceServices...${NC}"
    echo ""
    
    local isvc_list=$(oc get inferenceservice -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[0].status 2>/dev/null | grep -v "^NAMESPACE")
    
    if [ -z "$isvc_list" ]; then
        print_info "No InferenceServices found"
        return 0
    fi
    
    echo "InferenceServices:"
    echo "$isvc_list"
    echo ""
    
    # Find not-ready ones
    local failed_isvc=$(echo "$isvc_list" | grep -v "True" | awk '{print $1 "/" $2}')
    
    if [ -z "$failed_isvc" ]; then
        print_success "All InferenceServices are ready!"
        return 0
    fi
    
    echo -e "${YELLOW}Not-ready InferenceServices:${NC}"
    echo "$failed_isvc"
    echo ""
    
    read -p "Enter namespace/name to restart (or 'all' for all failed, 'q' to quit): " selection
    
    if [ "$selection" = "q" ]; then
        return 0
    fi
    
    if [ "$selection" = "all" ]; then
        for isvc in $failed_isvc; do
            local ns=$(echo "$isvc" | cut -d'/' -f1)
            local name=$(echo "$isvc" | cut -d'/' -f2)
            print_step "Restarting pods for $name in $ns..."
            oc delete pod -n "$ns" -l serving.kserve.io/inferenceservice="$name" 2>/dev/null || true
        done
    else
        local ns=$(echo "$selection" | cut -d'/' -f1)
        local name=$(echo "$selection" | cut -d'/' -f2)
        print_step "Restarting pods for $name in $ns..."
        oc delete pod -n "$ns" -l serving.kserve.io/inferenceservice="$name" 2>/dev/null || true
    fi
    
    print_success "Pods deleted. New pods will be created automatically."
    echo ""
    print_info "Check status with: oc get pods -n <namespace>"
}

# Troubleshooting submenu handler
troubleshooting_submenu() {
    while true; do
        show_troubleshooting_submenu
        read -p "Select an option (1-6, 0): " ts_choice
        
        case $ts_choice in
            1)
                fix_gpu_operator_cuda_compatibility
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                check_gpu_operator_status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                uncordon_gpu_nodes
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                print_info "Re-running operator channel validation..."
                echo ""
                # Call the validate function from install-rhoai-minimal.sh if available
                if [ -f "$SCRIPT_DIR/scripts/install-rhoai-minimal.sh" ]; then
                    source "$SCRIPT_DIR/lib/utils/common.sh" 2>/dev/null || true
                    echo "Checking operator channels..."
                    echo ""
                    echo "Kueue available channels:"
                    oc get packagemanifest kueue-operator -n openshift-marketplace -o jsonpath='{.status.channels[*].name}' 2>/dev/null && echo ""
                    echo ""
                    echo "LWS available channels:"
                    oc get packagemanifest leader-worker-set -n openshift-marketplace -o jsonpath='{.status.channels[*].name}' 2>/dev/null && echo ""
                    echo ""
                    print_info "To fix channel issues, re-run: ./scripts/install-rhoai-minimal.sh"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                check_all_operator_status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                restart_failed_model_pods
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                print_error "Invalid option. Please select 1-6 or 0."
                sleep 1
                ;;
        esac
    done
}

################################################################################
# MCP Server Functions
################################################################################

# Deploy Kubernetes MCP Server
deploy_kubernetes_mcp_server() {
    print_header "Deploy Kubernetes MCP Server"
    
    local namespace=$(oc project -q 2>/dev/null)
    echo "Current namespace: $namespace"
    read -p "Deploy to namespace [$namespace]: " target_ns
    target_ns="${target_ns:-$namespace}"
    
    # Check/create namespace
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_warning "Namespace '$target_ns' does not exist"
        read -p "Create it? (y/N): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc new-project "$target_ns" 2>/dev/null || oc create namespace "$target_ns"
        else
            return 1
        fi
    fi
    
    print_step "Deploying Kubernetes MCP Server..."
    oc apply -f "$SCRIPT_DIR/lib/manifests/demo/mcp-kubernetes.yaml" -n "$target_ns"
    
    print_step "Waiting for deployment..."
    oc rollout status deployment/kubernetes-mcp-server -n "$target_ns" --timeout=120s || true
    
    local mcp_url="http://kubernetes-mcp-server.${target_ns}.svc.cluster.local/mcp"
    
    print_success "Kubernetes MCP Server deployed"
    echo ""
    echo -e "${CYAN}MCP Endpoint:${NC} $mcp_url"
    echo ""
    
    # Ask to register in AI Assets
    read -p "Register in AI Asset endpoints (shows in UI)? (Y/n): " register_ai
    if [[ ! "$register_ai" =~ ^[Nn]$ ]]; then
        register_mcp_ai_asset "Kubernetes-MCP-Server" "$mcp_url" \
            "Kubernetes cluster operations - list pods, deployments, services, get logs." \
            "streamable-http"
    fi
    
    # Ask to register in LlamaStack
    read -p "Register in LlamaStack config (enables tool calling)? (Y/n): " register_ls
    if [[ ! "$register_ls" =~ ^[Nn]$ ]]; then
        register_mcp_llamastack "mcp::kubernetes" "$mcp_url" "$target_ns"
    fi
}

# Deploy Weather MCP Server with MongoDB
deploy_mcp_mongodb_only() {
    print_header "Deploy Weather MCP Server + MongoDB"
    
    local namespace=$(oc project -q 2>/dev/null)
    echo "Current namespace: $namespace"
    read -p "Deploy to namespace [$namespace]: " target_ns
    target_ns="${target_ns:-$namespace}"
    
    local mcp_dir="$SCRIPT_DIR/demo/llamastack-demo/mcp"
    
    if [ ! -d "$mcp_dir" ]; then
        print_error "Weather MCP directory not found: $mcp_dir"
        return 1
    fi
    
    print_step "Deploying MongoDB..."
    sed "s/namespace: demo-test/namespace: $target_ns/g" "$mcp_dir/mongodb-deployment.yaml" | oc apply -f - 2>/dev/null || \
        oc apply -f "$mcp_dir/mongodb-deployment.yaml" -n "$target_ns"
    
    oc rollout status deployment/mongodb -n "$target_ns" --timeout=120s || true
    
    print_step "Initializing weather data..."
    oc apply -f "$mcp_dir/init-data-job.yaml" -n "$target_ns" 2>/dev/null || true
    
    print_step "Building Weather MCP Server..."
    oc apply -f "$mcp_dir/buildconfig.yaml" -n "$target_ns"
    oc start-build weather-mcp-server --from-dir="$mcp_dir" --follow -n "$target_ns" 2>/dev/null || true
    
    print_step "Deploying Weather MCP Server..."
    oc apply -f "$mcp_dir/deployment.yaml" -n "$target_ns"
    oc rollout status deployment/weather-mcp-server -n "$target_ns" --timeout=120s || true
    
    local mcp_url="http://weather-mcp-server.${target_ns}.svc.cluster.local:8000/mcp"
    
    print_success "Weather MCP Server deployed"
    echo ""
    echo -e "${CYAN}MCP Endpoint:${NC} $mcp_url"
    echo ""
    
    # Ask to register
    read -p "Register in AI Asset endpoints? (Y/n): " register_ai
    if [[ ! "$register_ai" =~ ^[Nn]$ ]]; then
        register_mcp_ai_asset "Weather-MCP-Server" "$mcp_url" \
            "Weather data with MongoDB backend. Tools: search_weather, get_current_weather, list_stations." \
            "streamable-http"
    fi
    
    read -p "Register in LlamaStack config? (Y/n): " register_ls
    if [[ ! "$register_ls" =~ ^[Nn]$ ]]; then
        register_mcp_llamastack "mcp::weather-data" "$mcp_url" "$target_ns"
    fi
}

# Register MCP in AI Asset endpoints (gen-ai-aa-mcp-servers ConfigMap)
# Format: Each MCP server is a separate key with JSON value containing server_url
register_mcp_ai_asset() {
    local mcp_name="$1"
    local mcp_url="$2"
    local description="$3"
    local transport="${4:-streamable-http}"
    
    print_step "Registering '$mcp_name' in AI Asset endpoints..."
    
    # Sanitize name for use as ConfigMap key (replace spaces with dashes)
    local entry_key=$(echo "$mcp_name" | sed 's/ /-/g')
    
    # Create JSON value for this MCP server
    local mcp_json=$(cat <<MCPJSON
{
  "server_url": "$mcp_url",
  "description": "$description",
  "transport": "$transport"
}
MCPJSON
)
    
    # Check if ConfigMap exists
    if oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications &>/dev/null; then
        # Check if this MCP is already registered
        if oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o jsonpath="{.data.$entry_key}" 2>/dev/null | grep -q "server_url"; then
            print_info "'$mcp_name' is already registered"
            return 0
        fi
        
        # Patch to add new entry
        oc patch configmap gen-ai-aa-mcp-servers -n redhat-ods-applications \
            --type merge -p "{\"data\":{\"$entry_key\": $(echo "$mcp_json" | jq -c .)}}"
    else
        # Create new ConfigMap
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gen-ai-aa-mcp-servers
  namespace: redhat-ods-applications
  labels:
    app.kubernetes.io/part-of: rhoai
data:
  $entry_key: |
    {
      "server_url": "$mcp_url",
      "description": "$description",
      "transport": "$transport"
    }
EOF
    fi
    
    print_success "Registered '$mcp_name' in AI Asset endpoints"
    print_info "View in: OpenShift AI Dashboard → Settings → AI asset endpoints"
}

# Register MCP in LlamaStack config
register_mcp_llamastack() {
    local toolgroup_id="$1"
    local mcp_url="$2"
    local namespace="$3"
    
    print_step "Adding toolgroup '$toolgroup_id' to LlamaStack config..."
    
    # Check if llama-stack-config exists
    if ! oc get configmap llama-stack-config -n "$namespace" &>/dev/null; then
        print_warning "LlamaStack config not found in namespace '$namespace'"
        print_info "Deploy LlamaStack first, or the playground will create it"
        return 1
    fi
    
    # Get current config
    local current_config=$(oc get configmap llama-stack-config -n "$namespace" -o jsonpath='{.data.run\.yaml}')
    
    # Check if toolgroup already exists
    if echo "$current_config" | grep -q "toolgroup_id: $toolgroup_id"; then
        print_info "Toolgroup '$toolgroup_id' already registered"
        return 0
    fi
    
    print_info "Adding MCP toolgroup to LlamaStack config..."
    print_warning "Manual step required: Edit the ConfigMap to add:"
    echo ""
    echo "    - toolgroup_id: $toolgroup_id"
    echo "      provider_id: model-context-protocol"
    echo "      mcp_endpoint:"
    echo "        uri: $mcp_url"
    echo ""
    print_info "Then restart LlamaStack: oc delete pod -l app=lsd-genai-playground -n $namespace"
}

# Interactive registration for AI Asset endpoints
register_mcp_ai_asset_interactive() {
    print_header "Register MCP in AI Asset Endpoints"
    
    echo "This registers an MCP server in the OpenShift AI Dashboard"
    echo "Location: Settings → AI asset endpoints"
    echo ""
    
    read -p "MCP Server Name (e.g., My-MCP-Server): " mcp_name
    if [ -z "$mcp_name" ]; then
        print_error "Name is required"
        return 1
    fi
    
    read -p "MCP URL (e.g., http://my-mcp.ns.svc.cluster.local:8000/mcp): " mcp_url
    if [ -z "$mcp_url" ]; then
        print_error "URL is required"
        return 1
    fi
    
    read -p "Description: " description
    echo "Transport options: sse, streamable-http"
    read -p "Transport [streamable-http]: " transport
    transport="${transport:-streamable-http}"
    
    register_mcp_ai_asset "$mcp_name" "$mcp_url" "$description" "$transport"
}

# Interactive registration for LlamaStack
register_mcp_llamastack_interactive() {
    print_header "Register MCP in LlamaStack Config"
    
    local namespace=$(oc project -q 2>/dev/null)
    echo "This adds an MCP toolgroup to LlamaStack for tool calling"
    echo "Current namespace: $namespace"
    echo ""
    
    read -p "Toolgroup ID (e.g., mcp::my-tools): " toolgroup_id
    if [ -z "$toolgroup_id" ]; then
        print_error "Toolgroup ID is required"
        return 1
    fi
    
    read -p "MCP URL (e.g., http://my-mcp.ns.svc.cluster.local:8000/mcp): " mcp_url
    if [ -z "$mcp_url" ]; then
        print_error "URL is required"
        return 1
    fi
    
    read -p "Namespace for LlamaStack config [$namespace]: " ls_namespace
    ls_namespace="${ls_namespace:-$namespace}"
    
    register_mcp_llamastack "$toolgroup_id" "$mcp_url" "$ls_namespace"
}

# Show MCP server status
show_mcp_status() {
    print_header "MCP Server Status"
    
    local namespace=$(oc project -q 2>/dev/null)
    echo -e "${CYAN}Current Namespace:${NC} $namespace"
    echo ""
    
    echo -e "${CYAN}MCP Server Pods:${NC}"
    oc get pods -n "$namespace" 2>/dev/null | grep -E "NAME|mcp|weather|kubernetes" || echo "  No MCP pods found in $namespace"
    echo ""
    
    echo -e "${CYAN}AI Asset Endpoints (gen-ai-aa-mcp-servers):${NC}"
    if oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications &>/dev/null; then
        oc get configmap gen-ai-aa-mcp-servers -n redhat-ods-applications -o yaml 2>/dev/null | \
            grep -E "^  [A-Za-z].*-.*:" | sed 's/://' | sed 's/^/  - /' || echo "  No entries"
    else
        echo "  ConfigMap not found (no MCP servers registered)"
    fi
    echo ""
    
    echo -e "${CYAN}LlamaStack Toolgroups:${NC}"
    if oc get configmap llama-stack-config -n "$namespace" &>/dev/null; then
        oc get configmap llama-stack-config -n "$namespace" -o jsonpath='{.data.run\.yaml}' 2>/dev/null | \
            grep "toolgroup_id: mcp::" | sed 's/.*toolgroup_id: /  - /' || echo "  No MCP toolgroups in $namespace"
    else
        echo "  LlamaStack config not found in $namespace"
    fi
}

# Show available MCP tools from LlamaStack
show_mcp_tools() {
    print_header "Available MCP Tools"
    
    local namespace=$(oc project -q 2>/dev/null)
    echo -e "${CYAN}Querying LlamaStack in namespace: $namespace${NC}"
    echo ""
    
    oc exec deployment/lsd-genai-playground -n "$namespace" -- \
        curl -s http://localhost:8321/v1/tools 2>/dev/null | python3 -c "
import sys,json
try:
    data=json.load(sys.stdin)
    tools = data if isinstance(data, list) else data.get('data', [])
    groups = {}
    for t in tools:
        g = t.get('toolgroup_id', 'builtin')
        if g not in groups:
            groups[g] = []
        groups[g].append(t.get('name', 'unknown'))
    
    print(f'Total: {len(tools)} tools')
    print('')
    for g, tlist in sorted(groups.items()):
        if g.startswith('mcp::'):
            print(f'\033[0;36m{g}:\033[0m')
        else:
            print(f'{g}:')
        for tool in sorted(tlist):
            print(f'  - {tool}')
        print('')
except Exception as e:
    print(f'Error: {e}')
    print('Is LlamaStack (lsd-genai-playground) running?')
" 2>/dev/null || print_error "Could not connect to LlamaStack. Is it deployed in $namespace?"
}

################################################################################
# MCP Server Setup Menu
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
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           MCP Server Options                                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}MCP (Model Context Protocol) enables AI agents to use external tools.${NC}"
    echo ""
    echo -e "${MAGENTA}Deploy MCP Servers:${NC}"
    echo -e "${YELLOW}1)${NC} Deploy Kubernetes MCP Server ${GREEN}[Recommended]${NC}"
    echo "   └─ Query pods, deployments, services, logs via natural language"
    echo -e "${YELLOW}2)${NC} Deploy Weather MCP Server + MongoDB"
    echo "   └─ Sample MCP server with weather data tools (14 airports)"
    echo -e "${YELLOW}3)${NC} Deploy All MCP Servers"
    echo "   └─ Kubernetes + Weather MCP servers"
    echo ""
    echo -e "${MAGENTA}Register MCP Servers:${NC}"
    echo -e "${YELLOW}4)${NC} Register MCP in AI Asset Endpoints ${CYAN}[UI]${NC}"
    echo "   └─ Shows in OpenShift AI Dashboard → Settings → AI asset endpoints"
    echo -e "${YELLOW}5)${NC} Register MCP in LlamaStack Config ${CYAN}[Tool Calling]${NC}"
    echo "   └─ Enables tool calling in LlamaStack/Playground"
    echo ""
    echo -e "${MAGENTA}Status:${NC}"
    echo -e "${YELLOW}6)${NC} Show MCP Server Status"
    echo -e "${YELLOW}7)${NC} List Available Tools (from LlamaStack)"
    echo ""
    echo -e "${YELLOW}8)${NC} Full MCP Management Menu"
    echo "   └─ Advanced options via manage-mcp-servers.sh"
    echo -e "${YELLOW}0)${NC} Back to RHOAI Management Menu"
    echo ""
    
    read -p "Enter your choice: " mcp_choice
    
    case $mcp_choice in
        1)
            # Deploy Kubernetes MCP Server
            deploy_kubernetes_mcp_server
            ;;
        2)
            # Deploy Weather MCP Server
            deploy_mcp_mongodb_only
            ;;
        3)
            # Deploy all MCP servers
            deploy_kubernetes_mcp_server
            deploy_mcp_mongodb_only
            ;;
        4)
            # Register in AI Asset endpoints
            register_mcp_ai_asset_interactive
            ;;
        5)
            # Register in LlamaStack config
            register_mcp_llamastack_interactive
            ;;
        6)
            # Show status
            show_mcp_status
            ;;
        7)
            # List tools
            show_mcp_tools
            ;;
        8)
            # Full management script
            if [ -f "$SCRIPT_DIR/scripts/manage-mcp-servers.sh" ]; then
                "$SCRIPT_DIR/scripts/manage-mcp-servers.sh"
            else
                print_error "MCP management script not found"
            fi
            ;;
        0)
            return 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
    
    return 0
}

################################################################################
# LlamaStack Demo UI Deployment
################################################################################

deploy_llamastack_demo_interactive() {
    print_header "Deploy LlamaStack Demo UI"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    
    # Check if demo files exist
    local demo_dir="$SCRIPT_DIR/demo/llamastack-demo"
    if [ ! -d "$demo_dir" ]; then
        print_error "LlamaStack demo directory not found"
        echo ""
        echo "Expected: $demo_dir"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           LlamaStack + MCP Demo UI                             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}This will deploy a Streamlit-based chatbot frontend that:${NC}"
    echo "  • Connects to your LlamaStack distribution"
    echo "  • Shows MCP tool calls in real-time"
    echo "  • Provides a chat interface for testing AI agents"
    echo "  • Is fully configurable via environment variables"
    echo ""
    
    # Get target namespace
    echo -e "${CYAN}Target Namespace Configuration:${NC}"
    local current_project=$(oc project -q 2>/dev/null)
    echo "Current project: $current_project"
    echo ""
    read -p "Enter target namespace [default: $current_project]: " target_ns
    target_ns="${target_ns:-$current_project}"
    
    # Check if namespace exists
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_warning "Namespace '$target_ns' does not exist"
        read -p "Create it? (y/N): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc new-project "$target_ns" 2>/dev/null || oc create namespace "$target_ns"
            print_success "Namespace created"
        else
            print_error "Namespace required"
            return 1
        fi
    fi
    
    # Switch to target namespace
    oc project "$target_ns" &>/dev/null
    
    echo ""
    echo -e "${CYAN}LlamaStack Configuration:${NC}"
    echo ""
    
    # Try to auto-detect LlamaStack service
    local detected_llamastack=""
    detected_llamastack=$(oc get svc -n "$target_ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -E "llama|lsd" | head -1)
    
    if [ -n "$detected_llamastack" ]; then
        local default_llamastack_url="http://${detected_llamastack}.${target_ns}.svc.cluster.local:8321"
        echo "Detected LlamaStack service: $detected_llamastack"
    else
        local default_llamastack_url="http://lsd-genai-playground-service.${target_ns}.svc.cluster.local:8321"
        echo "No LlamaStack service auto-detected"
    fi
    
    read -p "LlamaStack URL [$default_llamastack_url]: " llamastack_url
    llamastack_url="${llamastack_url:-$default_llamastack_url}"
    
    # Model ID
    read -p "Model ID [qwen3-8b]: " model_id
    model_id="${model_id:-qwen3-8b}"
    
    # MCP Server URL
    local detected_mcp=""
    detected_mcp=$(oc get svc -n "$target_ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -i mcp | head -1)
    
    if [ -n "$detected_mcp" ]; then
        local default_mcp_url="http://${detected_mcp}.${target_ns}.svc.cluster.local:8000"
        echo "Detected MCP service: $detected_mcp"
    else
        local default_mcp_url="http://mcp-server.${target_ns}.svc.cluster.local:8000"
    fi
    
    read -p "MCP Server URL [$default_mcp_url]: " mcp_url
    mcp_url="${mcp_url:-$default_mcp_url}"
    
    echo ""
    echo -e "${CYAN}UI Customization (optional, press Enter to use defaults):${NC}"
    echo ""
    
    read -p "App Title [LlamaStack + MCP Demo]: " app_title
    app_title="${app_title:-LlamaStack + MCP Demo}"
    
    read -p "MCP Server Name [MCP Server]: " mcp_name
    mcp_name="${mcp_name:-MCP Server}"
    
    echo ""
    echo -e "${CYAN}Deployment Summary:${NC}"
    echo "  Namespace: $target_ns"
    echo "  LlamaStack URL: $llamastack_url"
    echo "  Model ID: $model_id"
    echo "  MCP Server URL: $mcp_url"
    echo "  App Title: $app_title"
    echo ""
    
    read -p "Proceed with deployment? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Deployment cancelled"
        return 0
    fi
    
    echo ""
    print_step "Applying ConfigMap and Deployment manifests..."
    
    # Apply deployment.yaml with namespace and config values substituted
    # The deployment.yaml contains ConfigMap, Deployment, Service, and Route
    sed -e "s/namespace: demo-test/namespace: $target_ns/g" \
        -e "s|demo-test/|$target_ns/|g" \
        -e "s|LLAMASTACK_URL:.*|LLAMASTACK_URL: \"$llamastack_url\"|g" \
        -e "s|MODEL_ID:.*|MODEL_ID: \"$model_id\"|g" \
        -e "s|MCP_SERVER_URL:.*|MCP_SERVER_URL: \"$mcp_url\"|g" \
        -e "s|APP_TITLE:.*|APP_TITLE: \"$app_title\"|g" \
        -e "s|MCP_SERVER_NAME:.*|MCP_SERVER_NAME: \"$mcp_name\"|g" \
        "$demo_dir/deployment.yaml" | oc apply -f -
    
    print_step "Creating BuildConfig and ImageStream..."
    apply_manifest "$demo_dir/buildconfig.yaml" "$target_ns"
    
    echo ""
    print_step "Building container image (this may take 1-2 minutes)..."
    echo ""
    
    # Start the build from the demo directory
    if oc start-build llamastack-mcp-demo --from-dir="$demo_dir" --follow -n "$target_ns"; then
        print_success "Build completed successfully"
    else
        print_error "Build failed"
        echo ""
        echo "You can check build logs with:"
        echo "  oc logs -f bc/llamastack-mcp-demo -n $target_ns"
        return 1
    fi
    
    echo ""
    print_step "Waiting for deployment to be ready..."
    if oc rollout status deployment/llamastack-mcp-demo -n "$target_ns" --timeout=120s; then
        print_success "Deployment ready"
    else
        print_warning "Deployment may still be starting"
    fi
    
    echo ""
    print_step "Getting application URL..."
    local route_url=$(oc get route llamastack-mcp-demo -n "$target_ns" -o jsonpath='{.spec.host}' 2>/dev/null)
    
    if [ -n "$route_url" ]; then
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✅ LlamaStack Demo UI Deployed Successfully!                  ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}📌 Application URL:${NC}"
        echo -e "   ${GREEN}https://$route_url${NC}"
        echo ""
        echo -e "${CYAN}📋 Configuration:${NC}"
        echo "   • Namespace: $target_ns"
        echo "   • LlamaStack: $llamastack_url"
        echo "   • Model: $model_id"
        echo "   • MCP Server: $mcp_url"
        echo ""
        echo -e "${YELLOW}📝 Next Steps:${NC}"
        echo "   1. Open the URL in your browser"
        echo "   2. Click '🔄 Check' in the sidebar to verify service status"
        echo "   3. Click '🔄 Refresh Tools' to load MCP tools"
        echo "   4. Start chatting!"
        echo ""
        echo -e "${CYAN}📚 To update configuration later:${NC}"
        echo "   oc edit configmap llamastack-demo-config -n $target_ns"
        echo "   oc rollout restart deployment/llamastack-mcp-demo -n $target_ns"
        echo ""
    else
        print_warning "Could not get route URL"
        echo "Check with: oc get route llamastack-mcp-demo -n $target_ns"
    fi
    
    return 0
}

################################################################################
# Weather MCP Server + MongoDB Deployment
################################################################################

# Helper function to apply manifest with namespace substitution
apply_manifest() {
    local manifest_file="$1"
    local target_ns="$2"
    
    if [ ! -f "$manifest_file" ]; then
        print_error "Manifest not found: $manifest_file"
        return 1
    fi
    
    # Replace demo-test namespace with target namespace
    sed -e "s/namespace: demo-test/namespace: $target_ns/g" \
        -e "s|demo-test/|$target_ns/|g" \
        "$manifest_file" | oc apply -f -
}

deploy_weather_mcp_server() {
    local target_ns="$1"
    local mcp_dir="$SCRIPT_DIR/demo/llamastack-demo/mcp"
    
    if [ ! -d "$mcp_dir" ]; then
        print_error "Weather MCP server directory not found"
        echo "Expected: $mcp_dir"
        return 1
    fi
    
    echo ""
    print_step "Deploying MongoDB..."
    
    # Check if PVC already exists
    if oc get pvc mongodb-data -n "$target_ns" &>/dev/null; then
        print_info "MongoDB PVC already exists, skipping PVC creation"
        # Apply only deployment and service (skip PVC by applying just the deployment part)
        sed -e "s/namespace: demo-test/namespace: $target_ns/g" "$mcp_dir/mongodb-deployment.yaml" | \
            awk 'BEGIN{skip=1} /^---$/{skip=0} !skip{print}' | oc apply -f -
    else
        # Apply full manifest including PVC
        apply_manifest "$mcp_dir/mongodb-deployment.yaml" "$target_ns"
    fi
    
    print_step "Waiting for MongoDB to be ready..."
    if ! oc wait --for=condition=available deployment/mongodb -n "$target_ns" --timeout=180s; then
        print_warning "MongoDB may still be starting"
    else
        print_success "MongoDB is ready"
    fi
    
    echo ""
    print_step "Initializing sample weather data..."
    
    # Delete existing job if present
    oc delete job init-weather-data -n "$target_ns" 2>/dev/null || true
    
    # Apply the init job
    apply_manifest "$mcp_dir/init-data-job.yaml" "$target_ns"
    
    # Wait for job to complete
    print_step "Waiting for data initialization (this may take 30-60 seconds)..."
    if oc wait --for=condition=complete job/init-weather-data -n "$target_ns" --timeout=120s 2>/dev/null; then
        print_success "Sample data loaded"
    else
        print_warning "Data initialization may still be running"
        echo "Check with: oc logs -f job/init-weather-data -n $target_ns"
    fi
    
    echo ""
    print_step "Building Weather MCP Server container..."
    
    # Apply BuildConfig and ImageStream
    apply_manifest "$mcp_dir/buildconfig.yaml" "$target_ns"
    
    # Build from local directory
    if oc start-build weather-mcp-server --from-dir="$mcp_dir" --follow -n "$target_ns"; then
        print_success "Build completed"
    else
        print_error "Build failed"
        return 1
    fi
    
    echo ""
    print_step "Deploying Weather MCP Server..."
    
    # Apply deployment
    apply_manifest "$mcp_dir/deployment.yaml" "$target_ns"
    
    print_step "Waiting for MCP server to be ready..."
    if oc rollout status deployment/weather-mcp-server -n "$target_ns" --timeout=120s; then
        print_success "Weather MCP Server deployed"
    else
        print_warning "MCP server may still be starting"
    fi
    
    return 0
}

################################################################################
# LlamaStack Demo Sub-Menu
################################################################################

show_llamastack_demo_submenu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           LlamaStack Demo Deployment Options                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}This demo includes:${NC}"
    echo "  • LlamaStack Demo UI - Streamlit chatbot frontend"
    echo "  • Weather MCP Server - Sample MCP server with weather tools"
    echo "  • MongoDB - Database with 14 global weather stations"
    echo ""
    echo -e "${MAGENTA}Full Stack (includes LlamaStack):${NC}"
    echo -e "${YELLOW}1)${NC} Deploy Everything with LlamaStack ${GREEN}[NEW]${NC}"
    echo "    → Deploys LlamaStack + MCP + MongoDB + UI (choose your LLM provider)"
    echo ""
    echo -e "${MAGENTA}Partial Deployment (existing LlamaStack):${NC}"
    echo -e "${YELLOW}2)${NC} Deploy Demo Stack (UI + MCP + MongoDB)"
    echo "    → Connects to your existing LlamaStack"
    echo ""
    echo -e "${YELLOW}3)${NC} Deploy Weather MCP Server + MongoDB only"
    echo -e "${YELLOW}4)${NC} Deploy Demo UI only"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to RHOAI Management Menu"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}💡 Not using OpenShift?${NC}"
    echo "   For Kubernetes or Docker deployment, see:"
    echo -e "   ${YELLOW}https://github.com/gymnatics/llamastack-demo${NC}"
    echo ""
}

deploy_llamastack_demo_menu() {
    print_header "Deploy LlamaStack Demo"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    
    while true; do
        show_llamastack_demo_submenu
        read -p "Enter your choice: " demo_choice
        
        case $demo_choice in
            1)
                # Full stack with LlamaStack
                deploy_full_stack_with_llamastack || true
                echo ""
                read -p "Press Enter to continue..."
                return 0
                ;;
            2)
                # Complete demo stack (existing LlamaStack)
                deploy_complete_llamastack_demo || true
                echo ""
                read -p "Press Enter to continue..."
                return 0
                ;;
            3)
                # MCP + MongoDB only
                deploy_mcp_mongodb_only || true
                echo ""
                read -p "Press Enter to continue..."
                return 0
                ;;
            4)
                # UI only
                deploy_llamastack_demo_interactive || true
                echo ""
                read -p "Press Enter to continue..."
                return 0
                ;;
            0)
                return 0
                ;;
            *)
                print_error "Invalid option. Please enter 1-4 or 0."
                sleep 1
                ;;
        esac
    done
}

################################################################################
# LlamaStack Setup (Generic, without Demo)
################################################################################

setup_llamastack_interactive() {
    print_header "Setup LlamaStack"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    
    # Check if LlamaStack CRD exists
    if ! oc get crd llamastackdistributions.llamastack.io &>/dev/null; then
        print_error "LlamaStackDistribution CRD not found!"
        echo ""
        echo -e "${YELLOW}LlamaStack operator is not enabled in your RHOAI installation.${NC}"
        echo ""
        echo "To enable LlamaStack:"
        echo ""
        echo "  1. Ensure you have RHOAI 3.0+ installed"
        echo ""
        echo "  2. Enable LlamaStack in your DataScienceCluster:"
        echo "     oc patch datasciencecluster default-dsc --type merge \\"
        echo "       -p '{\"spec\":{\"components\":{\"llamastackoperator\":{\"managementState\":\"Managed\"}}}}'"
        echo ""
        echo "  3. Wait for the operator to be ready (~2-3 minutes)"
        echo ""
        read -p "Would you like to enable LlamaStack now? (y/N): " enable_llamastack
        if [[ "$enable_llamastack" =~ ^[Yy]$ ]]; then
            print_step "Enabling LlamaStack operator..."
            if oc patch datasciencecluster default-dsc --type merge \
                -p '{"spec":{"components":{"llamastackoperator":{"managementState":"Managed"}}}}' 2>/dev/null; then
                print_success "LlamaStack operator enabled"
                echo ""
                print_step "Waiting for CRD to be available..."
                local max_wait=180
                local waited=0
                while [ $waited -lt $max_wait ]; do
                    if oc get crd llamastackdistributions.llamastack.io &>/dev/null; then
                        print_success "LlamaStack CRD is now available"
                        break
                    fi
                    sleep 5
                    waited=$((waited + 5))
                    echo "  Waiting... ($waited/$max_wait seconds)"
                done
                
                if [ $waited -ge $max_wait ]; then
                    print_warning "Timeout waiting for CRD. Please try again in a few minutes."
                    return 1
                fi
            else
                print_error "Failed to enable LlamaStack operator"
                return 1
            fi
        else
            return 1
        fi
    fi
    
    print_success "LlamaStack CRD found"
    echo ""
    
    # Get target namespace
    echo -e "${CYAN}Target Namespace Configuration:${NC}"
    local current_project=$(oc project -q 2>/dev/null)
    echo "Current project: $current_project"
    echo ""
    read -p "Enter target namespace [default: $current_project]: " target_ns
    target_ns="${target_ns:-$current_project}"
    
    # Check/create namespace
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_warning "Namespace '$target_ns' does not exist"
        read -p "Create it? (y/N): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc new-project "$target_ns" 2>/dev/null || oc create namespace "$target_ns"
            print_success "Namespace created"
        else
            print_error "Namespace required"
            return 1
        fi
    fi
    
    oc project "$target_ns" &>/dev/null
    
    echo ""
    echo -e "${CYAN}LlamaStack will be deployed with:${NC}"
    echo "  • Your chosen LLM provider (vLLM, Azure, OpenAI, Ollama, Bedrock)"
    echo "  • RAG capabilities (Milvus vector DB)"
    echo "  • MCP tool runtime support"
    echo "  • Agent orchestration"
    echo ""
    
    read -p "Proceed? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Cancelled"
        return 0
    fi
    
    # Deploy LlamaStack (reuse existing function but with custom MCP URL prompt)
    deploy_llamastack_distribution_generic "$target_ns"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✅ LlamaStack Deployed Successfully!                          ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}📦 LlamaStack Service:${NC}"
        echo "   • URL: http://llamastack-demo-service.$target_ns.svc.cluster.local:8321"
        echo "   • Provider: $LLM_PROVIDER"
        echo "   • Model: $MODEL_ID"
        echo ""
        echo -e "${CYAN}💡 Next Steps:${NC}"
        echo "   1. Test the connection:"
        echo "      curl http://llamastack-demo-service.$target_ns.svc.cluster.local:8321/v1/models"
        echo ""
        echo "   2. Add MCP servers (optional):"
        echo "      Edit the ConfigMap to add tool_groups with mcp_endpoint"
        echo ""
        echo "   3. Use from your application:"
        echo "      from llama_stack_client import LlamaStackClient"
        echo "      client = LlamaStackClient(base_url='http://llamastack-demo-service.$target_ns.svc.cluster.local:8321')"
        echo ""
    fi
    
    return 0
}

deploy_llamastack_distribution_generic() {
    local target_ns="$1"
    
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Deploying LlamaStack Distribution${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    # Select and configure provider
    show_llm_provider_menu
    read -p "Enter your choice [1]: " provider_choice
    provider_choice="${provider_choice:-1}"
    
    case $provider_choice in
        1) configure_vllm_provider "$target_ns" || return 1 ;;
        2) configure_azure_provider "$target_ns" || return 1 ;;
        3) configure_openai_provider "$target_ns" || return 1 ;;
        4) configure_ollama_provider "$target_ns" || return 1 ;;
        5) configure_bedrock_provider "$target_ns" || return 1 ;;
        *) print_error "Invalid choice"; return 1 ;;
    esac
    
    # Ask about MCP server (optional)
    echo ""
    read -p "Do you want to configure an MCP server? (y/N): " configure_mcp
    local mcp_config=""
    if [[ "$configure_mcp" =~ ^[Yy]$ ]]; then
        read -p "MCP Server Name (e.g., weather-data): " mcp_name
        mcp_name="${mcp_name:-custom-mcp}"
        read -p "MCP Server URL (e.g., http://my-mcp-server.ns.svc.cluster.local:8000/mcp): " mcp_url
        if [ -n "$mcp_url" ]; then
            mcp_config="    - toolgroup_id: mcp::$mcp_name
      provider_id: model-context-protocol
      mcp_endpoint:
        uri: $mcp_url"
        fi
    fi
    
    # Apply ConfigMap (modified to not include weather MCP by default)
    print_step "Creating LlamaStack ConfigMap..."
    
    # Use sed to modify the config file, optionally adding MCP
    if [ -n "$mcp_config" ]; then
        sed -e "s/NAMESPACE_PLACEHOLDER/$target_ns/g" \
            -e "s/MODEL_ID_PLACEHOLDER/$MODEL_ID/g" \
            -e "s|uri: http://weather-mcp-server.*|# Custom MCP configured below|g" \
            "$CONFIG_FILE" | \
        awk -v mcp="$mcp_config" '
            /toolgroup_id: mcp::weather-data/ { 
                # Replace weather MCP with custom MCP
                print mcp
                # Skip the next 3 lines (provider_id and mcp_endpoint)
                getline; getline; getline
                next
            }
            { print }
        ' | oc apply -f -
    else
        # No MCP - remove the weather MCP section
        sed -e "s/NAMESPACE_PLACEHOLDER/$target_ns/g" \
            -e "s/MODEL_ID_PLACEHOLDER/$MODEL_ID/g" \
            "$CONFIG_FILE" | \
        awk '
            /toolgroup_id: mcp::weather-data/,/uri:.*mcp$/ { next }
            { print }
        ' | oc apply -f -
    fi
    
    # Apply Distribution with env vars
    print_step "Creating LlamaStackDistribution..."
    
    local dist_file="$SCRIPT_DIR/demo/llamastack-demo/llamastack/llamastack-distribution.yaml"
    
    # Read base distribution and inject env vars
    sed -e "s/NAMESPACE_PLACEHOLDER/$target_ns/g" "$dist_file" | \
    awk -v env_vars="$DISTRIBUTION_ENV_VARS" '
        /env:/ && !done {
            print
            print env_vars
            done=1
            next
        }
        { print }
    ' | oc apply -f -
    
    print_step "Waiting for LlamaStack pod to be ready..."
    sleep 5
    
    if oc wait --for=condition=available deployment -l llamastack.io/distribution=llamastack-demo -n "$target_ns" --timeout=180s 2>/dev/null; then
        print_success "LlamaStack is ready"
    else
        print_warning "LlamaStack may still be starting. Check with: oc get pods -n $target_ns"
    fi
    
    return 0
}

################################################################################
# LlamaStack Deployment with Provider Selection (for Demo)
################################################################################

show_llm_provider_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 Select LLM Provider                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Choose your LLM backend:${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} vLLM (RHOAI Model Serving / KServe)"
    echo "    → Use a model deployed via OpenShift AI Model Serving"
    echo ""
    echo -e "${YELLOW}2)${NC} Azure OpenAI"
    echo "    → Connect to Azure OpenAI Service (GPT-4, GPT-4o, etc.)"
    echo ""
    echo -e "${YELLOW}3)${NC} OpenAI"
    echo "    → Connect to OpenAI API (GPT-4, GPT-4o, etc.)"
    echo ""
    echo -e "${YELLOW}4)${NC} Ollama"
    echo "    → Connect to an Ollama server"
    echo ""
    echo -e "${YELLOW}5)${NC} AWS Bedrock"
    echo "    → Connect to AWS Bedrock (Claude, Llama, etc.)"
    echo ""
}

configure_vllm_provider() {
    local target_ns="$1"
    
    echo ""
    print_step "Configuring vLLM provider..."
    echo ""
    
    # Try to detect existing inference services
    local detected_is=""
    detected_is=$(oc get inferenceservice -n "$target_ns" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    
    if [ -n "$detected_is" ]; then
        local detected_url=$(oc get inferenceservice "$detected_is" -n "$target_ns" -o jsonpath='{.status.url}' 2>/dev/null || true)
        print_info "Detected InferenceService: $detected_is"
        if [ -n "$detected_url" ]; then
            print_info "URL: $detected_url"
        fi
        echo ""
    fi
    
    read -p "vLLM/Model Serving URL (e.g., https://model-name.apps.cluster.example.com): " VLLM_URL
    if [ -z "$VLLM_URL" ]; then
        print_error "vLLM URL is required"
        return 1
    fi
    
    read -p "Model ID (e.g., qwen3-8b, llama-3-8b): " MODEL_ID
    MODEL_ID="${MODEL_ID:-qwen3-8b}"
    
    read -p "API Token (leave empty if not required): " VLLM_API_TOKEN
    
    # Create secret for vLLM
    print_step "Creating vLLM secret..."
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: vllm-secret
  namespace: $target_ns
type: Opaque
stringData:
  url: "$VLLM_URL"
  api-token: "${VLLM_API_TOKEN:-}"
EOF
    
    # Set env vars for distribution
    DISTRIBUTION_ENV_VARS=$(cat <<'ENVEOF'
      - name: VLLM_URL
        valueFrom:
          secretKeyRef:
            name: vllm-secret
            key: url
      - name: VLLM_API_TOKEN
        valueFrom:
          secretKeyRef:
            name: vllm-secret
            key: api-token
      - name: VLLM_TLS_VERIFY
        value: "false"
      - name: VLLM_MAX_TOKENS
        value: "4096"
ENVEOF
    )
    
    LLM_PROVIDER="vllm"
    CONFIG_FILE="$SCRIPT_DIR/demo/llamastack-demo/llamastack/llamastack-config-vllm.yaml"
}

configure_azure_provider() {
    local target_ns="$1"
    
    echo ""
    print_step "Configuring Azure OpenAI provider..."
    echo ""
    
    read -p "Azure OpenAI Endpoint (e.g., https://your-resource.openai.azure.com): " AZURE_ENDPOINT
    if [ -z "$AZURE_ENDPOINT" ]; then
        print_error "Azure endpoint is required"
        return 1
    fi
    
    read -p "Deployment Name (e.g., gpt-4o): " AZURE_DEPLOYMENT
    AZURE_DEPLOYMENT="${AZURE_DEPLOYMENT:-gpt-4o}"
    MODEL_ID="$AZURE_DEPLOYMENT"
    
    read -p "API Key: " AZURE_API_KEY
    if [ -z "$AZURE_API_KEY" ]; then
        print_error "API key is required"
        return 1
    fi
    
    read -p "API Version [2024-08-01-preview]: " AZURE_API_VERSION
    AZURE_API_VERSION="${AZURE_API_VERSION:-2024-08-01-preview}"
    
    # Create secret
    print_step "Creating Azure OpenAI secret..."
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: azure-openai-secret
  namespace: $target_ns
type: Opaque
stringData:
  endpoint: "$AZURE_ENDPOINT"
  deployment: "$AZURE_DEPLOYMENT"
  api-key: "$AZURE_API_KEY"
  api-version: "$AZURE_API_VERSION"
EOF
    
    DISTRIBUTION_ENV_VARS=$(cat <<'ENVEOF'
      - name: AZURE_OPENAI_ENDPOINT
        valueFrom:
          secretKeyRef:
            name: azure-openai-secret
            key: endpoint
      - name: AZURE_OPENAI_API_KEY
        valueFrom:
          secretKeyRef:
            name: azure-openai-secret
            key: api-key
      - name: AZURE_OPENAI_DEPLOYMENT
        valueFrom:
          secretKeyRef:
            name: azure-openai-secret
            key: deployment
      - name: AZURE_OPENAI_API_VERSION
        valueFrom:
          secretKeyRef:
            name: azure-openai-secret
            key: api-version
ENVEOF
    )
    
    LLM_PROVIDER="azure"
    CONFIG_FILE="$SCRIPT_DIR/demo/llamastack-demo/llamastack/llamastack-config-azure.yaml"
}

configure_openai_provider() {
    local target_ns="$1"
    
    echo ""
    print_step "Configuring OpenAI provider..."
    echo ""
    
    read -p "OpenAI API Key: " OPENAI_API_KEY
    if [ -z "$OPENAI_API_KEY" ]; then
        print_error "API key is required"
        return 1
    fi
    
    read -p "Model ID [gpt-4o]: " MODEL_ID
    MODEL_ID="${MODEL_ID:-gpt-4o}"
    
    # Create secret
    print_step "Creating OpenAI secret..."
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: openai-secret
  namespace: $target_ns
type: Opaque
stringData:
  api-key: "$OPENAI_API_KEY"
EOF
    
    DISTRIBUTION_ENV_VARS=$(cat <<'ENVEOF'
      - name: OPENAI_API_KEY
        valueFrom:
          secretKeyRef:
            name: openai-secret
            key: api-key
ENVEOF
    )
    
    LLM_PROVIDER="openai"
    CONFIG_FILE="$SCRIPT_DIR/demo/llamastack-demo/llamastack/llamastack-config-openai.yaml"
}

configure_ollama_provider() {
    local target_ns="$1"
    
    echo ""
    print_step "Configuring Ollama provider..."
    echo ""
    
    read -p "Ollama URL [http://ollama.${target_ns}.svc.cluster.local:11434]: " OLLAMA_URL
    OLLAMA_URL="${OLLAMA_URL:-http://ollama.${target_ns}.svc.cluster.local:11434}"
    
    read -p "Model ID [llama3.2]: " MODEL_ID
    MODEL_ID="${MODEL_ID:-llama3.2}"
    
    DISTRIBUTION_ENV_VARS=$(cat <<ENVEOF
      - name: OLLAMA_URL
        value: "$OLLAMA_URL"
ENVEOF
    )
    
    LLM_PROVIDER="ollama"
    CONFIG_FILE="$SCRIPT_DIR/demo/llamastack-demo/llamastack/llamastack-config-ollama.yaml"
}

configure_bedrock_provider() {
    local target_ns="$1"
    
    echo ""
    print_step "Configuring AWS Bedrock provider..."
    echo ""
    
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
    if [ -z "$AWS_ACCESS_KEY_ID" ]; then
        print_error "AWS Access Key ID is required"
        return 1
    fi
    
    read -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        print_error "AWS Secret Access Key is required"
        return 1
    fi
    
    read -p "AWS Region [us-east-1]: " AWS_REGION
    AWS_REGION="${AWS_REGION:-us-east-1}"
    
    read -p "Model ID [anthropic.claude-3-sonnet-20240229-v1:0]: " MODEL_ID
    MODEL_ID="${MODEL_ID:-anthropic.claude-3-sonnet-20240229-v1:0}"
    
    # Create secret
    print_step "Creating Bedrock secret..."
    cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: bedrock-secret
  namespace: $target_ns
type: Opaque
stringData:
  aws-access-key-id: "$AWS_ACCESS_KEY_ID"
  aws-secret-access-key: "$AWS_SECRET_ACCESS_KEY"
  aws-region: "$AWS_REGION"
EOF
    
    DISTRIBUTION_ENV_VARS=$(cat <<'ENVEOF'
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: bedrock-secret
            key: aws-access-key-id
      - name: AWS_SECRET_ACCESS_KEY
        valueFrom:
          secretKeyRef:
            name: bedrock-secret
            key: aws-secret-access-key
      - name: AWS_REGION
        valueFrom:
          secretKeyRef:
            name: bedrock-secret
            key: aws-region
ENVEOF
    )
    
    LLM_PROVIDER="bedrock"
    CONFIG_FILE="$SCRIPT_DIR/demo/llamastack-demo/llamastack/llamastack-config-bedrock.yaml"
}

deploy_llamastack_distribution() {
    local target_ns="$1"
    
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Deploying LlamaStack Distribution${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    # Check if LlamaStack CRD exists
    if ! oc get crd llamastackdistributions.llamastack.io &>/dev/null; then
        print_error "LlamaStackDistribution CRD not found!"
        echo ""
        echo "Please ensure:"
        echo "  1. Red Hat OpenShift AI 3.0+ is installed"
        echo "  2. LlamaStack operator is enabled in DataScienceCluster"
        echo ""
        echo "To enable LlamaStack in your DSC:"
        echo "  oc patch datasciencecluster default-dsc --type merge \\"
        echo "    -p '{\"spec\":{\"components\":{\"llamastackoperator\":{\"managementState\":\"Managed\"}}}}'"
        echo ""
        return 1
    fi
    
    print_success "LlamaStack CRD found"
    
    # Select and configure provider
    show_llm_provider_menu
    read -p "Enter your choice [1]: " provider_choice
    provider_choice="${provider_choice:-1}"
    
    case $provider_choice in
        1) configure_vllm_provider "$target_ns" || return 1 ;;
        2) configure_azure_provider "$target_ns" || return 1 ;;
        3) configure_openai_provider "$target_ns" || return 1 ;;
        4) configure_ollama_provider "$target_ns" || return 1 ;;
        5) configure_bedrock_provider "$target_ns" || return 1 ;;
        *) print_error "Invalid choice"; return 1 ;;
    esac
    
    # Apply ConfigMap
    print_step "Creating LlamaStack ConfigMap..."
    sed -e "s/NAMESPACE_PLACEHOLDER/$target_ns/g" \
        -e "s/MODEL_ID_PLACEHOLDER/$MODEL_ID/g" \
        "$CONFIG_FILE" | oc apply -f -
    
    # Apply Distribution with env vars
    print_step "Creating LlamaStackDistribution..."
    
    local dist_file="$SCRIPT_DIR/demo/llamastack-demo/llamastack/llamastack-distribution.yaml"
    
    # Read base distribution and inject env vars
    sed -e "s/NAMESPACE_PLACEHOLDER/$target_ns/g" "$dist_file" | \
    awk -v env_vars="$DISTRIBUTION_ENV_VARS" '
        /env:/ && !done {
            print
            print env_vars
            done=1
            next
        }
        { print }
    ' | oc apply -f -
    
    print_step "Waiting for LlamaStack pod to be ready..."
    sleep 5
    
    if oc wait --for=condition=available deployment -l llamastack.io/distribution=llamastack-demo -n "$target_ns" --timeout=180s 2>/dev/null; then
        print_success "LlamaStack is ready"
    else
        print_warning "LlamaStack may still be starting. Check with: oc get pods -n $target_ns"
    fi
    
    # Store LlamaStack URL for Demo UI
    LLAMASTACK_URL="http://llamastack-demo-service.${target_ns}.svc.cluster.local:8321"
    
    return 0
}

deploy_full_stack_with_llamastack() {
    print_header "Deploy Full Stack with LlamaStack"
    
    # Get target namespace
    echo -e "${CYAN}Target Namespace Configuration:${NC}"
    local current_project=$(oc project -q 2>/dev/null)
    echo "Current project: $current_project"
    echo ""
    read -p "Enter target namespace [default: $current_project]: " target_ns
    target_ns="${target_ns:-$current_project}"
    
    # Check/create namespace
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_warning "Namespace '$target_ns' does not exist"
        read -p "Create it? (y/N): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc new-project "$target_ns" 2>/dev/null || oc create namespace "$target_ns"
            print_success "Namespace created"
        else
            print_error "Namespace required"
            return 1
        fi
    fi
    
    oc project "$target_ns" &>/dev/null
    
    echo ""
    echo -e "${CYAN}This will deploy:${NC}"
    echo "  • LlamaStack Distribution (with your chosen LLM provider)"
    echo "  • Weather MCP Server (5 weather query tools)"
    echo "  • MongoDB with sample weather data"
    echo "  • Demo UI (Streamlit chatbot)"
    echo ""
    echo -e "${YELLOW}Requirements:${NC}"
    echo "  • RHOAI 3.0+ with LlamaStack operator enabled"
    echo "  • Access to your chosen LLM provider"
    echo ""
    
    read -p "Proceed? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Cancelled"
        return 0
    fi
    
    # Step 1: Deploy LlamaStack
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Step 1/3: Deploying LlamaStack${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    if ! deploy_llamastack_distribution "$target_ns"; then
        print_error "Failed to deploy LlamaStack"
        return 1
    fi
    
    # Step 2: Deploy MCP + MongoDB
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Step 2/3: Deploying Weather MCP Server + MongoDB${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    deploy_weather_mcp_server "$target_ns"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to deploy MCP server"
        return 1
    fi
    
    # Step 3: Deploy UI
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Step 3/3: Deploying LlamaStack Demo UI${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    local demo_dir="$SCRIPT_DIR/demo/llamastack-demo"
    local mcp_url="http://weather-mcp-server.${target_ns}.svc.cluster.local:8000"
    
    print_step "Applying ConfigMap and Deployment manifests..."
    
    # Apply deployment.yaml with namespace and config values substituted
    sed -e "s/namespace: demo-test/namespace: $target_ns/g" \
        -e "s|demo-test/|$target_ns/|g" \
        -e "s|LLAMASTACK_URL:.*|LLAMASTACK_URL: \"$LLAMASTACK_URL\"|g" \
        -e "s|MODEL_ID:.*|MODEL_ID: \"$MODEL_ID\"|g" \
        -e "s|MCP_SERVER_URL:.*|MCP_SERVER_URL: \"$mcp_url\"|g" \
        -e "s|APP_TITLE:.*|APP_TITLE: \"LlamaStack + MCP Demo\"|g" \
        -e "s|APP_SUBTITLE:.*|APP_SUBTITLE: \"AI Agent with Weather Data Tools\"|g" \
        -e "s|MCP_SERVER_NAME:.*|MCP_SERVER_NAME: \"Weather MCP\"|g" \
        -e "s|MCP_SERVER_DESCRIPTION:.*|MCP_SERVER_DESCRIPTION: \"Provides weather data queries for 14 global airports\"|g" \
        -e "s|DATA_SOURCE_NAME:.*|DATA_SOURCE_NAME: \"MongoDB\"|g" \
        -e "s|CHAT_PLACEHOLDER:.*|CHAT_PLACEHOLDER: \"Ask about weather conditions...\"|g" \
        "$demo_dir/deployment.yaml" | oc apply -f -
    
    print_step "Creating BuildConfig..."
    apply_manifest "$demo_dir/buildconfig.yaml" "$target_ns"
    
    echo ""
    print_step "Building Demo UI container..."
    if oc start-build llamastack-mcp-demo --from-dir="$demo_dir" --follow -n "$target_ns"; then
        print_success "Build completed"
    else
        print_error "Build failed"
        return 1
    fi
    
    echo ""
    print_step "Waiting for deployment..."
    if oc rollout status deployment/llamastack-mcp-demo -n "$target_ns" --timeout=120s; then
        print_success "Demo UI deployed"
    else
        print_warning "Deployment may still be starting"
    fi
    
    # Get route
    local route_url=$(oc get route llamastack-mcp-demo -n "$target_ns" -o jsonpath='{.spec.host}' 2>/dev/null)
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ Full LlamaStack Demo Stack Deployed!                       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📦 Deployed Components:${NC}"
    echo "   • LlamaStack: llamastack-demo-service.$target_ns.svc.cluster.local:8321"
    echo "   • Provider: $LLM_PROVIDER"
    echo "   • Model: $MODEL_ID"
    echo "   • MongoDB: mongodb.$target_ns.svc.cluster.local:27017"
    echo "   • Weather MCP: weather-mcp-server.$target_ns.svc.cluster.local:8000"
    echo ""
    echo -e "${CYAN}📌 Application URL:${NC}"
    echo -e "   ${GREEN}https://$route_url${NC}"
    echo ""
    echo -e "${CYAN}💡 MCP tools are pre-registered in LlamaStack config.${NC}"
    echo "   The Weather MCP tools should be available immediately."
    echo ""
    
    return 0
}

################################################################################
# Open WebUI Deployment
################################################################################

deploy_open_webui() {
    print_header "Deploy Open WebUI"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    # Get target namespace
    echo -e "${CYAN}Target Namespace Configuration:${NC}"
    local current_project=$(oc project -q 2>/dev/null)
    echo "Current project: $current_project"
    echo ""
    read -p "Enter target namespace [default: $current_project]: " target_ns
    target_ns="${target_ns:-$current_project}"
    
    # Check/create namespace
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_warning "Namespace '$target_ns' does not exist"
        read -p "Create it? (y/N): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc new-project "$target_ns" 2>/dev/null || oc create namespace "$target_ns"
            print_success "Namespace created"
        else
            print_error "Namespace required"
            return 1
        fi
    fi
    
    oc project "$target_ns" &>/dev/null
    
    # Detect available models
    echo ""
    echo -e "${CYAN}Detecting deployed models...${NC}"
    local models=$(oc get inferenceservice -n "$target_ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    local model_urls=""
    
    if [ -n "$models" ]; then
        echo "Found models in $target_ns:"
        for model in $models; do
            local url="http://${model}-predictor.${target_ns}.svc.cluster.local:8080/v1"
            echo "  • $model → $url"
            if [ -z "$model_urls" ]; then
                model_urls="$url"
            else
                model_urls="${model_urls};${url}"
            fi
        done
    else
        echo "No models found in $target_ns"
        # Check other namespaces
        local all_models=$(oc get inferenceservice -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} {end}' 2>/dev/null)
        if [ -n "$all_models" ]; then
            echo ""
            echo "Models in other namespaces:"
            for m in $all_models; do
                local ns=$(echo "$m" | cut -d'/' -f1)
                local name=$(echo "$m" | cut -d'/' -f2)
                echo "  • $name (namespace: $ns)"
            done
        fi
    fi
    
    echo ""
    read -p "Enter model URL(s) [semicolon-separated, or press Enter for detected]: " custom_urls
    if [ -n "$custom_urls" ]; then
        model_urls="$custom_urls"
    fi
    
    if [ -z "$model_urls" ]; then
        print_warning "No model URLs configured. You can add them later via ConfigMap."
        model_urls="http://localhost:8080/v1"
    fi
    
    echo ""
    echo -e "${CYAN}This will deploy:${NC}"
    echo "  • Open WebUI (web interface for chatting with models)"
    echo "  • 2Gi persistent storage for data"
    echo "  • Route for external access"
    echo ""
    echo "Model URL(s): $model_urls"
    echo ""
    
    read -p "Proceed? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Cancelled"
        return 0
    fi
    
    # Deploy Open WebUI
    print_step "Deploying Open WebUI..."
    
    local manifest_file="$SCRIPT_DIR/lib/manifests/demo/open-webui.yaml"
    
    if [ -f "$manifest_file" ]; then
        # Use local manifest with variable substitution
        export MODEL_URL="$model_urls"
        sed -e "s|\${MODEL_URL:-http://localhost:8080/v1}|$model_urls|g" \
            "$manifest_file" | oc apply -n "$target_ns" -f -
        unset MODEL_URL
    else
        # Fallback to external manifest
        print_info "Using external Open WebUI manifest..."
        oc apply -f https://raw.githubusercontent.com/tsailiming/openshift-open-webui/refs/heads/main/open-webui.yaml -n "$target_ns"
        
        # Configure model URLs
        oc patch configmap openwebui-config -n "$target_ns" --type merge \
            -p "{\"data\":{\"OPENAI_API_BASE_URLS\":\"$model_urls\",\"OPENAI_API_KEYS\":\"\"}}" 2>/dev/null || true
    fi
    
    # Disable persistent config so ConfigMap changes take effect
    oc set env deploy/open-webui ENABLE_PERSISTENT_CONFIG=False -n "$target_ns" 2>/dev/null || true
    
    print_step "Waiting for Open WebUI to be ready..."
    if oc rollout status deployment/open-webui -n "$target_ns" --timeout=180s; then
        print_success "Open WebUI deployed"
    else
        print_warning "Open WebUI may still be starting"
    fi
    
    # Get route
    local route_url=$(oc get route open-webui -n "$target_ns" -o jsonpath='{.spec.host}' 2>/dev/null)
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ Open WebUI Deployed Successfully!                          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    if [ -n "$route_url" ]; then
        echo -e "${CYAN}🌐 Access URL:${NC} https://$route_url"
    fi
    echo ""
    echo -e "${CYAN}📋 Configuration:${NC}"
    echo "   • Model URLs: $model_urls"
    echo "   • Auth disabled (workshop mode)"
    echo ""
    echo -e "${YELLOW}📝 To add more models later:${NC}"
    echo "   oc patch configmap openwebui-config -n $target_ns --type merge \\"
    echo "     -p '{\"data\":{\"OPENAI_API_BASE_URLS\":\"url1;url2\"}}'"
    echo "   oc rollout restart deployment/open-webui -n $target_ns"
    echo ""
    
    return 0
}

################################################################################
# Kubernetes MCP Server Deployment
################################################################################

deploy_kubernetes_mcp_server() {
    print_header "Deploy Kubernetes MCP Server"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi
    
    # Get target namespace
    echo -e "${CYAN}Target Namespace Configuration:${NC}"
    local current_project=$(oc project -q 2>/dev/null)
    echo "Current project: $current_project"
    echo ""
    read -p "Enter target namespace [default: $current_project]: " target_ns
    target_ns="${target_ns:-$current_project}"
    
    # Check/create namespace
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_warning "Namespace '$target_ns' does not exist"
        read -p "Create it? (y/N): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc new-project "$target_ns" 2>/dev/null || oc create namespace "$target_ns"
            print_success "Namespace created"
        else
            print_error "Namespace required"
            return 1
        fi
    fi
    
    oc project "$target_ns" &>/dev/null
    
    echo ""
    echo -e "${CYAN}This will deploy:${NC}"
    echo "  • Kubernetes MCP Server"
    echo "  • ServiceAccount with read-only cluster access"
    echo "  • Enables querying pods, deployments, services, logs via LLM"
    echo ""
    echo -e "${YELLOW}Available tools after deployment:${NC}"
    echo "  • List/describe pods, deployments, services"
    echo "  • Get pod logs"
    echo "  • Query InferenceServices"
    echo "  • Check namespace resources"
    echo ""
    
    read -p "Proceed? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Cancelled"
        return 0
    fi
    
    # Deploy Kubernetes MCP Server
    print_step "Deploying Kubernetes MCP Server..."
    
    local manifest_file="$SCRIPT_DIR/lib/manifests/demo/mcp-kubernetes.yaml"
    
    if [ -f "$manifest_file" ]; then
        oc apply -f "$manifest_file" -n "$target_ns"
    else
        print_error "Kubernetes MCP manifest not found: $manifest_file"
        return 1
    fi
    
    print_step "Waiting for Kubernetes MCP Server to be ready..."
    if oc rollout status deployment/kubernetes-mcp-server -n "$target_ns" --timeout=120s; then
        print_success "Kubernetes MCP Server deployed"
    else
        print_warning "MCP server may still be starting"
    fi
    
    local mcp_url="http://kubernetes-mcp-server.${target_ns}.svc.cluster.local/mcp"
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ Kubernetes MCP Server Deployed Successfully!               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📋 MCP Endpoint:${NC}"
    echo "   $mcp_url"
    echo ""
    echo -e "${CYAN}🔧 Available Tools:${NC}"
    echo "   • list_pods - List pods in namespace"
    echo "   • describe_pod - Get pod details"
    echo "   • get_pod_logs - Get container logs"
    echo "   • list_deployments - List deployments"
    echo "   • list_services - List services"
    echo "   • list_inferenceservices - List RHOAI models"
    echo ""
    echo -e "${YELLOW}📝 To use with LlamaStack, add to config:${NC}"
    echo "   tool_groups:"
    echo "   - toolgroup_id: mcp::kubernetes"
    echo "     provider_id: model-context-protocol"
    echo "     mcp_endpoint:"
    echo "       uri: $mcp_url"
    echo ""
    
    return 0
}

################################################################################
# MCP + MongoDB Deployment
################################################################################

deploy_mcp_mongodb_only() {
    print_header "Deploy Weather MCP Server + MongoDB"
    
    # Get target namespace
    echo -e "${CYAN}Target Namespace Configuration:${NC}"
    local current_project=$(oc project -q 2>/dev/null)
    echo "Current project: $current_project"
    echo ""
    read -p "Enter target namespace [default: $current_project]: " target_ns
    target_ns="${target_ns:-$current_project}"
    
    # Check/create namespace
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_warning "Namespace '$target_ns' does not exist"
        read -p "Create it? (y/N): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc new-project "$target_ns" 2>/dev/null || oc create namespace "$target_ns"
            print_success "Namespace created"
        else
            print_error "Namespace required"
            return 1
        fi
    fi
    
    oc project "$target_ns" &>/dev/null
    
    echo ""
    echo -e "${CYAN}This will deploy:${NC}"
    echo "  • MongoDB with 1Gi persistent storage"
    echo "  • Sample weather data (14 stations, 48 hours of data)"
    echo "  • Weather MCP Server with 5 tools"
    echo ""
    
    read -p "Proceed? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Cancelled"
        return 0
    fi
    
    # Deploy
    deploy_weather_mcp_server "$target_ns"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✅ Weather MCP Server Deployed Successfully!                  ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}📋 Deployed Components:${NC}"
        echo "   • MongoDB: mongodb.$target_ns.svc.cluster.local:27017"
        echo "   • MCP Server: weather-mcp-server.$target_ns.svc.cluster.local:8000"
        echo ""
        echo -e "${CYAN}🔧 Available Tools:${NC}"
        echo "   • search_weather - Search observations with filters"
        echo "   • get_current_weather - Get latest observation for a station"
        echo "   • list_stations - List all weather stations"
        echo "   • get_statistics - Get database stats"
        echo "   • health_check - Check server health"
        echo ""
        echo -e "${YELLOW}📝 Next Steps:${NC}"
        echo "   1. Register MCP server with LlamaStack:"
        echo "      Add to your LlamaStack config under tool_groups:"
        echo ""
        echo "      - toolgroup_id: mcp::weather-data"
        echo "        provider_id: model-context-protocol"
        echo "        mcp_endpoint:"
        echo "          uri: http://weather-mcp-server.$target_ns.svc.cluster.local:8000/mcp"
        echo ""
        echo "   2. Restart LlamaStack to pick up the new tools"
        echo ""
    fi
    
    return 0
}

deploy_complete_llamastack_demo() {
    print_header "Deploy Complete LlamaStack Demo Stack"
    
    # Get target namespace
    echo -e "${CYAN}Target Namespace Configuration:${NC}"
    local current_project=$(oc project -q 2>/dev/null)
    echo "Current project: $current_project"
    echo ""
    read -p "Enter target namespace [default: $current_project]: " target_ns
    target_ns="${target_ns:-$current_project}"
    
    # Check/create namespace
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_warning "Namespace '$target_ns' does not exist"
        read -p "Create it? (y/N): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc new-project "$target_ns" 2>/dev/null || oc create namespace "$target_ns"
            print_success "Namespace created"
        else
            print_error "Namespace required"
            return 1
        fi
    fi
    
    oc project "$target_ns" &>/dev/null
    
    echo ""
    echo -e "${CYAN}LlamaStack Configuration:${NC}"
    echo ""
    
    # Try to auto-detect LlamaStack service
    local detected_llamastack=""
    detected_llamastack=$(oc get svc -n "$target_ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -E "llama|lsd" | head -1)
    
    if [ -n "$detected_llamastack" ]; then
        local default_llamastack_url="http://${detected_llamastack}.${target_ns}.svc.cluster.local:8321"
        echo "Detected LlamaStack service: $detected_llamastack"
    else
        local default_llamastack_url="http://lsd-genai-playground-service.${target_ns}.svc.cluster.local:8321"
        echo "No LlamaStack service auto-detected"
    fi
    
    read -p "LlamaStack URL [$default_llamastack_url]: " llamastack_url
    llamastack_url="${llamastack_url:-$default_llamastack_url}"
    
    # Model ID
    read -p "Model ID [qwen3-8b]: " model_id
    model_id="${model_id:-qwen3-8b}"
    
    echo ""
    echo -e "${CYAN}This will deploy:${NC}"
    echo "  • MongoDB with sample weather data"
    echo "  • Weather MCP Server (5 weather query tools)"
    echo "  • LlamaStack Demo UI (Streamlit chatbot)"
    echo ""
    echo "  LlamaStack URL: $llamastack_url"
    echo "  Model ID: $model_id"
    echo ""
    
    read -p "Proceed with deployment? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Deployment cancelled"
        return 0
    fi
    
    # Step 1: Deploy MCP + MongoDB
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Step 1/2: Deploying Weather MCP Server + MongoDB${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    deploy_weather_mcp_server "$target_ns"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to deploy MCP server"
        return 1
    fi
    
    # Step 2: Deploy UI with the Weather MCP server
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Step 2/2: Deploying LlamaStack Demo UI${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    local demo_dir="$SCRIPT_DIR/demo/llamastack-demo"
    local mcp_url="http://weather-mcp-server.${target_ns}.svc.cluster.local:8000"
    
    echo ""
    print_step "Applying ConfigMap and Deployment manifests..."
    
    # Apply deployment.yaml with namespace and config values substituted for Weather demo
    sed -e "s/namespace: demo-test/namespace: $target_ns/g" \
        -e "s|demo-test/|$target_ns/|g" \
        -e "s|LLAMASTACK_URL:.*|LLAMASTACK_URL: \"$llamastack_url\"|g" \
        -e "s|MODEL_ID:.*|MODEL_ID: \"$model_id\"|g" \
        -e "s|MCP_SERVER_URL:.*|MCP_SERVER_URL: \"$mcp_url\"|g" \
        -e "s|APP_TITLE:.*|APP_TITLE: \"LlamaStack + MCP Demo\"|g" \
        -e "s|APP_SUBTITLE:.*|APP_SUBTITLE: \"AI Agent with Weather Data Tools\"|g" \
        -e "s|MCP_SERVER_NAME:.*|MCP_SERVER_NAME: \"Weather MCP\"|g" \
        -e "s|MCP_SERVER_DESCRIPTION:.*|MCP_SERVER_DESCRIPTION: \"Provides weather data queries for 14 global airports\"|g" \
        -e "s|DATA_SOURCE_NAME:.*|DATA_SOURCE_NAME: \"MongoDB\"|g" \
        -e "s|CHAT_PLACEHOLDER:.*|CHAT_PLACEHOLDER: \"Ask about weather conditions...\"|g" \
        "$demo_dir/deployment.yaml" | oc apply -f -
    
    print_step "Creating BuildConfig..."
    apply_manifest "$demo_dir/buildconfig.yaml" "$target_ns"
    
    echo ""
    print_step "Building Demo UI container..."
    if oc start-build llamastack-mcp-demo --from-dir="$demo_dir" --follow -n "$target_ns"; then
        print_success "Build completed"
    else
        print_error "Build failed"
        return 1
    fi
    
    echo ""
    print_step "Waiting for deployment..."
    if oc rollout status deployment/llamastack-mcp-demo -n "$target_ns" --timeout=120s; then
        print_success "Demo UI deployed"
    else
        print_warning "Deployment may still be starting"
    fi
    
    # Get route
    local route_url=$(oc get route llamastack-mcp-demo -n "$target_ns" -o jsonpath='{.spec.host}' 2>/dev/null)
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ Complete LlamaStack Demo Stack Deployed!                   ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📋 Deployed Components:${NC}"
    echo "   • MongoDB: mongodb.$target_ns.svc.cluster.local:27017"
    echo "   • Weather MCP Server: weather-mcp-server.$target_ns.svc.cluster.local:8000"
    echo "   • Demo UI: https://$route_url"
    echo ""
    echo -e "${CYAN}📌 Application URL:${NC}"
    echo -e "   ${GREEN}https://$route_url${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Important: Register MCP with LlamaStack${NC}"
    echo "   Add to your LlamaStack config under tool_groups:"
    echo ""
    echo "   - toolgroup_id: mcp::weather-data"
    echo "     provider_id: model-context-protocol"
    echo "     mcp_endpoint:"
    echo "       uri: http://weather-mcp-server.$target_ns.svc.cluster.local:8000/mcp"
    echo ""
    echo "   Then restart LlamaStack to load the new tools."
    echo ""
    
    return 0
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
        read -p "Select an option (1-4, 0): " model_choice
        
        case $model_choice in
            1)
                deploy_model_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                add_model_to_playground_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                create_hardware_profile_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                create_hardware_profile_quick
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                print_error "Invalid option. Please select 1-4 or 0."
                sleep 1
                ;;
        esac
    done
}

ai_services_submenu() {
    while true; do
        show_ai_services_submenu
        read -p "Select an option (1-5, 0): " ai_choice
        
        case $ai_choice in
            1)
                deploy_open_webui
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                deploy_llamastack_demo_menu
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                setup_mcp_servers_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                setup_llamastack_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                MAAS_ONLY=true
                run_maas_only_setup
                echo ""
                read -p "Press Enter to continue..."
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

rhoai_management_menu() {
    while true; do
        show_rhoai_management_menu
        read -p "Select an option (1-6, 0): " rhoai_choice
        
        case $rhoai_choice in
            1)
                model_management_submenu
                ;;
            2)
                ai_services_submenu
                ;;
            3)
                enable_dashboard_features_interactive
                echo ""
                read -p "Press Enter to return to RHOAI Management menu..."
                ;;
            4)
                quick_start_wizard
                echo ""
                read -p "Press Enter to return to RHOAI Management menu..."
                ;;
            5)
                approve_pending_csrs
                echo ""
                read -p "Press Enter to return to RHOAI Management menu..."
                ;;
            6)
                troubleshooting_submenu
                ;;
            0)
                print_info "Returning to main menu..."
                break
                ;;
            *)
                print_error "Invalid option. Please select 1-6 or 0."
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
# Kubeconfig Management
################################################################################

configure_kubeconfig_interactive() {
    print_header "Configure Kubeconfig"
    
    # Show current status
    echo -e "${CYAN}Current Kubeconfig Status:${NC}"
    echo ""
    
    if [ -n "$KUBECONFIG" ]; then
        echo -e "  KUBECONFIG env: ${GREEN}$KUBECONFIG${NC}"
        if [ -f "$KUBECONFIG" ]; then
            echo -e "  File exists: ${GREEN}Yes${NC}"
        else
            echo -e "  File exists: ${RED}No${NC}"
        fi
    else
        echo -e "  KUBECONFIG env: ${YELLOW}Not set${NC}"
        if [ -f "$HOME/.kube/config" ]; then
            echo -e "  Default (~/.kube/config): ${GREEN}Exists${NC}"
        else
            echo -e "  Default (~/.kube/config): ${YELLOW}Not found${NC}"
        fi
    fi
    
    echo ""
    
    # Check if logged in
    if oc whoami &>/dev/null; then
        local cluster_url=$(oc whoami --show-server 2>/dev/null)
        local cluster_user=$(oc whoami 2>/dev/null)
        echo -e "  Connected: ${GREEN}Yes${NC}"
        echo -e "  Cluster: ${GREEN}$cluster_url${NC}"
        echo -e "  User: ${GREEN}$cluster_user${NC}"
    else
        echo -e "  Connected: ${RED}No${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║               Kubeconfig Options                               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} Login with token (oc login --token=...)"
    echo -e "${YELLOW}2)${NC} Login with username/password"
    echo -e "${YELLOW}3)${NC} Set KUBECONFIG from existing file"
    echo -e "${YELLOW}4)${NC} Create new kubeconfig in workspace"
    echo -e "${YELLOW}5)${NC} View current kubeconfig"
    echo -e "${YELLOW}6)${NC} Test connection"
    echo -e "${YELLOW}7)${NC} Back to Main Menu"
    echo ""
    
    read -p "Select an option (1-7): " kube_choice
    
    case $kube_choice in
        1)
            login_with_token
            ;;
        2)
            login_with_credentials
            ;;
        3)
            set_kubeconfig_from_file
            ;;
        4)
            create_workspace_kubeconfig
            ;;
        5)
            view_kubeconfig
            ;;
        6)
            test_connection
            ;;
        7)
            return 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    
    # Recursive call to show menu again
    configure_kubeconfig_interactive
}

login_with_token() {
    echo ""
    print_step "Login with Token"
    echo ""
    echo -e "${CYAN}Enter your OpenShift login command or provide the details:${NC}"
    echo ""
    echo "You can paste the full command like:"
    echo "  oc login --token=sha256~xxx --server=https://api.cluster.example.com:6443"
    echo ""
    echo "Or enter the details separately."
    echo ""
    
    read -p "Paste full oc login command (or press Enter to enter details separately): " full_command
    
    if [ -n "$full_command" ]; then
        # Extract token and server from the command
        local token=$(echo "$full_command" | grep -oE '\-\-token=[^ ]+' | sed 's/--token=//')
        local server=$(echo "$full_command" | grep -oE '\-\-server=[^ ]+' | sed 's/--server=//')
        
        if [ -z "$token" ] || [ -z "$server" ]; then
            print_error "Could not parse token and server from command"
            echo "Please enter details separately:"
            read -p "Server URL (e.g., https://api.cluster.example.com:6443): " server
            read -p "Token: " token
        fi
    else
        read -p "Server URL (e.g., https://api.cluster.example.com:6443): " server
        read -p "Token: " token
    fi
    
    if [ -z "$token" ] || [ -z "$server" ]; then
        print_error "Token and server are required"
        return 1
    fi
    
    # Ask about kubeconfig location
    echo ""
    echo -e "${CYAN}Where should the kubeconfig be saved?${NC}"
    echo "  1) Workspace (./kubeconfig) - recommended for this project"
    echo "  2) Default (~/.kube/config)"
    echo "  3) Custom path"
    echo ""
    read -p "Select option [1-3] (default: 1): " save_choice
    save_choice=${save_choice:-1}
    
    local kubeconfig_path
    case $save_choice in
        1)
            kubeconfig_path="$SCRIPT_DIR/kubeconfig"
            ;;
        2)
            kubeconfig_path="$HOME/.kube/config"
            ;;
        3)
            read -p "Enter path: " kubeconfig_path
            ;;
        *)
            kubeconfig_path="$SCRIPT_DIR/kubeconfig"
            ;;
    esac
    
    # Ensure directory exists
    mkdir -p "$(dirname "$kubeconfig_path")"
    
    # Export and login
    export KUBECONFIG="$kubeconfig_path"
    
    echo ""
    print_step "Logging in..."
    
    if oc login --token="$token" --server="$server" --insecure-skip-tls-verify 2>&1; then
        echo ""
        print_success "Login successful!"
        print_success "KUBECONFIG set to: $kubeconfig_path"
        echo ""
        echo -e "${YELLOW}To use this kubeconfig in your shell, run:${NC}"
        echo -e "  ${GREEN}export KUBECONFIG=\"$kubeconfig_path\"${NC}"
        echo ""
        
        # Ask if user wants to add to shell profile
        read -p "Add KUBECONFIG export to your shell profile? (y/N): " add_to_profile
        if [[ "$add_to_profile" =~ ^[Yy]$ ]]; then
            add_kubeconfig_to_profile "$kubeconfig_path"
        fi
    else
        print_error "Login failed"
        return 1
    fi
}

login_with_credentials() {
    echo ""
    print_step "Login with Username/Password"
    echo ""
    
    read -p "Server URL (e.g., https://api.cluster.example.com:6443): " server
    read -p "Username: " username
    read -s -p "Password: " password
    echo ""
    
    if [ -z "$server" ] || [ -z "$username" ] || [ -z "$password" ]; then
        print_error "Server, username, and password are required"
        return 1
    fi
    
    # Ask about kubeconfig location
    echo ""
    echo -e "${CYAN}Where should the kubeconfig be saved?${NC}"
    echo "  1) Workspace (./kubeconfig)"
    echo "  2) Default (~/.kube/config)"
    echo ""
    read -p "Select option [1-2] (default: 1): " save_choice
    save_choice=${save_choice:-1}
    
    local kubeconfig_path
    if [ "$save_choice" = "2" ]; then
        kubeconfig_path="$HOME/.kube/config"
    else
        kubeconfig_path="$SCRIPT_DIR/kubeconfig"
    fi
    
    mkdir -p "$(dirname "$kubeconfig_path")"
    export KUBECONFIG="$kubeconfig_path"
    
    echo ""
    print_step "Logging in..."
    
    if oc login --username="$username" --password="$password" --server="$server" --insecure-skip-tls-verify 2>&1; then
        echo ""
        print_success "Login successful!"
        print_success "KUBECONFIG set to: $kubeconfig_path"
    else
        print_error "Login failed"
        return 1
    fi
}

set_kubeconfig_from_file() {
    echo ""
    print_step "Set KUBECONFIG from Existing File"
    echo ""
    
    # Show common locations
    echo -e "${CYAN}Common kubeconfig locations:${NC}"
    local found_configs=()
    
    if [ -f "$SCRIPT_DIR/kubeconfig" ]; then
        found_configs+=("$SCRIPT_DIR/kubeconfig")
        echo "  1) $SCRIPT_DIR/kubeconfig"
    fi
    if [ -f "$SCRIPT_DIR/openshift-cluster-install/auth/kubeconfig" ]; then
        found_configs+=("$SCRIPT_DIR/openshift-cluster-install/auth/kubeconfig")
        echo "  2) $SCRIPT_DIR/openshift-cluster-install/auth/kubeconfig"
    fi
    if [ -f "$HOME/.kube/config" ]; then
        found_configs+=("$HOME/.kube/config")
        echo "  3) $HOME/.kube/config"
    fi
    
    echo "  c) Enter custom path"
    echo ""
    
    read -p "Select option: " file_choice
    
    local selected_path
    case $file_choice in
        1)
            selected_path="${found_configs[0]:-}"
            ;;
        2)
            selected_path="${found_configs[1]:-}"
            ;;
        3)
            selected_path="${found_configs[2]:-}"
            ;;
        c|C)
            read -p "Enter kubeconfig path: " selected_path
            ;;
        *)
            print_error "Invalid option"
            return 1
            ;;
    esac
    
    if [ -z "$selected_path" ]; then
        print_error "No path selected"
        return 1
    fi
    
    if [ ! -f "$selected_path" ]; then
        print_error "File does not exist: $selected_path"
        return 1
    fi
    
    export KUBECONFIG="$selected_path"
    print_success "KUBECONFIG set to: $selected_path"
    
    # Test connection
    echo ""
    print_step "Testing connection..."
    if oc whoami &>/dev/null; then
        print_success "Connected as: $(oc whoami)"
        print_success "Cluster: $(oc whoami --show-server)"
    else
        print_warning "Could not connect to cluster - token may be expired"
        echo ""
        read -p "Would you like to login again? (y/N): " relogin
        if [[ "$relogin" =~ ^[Yy]$ ]]; then
            login_with_token
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}To persist this setting, run:${NC}"
    echo -e "  ${GREEN}export KUBECONFIG=\"$selected_path\"${NC}"
}

create_workspace_kubeconfig() {
    echo ""
    print_step "Create New Kubeconfig in Workspace"
    echo ""
    
    local kubeconfig_path="$SCRIPT_DIR/kubeconfig"
    
    if [ -f "$kubeconfig_path" ]; then
        print_warning "Kubeconfig already exists at: $kubeconfig_path"
        read -p "Overwrite? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            return 0
        fi
    fi
    
    export KUBECONFIG="$kubeconfig_path"
    print_success "KUBECONFIG set to: $kubeconfig_path"
    echo ""
    
    # Now login
    login_with_token
}

view_kubeconfig() {
    echo ""
    print_step "Current Kubeconfig Contents"
    echo ""
    
    local config_path="${KUBECONFIG:-$HOME/.kube/config}"
    
    if [ ! -f "$config_path" ]; then
        print_error "Kubeconfig not found at: $config_path"
        return 1
    fi
    
    echo -e "${CYAN}File: $config_path${NC}"
    echo ""
    
    # Show sanitized version (hide tokens)
    cat "$config_path" | sed 's/token: .*/token: <REDACTED>/' | head -50
    
    local total_lines=$(wc -l < "$config_path")
    if [ "$total_lines" -gt 50 ]; then
        echo ""
        echo -e "${YELLOW}... (showing first 50 of $total_lines lines)${NC}"
    fi
}

test_connection() {
    echo ""
    print_step "Testing OpenShift Connection"
    echo ""
    
    if [ -n "$KUBECONFIG" ]; then
        echo "KUBECONFIG: $KUBECONFIG"
    else
        echo "KUBECONFIG: (not set, using default)"
    fi
    echo ""
    
    if oc whoami &>/dev/null; then
        print_success "Connection successful!"
        echo ""
        echo "  User: $(oc whoami)"
        echo "  Server: $(oc whoami --show-server)"
        echo ""
        
        print_step "Cluster nodes:"
        oc get nodes 2>/dev/null || echo "  (unable to list nodes)"
        
        echo ""
        print_step "OpenShift version:"
        oc version 2>/dev/null | head -5 || echo "  (unable to get version)"
    else
        print_error "Connection failed"
        echo ""
        echo "Possible issues:"
        echo "  • Token expired (demo environments expire after ~24 hours)"
        echo "  • KUBECONFIG not set or pointing to wrong file"
        echo "  • Network connectivity issues"
        echo ""
        echo "Try logging in again with option 1 (Login with token)"
    fi
}

add_kubeconfig_to_profile() {
    local kubeconfig_path="$1"
    local shell_profile=""
    
    # Detect shell
    if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ]; then
        shell_profile="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ] || [ "$SHELL" = "/bin/bash" ]; then
        shell_profile="$HOME/.bashrc"
    else
        shell_profile="$HOME/.profile"
    fi
    
    echo ""
    print_step "Adding KUBECONFIG to $shell_profile"
    
    # Check if already in profile
    if grep -q "export KUBECONFIG=" "$shell_profile" 2>/dev/null; then
        print_warning "KUBECONFIG export already exists in $shell_profile"
        echo "Current line:"
        grep "export KUBECONFIG=" "$shell_profile"
        echo ""
        read -p "Replace it? (y/N): " replace
        if [[ "$replace" =~ ^[Yy]$ ]]; then
            # Remove old line and add new
            sed -i.bak '/export KUBECONFIG=/d' "$shell_profile"
            echo "export KUBECONFIG=\"$kubeconfig_path\"" >> "$shell_profile"
            print_success "Updated KUBECONFIG in $shell_profile"
        fi
    else
        echo "" >> "$shell_profile"
        echo "# OpenShift kubeconfig" >> "$shell_profile"
        echo "export KUBECONFIG=\"$kubeconfig_path\"" >> "$shell_profile"
        print_success "Added KUBECONFIG to $shell_profile"
    fi
    
    echo ""
    print_info "Run 'source $shell_profile' to apply changes to current shell"
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
        read -p "Select an option (1-7): " choice
        
        case $choice in
            1)
                run_complete_setup
                ;;
            2)
                run_minimal_setup
                ;;
            3)
                rhoai_management_menu
                ;;
            4)
                create_gpu_machineset_interactive
                echo ""
                read -p "Press Enter to return to main menu..."
                ;;
            5)
                configure_kubeconfig_interactive
                ;;
            6)
                show_help
                echo ""
                read -p "Press Enter to return to main menu..."
                ;;
            7)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-7."
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

