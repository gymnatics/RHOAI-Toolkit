#!/bin/bash
################################################################################
# run-all.sh -- run toolkit-ops checks end to end (read-only unless --execute is passed through)
#
# Usage: run-all.sh [--phases infra,platform,serving,maas,demos,notebooks] [--demo NAME[,NAME]]
#                   [--execute] [--force] [--report FILE.md] [--json]
#   --phases   subset/order of phases (default: all, in the order above)
#   --demo     limit demos + notebooks phases to these demos
#   --execute  passed to check-notebooks.sh (RUNS NOTEBOOK CODE; ask the user first)
#   --report   also write a Markdown report (e.g. docs/test-reports/toolkit-ops-YYYY-MM-DD.md)
################################################################################
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$D/lib.sh"
ops_parse_common_flags "$@"
PHASES="infra,platform,serving,maas,demos,notebooks"; DEMO=""; NB_EXTRA=(); REPORT=""
set -- "${OPS_ARGS[@]}"
while [[ $# -gt 0 ]]; do
    case $1 in
        --phases) PHASES="$2"; shift 2 ;;
        --demo) DEMO="$2"; shift 2 ;;
        --execute|--force) NB_EXTRA+=("$1"); shift ;;
        --report) REPORT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

export TOOLKIT_OPS_RESULTS
quiet=(); $OPS_QUIET && quiet=(--quiet)
for phase in ${PHASES//,/ }; do
    args=("${quiet[@]}" --timeout "$OPS_TIMEOUT")
    case "$phase" in
        infra)     bash "$D/check-infra.sh" "${args[@]}" ;;
        platform)  bash "$D/check-platform.sh" "${args[@]}" ;;
        serving)   bash "$D/check-serving.sh" "${args[@]}" ;;
        maas)      bash "$D/check-maas.sh" "${args[@]}" ;;
        demos)     bash "$D/check-demos.sh" "${args[@]}" ${DEMO:+--demo "$DEMO"} ;;
        notebooks) bash "$D/check-notebooks.sh" "${args[@]}" ${DEMO:+--demo "$DEMO"} "${NB_EXTRA[@]}" ;;
        *) echo "unknown phase $phase" >&2 ;;
    esac >/dev/null 2>&1
    $OPS_QUIET || echo "  phase $phase done ($(wc -l < "$TOOLKIT_OPS_RESULTS" | tr -d ' ') results so far)"
    # Stop early if the cluster is unreachable: every later phase would fail the same way
    if awk -F'\t' '$2=="cluster-reachable" && $3=="FAIL"{f=1} END{exit !f}' "$TOOLKIT_OPS_RESULTS"; then
        echo -e "${RED}Cluster unreachable: stopping after $phase${NC}" >&2
        break
    fi
done

# Print everything once, grouped (scripts ran quiet into the shared results file)
if ! $OPS_QUIET; then
    awk -F'\t' -v R="$RED" -v G="$GREEN" -v Y="$YELLOW" -v B="$BLUE" -v C="$CYAN" -v N="$NC" '
      { col=($3=="PASS")?G:($3=="FAIL")?R:($3=="WARN")?Y:($3=="INFO")?C:B
        printf "  %s[%s]%s %s/%s: %s\n", col, $3, N, $1, $2, $4
        if ($5!="" && $3!="PASS") printf "         %s-> %s%s\n", B, $5, N }' "$TOOLKIT_OPS_RESULTS"
fi

# Cluster facts for the report/summary (skip if unreachable: already recorded)
if ! awk -F'\t' '$2=="cluster-reachable" && $3=="FAIL"{f=1} END{exit !f}' "$TOOLKIT_OPS_RESULTS"; then
    ops_require_cluster >/dev/null 2>&1 || true
fi

if [ -n "$REPORT" ]; then
    {
        echo "# toolkit-ops check report"
        echo ""
        echo "- Date: $(date '+%Y-%m-%d %H:%M %Z')"
        echo "- Cluster: $(k whoami --show-server 2>/dev/null) | OpenShift ${OCP_VERSION:-?} | RHOAI ${RHOAI_CSV_VERSION:-?}"
        echo "- Phases: $PHASES ${DEMO:+| demos: $DEMO}"
        echo ""
        for s in FAIL WARN PASS INFO SKIP; do
            n=$(awk -F'\t' -v s="$s" '$3==s' "$TOOLKIT_OPS_RESULTS" | wc -l | tr -d ' ')
            printf -- "- %s: %s\n" "$s" "$n"
        done
        echo ""
        echo "| Status | Area | Check | Result | Next step |"
        echo "|---|---|---|---|---|"
        awk -F'\t' 'BEGIN{o["FAIL"]=1;o["WARN"]=2;o["INFO"]=3;o["SKIP"]=4;o["PASS"]=5} {print o[$3]"\t"$0}' "$TOOLKIT_OPS_RESULTS" | sort -s -n -k1,1 | cut -f2- | \
            awk -F'\t' '{gsub(/\|/,"\\|",$4); gsub(/\|/,"\\|",$5); printf "| %s | %s | %s | %s | %s |\n", $3, $1, $2, $4, $5}'
    } > "$REPORT"
    echo "Report written: $REPORT"
fi

ops_summary
