#!/bin/bash
################################################################################
# workshop.sh — Workshop Demo Setup menu for rhoai-toolkit.sh
################################################################################

_WORKSHOP_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

show_workshop_setup_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         Workshop Demo Setup (RHOAI 2.25 + GenAI Workshop)      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}This sets up a complete workshop environment including:${NC}"
    echo "  • RHOAI 2.25 installation (NFD, GPU Operator, dependencies)"
    echo "  • GPU MachineSet creation"
    echo "  • Worker node scaling"
    echo "  • Workshop users (htpasswd authentication)"
    echo "  • User workload monitoring (Prometheus)"
    echo "  • Grafana with pre-configured dashboards"
    echo "  • Admin model deployment (qwen3-4b)"
    echo "  • LlamaStack and MCP Server"
    echo "  • AnythingLLM workbench image"
    echo ""
    echo -e "${MAGENTA}Workshop Guide:${NC} https://github.com/cbtham/rhoai-genai-workshop"
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
    echo -e "${YELLOW}4)${NC} Deploy Admin Model and MCP Server Only"
    echo "    Deploy qwen3-4b, LlamaStack, MCP server"
    echo ""
    echo -e "${YELLOW}5)${NC} Setup Grafana and Dashboards Only"
    echo "    Deploy Grafana with vLLM and DCGM dashboards"
    echo ""
    echo -e "${YELLOW}6)${NC} Enable User Workload Monitoring Only"
    echo "    Enable Prometheus UWM and vLLM metrics"
    echo ""
    echo -e "${YELLOW}0)${NC} Back to Main Menu"
    echo ""
}

workshop_setup_menu() {
    while true; do
        show_workshop_setup_menu
        read -p "Select an option (0-6): " choice
        
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
                
                setup_user_workload_monitoring
                setup_workshop_users "$user_count"
                setup_workshop_grafana
                setup_workshop_model_and_mcp
                
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
                setup_workshop_model_and_mcp
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                setup_workshop_grafana
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                setup_user_workload_monitoring
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
