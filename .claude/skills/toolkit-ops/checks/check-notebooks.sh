#!/bin/bash
################################################################################
# check-notebooks.sh -- workbench + notebook checks inside RHOAI workbench pods
#
# Usage: check-notebooks.sh [--demo NAME[,NAME]] [--all-workbenches] [--execute] [--force]
#                           [--notebook SUBSTR] [--exec-timeout SECS] [--json] [--quiet]
#
# Default (read-only; uses `oc exec` only for test/ls/env/python probes):
#   per workbench : Notebook CR exists, not stopped, pod <wb>-0 Ready, image tag vs RHOAI version,
#                   hardware-profile annotation, toolkit repo cloned (+ commit), MLflow env when annotated
#   env drift     : every key in ConfigMap notebook-env must be in the pod env (inject_notebook_env
#                   updates the ConfigMap but never restarts the pod -> notebooks see stale env)
#   per notebook  : file present, required env vars set in the pod, Python imports available,
#                   URL env vars reachable from inside the pod
#   --all-workbenches : also run the generic workbench checks on every Notebook CR in the cluster
#
# --execute (RUNS NOTEBOOK CODE in the pod: may call models, write to S3/MLflow/EvalHub):
#   runs `jupyter nbconvert --execute` for notebooks whose class allows it (see notebook-specs.conf);
#   output goes to /tmp/toolkit-ops/ in the pod, the repo copy is not modified.
#   --force also runs needs-data / long notebooks. gpu and broken are never auto-run.
################################################################################
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
ops_parse_common_flags "$@"
SPEC="$_OPS_LIB_DIR/notebook-specs.conf"
REPO_IN_POD="/opt/app-root/src/RHOAI-Toolkit"
ONLY=""; ALL_WB=false; EXECUTE=false; FORCE=false; NB_FILTER=""; EXEC_TIMEOUT=900
set -- "${OPS_ARGS[@]}"
while [[ $# -gt 0 ]]; do
    case $1 in
        --demo) ONLY=",$2,"; shift 2 ;;
        --all-workbenches) ALL_WB=true; shift ;;
        --execute) EXECUTE=true; shift ;;
        --force) FORCE=true; shift ;;
        --notebook) NB_FILTER="$2"; shift 2 ;;
        --exec-timeout) EXEC_TIMEOUT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

ops_section "Workbench & notebook checks"
ops_require_cluster || { ops_summary; exit 1; }

# oc exec into the workbench container (container name == Notebook name, pod == <name>-0)
wx() { local ns="$1" wb="$2"; shift 2; timeout_cmd "${WX_TIMEOUT:-$OPS_TIMEOUT}" oc exec "$wb-0" -c "$wb" -n "$ns" -- "$@" 2>/dev/null </dev/null; }

