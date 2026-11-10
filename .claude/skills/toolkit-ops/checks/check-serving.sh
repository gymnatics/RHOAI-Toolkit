#!/bin/bash
################################################################################
# check-serving.sh -- model serving health (read-only)
#
# Usage: check-serving.sh [-n NAMESPACE] [--probe] [--json] [--quiet] [--timeout N]
#   -n       limit to one namespace (default: all)
#   --probe  GET /v1/models on each model through the API-server service proxy
#            (`oc get --raw .../services/<scheme>:<svc>:<port>/proxy/v1/models`): read-only, no pods
#
# Checks InferenceService (v1beta1) and LLMInferenceService (v1alpha1): Ready, URL, predictor pods,
# and the three hardware-profile annotations the dashboard needs (Critical Gotchas in TOOLKIT-CONTEXT).
################################################################################
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
ops_parse_common_flags "$@"
NS_ARGS=(-A); PROBE=false
set -- "${OPS_ARGS[@]}"
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NS_ARGS=(-n "$2"); shift 2 ;;
        --probe) PROBE=true; shift ;;
        *) shift ;;
    esac
done

ops_section "Model serving checks"
ops_require_cluster || { ops_summary; exit 1; }

probe() {  # ns svc port scheme
    local out
    out="$(timeout_cmd "$OPS_TIMEOUT" oc get --raw "/api/v1/namespaces/$1/services/$4:$2:$3/proxy/v1/models" 2>/dev/null)"
    echo "$out" | jq -r '[.data[]?.id] | join(",")' 2>/dev/null
}

check_kind() {
    local kind="$1" short="$2"
    local items
    items="$(k get "$kind" "${NS_ARGS[@]}" -o json | jq -c '.items[]?')"
    if [ -z "$items" ]; then
        record serving "$short" INFO "No ${kind}s"
        return
    fi
    while read -r it; do
        local ns name id ready msg url hwp
        ns="$(echo "$it" | jq -r .metadata.namespace)"; name="$(echo "$it" | jq -r .metadata.name)"
        id="$short:$ns/$name"
        ready="$(echo "$it" | jq -r '[.status.conditions[]? | select(.type=="Ready")][0].status // "Unknown"')"
        msg="$(echo "$it" | jq -r '[.status.conditions[]? | select(.status!="True")][0] | if . then "\(.type): \(.message // .reason // "")" else "" end' | cut -c1-200)"
        url="$(echo "$it" | jq -r '.status.url // .status.addresses[0].url // empty')"
        if [ "$(echo "$it" | jq -r '.metadata.annotations["serving.kserve.io/stop"] // ""')" = "true" ]; then
            record serving "$id" INFO "Stopped on purpose (serving.kserve.io/stop=true)" "Start it in the dashboard or remove the annotation (user approval) before demos that need it"
            continue
        fi
        if [ "$ready" = "True" ]; then
            record serving "$id" PASS "Ready${url:+ ($url)}"
        else
            local pods
            pods="$(k get pods -n "$ns" -o json | jq -r --arg n "$name" '[.items[] | select((.metadata.labels["serving.kserve.io/inferenceservice"]==$n) or (.metadata.labels["app.kubernetes.io/name"]==$n)) | "\(.metadata.name):\(.status.phase)/\([.status.containerStatuses[]? | .state | keys[0]] | join("+"))"] | join(",")')"
            record serving "$id" FAIL "Ready=$ready $msg pods=[${pods:-none}]" \
                "oc describe $kind -n $ns $name; GPU pending -> check-infra gpu-allocatable + hardware profile tolerations"
        fi
        # dashboard needs all three hardware-profile annotations on deployed models
        hwp="$(echo "$it" | jq -r '[.metadata.annotations // {} | keys[] | select(startswith("opendatahub.io/hardware-profile-"))] | length')"
        if [ "$hwp" -gt 0 ] && [ "$hwp" -lt 3 ]; then
            record serving "$id-hwprofile" WARN "Only $hwp/3 hardware-profile annotations (name, namespace, resource-version)" "Dashboard may not show the profile: scripts/fix-hardware-profile.sh"
        fi
        if $PROBE && [ "$ready" = "True" ]; then
            local svc port scheme models
            # Same conventions as lib/functions/notebook-env.sh / lib/functions/demos.sh
            if [ "$short" = "llmisvc" ]; then svc="${name}-kserve-workload-svc"; scheme=https; port=8000
            else svc="${name}-predictor"; scheme=http; port=8080; fi
            port="$(k get svc "$svc" -n "$ns" -o jsonpath='{.spec.ports[0].port}')"; port="${port:-8000}"
            models="$(probe "$ns" "$svc" "$port" "$scheme")"
            if [ -n "$models" ]; then record serving "$id-probe" PASS "/v1/models -> $models"
            else record serving "$id-probe" WARN "/v1/models probe via $scheme:$svc:$port returned nothing" "Service name/port may differ: oc get svc -n $ns; not necessarily a failure"; fi
        fi
    done <<< "$items"
}

check_kind inferenceservice isvc
check_kind llminferenceservice llmisvc

ops_summary
