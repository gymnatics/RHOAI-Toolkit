#!/bin/bash
################################################################################
# Deploy the AI Governance Demo (separate repo: ai-governance-demo)
################################################################################
# Clones (or updates) the ai-governance-demo repo and runs its setup against the
# cluster you are logged into: MaaS per-app access, quotas, chargeback, budget
# alerts, NeMo Guardrails (PII masking, prompt injection), MLflow audit trail,
# workbench with notebooks, interactive run sheet.
#
# Usage:
#   ./deploy.sh                                  # clone + setup (namespace ai-governance-demo)
#   ./deploy.sh -n my-ns                         # custom demo namespace (DEMO_NS)
#   ./deploy.sh --dir ~/src/ai-governance-demo   # where to clone (default: $HOME/ai-governance-demo)
#   ./deploy.sh --gpu-nodes 2 --with-loki        # extra flags are passed to scripts/setup.sh
#   ./deploy.sh --verify                         # run the demo health check only
#   ./deploy.sh --delete                         # teardown (restores cluster-wide settings)
#
# Repo: --repo or AIGOV_DEMO_REPO (default github.com/gymnatics/rhoai-ai-governance-demo, private).
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"

REPO_URL="${AIGOV_DEMO_REPO:-https://github.com/gymnatics/rhoai-ai-governance-demo.git}"
DEST="${AIGOV_DEMO_DIR:-$HOME/ai-governance-demo}"
NAMESPACE=""
MODE=setup
SETUP_ARGS=(--with-workbench)
# Positional namespace still works (./deploy.sh my-ns); a leading flag is not a namespace
[[ -n "${1:-}" && "${1:-}" != -* ]] && { NAMESPACE="$1"; shift; }

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --repo) REPO_URL="$2"; shift 2 ;;
        --dir) DEST="$2"; shift 2 ;;
        --delete) MODE=teardown; shift ;;
        --verify) MODE=verify; shift ;;
        --no-workbench) SETUP_ARGS=("${SETUP_ARGS[@]/--with-workbench}"); shift ;;
        -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) SETUP_ARGS+=("$1"); shift ;;
    esac
done

print_header "AI Governance Demo"
command -v git >/dev/null || { print_error "git is required"; exit 1; }
command -v envsubst >/dev/null || { print_error "envsubst is required (gettext)"; exit 1; }
oc whoami >/dev/null 2>&1 || { print_error "Not logged in to OpenShift (oc login first)"; exit 1; }

if [ -d "$DEST/.git" ]; then
    if git -C "$DEST" remote get-url origin >/dev/null 2>&1; then
        print_step "Updating $DEST"
        git -C "$DEST" pull --ff-only || print_warning "git pull failed; using the existing checkout"
    else
        print_info "Using local checkout $DEST (no remote configured)"
    fi
elif [ -n "$REPO_URL" ]; then
    print_step "Cloning $REPO_URL -> $DEST"
    git clone "$REPO_URL" "$DEST"
else
    print_error "No checkout at $DEST and no repo URL. Use --repo <git-url> or export AIGOV_DEMO_REPO."
    exit 1
fi

export TOOLKIT_DIR="$ROOT_DIR"
[ -n "$NAMESPACE" ] && export DEMO_NS="$NAMESPACE"

case $MODE in
    setup)    bash "$DEST/scripts/setup.sh" "${SETUP_ARGS[@]}" ;;
    verify)   bash "$DEST/scripts/verify.sh" ;;
    teardown) bash "$DEST/scripts/teardown.sh" ;;
esac