# bash 3.2 compatible caches (macOS /bin/bash): per-workbench state in a temp dir
WB_CACHE="$(mktemp -d "${TMPDIR:-/tmp}/toolkit-ops-wb.XXXXXX")"
wbkey() { echo "$1__$2" | tr '/' '_'; }
check_workbench() {  # ns wb area
    local ns="$1" wb="$2" area="$3" key; key="$(wbkey "$1" "$2")"
    [ -f "$WB_CACHE/$key.ok" ] && return "$(cat "$WB_CACHE/$key.ok")"
    local nb; nb="$(k get notebooks.kubeflow.org "$wb" -n "$ns" -o json)"
    if [ -z "$nb" ]; then
        record "$area" "wb:$wb" FAIL "Notebook $ns/$wb not found" "Re-run the demo deploy (lib/functions/workbench.sh ensure_workbench)"
        echo 1 > "$WB_CACHE/$key.ok"; return 1
    fi
    local stopped; stopped="$(echo "$nb" | jq -r '.metadata.annotations["kubeflow-resource-stopped"] // empty')"
    if [ -n "$stopped" ]; then
        record "$area" "wb:$wb" WARN "Workbench stopped since $stopped" "Start it in the dashboard, then re-run"
        echo 1 > "$WB_CACHE/$key.ok"; return 1
    fi
    local pod; pod="$(k get pod "$wb-0" -n "$ns" -o json)"
    local ready; ready="$(echo "$pod" | jq -r '[.status.conditions[]? | select(.type=="Ready")][0].status // "missing"')"
    if [ "$ready" != "True" ]; then
        local why; why="$(echo "$pod" | jq -r '[.status.containerStatuses[]? | select(.ready!=true) | "\(.name):\(.state | to_entries[0] | "\(.key) \(.value.reason // "")")"] | join(", ")')"
        record "$area" "wb:$wb" FAIL "Pod $wb-0 Ready=$ready ${why}" \
            "oc describe pod -n $ns $wb-0 (Pending: GPU/hardware-profile tolerations; ImagePull: image tag missing in redhat-ods-applications ImageStream)"
        echo 1 > "$WB_CACHE/$key.ok"; return 1
    fi
    record "$area" "wb:$wb" PASS "Workbench $ns/$wb running and Ready"

    # Image tag vs RHOAI version (toolkit defaults to :3.4 tags; 3.5 images are 2025.2)
    local image; image="$(echo "$nb" | jq -r '.spec.template.spec.containers[0].image')"
    if [ "$RHOAI_MM" = "3.5" ] && [[ "$image" == *:3.4 ]]; then
        record "$area" "wb:$wb-image" WARN "Image ${image##*/} is a 3.4 tag on RHOAI 3.5" "lib/functions/workbench.sh:40 default; create_workbench never updates an existing Notebook"
    fi
    [ -z "$(echo "$nb" | jq -r '.metadata.annotations["opendatahub.io/hardware-profile-name"] // empty')" ] && \
        record "$area" "wb:$wb-hwprofile" INFO "No hardware-profile annotation on the Notebook"

    # Repo clone
    local commit; commit="$(wx "$ns" "$wb" git -C "$REPO_IN_POD" log -1 --format='%h %cs')"
    if [ -n "$commit" ]; then
        local local_head; local_head="$(git -C "$OPS_ROOT_DIR" rev-parse --short HEAD 2>/dev/null)"
        record "$area" "wb:$wb-repo" PASS "Toolkit cloned at $commit (local checkout $local_head; pod tracks GitHub main, not local edits)"
    else
        record "$area" "wb:$wb-repo" FAIL "Toolkit repo not cloned at $REPO_IN_POD" "scripts/clone-toolkit-in-workbenches.sh -n $ns"
    fi

    # Env drift: ConfigMap keys missing from the live pod env
    local cm_keys pod_env missing
    cm_keys="$(k get configmap notebook-env -n "$ns" -o json | jq -r '.data // {} | keys[]')"
    pod_env="$(wx "$ns" "$wb" env)"
    printf '%s\n' "$pod_env" > "$WB_CACHE/$key.env"
    missing=""
    for kk in $cm_keys; do echo "$pod_env" | grep -q "^$kk=" || missing+="$kk "; done
    if [ -n "$missing" ]; then
        record "$area" "wb:$wb-env-drift" FAIL "ConfigMap notebook-env has keys the pod does not: $missing" \
            "Pod started before inject_notebook_env updated the ConfigMap. Restart the workbench (stop/start in dashboard, or oc delete pod -n $ns $wb-0 after user approval)"
    else
        record "$area" "wb:$wb-env-drift" PASS "Pod env matches ConfigMap notebook-env ($(echo "$cm_keys" | wc -w | tr -d ' ') keys)"
    fi

    # MLflow injection (Working with MLflow 3.5 ch.4: annotation -> MLFLOW_TRACKING_URI)
    if [ -n "$(echo "$nb" | jq -r '.metadata.annotations["opendatahub.io/mlflow-instance"] // empty')" ] && \
       ! echo "$pod_env" | grep -q '^MLFLOW_TRACKING_URI='; then
        record "$area" "wb:$wb-mlflow" WARN "mlflow-instance annotation set but MLFLOW_TRACKING_URI not injected" "Gateway hostname unavailable at pod start (degraded state per docs); restart workbench"
    fi
    echo 0 > "$WB_CACHE/$key.ok"; return 0
}

check_url_from_pod() {  # ns wb area var url
    local code
    code="$(WX_TIMEOUT=20 wx "$1" "$2" python3 -c "
import ssl,sys,urllib.request
ctx=ssl._create_unverified_context()
try:
    r=urllib.request.urlopen(urllib.request.Request(sys.argv[1],method='GET'),timeout=10,context=ctx); print(r.status)
except urllib.error.HTTPError as e: print(e.code)
except Exception as e: print('ERR:'+type(e).__name__)
" "$5")"
    case "$code" in
        ERR:*|"") record "$3" "url:$4" FAIL "$4=$5 unreachable from $2 (${code:-no output})" "Service/DNS/NetworkPolicy issue; the endpoint may have moved: scripts/refresh-notebook-env.sh $1" ;;
        *)        record "$3" "url:$4" PASS "$4 reachable from pod (HTTP $code)" ;;
    esac
}

spec_rows() {
    grep -vE '^\s*(#|$)' "$SPEC" | awk -F'|' '{for(i=1;i<=NF;i++){gsub(/^[ \t]+|[ \t]+$/,"",$i)}; print $1"|"$2"|"$3"|"$4"|"$5"|"$6"|"$7}'
}

