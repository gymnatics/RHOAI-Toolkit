#!/bin/bash

################################################################################
# Kubeconfig Management Utility
################################################################################
# Helps manage kubeconfig files and KUBECONFIG environment variable
#
# Usage:
#   ./manage-kubeconfig.sh              # Interactive menu
#   ./manage-kubeconfig.sh --clear      # Clear KUBECONFIG
#   ./manage-kubeconfig.sh --show       # Show current config
#   ./manage-kubeconfig.sh --logout     # Logout from cluster

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                  Kubeconfig Manager                            ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

################################################################################
# Main Functions
################################################################################

show_current_config() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Current Configuration${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check KUBECONFIG environment variable
    if [ -n "$KUBECONFIG" ]; then
        print_info "KUBECONFIG environment variable is SET:"
        echo "  Path: $KUBECONFIG"
        echo ""
        
        if [ -f "$KUBECONFIG" ]; then
            print_success "File exists"
            
            # Show file info
            local file_size=$(ls -lh "$KUBECONFIG" | awk '{print $5}')
            local file_date=$(ls -l "$KUBECONFIG" | awk '{print $6, $7, $8}')
            echo "  Size: $file_size"
            echo "  Modified: $file_date"
        else
            print_warning "File does NOT exist at this path"
        fi
    else
        print_info "KUBECONFIG environment variable is NOT set"
        echo "  Using default: ~/.kube/config"
        
        if [ -f "$HOME/.kube/config" ]; then
            print_success "Default kubeconfig exists"
        else
            print_warning "Default kubeconfig does not exist"
        fi
    fi
    
    echo ""
    
    # Check if logged in
    if oc whoami &>/dev/null; then
        print_success "Connected to OpenShift cluster"
        echo ""
        
        local cluster_url=$(oc whoami --show-server 2>/dev/null || echo "unknown")
        local cluster_user=$(oc whoami 2>/dev/null || echo "unknown")
        local cluster_context=$(oc config current-context 2>/dev/null || echo "unknown")
        
        echo "  Server:  $cluster_url"
        echo "  User:    $cluster_user"
        echo "  Context: $cluster_context"
        echo ""
        
        # Show cluster version
        local cluster_version=$(oc version --short 2>/dev/null | grep "Server" | awk '{print $3}' || echo "unknown")
        echo "  OpenShift Version: $cluster_version"
    else
        print_warning "Not currently logged in to any cluster"
    fi
    
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

clear_kubeconfig() {
    print_header
    echo -e "${YELLOW}This will clear your kubeconfig configuration${NC}"
    echo ""
    
    show_current_config
    
    echo ""
    echo -e "${YELLOW}What would you like to do?${NC}"
    echo ""
    echo "  1) Clear KUBECONFIG environment variable only"
    echo "  2) Clear KUBECONFIG and remove the file"
    echo "  3) Remove default kubeconfig (~/.kube/config)"
    echo "  4) Clear KUBECONFIG and remove from shell profile"
    echo "  5) Cancel"
    echo ""
    
    read -p "$(echo -e ${BLUE}Select option [1-5]${NC}: )" choice
    
    case $choice in
        1)
            if [ -n "$KUBECONFIG" ]; then
                echo ""
                print_info "Clearing KUBECONFIG environment variable..."
                export KUBECONFIG=""
                unset KUBECONFIG
                print_success "KUBECONFIG cleared for this session"
                echo ""
                print_warning "Note: This only affects the current shell session"
                print_info "To persist, remove KUBECONFIG from your shell profile"
            else
                print_warning "KUBECONFIG is not set"
            fi
            ;;
        2)
            if [ -n "$KUBECONFIG" ]; then
                echo ""
                print_warning "This will delete: $KUBECONFIG"
                read -p "$(echo -e ${YELLOW}Are you sure?${NC} [y/N]: )" confirm
                
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    if [ -f "$KUBECONFIG" ]; then
                        rm -f "$KUBECONFIG"
                        print_success "Removed file: $KUBECONFIG"
                    fi
                    
                    export KUBECONFIG=""
                    unset KUBECONFIG
                    print_success "KUBECONFIG cleared"
                else
                    print_info "Cancelled"
                fi
            else
                print_warning "KUBECONFIG is not set"
            fi
            ;;
        3)
            echo ""
            print_warning "This will delete: ~/.kube/config"
            read -p "$(echo -e ${YELLOW}Are you sure?${NC} [y/N]: )" confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if [ -f "$HOME/.kube/config" ]; then
                    # Backup first
                    cp "$HOME/.kube/config" "$HOME/.kube/config.backup.$(date +%Y%m%d-%H%M%S)"
                    print_info "Created backup: ~/.kube/config.backup.$(date +%Y%m%d-%H%M%S)"
                    
                    rm -f "$HOME/.kube/config"
                    print_success "Removed ~/.kube/config"
                else
                    print_warning "~/.kube/config does not exist"
                fi
            else
                print_info "Cancelled"
            fi
            ;;
        4)
            echo ""
            print_info "Checking shell profiles for KUBECONFIG..."
            echo ""
            
            local profiles=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile")
            local found=false
            
            for profile in "${profiles[@]}"; do
                if [ -f "$profile" ]; then
                    if grep -q "KUBECONFIG" "$profile" 2>/dev/null; then
                        echo -e "${YELLOW}Found in: $profile${NC}"
                        grep "KUBECONFIG" "$profile"
                        echo ""
                        found=true
                    fi
                fi
            done
            
            if [ "$found" = false ]; then
                print_info "No KUBECONFIG entries found in shell profiles"
            else
                echo ""
                print_warning "Manual action required:"
                echo "  Edit the file(s) above and remove KUBECONFIG exports"
                echo ""
                read -p "Do you want to open ~/.zshrc in nano? [y/N]: " open_editor
                if [[ "$open_editor" =~ ^[Yy]$ ]]; then
                    nano "$HOME/.zshrc"
                fi
            fi
            
            # Clear for current session
            if [ -n "$KUBECONFIG" ]; then
                export KUBECONFIG=""
                unset KUBECONFIG
                print_success "KUBECONFIG cleared for this session"
            fi
            ;;
        5)
            print_info "Cancelled"
            return 0
            ;;
        *)
            print_error "Invalid option"
            return 1
            ;;
    esac
    
    echo ""
}

