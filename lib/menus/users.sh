#!/bin/bash
################################################################################
# users.sh — User Management submenu for rhoai-toolkit.sh
################################################################################

_USERS_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

show_user_management_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    User Management                             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${MAGENTA}User Creation:${NC}"
    echo -e "${YELLOW}1)${NC} Create Users + Assign Roles ${GREEN}[New]${NC}"
    echo "    Create htpasswd users with interactive ClusterRole picker"
    echo ""
    echo -e "${MAGENTA}Role Management:${NC}"
    echo -e "${YELLOW}2)${NC} Add Roles to Existing Users"
    echo "    Pick ClusterRoleBindings for users already on the cluster"
    echo ""
    echo -e "${YELLOW}3)${NC} View User Role Bindings"
    echo "    Show all ClusterRoleBindings for a specific user"
    echo ""
    echo -e "${YELLOW}4)${NC} Remove User Role Bindings ${RED}[Destructive]${NC}"
    echo "    Selectively remove ClusterRoleBindings from a user"
    echo ""
    echo -e "${MAGENTA}Workshop:${NC}"
    echo -e "${YELLOW}5)${NC} Workshop Users (legacy)"
    echo "    Create workshop users with htpasswd + secret-reader RBAC"
    echo ""
    echo -e "${YELLOW}0)${NC} Back"
    echo ""
}

user_management_menu() {
    while true; do
        show_user_management_menu
        read -p "Select an option (0-5): " choice

        case $choice in
            1)
                manage_users_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                add_roles_interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                list_user_bindings
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                remove_user_bindings
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                echo ""
                read -p "Number of users [150]: " user_count
                user_count=${user_count:-150}
                setup_workshop_users "$user_count"
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
