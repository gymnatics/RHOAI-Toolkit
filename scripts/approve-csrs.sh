#!/bin/bash

################################################################################
# Approve Pending Certificate Signing Requests (CSRs)
################################################################################
# This script approves all pending CSRs in the cluster.
#
# Usage:
#   ./scripts/approve-csrs.sh           # Interactive mode
#   ./scripts/approve-csrs.sh --auto    # Auto-approve without prompting
#   ./scripts/approve-csrs.sh --watch   # Watch and auto-approve for 5 minutes
#
# When to use:
#   - After adding new nodes to the cluster
#   - After node reboots
#   - When nodes are stuck in NotReady due to certificate issues
#   - During cluster recovery
#
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

# Parse arguments
AUTO_APPROVE=false
WATCH_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --auto|-a)
            AUTO_APPROVE=true
            shift
            ;;
        --watch|-w)
            WATCH_MODE=true
            AUTO_APPROVE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --auto, -a    Auto-approve all pending CSRs without prompting"
            echo "  --watch, -w   Watch for new CSRs and auto-approve for 5 minutes"
            echo "  --help, -h    Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0              # Interactive mode"
            echo "  $0 --auto       # Auto-approve once"
            echo "  $0 --watch      # Watch and approve for 5 minutes"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if logged in
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift cluster"
    echo ""
    echo "Please log in first:"
    echo "  oc login <cluster-url>"
    exit 1
fi

print_header "Approve Pending CSRs"
print_success "Connected to cluster: $(oc whoami --show-server)"
echo ""

approve_all_pending() {
    local pending_csrs
    pending_csrs=$(oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' 2>/dev/null)
    
    if [ -z "$pending_csrs" ]; then
        return 0
    fi
    
    local approved=0
    while IFS= read -r csr_name; do
        if [ -n "$csr_name" ]; then
            if oc adm certificate approve "$csr_name" &>/dev/null; then
                print_success "Approved: $csr_name"
                ((approved++))
            else
                print_error "Failed to approve: $csr_name"
            fi
        fi
    done <<< "$pending_csrs"
    
    return $approved
}

# Watch mode - continuously approve for 5 minutes
if [ "$WATCH_MODE" = true ]; then
    print_info "Watch mode: Will monitor and approve CSRs for 5 minutes"
    echo ""
    
    end_time=$(($(date +%s) + 300))  # 5 minutes from now
    
    while [ $(date +%s) -lt $end_time ]; do
        pending_count=$(oc get csr 2>/dev/null | grep -ci pending || echo "0")
        
        if [ "$pending_count" -gt 0 ]; then
            print_step "Found $pending_count pending CSR(s), approving..."
            approve_all_pending
        else
            remaining=$((end_time - $(date +%s)))
            printf "\r${CYAN}Watching for pending CSRs... (%ds remaining)${NC}  " "$remaining"
        fi
        
        sleep 5
    done
    
    echo ""
    print_success "Watch mode complete"
    exit 0
fi

# Regular mode
print_step "Checking for pending CSRs..."
pending_csrs=$(oc get csr 2>/dev/null | grep -i pending || true)

if [ -z "$pending_csrs" ]; then
    print_success "No pending CSRs found - all certificates are approved!"
    echo ""
    echo "Current CSR status:"
    oc get csr 2>/dev/null | head -20 || echo "  No CSRs found"
    exit 0
fi

echo ""
echo -e "${YELLOW}Found pending CSRs:${NC}"
echo "$pending_csrs"
echo ""

pending_count=$(echo "$pending_csrs" | wc -l | tr -d ' ')
echo -e "${CYAN}Found ${pending_count} pending CSR(s).${NC}"
echo ""

if [ "$AUTO_APPROVE" = false ]; then
    echo "CSRs are typically generated when:"
    echo "  • New nodes join the cluster"
    echo "  • Nodes are rebooted"
    echo "  • Kubelet certificates need renewal"
    echo ""
    
    read -p "Approve all pending CSRs? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "CSR approval cancelled"
        exit 0
    fi
fi

echo ""
print_step "Approving all pending CSRs..."
approve_all_pending

# Check for more (CSRs often come in waves)
echo ""
print_step "Checking for additional pending CSRs..."
sleep 3

more_pending=$(oc get csr 2>/dev/null | grep -i pending || true)

if [ -n "$more_pending" ]; then
    echo ""
    print_warning "More pending CSRs detected:"
    echo "$more_pending"
    
    if [ "$AUTO_APPROVE" = true ]; then
        print_step "Auto-approving additional CSRs..."
        approve_all_pending
    else
        echo ""
        read -p "Approve these as well? (y/N): " confirm_more
        if [[ "$confirm_more" =~ ^[Yy]$ ]]; then
            approve_all_pending
        fi
    fi
else
    print_success "No more pending CSRs"
fi

echo ""
echo -e "${GREEN}CSR approval complete!${NC}"
echo ""
echo "Current node status:"
oc get nodes 2>/dev/null || echo "  Unable to get node status"

