#!/bin/bash
################################################################################
# check-demos.sh -- per-demo deployment checks driven by demo-specs.conf (read-only)
#
# Usage: check-demos.sh [--demo NAME[,NAME]] [--list] [--json] [--quiet] [--timeout N]
#   (no --demo)  check every demo; demos that are not deployed are SKIPPED
#   --demo X     check only X; "not deployed" becomes a FAIL
#   --list       print demos defined in demo-specs.conf and exit
#
# Deep workbench/notebook checks are in check-notebooks.sh.
################################################################################
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
ops_parse_common_flags "$@"
SPEC="$_OPS_LIB_DIR/demo-specs.conf"
ONLY=""; LIST=false
set -- "${OPS_ARGS[@]}"
while [[ $# -gt 0 ]]; do
    case $1 in
        --demo) ONLY=",$2,"; shift 2 ;;
        --list) LIST=true; shift ;;
        *) shift ;;
    esac
done

spec_rows() {  # strip comments/blank lines, trim fields
    grep -vE '^\s*(#|$)' "$SPEC" | awk -F'|' '{for(i=1;i<=NF;i++){gsub(/^[ \t]+|[ \t]+$/,"",$i)}; print $1"|"$2"|"$3"|"$4"|"$5}'
}

if $LIST; then spec_rows | cut -d'|' -f1 | uniq; exit 0; fi

ops_section "Demo deployment checks"
ops_require_cluster || { ops_summary; exit 1; }

gate_ok() {  # "rhoai>=3.5" / "rhoai<3.5"
    local c="$1"
    [ -z "$c" ] && return 0
    case "$c" in
        rhoai\>=*) ver_ge "$RHOAI_MM" "${c#rhoai>=}" ;;
        rhoai\<*)  ! ver_ge "$RHOAI_MM" "${c#rhoai<}" ;;
        *) return 0 ;;
    esac
}

