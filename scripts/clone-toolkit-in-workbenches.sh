#!/bin/bash
################################################################################
# clone-toolkit-in-workbenches.sh — Retry/recover the RHOAI-Toolkit git clone
# in demo workbenches whose pods weren't Running yet when their deploy.sh's
# ensure_workbench() call ran (most commonly GPU workbenches waiting on a
# GPU node to provision -- see lib/functions/workbench.sh).
################################################################################
# Usage:
#   ./scripts/clone-toolkit-in-workbenches.sh              # all known demo namespaces
#   ./scripts/clone-toolkit-in-workbenches.sh -n NS1,NS2   # specific namespace(s)
#   ./scripts/clone-toolkit-in-workbenches.sh --all-ns     # discover Notebook CRs cluster-wide
#
# Safe to run repeatedly -- clone_if_missing() is a no-op if the repo is
# already cloned, and just reports "not Running yet" (not an error) if the
# workbench pod still isn't up.
################################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
}
source "$ROOT_DIR/lib/functions/workbench.sh"

# Known demo namespaces that provision a workbench via ensure_workbench().
# Keep in sync with the demos listed in .cursor/rules/demo-apps.mdc. Feast's
# namespace is user-chosen at deploy time (see deploy_banking_demo() in
# lib/functions/rhoai.sh), so it's not included here by default -- pass it
# explicitly via -n, or use --all-ns to discover it automatically.
DEFAULT_NAMESPACES=(
    "financial-loan-demo"
    "lmeval-demo"
    "pipeline-demo"
    "maas-ratelimit-demo"
)

DISCOVER_ALL=false
NAMESPACES=()

usage() {
    echo "Usage: $0 [-n ns1,ns2,...] [--all-ns] [-h]"
    echo ""
    echo "  -n, --namespaces  Comma-separated list of namespaces to check (default:"
    echo "                    ${DEFAULT_NAMESPACES[*]})"
    echo "  --all-ns          Discover every namespace with a Notebook CR cluster-wide"
    echo "                    instead of using the default list"
    echo "  -h, --help        Show this help"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespaces)
            IFS=',' read -ra NAMESPACES <<< "$2"
            shift 2
            ;;
        --all-ns)
            DISCOVER_ALL=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

if ! oc whoami &>/dev/null; then
    echo -e "${RED}✗ Not logged in to OpenShift. Run: oc login <cluster-url>${NC}"
    exit 1
fi

if [ "$DISCOVER_ALL" = true ]; then
    print_step "Discovering namespaces with Notebook CRs cluster-wide..."
    NAMESPACES=()
    while IFS= read -r ns; do
        [ -n "$ns" ] && NAMESPACES+=("$ns")
    done < <(oc get notebooks -A --no-headers 2>/dev/null | awk '{print $1}' | sort -u)
elif [ ${#NAMESPACES[@]} -eq 0 ]; then
    NAMESPACES=("${DEFAULT_NAMESPACES[@]}")
fi

if [ ${#NAMESPACES[@]} -eq 0 ]; then
    print_warning "No namespaces to check."
    exit 0
fi

print_header "Retry RHOAI-Toolkit clone in demo workbenches"
print_info "Namespaces: ${NAMESPACES[*]}"
echo ""

cloned_count=0
skipped_count=0
notfound_count=0

for ns in "${NAMESPACES[@]}"; do
    if ! oc get namespace "$ns" &>/dev/null 2>&1; then
        print_info "[$ns] namespace not found -- skipping"
        notfound_count=$((notfound_count + 1))
        continue
    fi

    wb_names=$(oc get notebooks -n "$ns" --no-headers 2>/dev/null | awk '{print $1}')
    if [ -z "$wb_names" ]; then
        print_info "[$ns] no workbenches (Notebook CRs) found -- skipping"
        notfound_count=$((notfound_count + 1))
        continue
    fi

    while IFS= read -r wb_name; do
        [ -z "$wb_name" ] && continue
        print_step "[$ns/$wb_name] checking..."
        pod_name="${wb_name}-0"
        phase=$(oc get pod "$pod_name" -n "$ns" -o jsonpath='{.status.phase}' 2>/dev/null)

        if [ "$phase" != "Running" ]; then
            print_warning "[$ns/$wb_name] pod phase=${phase:-NotFound} -- not Running yet, skipping (re-run this script once it is)"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        already=$(oc exec "$pod_name" -c "$wb_name" -n "$ns" -- \
            bash -c "[ -d '${WORKBENCH_HOME}/${DEFAULT_REPO_DIR}/.git' ] && echo yes || echo no" 2>/dev/null)

        if clone_if_missing "$ns" "$wb_name"; then
            if [ "$already" = "yes" ]; then
                print_info "[$ns/$wb_name] already cloned"
            else
                print_success "[$ns/$wb_name] cloned RHOAI-Toolkit"
                cloned_count=$((cloned_count + 1))
            fi
        fi
    done <<< "$wb_names"
done

echo ""
print_header "Summary"
echo -e "  ${GREEN}Newly cloned:${NC}    $cloned_count"
echo -e "  ${YELLOW}Skipped (not Running):${NC} $skipped_count"
echo -e "  ${CYAN}No workbench found:${NC}   $notfound_count"
echo ""

if [ "$skipped_count" -gt 0 ]; then
    print_info "Some workbenches were still Pending. Re-run this script once they're Running:"
    print_info "  ./scripts/clone-toolkit-in-workbenches.sh -n ${NAMESPACES[*]// /,}"
fi
