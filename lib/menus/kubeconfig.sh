#!/bin/bash
################################################################################
# Kubeconfig Management Menu
# Delegates to scripts/manage-kubeconfig.sh (standalone implementation)
################################################################################

_KUBECONFIG_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

configure_kubeconfig_interactive() {
    if [ -f "$_KUBECONFIG_MENU_DIR/scripts/manage-kubeconfig.sh" ]; then
        "$_KUBECONFIG_MENU_DIR/scripts/manage-kubeconfig.sh"
    else
        print_error "scripts/manage-kubeconfig.sh not found"
        return 1
    fi
}
