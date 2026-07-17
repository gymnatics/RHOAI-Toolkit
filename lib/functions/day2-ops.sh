#!/bin/bash
################################################################################
# day2-ops.sh — Day 2 cluster operations (CSR approval, kubeadmin removal)
# Extracted from rhoai-toolkit.sh
################################################################################

_DAY2_OPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_DAY2_OPS_DIR/lib/utils/colors.sh" 2>/dev/null || true

approve_pending_csrs() {
    print_header "Approve Pending Certificate Signing Requests (CSRs)"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    echo ""
    
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

remove_kubeadmin() {
    print_header "Remove kubeadmin User"

    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        return 1
    fi

    local current_user
    current_user=$(oc whoami 2>/dev/null)

    if [ "$current_user" = "kube:admin" ]; then
        print_error "You are currently logged in as kube:admin!"
        echo ""
        echo "You must log in as a different cluster-admin user before removing kubeadmin."
        echo "  oc login -u admin -p 'R3dh4t1!' $(oc whoami --show-server 2>/dev/null)"
        return 1
    fi

    if ! oc auth can-i '*' '*' --all-namespaces &>/dev/null; then
        print_error "Current user '$current_user' does not have cluster-admin privileges"
        return 1
    fi

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
