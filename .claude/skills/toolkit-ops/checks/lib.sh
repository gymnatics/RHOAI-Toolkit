#!/bin/bash
################################################################################
# toolkit-ops check library (sourced by every check-*.sh)
#
# All checks are READ-ONLY: they only run `oc get/describe/auth can-i/exec ls|env|curl`.
# Anything that mutates the cluster lives behind an explicit flag documented in SKILL.md.
#
# Result model: record <area> <id> <PASS|WARN|FAIL|SKIP|INFO> <message> [hint]
#   - printed as a coloured line
#   - appended to $TOOLKIT_OPS_RESULTS (TSV) so a run of several scripts can be summarised
#   - `ops_summary` prints totals (and JSON with --json) and returns 1 if any FAIL
################################################################################

_OPS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPS_SKILL_DIR="$(cd "$_OPS_LIB_DIR/.." && pwd)"
OPS_ROOT_DIR="$(cd "$_OPS_LIB_DIR/../../../.." && pwd)"

# shellcheck source=/dev/null
source "$OPS_ROOT_DIR/lib/utils/colors.sh"
# shellcheck source=/dev/null
source "$OPS_ROOT_DIR/lib/utils/os-compat.sh"
# shellcheck source=/dev/null
source "$OPS_ROOT_DIR/lib/utils/rhoai-version.sh"

: "${TOOLKIT_OPS_RESULTS:=$(mktemp "${TMPDIR:-/tmp}/toolkit-ops.XXXXXX")}"
export TOOLKIT_OPS_RESULTS
OPS_JSON=false
OPS_QUIET=false
OPS_TIMEOUT="${OPS_TIMEOUT:-30}"

# Parse the flags every check script accepts; leaves the rest in OPS_ARGS.
ops_parse_common_flags() {
    OPS_ARGS=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            --json) OPS_JSON=true; OPS_QUIET=true; shift ;;
            --quiet) OPS_QUIET=true; shift ;;
            --timeout) OPS_TIMEOUT="$2"; shift 2 ;;
            *) OPS_ARGS+=("$1"); shift ;;
        esac
    done
}

# oc with a timeout; never prompts.
k() {
    timeout_cmd "$OPS_TIMEOUT" oc "$@" 2>/dev/null </dev/null
}

# k get ... -o json | jq -r <filter>, empty string on failure
kjq() {
    local filter="$1"; shift
    k get "$@" -o json | jq -r "$filter" 2>/dev/null
}

record() {
    local area="$1" id="$2" status="$3" msg="$4" hint="${5:-}"
    printf '%s\t%s\t%s\t%s\t%s\n' "$area" "$id" "$status" "${msg//$'\t'/ }" "${hint//$'\t'/ }" >> "$TOOLKIT_OPS_RESULTS"
    $OPS_QUIET && return 0
    local color
    case "$status" in
        PASS) color="$GREEN" ;;
        WARN) color="$YELLOW" ;;
        FAIL) color="$RED" ;;
        INFO) color="$CYAN" ;;
        *)    color="$BLUE" ;;
    esac
    echo -e "  ${color}[$status]${NC} ${area}/${id}: ${msg}"
    if [ -n "$hint" ] && [ "$status" != "PASS" ]; then
        echo -e "         ${BLUE}-> ${hint}${NC}"
    fi
}

ops_section() {
    $OPS_QUIET || print_header "$1"
}

# Version comparison: ver_ge 4.21 4.20 -> true
ver_ge() {
    [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]
}

# Cluster facts, cached for the run
ops_require_cluster() {
    if ! command -v oc >/dev/null 2>&1; then
        record infra oc-cli FAIL "oc CLI not found" "Install the OpenShift CLI"
        return 1
    fi
    if ! k whoami >/dev/null; then
        record infra cluster-reachable FAIL "Cannot reach the cluster API (oc whoami failed)" \
            "Check KUBECONFIG (scripts/manage-kubeconfig.sh) and that the cluster is running (scripts/manage-gpu-nodes.sh status / restart-cluster-instances.sh)"
        return 1
    fi
    OCP_VERSION="$(kjq '.status.desired.version // empty' clusterversion version)"
    OCP_MINOR="$(echo "$OCP_VERSION" | cut -d. -f1-2)"
    detect_rhoai_version >/dev/null 2>&1 || true
    RHOAI_MM="${RHOAI_MAJOR_VERSION:-0}.${RHOAI_MINOR_VERSION:-0}"
    RHOAI_CSV_VERSION="$(kjq '[.items[] | select(.metadata.name|startswith("rhods-operator"))][0].spec.version // empty' csv -n redhat-ods-operator)"
    export OCP_VERSION OCP_MINOR RHOAI_MM RHOAI_CSV_VERSION
    return 0
}

# Print totals for the current results file. Returns 1 if any FAIL.
ops_summary() {
    local f="$TOOLKIT_OPS_RESULTS"
    local pass warn fail skip
    pass=$(awk -F'\t' '$3=="PASS"' "$f" | wc -l | tr -d ' ')
    warn=$(awk -F'\t' '$3=="WARN"' "$f" | wc -l | tr -d ' ')
    fail=$(awk -F'\t' '$3=="FAIL"' "$f" | wc -l | tr -d ' ')
    skip=$(awk -F'\t' '$3=="SKIP"' "$f" | wc -l | tr -d ' ')
    if $OPS_JSON; then
        jq -R -s --arg ocp "${OCP_VERSION:-}" --arg rhoai "${RHOAI_CSV_VERSION:-$RHOAI_MM}" '
          split("\n") | map(select(length>0) | split("\t")
            | {area:.[0], id:.[1], status:.[2], message:.[3], hint:(.[4] // "")})
          | {ocp_version:$ocp, rhoai_version:$rhoai,
             totals:(group_by(.status) | map({(.[0].status): length}) | add // {}),
             results:.}' "$f"
    else
        echo ""
        echo -e "Summary: ${GREEN}${pass} PASS${NC}  ${YELLOW}${warn} WARN${NC}  ${RED}${fail} FAIL${NC}  ${BLUE}${skip} SKIP${NC}   (results: $f)"
        if [ "$fail" -gt 0 ]; then
            echo -e "${RED}Failures:${NC}"
            awk -F'\t' '$3=="FAIL"{printf "  - %s/%s: %s\n", $1, $2, $4}' "$f"
        fi
    fi
    [ "$fail" -eq 0 ]
}
