#!/bin/bash
################################################################################
# RHOAI Installation Router
# Interactive version selection, then delegates to version-specific scripts.
# Can also be called with --version flag for non-interactive use.
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

RHOAI_VERSION=""
PASSTHROUGH_ARGS=()

# Parse --version, pass everything else through
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            RHOAI_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--version <3.4|3.3>] [OPTIONS...]"
            echo ""
            echo "Routes to the version-specific installation script."
            echo "All other options are passed through to the target script."
            echo ""
            echo "Versions:"
            echo "  3.4   RHOAI 3.4 (latest GA)"
            echo "  3.3   RHOAI 3.3"
            echo ""
            echo "Examples:"
            echo "  $0                                # Interactive version selection"
            echo "  $0 --version 3.4                  # Install RHOAI 3.4"
            echo "  $0 --version 3.3 --skip-rhcl      # Install RHOAI 3.3 without RHCL"
            exit 0
            ;;
        *)
            PASSTHROUGH_ARGS+=("$1")
            shift
            ;;
    esac
done

# Interactive version selection if not specified
if [ -z "$RHOAI_VERSION" ]; then
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              RHOAI Installation - Version Selection            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${YELLOW}1)${NC} RHOAI 3.4 ${GREEN}[Latest GA]${NC}"
    echo -e "     MaaS GA, MLflow GA, native vLLM multi-node"
    echo ""
    echo -e "  ${YELLOW}2)${NC} RHOAI 3.3"
    echo -e "     MaaS TP, MLflow TP, Kubeflow Trainer v2 GA"
    echo ""
    echo -e "  ${YELLOW}0)${NC} Cancel"
    echo ""

    while true; do
        read -p "Select version (1-2) [default: 1]: " choice
        choice=${choice:-1}
        case $choice in
            1) RHOAI_VERSION="3.4"; break ;;
            2) RHOAI_VERSION="3.3"; break ;;
            0) echo "Cancelled."; exit 0 ;;
            *) echo -e "${RED}Invalid selection.${NC}" ;;
        esac
    done
fi

# Route to version-specific script
case "$RHOAI_VERSION" in
    3.4)
        echo -e "${CYAN}▶ Launching RHOAI 3.4 installer...${NC}"
        exec "$SCRIPT_DIR/install-rhoai-34.sh" "${PASSTHROUGH_ARGS[@]}"
        ;;
    3.3)
        echo -e "${CYAN}▶ Launching RHOAI 3.3 installer...${NC}"
        exec "$SCRIPT_DIR/install-rhoai-33.sh" "${PASSTHROUGH_ARGS[@]}"
        ;;
    *)
        echo -e "${RED}Unsupported version: $RHOAI_VERSION${NC}"
        echo "Supported versions: 3.4, 3.3"
        exit 1
        ;;
esac