logout_cluster() {
    print_header
    
    if ! oc whoami &>/dev/null; then
        print_warning "Not currently logged in to any cluster"
        return 0
    fi
    
    show_current_config
    
    echo ""
    read -p "$(echo -e ${YELLOW}Logout from this cluster?${NC} [y/N]: )" confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        print_info "Logging out..."
        
        # Remove current context
        local current_context=$(oc config current-context 2>/dev/null || echo "")
        if [ -n "$current_context" ]; then
            oc config delete-context "$current_context" &>/dev/null || true
            print_success "Logged out from cluster"
        fi
    else
        print_info "Cancelled"
    fi
    
    echo ""
}

set_kubeconfig() {
    print_header
    
    echo -e "${CYAN}Set Kubeconfig File${NC}"
    echo ""
    echo "This will set the KUBECONFIG environment variable to point to a specific file."
    echo ""
    
    # Look for kubeconfig files in workspace
    echo "Looking for kubeconfig files in workspace..."
    echo ""
    
    local kubeconfig_files=()
    while IFS= read -r -d '' file; do
        kubeconfig_files+=("$file")
    done < <(find "$WORKSPACE_DIR" -type f \( -name "kubeconfig" -o -name "*kubeconfig*" \) -not -path "*/.git/*" -print0 2>/dev/null)
    
    if [ ${#kubeconfig_files[@]} -gt 0 ]; then
        echo "Found kubeconfig files:"
        for i in "${!kubeconfig_files[@]}"; do
            echo "  $((i+1))) ${kubeconfig_files[$i]}"
        done
        echo "  $((${#kubeconfig_files[@]}+1))) Enter custom path"
        echo "  $((${#kubeconfig_files[@]}+2))) Cancel"
        echo ""
        
        read -p "$(echo -e ${BLUE}Select option${NC}: )" choice
        
        if [ "$choice" -le "${#kubeconfig_files[@]}" ] && [ "$choice" -gt 0 ]; then
            local selected_file="${kubeconfig_files[$((choice-1))]}"
            export KUBECONFIG="$selected_file"
            print_success "KUBECONFIG set to: $selected_file"
            echo ""
            print_warning "This only affects the current session"
            print_info "To persist, add to your shell profile:"
            echo "  export KUBECONFIG=\"$selected_file\""
        elif [ "$choice" -eq "$((${#kubeconfig_files[@]}+1))" ]; then
            read -p "$(echo -e ${BLUE}Enter kubeconfig file path${NC}: )" custom_path
            custom_path="${custom_path/#\~/$HOME}"
            
            if [ -f "$custom_path" ]; then
                export KUBECONFIG="$custom_path"
                print_success "KUBECONFIG set to: $custom_path"
            else
                print_error "File not found: $custom_path"
            fi
        else
            print_info "Cancelled"
        fi
    else
        echo "No kubeconfig files found in workspace"
        echo ""
        read -p "$(echo -e ${BLUE}Enter kubeconfig file path${NC}: )" custom_path
        custom_path="${custom_path/#\~/$HOME}"
        
        if [ -f "$custom_path" ]; then
            export KUBECONFIG="$custom_path"
            print_success "KUBECONFIG set to: $custom_path"
            echo ""
            print_warning "This only affects the current session"
            print_info "To persist, add to your shell profile:"
            echo "  export KUBECONFIG=\"$custom_path\""
        else
            print_error "File not found: $custom_path"
        fi
    fi
    
    echo ""
}

show_menu() {
    print_header
    
    echo -e "${CYAN}Kubeconfig Management${NC}"
    echo ""
    echo "  1) Show current configuration"
    echo "  2) Clear kubeconfig"
    echo "  3) Logout from cluster"
    echo "  4) Set kubeconfig file"
    echo "  5) Exit"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    # Handle command line arguments
    if [ "$#" -gt 0 ]; then
        case "$1" in
            --show|-s)
                show_current_config
                exit 0
                ;;
            --clear|-c)
                clear_kubeconfig
                exit 0
                ;;
            --logout|-l)
                logout_cluster
                exit 0
                ;;
            --set)
                set_kubeconfig
                exit 0
                ;;
            --help|-h)
                echo "Usage: $0 [OPTION]"
                echo ""
                echo "Options:"
                echo "  --show, -s      Show current kubeconfig configuration"
                echo "  --clear, -c     Clear kubeconfig (interactive)"
                echo "  --logout, -l    Logout from current cluster"
                echo "  --set           Set kubeconfig file path"
                echo "  --help, -h      Show this help message"
                echo ""
                echo "If no option is provided, the interactive menu will be shown."
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    fi
    
    # Interactive menu
    while true; do
        show_menu
        read -p "$(echo -e ${BLUE}Select option [1-5]${NC}: )" choice
        
        case $choice in
            1)
                show_current_config
                read -p "Press Enter to continue..."
                ;;
            2)
                clear_kubeconfig
                read -p "Press Enter to continue..."
                ;;
            3)
                logout_cluster
                read -p "Press Enter to continue..."
                ;;
            4)
                set_kubeconfig
                read -p "Press Enter to continue..."
                ;;
            5)
                echo ""
                print_info "Exiting..."
                echo ""
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-5."
                sleep 2
                ;;
        esac
        
        clear
    done
}

# Run main
main "$@"

