#!/bin/bash
################################################################################
# MaaS Demo Launcher
################################################################################
# This script launches the Streamlit MaaS demo with auto-configuration.
#
# Features:
# - Auto-detects cluster settings if logged in via oc
# - Pre-generates API token
# - Sets environment variables for the Streamlit app
#
# Usage:
#   ./run-demo.sh                    # Auto-detect everything
#   ./run-demo.sh --no-auto          # Manual configuration
#   ./run-demo.sh --namespace myns   # Specify namespace
#   ./run-demo.sh --model mymodel    # Specify model
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
AUTO_DETECT=true
NAMESPACE=""
MODEL=""
GENERATE_TOKEN=true
PORT=8501

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-auto)
            AUTO_DETECT=false
            shift
            ;;
        --namespace|-n)
            NAMESPACE="$2"
            shift 2
            ;;
        --model|-m)
            MODEL="$2"
            shift 2
            ;;
        --no-token)
            GENERATE_TOKEN=false
            shift
            ;;
        --port|-p)
            PORT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --no-auto         Disable auto-detection"
            echo "  --namespace, -n   Specify namespace"
            echo "  --model, -m       Specify model name"
            echo "  --no-token        Don't generate token"
            echo "  --port, -p        Streamlit port (default: 8501)"
            echo "  --help, -h        Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  MaaS Demo Launcher                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for Python and Streamlit
if ! command -v python3 &>/dev/null; then
    echo -e "${RED}✗ Python3 not found${NC}"
    exit 1
fi

if ! python3 -c "import streamlit" &>/dev/null; then
    echo -e "${YELLOW}⚠ Streamlit not installed. Installing...${NC}"
    pip install -r "$SCRIPT_DIR/requirements.txt"
fi

# Auto-detect settings if enabled
if [ "$AUTO_DETECT" = true ]; then
    echo -e "${CYAN}▶ Auto-detecting cluster settings...${NC}"
    
    # Check if oc is available and logged in
    if command -v oc &>/dev/null; then
        if oc whoami &>/dev/null; then
            echo -e "${GREEN}✓ Logged in to OpenShift${NC}"
            
            # Get cluster domain
            CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
            if [ -n "$CLUSTER_DOMAIN" ]; then
                export MAAS_ENDPOINT="inference-gateway.${CLUSTER_DOMAIN}"
                echo -e "${GREEN}✓ Endpoint: ${MAAS_ENDPOINT}${NC}"
            fi
            
            # Get RHOAI version
            RHOAI_VERSION=$(oc get csv -n redhat-ods-operator -o jsonpath='{.items[0].spec.version}' 2>/dev/null)
            if [ -n "$RHOAI_VERSION" ]; then
                echo -e "${GREEN}✓ RHOAI Version: ${RHOAI_VERSION}${NC}"
            fi
            
            # Find models if namespace not specified
            if [ -z "$NAMESPACE" ]; then
                echo -e "${CYAN}▶ Searching for deployed models...${NC}"
                
                # Get first ready LLMInferenceService
                MODELS=$(oc get llminferenceservice -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}/{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null)
                
                while IFS= read -r line; do
                    if [ -n "$line" ]; then
                        IFS='/' read -r ns name ready <<< "$line"
                        if [ "$ready" = "True" ]; then
                            NAMESPACE="$ns"
                            MODEL="$name"
                            echo -e "${GREEN}✓ Found ready model: ${ns}/${name}${NC}"
                            break
                        fi
                    fi
                done <<< "$MODELS"
                
                if [ -z "$NAMESPACE" ]; then
                    echo -e "${YELLOW}⚠ No ready models found${NC}"
                fi
            fi
            
            # Generate token if namespace is set
            if [ "$GENERATE_TOKEN" = true ] && [ -n "$NAMESPACE" ]; then
                echo -e "${CYAN}▶ Generating API token...${NC}"
                
                TOKEN=$(oc create token default -n "$NAMESPACE" --duration=1h --audience=https://kubernetes.default.svc 2>/dev/null)
                if [ -n "$TOKEN" ]; then
                    export MAAS_TOKEN="$TOKEN"
                    echo -e "${GREEN}✓ Token generated (valid for 1 hour)${NC}"
                else
                    echo -e "${YELLOW}⚠ Failed to generate token${NC}"
                fi
            fi
        else
            echo -e "${YELLOW}⚠ Not logged in to OpenShift. Run: oc login${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ oc CLI not found. Manual configuration required.${NC}"
    fi
fi

# Set environment variables
if [ -n "$NAMESPACE" ]; then
    export MAAS_NAMESPACE="$NAMESPACE"
fi
if [ -n "$MODEL" ]; then
    export MAAS_MODEL="$MODEL"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Configuration:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Endpoint:  ${GREEN}${MAAS_ENDPOINT:-Not set}${NC}"
echo -e "  Namespace: ${GREEN}${MAAS_NAMESPACE:-Not set}${NC}"
echo -e "  Model:     ${GREEN}${MAAS_MODEL:-Not set}${NC}"
echo -e "  Token:     ${GREEN}$([ -n "$MAAS_TOKEN" ] && echo "Generated" || echo "Not set")${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}▶ Starting Streamlit app on port ${PORT}...${NC}"
echo -e "${CYAN}  Open: http://localhost:${PORT}${NC}"
echo ""

# Run Streamlit
cd "$SCRIPT_DIR"
python3 -m streamlit run app.py --server.port "$PORT" --server.headless true