# Run one check; echo "STATUS|message|hint". STATUS=ABSENT means the target does not exist.
run_check() {
    local ns="$1" type="$2" target="$3" cond="$4" nsarg=()
    [ "$ns" != "-" ] && nsarg=(-n "$ns")
    if [ "$ns" != "-" ] && ! k get namespace "$ns" >/dev/null; then echo "ABSENT|namespace $ns missing|"; return; fi
    case "$type" in
        deploy)
            local sel=(deploy "$target"); [ "$target" = "*" ] && sel=(deploy)
            local j; j="$(k get "${sel[@]}" "${nsarg[@]}" -o json)"
            [ -z "$j" ] && { echo "ABSENT|deployment $target missing|"; return; }
            local bad; bad="$(echo "$j" | jq -r '[(.items // [.])[] | select((.status.readyReplicas // 0) < (.spec.replicas // 1)) | "\(.metadata.name)=\(.status.readyReplicas // 0)/\(.spec.replicas // 1)"] | join(",")')"
            local cnt; cnt="$(echo "$j" | jq '(.items // [.]) | length')"
            [ "$cnt" -eq 0 ] && { echo "ABSENT|no deployments|"; return; }
            [ -z "$bad" ] && echo "PASS|$cnt deployment(s) ready|" || echo "FAIL|not ready: $bad|oc get pods -n $ns; oc describe deploy -n $ns <name>" ;;
        isvc|llmisvc)
            local kind=inferenceservice; [ "$type" = llmisvc ] && kind=llminferenceservice
            local j
            if [ "$target" = "*" ]; then j="$(k get "$kind" "${nsarg[@]}" -o json | jq '.items')"
            else j="$(k get "$kind" "$target" "${nsarg[@]}" -o json | jq '[.]')"; fi
            [ -z "$j" ] || [ "$(echo "$j" | jq length)" -eq 0 ] && { echo "ABSENT|$kind $target missing|"; return; }
            local stopped; stopped="$(echo "$j" | jq -r '[.[] | select(.metadata.annotations["serving.kserve.io/stop"]=="true") | .metadata.name] | join(",")')"
            if [ -n "$stopped" ] && [ "$(echo "$j" | jq length)" -eq "$(echo "$stopped" | tr ',' '\n' | wc -l | tr -d ' ')" ]; then
                echo "WARN|$kind $stopped stopped on purpose (serving.kserve.io/stop=true)|Start it before using this demo (user approval)"; return
            fi
            local ready; ready="$(echo "$j" | jq -r '[.[] | select(any(.status.conditions[]?; .type=="Ready" and .status=="True")) | .metadata.name] | join(",")')"
            local why; why="$(echo "$j" | jq -r '[.[] | .status.conditions[]? | select(.status!="True") | "\(.type): \(.message // .reason // "")"] | first // ""' | cut -c1-160)"
            [ -n "$ready" ] && echo "PASS|Ready: $ready|" || echo "FAIL|$kind $target not Ready ($why)|check-serving.sh -n $ns; GPU? check-infra.sh" ;;
        notebook)
            k get notebooks.kubeflow.org "$target" "${nsarg[@]}" >/dev/null || { echo "ABSENT|notebook $target missing|"; return; }
            local stopped; stopped="$(k get notebooks.kubeflow.org "$target" "${nsarg[@]}" -o jsonpath='{.metadata.annotations.kubeflow-resource-stopped}')"
            [ -n "$stopped" ] && { echo "WARN|workbench $target is stopped (since $stopped)|Start it from the dashboard"; return; }
            local r; r="$(k get pod "$target-0" "${nsarg[@]}" -o json | jq -r '[.status.conditions[]? | select(.type=="Ready")][0].status // "missing"')"
            [ "$r" = "True" ] && echo "PASS|workbench pod $target-0 Ready (deep checks: check-notebooks.sh)|" || echo "FAIL|workbench pod $target-0 Ready=$r|oc describe pod -n $ns $target-0" ;;
        route)
            local name="${target%%/*}" path=""; [[ "$target" == */* ]] && path="/${target#*/}"
            local host; host="$(k get route "$name" "${nsarg[@]}" -o jsonpath='{.spec.host}')"
            [ -z "$host" ] && { echo "ABSENT|route $name missing|"; return; }
            local code; code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 15 "https://$host$path")"
            case "$code" in
                2??|3??|401|403) echo "PASS|https://$host$path -> $code|" ;;
                *) echo "FAIL|https://$host$path -> ${code:-timeout}|Backend not serving: oc get pods -n $ns; oc get endpoints -n $ns $name" ;;
            esac ;;
        exists)
            k get "$target" "${nsarg[@]}" >/dev/null && echo "PASS|$target exists|" || echo "ABSENT|$target missing|" ;;
        field)
            local path="${cond%=*}" want="${cond##*=}"
            k get "$target" "${nsarg[@]}" >/dev/null || { echo "ABSENT|$target missing|"; return; }
            local got; got="$(k get "$target" "${nsarg[@]}" -o "jsonpath={$path}")"
            [ "$got" = "$want" ] && echo "PASS|$target $path=$got|" || echo "FAIL|$target $path=${got:-<empty>} (want $want)|oc describe $target -n $ns" ;;
        servedmodel)
            # cond = ConfigMap key holding an OpenAI "model" id; it must be an id some model serves
            # (LLMInferenceService spec.model.name, InferenceService --served-model-name or name)
            local key="${cond:-LLM_MODEL_NAME}"
            k get "$target" "${nsarg[@]}" >/dev/null || { echo "ABSENT|$target missing|"; return; }
            local want; want="$(k get "$target" "${nsarg[@]}" -o json | jq -r --arg k "$key" '.data[$k] // ""')"
            [ -z "$want" ] && { echo "WARN|$target has no $key|"; return; }
            local served; served="$( { k get llminferenceservice -A -o json | jq -r '.items[] | .spec.model.name // .metadata.name';
                k get inferenceservice -A -o json | jq -r '.items[] | .metadata.name,
                    ([.spec.predictor.model.args[]?, .spec.predictor.containers[]?.args[]?] | .[] | select(startswith("--served-model-name=")) | sub("^--served-model-name="; ""))'; } | sort -u)"
            if echo "$served" | grep -qxF "$want"; then echo "PASS|$key=$want is a served model id|"
            else echo "FAIL|$key=$want is not served by any model (served: $(echo "$served" | grep -v '^$' | head -6 | paste -sd, -))|Use the served id (LLMInferenceService spec.model.name), not the resource name; redeploy the demo or patch $target"; fi ;;
        probe)
            # Functional probe through the app's Route (HTTP only; no cluster changes). cond = probe kind
            local host; host="$(k get route "$target" "${nsarg[@]}" -o jsonpath='{.spec.host}')"
            [ -z "$host" ] && { echo "ABSENT|route $target missing|"; return; }
            local u="https://$host"
            case "$cond" in
                openwebui)  # WEBUI_AUTH=False: signin with empty credentials returns a session token
                    local tok models
                    tok="$(curl -sk -m 20 -X POST "$u/api/v1/auths/signin" -H 'Content-Type: application/json' -d '{"email":"","password":""}' | jq -r '.token // empty' 2>/dev/null)"
                    models="$(curl -sk -m 30 "$u/api/models" -H "Authorization: Bearer $tok" | jq -r '[.data[]?.id | select(. != "arena-model")] | join(",")' 2>/dev/null)"
                    [ -n "$models" ] && echo "PASS|Open WebUI lists models: $models|" \
                        || echo "FAIL|Open WebUI lists no models (model URL empty, unrendered or unreachable)|oc get cm openwebui-config -n $ns -o jsonpath='{.data.OPENAI_API_BASE_URLS}'; rerun demo/open-webui-demo/deploy.sh -n $ns" ;;
                nemo)  # PII prompt must be blocked; in selfcheck mode "model" must be the served id
                    local model r st
                    model="$(k get configmap "$target-config" "${nsarg[@]}" -o jsonpath='{.data.config\.yaml}' | awk '/model_name:/ {gsub(/"/,"",$2); print $2; exit}')"
                    r="$(curl -sk -m 120 -X POST "$u/v1/guardrail/checks" -H 'Content-Type: application/json' -H "Authorization: Bearer $(k whoami -t)" \
                        -d "{\"model\":\"${model:-test}\",\"messages\":[{\"role\":\"user\",\"content\":\"Contact me at alice@example.com\"}]}")"
                    st="$(echo "$r" | jq -r '.status // empty' 2>/dev/null)"
                    case "$st" in
                        blocked) if [ -n "$model" ]; then echo "PASS|PII prompt blocked (selfcheck mode, model $model)|"; else echo "PASS|PII prompt blocked (basic mode)|"; fi ;;
                        "") echo "FAIL|guardrail check returned no status: $(echo "$r" | tr -d '\n' | cut -c1-120)|oc logs deploy/$target -n $ns" ;;
                        *) echo "FAIL|PII prompt not blocked (status $st): $(echo "$r" | jq -r '.guardrails_data.details // ""' 2>/dev/null | cut -c1-140)|oc logs deploy/$target -n $ns; model_name must be the served id" ;;
                    esac ;;
                lemonade-chat)  # one on-topic chat through the app -> NeMo -> LLM
                    local out err txt
                    out="$(curl -sk -m 240 -X POST "$u/api/chat" -H 'Content-Type: application/json' -d '{"message":"Give me a one-sentence lemonade tip."}')"
                    err="$(echo "$out" | sed -n 's/^data: //p' | jq -r 'select(.type=="error") | .message' 2>/dev/null | head -1)"
                    txt="$(echo "$out" | sed -n 's/^data: //p' | jq -rj 'select(.type=="chunk") | .content' 2>/dev/null)"
                    if [ -n "$err" ]; then echo "FAIL|chat error: $err|401 = expired NeMo token: rerun demo/nemo-guardrails-demo/deploy.sh then demo/lemonade-stand-demo/deploy.sh; oc logs deploy/$target -n $ns"
                    elif [ -z "$txt" ]; then echo "FAIL|chat returned no text|oc logs deploy/$target -n $ns"
                    elif [[ "$txt" == *"<think>"* ]]; then echo "WARN|chat answered but shows model reasoning (<think>)|DISABLE_THINKING=true in the app (default)"
                    else echo "PASS|chat answered: $(echo "$txt" | tr -d '\n' | cut -c1-80)|"; fi ;;
                *) echo "SKIP|unknown probe $cond|" ;;
            esac ;;
        *) echo "SKIP|unknown check type $type|" ;;
    esac
}