URLS_DONE=" "
while IFS='|' read -r demo ns wb nbpath envs imports class; do
    [ -n "$ONLY" ] && [[ "$ONLY" != *",$demo,"* ]] && continue
    [ -n "$NB_FILTER" ] && [[ "$nbpath" != *"$NB_FILTER"* ]] && continue
    [[ "$ns" == *'$'* ]] && ns="$(eval "printf '%s' \"$ns\"")"
    area="nb:$demo"; nbname="$(basename "$nbpath" .ipynb)"
    if ! k get namespace "$ns" >/dev/null; then
        [ -n "$ONLY" ] && record "$area" "$nbname" FAIL "namespace $ns missing (demo not deployed)" || record "$area" "$nbname" SKIP "demo not deployed"
        continue
    fi
    check_workbench "$ns" "$wb" "$area" || { record "$area" "$nbname" SKIP "workbench not usable"; continue; }
    pod_env="$(cat "$WB_CACHE/$(wbkey "$ns" "$wb").env" 2>/dev/null)"

    if ! wx "$ns" "$wb" test -f "$REPO_IN_POD/$nbpath"; then
        record "$area" "$nbname" FAIL "$nbpath not found in pod" "Repo clone stale/missing: scripts/clone-toolkit-in-workbenches.sh -n $ns"
        continue
    fi

    # Required env vars
    miss=""
    for v in ${envs//,/ }; do echo "$pod_env" | grep -q "^$v=." || miss+="$v "; done
    if [ -n "$miss" ]; then
        record "$area" "$nbname-env" FAIL "Env vars not set in pod: $miss" "Check the demo deploy.sh inject_notebook_env call; then restart the workbench"
    else
        record "$area" "$nbname-env" PASS "Required env vars present"
    fi

    # URL env vars reachable from inside the pod (once per workbench+var)
    for v in ${envs//,/ }; do
        [[ "$v" =~ (URL|ENDPOINT)$ ]] || continue
        val="$(echo "$pod_env" | sed -n "s/^$v=//p" | head -1)"
        [ -z "$val" ] && continue
        [[ "$val" != http* ]] && val="https://$val"
        [[ "$URLS_DONE" == *" $ns/$wb/$v "* ]] && continue
        URLS_DONE+="$ns/$wb/$v "
        check_url_from_pod "$ns" "$wb" "$area" "$v" "$val"
    done

    # Python imports
    for m in ${imports//,/ }; do
        mod="${m#pip:}"
        if wx "$ns" "$wb" python3 -c "import $mod" >/dev/null; then
            record "$area" "$nbname-import-$mod" PASS "import $mod OK"
        elif [[ "$m" == pip:* ]]; then
            record "$area" "$nbname-import-$mod" INFO "$mod not in image (notebook pip-installs it: needs internet egress)"
        else
            record "$area" "$nbname-import-$mod" FAIL "import $mod fails and the notebook does not install it" "pip install in the workbench, or add a pip cell to $nbpath"
        fi
    done

    # Execution class
    cls="${class%%:*}"; reason="${class#*:}"; [ "$reason" = "$class" ] && reason=""
    run=false
    case "$cls" in
        safe) run=true ;;
        needs-key) if echo "$pod_env" | grep -q "^$reason=."; then run=true; else record "$area" "$nbname-exec" INFO "Needs $reason in the pod env to run" "get_maas_api_key (demo/lib/rhoai-detect.sh:273), add to notebook-env, restart workbench"; fi ;;
        needs-data|long) $FORCE && run=true || record "$area" "$nbname-exec" INFO "class=$cls${reason:+ ($reason)}: run with --execute --force" ;;
        gpu) record "$area" "$nbname-exec" INFO "class=gpu: not auto-run (GPU + Hugging Face downloads, long)" ;;
        broken) record "$area" "$nbname-exec" WARN "Known defect, not run: $reason" "See reference/demo-checks.md gaps; fix the notebook or deploy.sh" ;;
    esac
    if $EXECUTE && $run; then
        out="$(WX_TIMEOUT=$((EXEC_TIMEOUT + 60)) wx "$ns" "$wb" bash -c "mkdir -p /tmp/toolkit-ops && cd $REPO_IN_POD/$(dirname "$nbpath") && jupyter nbconvert --to notebook --execute --ExecutePreprocessor.timeout=$EXEC_TIMEOUT --output-dir /tmp/toolkit-ops --output $nbname.out $REPO_IN_POD/$nbpath 2>&1; echo EXIT=\$?")"
        rc="$(echo "$out" | sed -n 's/^EXIT=//p' | tail -1)"
        if [ "$rc" = "0" ]; then
            record "$area" "$nbname-exec" PASS "Executed headless OK (output /tmp/toolkit-ops/$nbname.out.ipynb in pod)"
        else
            err="$(echo "$out" | grep -E 'Error|Exception|Traceback|CellExecutionError|Timeout' | tail -3 | tr '\n' ' ' | cut -c1-300)"
            record "$area" "$nbname-exec" FAIL "Execution failed (rc=${rc:-timeout}): ${err:-see pod}" \
                "oc exec -n $ns $wb-0 -c $wb -- cat /tmp/toolkit-ops/$nbname.out.ipynb | jq '.cells[].outputs[]? | select(.output_type==\"error\")'"
        fi
    elif ! $EXECUTE && $run; then
        record "$area" "$nbname-exec" INFO "Runnable headless: add --execute to run it"
    fi
done < <(spec_rows)

if $ALL_WB; then
    while read -r ns wb; do
        [ -z "$wb" ] && continue
        check_workbench "$ns" "$wb" "workbench" >/dev/null || true
    done < <(k get notebooks.kubeflow.org -A -o json | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"')
fi

ops_summary
