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
    echo -e "${MAGENTA}Restricted Access:${NC}"
    echo -e "${YELLOW}6)${NC} Create Restricted Client Admin ${GREEN}[New]${NC}"
    echo "    Real cluster-admin for a client, except Machine API/node-count"
    echo "    mutations and Node deletion (admission-layer deny policy)"
    echo ""
    echo -e "${YELLOW}0)${NC} Back"
    echo ""
}

user_management_menu() {
    while true; do
        show_user_management_menu
        read -p "Select an option (0-6): " choice

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
            6)
                echo ""
                print_header "Create Restricted Client Admin"
                echo -e "${CYAN}Grants a client a real cluster-admin ClusterRoleBinding, but blocks${NC}"
                echo -e "${CYAN}Machine API / autoscaler mutations and Node deletion via an${NC}"
                echo -e "${CYAN}admission-layer ValidatingAdmissionPolicy. See:${NC}"
                echo -e "${CYAN}docs/guides/RESTRICTED-CLIENT-ADMIN-ACCESS.md${NC}"
                echo ""
                read -p "Client username: " rca_user
                if [ -z "$rca_user" ]; then
                    print_error "Client username is required"
                else
                    read -s -p "Client password (leave blank to auto-generate): " rca_pass
                    echo ""
                    if [ -z "$rca_pass" ]; then
                        rca_pass=$(head -c 16 /dev/urandom 2>/dev/null | base64 | tr -dc 'a-zA-Z0-9' | head -c 16)
                        print_info "Generated password: $rca_pass"
                    fi
                    read -p "Owner/break-glass username [$(oc whoami 2>/dev/null)]: " rca_owner
                    local rca_args=(--client-user "$rca_user" --client-password "$rca_pass")
                    [ -n "$rca_owner" ] && rca_args+=(--owner-user "$rca_owner")
                    bash "$_USERS_MENU_DIR/scripts/create-restricted-client-admin.sh" "${rca_args[@]}"
                fi
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