current=""; skip_demo=false; checked=0
while IFS='|' read -r demo ns type target cond; do
    [ -n "$ONLY" ] && [[ "$ONLY" != *",$demo,"* ]] && continue
    # Expand ${VAR:-default} only (no globbing: target may be "*")
    [[ "$ns" == *'$'* ]] && ns="$(eval "printf '%s' \"$ns\"")"
    [[ "$target" == *'$'* ]] && target="$(eval "printf '%s' \"$target\"")"
    # 5th field is either a version gate or a field condition
    gate=""; fcond=""
    if [[ "$cond" == rhoai* ]]; then gate="$cond"; else fcond="$cond"; fi
    if [ "$demo" != "$current" ]; then
        current="$demo"; skip_demo=false; first=true
    fi
    $skip_demo && continue
    gate_ok "$gate" || continue
    res="$(run_check "$ns" "$type" "$target" "$fcond")"
    st="${res%%|*}"; rest="${res#*|}"; msg="${rest%%|*}"; hint="${rest#*|}"
    id="$type:${target}"
    if [ "$st" = "ABSENT" ]; then
        if $first && [ -z "$ONLY" ]; then
            record "demo:$demo" deployed SKIP "not deployed ($msg)"
            skip_demo=true; continue
        fi
        st=FAIL; hint="Re-run demo/$demo deploy script; see reference/demo-checks.md"
    fi
    first=false; checked=$((checked+1))
    record "demo:$demo" "$id" "$st" "$msg" "$hint"
done < <(spec_rows)

[ "$checked" -eq 0 ] && [ -n "$ONLY" ] && record demos selection FAIL "No checks ran for --demo ${ONLY//,/ }" "check-demos.sh --list"
ops_summary
