#!/bin/bash
################################################################################
# workshop.sh — Workshop Demo Setup menu for rhoai-toolkit.sh
################################################################################

_WORKSHOP_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

show_workshop_setup_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          Workshop Demo Setup (RHOAI 3.4 + OpenWebUI)           ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}This sets up a complete workshop environment including:${NC}"
    echo "  • RHOAI 3.4 installation (NFD, GPU Operator, dependencies)"
    echo "  • GPU hardware profile and MachineSet creation"
    echo "  • Worker node scaling"
    echo "  • Workshop users (htpasswd authentication)"
    echo "  • User workload monitoring (Prometheus)"
    echo "  • Grafana with pre-configured dashboards"
    echo "  • Admin model deployment (qwen3-4b with tool calling)"
    echo "  • Kubernetes MCP Server (tool calling)"
    echo ""
    echo -e "${CYAN}Participants deploy OpenWebUI in their own namespaces.${NC}"
    echo ""
    echo -e "${MAGENTA}Workshop Guide:${NC} https://github.com/gymnatics/Red-Hat-Inference-Workshop"
    echo ""
    echo -e "${YELLOW}1)${NC} Complete Workshop Setup ${GREEN}[Full - Recommended]${NC}"
    echo "    Install everything from scratch"
    echo ""
    echo -e "${YELLOW}2)${NC} Workshop Setup (RHOAI already installed)"
    echo "    Skip RHOAI installation, set up workshop components only"
    echo ""
    echo -e "${YELLOW}3)${NC} Add Workshop Users Only"
    echo "    Create htpasswd users and RBAC"
    echo ""
    echo -e "${YELLOW}4)${NC} Deploy Admin Model + MCP Server"
    echo "    Deploy qwen3-4b (tool calling) + Kubernetes MCP server + AI Asset registration"
    echo ""
    echo -e "${YELLOW}5)${NC} Deploy MCP Server Only"
    echo "    Deploy Kubernetes MCP server + register in AI Asset endpoints (model already deployed)"
    echo ""
    echo -e "${YELLOW}6)${NC} Setup Grafana and Dashboards Only"
    echo "    Deploy Grafana with vLLM and DCGM dashboards"
    echo ""
    echo -e "${YELLOW}7)${NC} Enable User Workload Monitoring Only"
    echo "    Enable Prometheus UWM and vLLM metrics"
    echo ""
    echo -e "${YELLOW}8)${NC} Install Web Terminal Only"
    echo "    In-browser terminal for workshop participants"
    echo ""
    echo -e "${YELLOW}9)${NC} Disable vLLM on MaaS (Tech Preview)"
    echo "    Turn off vLLM MaaS runtime to avoid workshop confusion"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to Main Menu"
    echo ""
}

workshop_setup_menu() {
    while true; do
        show_workshop_setup_menu
        read -p "Select an option (0-9): " choice
        
        case $choice in
            1)
                echo ""
                read -p "Number of users [150]: " user_count
                user_count=${user_count:-150}
                read -p "GPU instance type (g6e.xlarge/g6e.2xlarge) [g6e.xlarge]: " gpu_instance
                gpu_instance=${gpu_instance:-g6e.xlarge}
                
                local max_gpu=64
                if [ "$gpu_instance" == "g6e.2xlarge" ]; then
                    max_gpu=32
                fi
                read -p "Number of GPU nodes (max $max_gpu) [$max_gpu]: " gpu_count
                gpu_count=${gpu_count:-$max_gpu}
                
                read -p "Number of worker nodes [12]: " worker_count
                worker_count=${worker_count:-12}
                
                run_complete_workshop_setup "$user_count" "$gpu_instance" "$gpu_count" "$worker_count"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                echo ""
                read -p "Number of users [150]: " user_count
                user_count=${user_count:-150}

                print_step "Creating GPU hardware profile..."
                oc apply -f "$_WORKSHOP_MENU_DIR/lib/manifests/rhoai/hardware-profile-gpu.yaml" 2>/dev/null || true

                install_web_terminal
                disable_vllm_on_maas
                setup_user_workload_monitoring
                setup_workshop_users "$user_count"
                setup_workshop_grafana
                setup_workshop_model_and_mcp "$user_count"
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                echo ""
                read -p "Number of users [150]: " user_count
                user_count=${user_count:-150}
                setup_workshop_users "$user_count"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                echo ""
                read -p "Number of users [25]: " user_count
                user_count=${user_count:-25}
                setup_workshop_model_and_mcp "$user_count"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                echo ""
                read -p "Namespace [admin-workshop]: " ns
                ns=${ns:-admin-workshop}
                setup_workshop_mcp_only "$ns"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                setup_workshop_grafana
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                setup_user_workload_monitoring
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                install_web_terminal
                echo ""
                read -p "Press Enter to continue..."
                ;;
            9)
                disable_vllm_on_maas
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
