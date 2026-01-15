#!/bin/bash
################################################################################
# Quick GPU Hardware Profile Creation
################################################################################
# Creates pre-configured GPU hardware profiles with recommended defaults
#
# Usage:
#   ./scripts/create-hardware-profile-quick.sh [namespace]
#   ./scripts/create-hardware-profile-quick.sh demo
#   ./scripts/create-hardware-profile-quick.sh --all demo
#
# Options:
#   --all    Create all profile sizes (small, medium, large)
#
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../lib/manifests/templates"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

# Parse arguments
CREATE_ALL=false
NAMESPACE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            CREATE_ALL=true
            shift
            ;;
        *)
            NAMESPACE="$1"
            shift
            ;;
    esac
done

print_header "Quick GPU Hardware Profile Setup"

# Check login
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift"
    exit 1
fi

# Get namespace
if [ -z "$NAMESPACE" ]; then
    NAMESPACE=$(oc project -q 2>/dev/null || echo "")
    if [ -z "$NAMESPACE" ]; then
        read -p "Enter target namespace: " NAMESPACE
    fi
fi

# Verify namespace exists
if ! oc get namespace "$NAMESPACE" &>/dev/null; then
    print_error "Namespace '$NAMESPACE' does not exist"
    exit 1
fi

echo -e "Target namespace: ${YELLOW}$NAMESPACE${NC}"
echo ""

if [ "$CREATE_ALL" = true ]; then
    # Create all profiles
    echo "Creating all GPU hardware profiles..."
    echo ""
    
    for size in small medium large; do
        template="$TEMPLATE_DIR/hardwareprofile-gpu-${size}.yaml.tmpl"
        if [ -f "$template" ]; then
            export NAMESPACE
            envsubst < "$template" | oc apply -f -
            print_success "Created gpu-${size} profile"
        fi
    done
else
    # Interactive selection
    echo -e "${CYAN}Select GPU Hardware Profile Size:${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} Small  - For 4B-8B models (Qwen3-4B, Llama-3-8B)"
    echo "         CPU: 2 (max 8) | Memory: 8Gi (max 24Gi) | GPU: 1"
    echo "         Best for: g6e.xlarge, g6e.2xlarge"
    echo ""
    echo -e "${YELLOW}2)${NC} Medium - For 8B-30B models (Llama-3-70B quantized, Qwen-14B)"
    echo "         CPU: 4 (max 16) | Memory: 32Gi (max 64Gi) | GPU: 1"
    echo "         Best for: g6e.4xlarge, g6e.8xlarge"
    echo ""
    echo -e "${YELLOW}3)${NC} Large  - For 70B+ models, multi-GPU (Llama-3-70B, Mixtral)"
    echo "         CPU: 16 (max 96) | Memory: 128Gi (max 512Gi) | GPU: 4 (max 8)"
    echo "         Best for: p5.48xlarge, g6e.48xlarge"
    echo ""
    echo -e "${YELLOW}4)${NC} All    - Create all three profiles"
    echo ""
    
    read -p "Select option (1-4): " choice
    
    case $choice in
        1)
            template="$TEMPLATE_DIR/hardwareprofile-gpu-small.yaml.tmpl"
            profile_name="gpu-small"
            ;;
        2)
            template="$TEMPLATE_DIR/hardwareprofile-gpu-medium.yaml.tmpl"
            profile_name="gpu-medium"
            ;;
        3)
            template="$TEMPLATE_DIR/hardwareprofile-gpu-large.yaml.tmpl"
            profile_name="gpu-large"
            ;;
        4)
            for size in small medium large; do
                template="$TEMPLATE_DIR/hardwareprofile-gpu-${size}.yaml.tmpl"
                if [ -f "$template" ]; then
                    export NAMESPACE
                    envsubst < "$template" | oc apply -f -
                    print_success "Created gpu-${size} profile"
                fi
            done
            echo ""
            print_success "All GPU hardware profiles created in $NAMESPACE"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    if [ -f "$template" ]; then
        export NAMESPACE
        envsubst < "$template" | oc apply -f -
        print_success "Created $profile_name profile in $NAMESPACE"
    else
        print_error "Template not found: $template"
        exit 1
    fi
fi

echo ""
print_header "Hardware Profiles Created"

oc get hardwareprofile -n "$NAMESPACE" 2>/dev/null || echo "No profiles found"

echo ""
print_info "Use these profiles when deploying models in the RHOAI dashboard"
print_info "Or reference them in InferenceService annotations:"
echo "    opendatahub.io/hardware-profile-name: gpu-small"
echo "    opendatahub.io/hardware-profile-namespace: $NAMESPACE"
