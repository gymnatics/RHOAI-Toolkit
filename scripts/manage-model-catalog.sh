#!/bin/bash
################################################################################
# Manage Model Catalog (Interactive CLI)
################################################################################
# Add, remove, list, and rename entries in the RHOAI Model Catalog.
#
# Usage:
#   ./manage-model-catalog.sh              # Interactive menu
#   ./manage-model-catalog.sh list         # List entries
#   ./manage-model-catalog.sh add          # Add a model
#   ./manage-model-catalog.sh remove       # Remove a model
#   ./manage-model-catalog.sh rename       # Rename catalog
#   ./manage-model-catalog.sh add-from-registry  # Add from Model Registry
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/functions/model-catalog.sh"

ACTION="${1:-}"

show_menu() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║               Model Catalog Management                       ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${YELLOW}1)${NC} List catalog entries"
    echo -e "  ${YELLOW}2)${NC} Add model to catalog"
    echo -e "  ${YELLOW}3)${NC} Remove model from catalog"
    echo -e "  ${YELLOW}4)${NC} Add model from Model Registry"
    echo -e "  ${YELLOW}5)${NC} Rename catalog"
    echo -e "  ${YELLOW}6)${NC} Apply changes (restart pods)"
    echo -e "  ${YELLOW}0)${NC} Exit"
    echo ""
}

handle_action() {
    case "$1" in
        list|1) catalog_list ;;
        add|2) catalog_add ;;
        remove|3) catalog_remove ;;
        add-from-registry|4) catalog_add_from_registry ;;
        rename|5) catalog_rename ;;
        apply|6) catalog_apply ;;
        0) exit 0 ;;
        *) print_error "Unknown action: $1" ;;
    esac
}

if [ -n "$ACTION" ]; then
    handle_action "$ACTION"
    exit 0
fi

while true; do
    show_menu
    read -rp "Select option: " choice
    handle_action "$choice"
done
