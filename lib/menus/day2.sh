#!/bin/bash
################################################################################
# day2.sh — Day 2 Operations submenu
# Extracted from rhoai-toolkit.sh
################################################################################

_DAY2_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

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
        echo -e "${YELLOW}4)${NC} Worker Node Scheduling ${BLUE}→${NC} ${GREEN}[New]${NC}"
        echo "    Scale worker/GPU nodes up/down on a schedule (cost savings)"
        echo ""
        echo -e "${YELLOW}5)${NC} Retry Workbench Clone ${GREEN}[New]${NC}"
        echo "    Re-run the RHOAI-Toolkit git clone in demo workbenches that"
        echo "    weren't Running yet when their deploy.sh first tried"
        echo ""
        echo -e "${YELLOW}0)${NC} Back"
        echo ""

        read -p "Select an option (0-5): " day2_choice
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
            4)
                node_scheduler_submenu
                ;;
            5)
                echo ""
                print_header "Retry Workbench Clone"
                read -p "Namespaces (comma-separated, blank = defaults): " ws_ns
                if [ -n "$ws_ns" ]; then
                    bash "$_DAY2_MENU_DIR/scripts/clone-toolkit-in-workbenches.sh" -n "$ws_ns"
                else
                    bash "$_DAY2_MENU_DIR/scripts/clone-toolkit-in-workbenches.sh"
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
# node_scheduler_submenu — Worker/GPU node scheduling (CronJob-based scale
# up/down). Wraps scripts/setup-node-scheduler.sh. See
# docs/guides/NODE-SCHEDULING.md.
################################################################################
show_node_scheduler_submenu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 Worker Node Scheduling                         ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Default schedule: scale up 8 AM, down 6 PM, Mon-Fri (Asia/Singapore)${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} Deploy/Apply Schedule"
    echo "    Install the CronJobs (default 8am-6pm Mon-Fri schedule)"
    echo ""
    echo -e "${YELLOW}2)${NC} Trigger Scale Up Now"
    echo -e "${YELLOW}3)${NC} Trigger Scale Down Now"
    echo ""
    echo -e "${YELLOW}4)${NC} Show Status"
    echo "    CronJob status, last run, current MachineSet state"
    echo ""
    echo -e "${YELLOW}5)${NC} Extend Hold (delay next scale-down)"
    echo -e "${YELLOW}6)${NC} Show Hold Status"
    echo -e "${YELLOW}7)${NC} Cancel Hold"
    echo ""
    echo -e "${YELLOW}8)${NC} Remove Node Scheduler ${RED}[Destructive]${NC}"
    echo ""
    echo -e "${YELLOW}0)${NC} Back"
    echo ""
}

node_scheduler_submenu() {
    local ns_script="$_DAY2_MENU_DIR/scripts/setup-node-scheduler.sh"
    while true; do
        show_node_scheduler_submenu
        read -p "Select an option (0-8): " ns_choice
        case $ns_choice in
            1)
                bash "$ns_script"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                bash "$ns_script" --trigger up
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                bash "$ns_script" --trigger down
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                bash "$ns_script" --status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                read -p "Hold duration (e.g. 1h, 2h, 30m) [1h]: " hold_dur
                hold_dur="${hold_dur:-1h}"
                bash "$ns_script" --extend "$hold_dur"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                bash "$ns_script" --hold-status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                bash "$ns_script" --cancel-hold
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                read -p "Remove all node-scheduler resources? (y/N): " ns_confirm
                if [[ "$ns_confirm" =~ ^[Yy]$ ]]; then
                    bash "$ns_script" --remove
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
