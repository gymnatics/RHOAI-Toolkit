#!/bin/bash
################################################################################
# Deploy Marketing Assistant Demo
################################################################################
# Multi-agent A2A campaign manager with TrustyAI guardrails.
# Requires 3x L40S GPUs (Qwen-Coder-32B, Qwen3-32B, FLUX.2-klein-4B).
#
# This is a standalone deployment -- NOT included in deploy-all due to
# heavy GPU requirements.
#
# Usage:
#   ./deploy.sh                    # Interactive deployment
#   ./deploy.sh --delete           # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/functions/external-repos.sh"

DELETE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --delete) DELETE_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--delete]"
            echo ""
            echo "Requires 3x L40S GPUs. Deploys:"
            echo "  - React Dashboard + Campaign API + Event Hub"
            echo "  - 5 A2A agents (Director, Creative, Analyst, Delivery, Guardian)"
            echo "  - 2 MCP servers (MongoDB, ImageGen)"
            echo "  - TrustyAI Guardrails (Regex, HAP, Prompt Injection)"
            echo "  - MLflow tracing stack"
            exit 0
            ;;
        *) shift ;;
    esac
done

print_header "Marketing Assistant Demo (Multi-Agent A2A)"

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

clone_or_update_repo "marketing-assistant"
REPO_PATH=$(get_repo_path "marketing-assistant")

if [ "$DELETE_MODE" = true ]; then
    print_step "Running cleanup from Marketing Assistant repo..."
    if [ -f "$REPO_PATH/reset-demo.sh" ]; then
        (cd "$REPO_PATH" && bash reset-demo.sh)
    fi
    print_success "Marketing Assistant demo cleaned up"
    exit 0
fi

print_warning "This demo requires 3x NVIDIA L40S GPUs (or equivalent 48GB VRAM each)"
print_info "Models needed: Qwen2.5-Coder-32B, Qwen3-32B, FLUX.2-klein-4B"
echo ""
read -rp "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

print_step "Launching Marketing Assistant deploy.sh..."
print_info "The repo's deploy script will auto-detect your cluster and models."
echo ""

(cd "$REPO_PATH" && bash deploy.sh)

echo ""
print_success "Marketing Assistant Demo deployment complete"
print_info "Repo: $REPO_PATH"
