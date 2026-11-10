#!/bin/bash
################################################################################
# check-maas.sh -- Models-as-a-Service state (read-only)
#
# Usage: check-maas.sh [--no-diagnose] [--json] [--quiet] [--timeout N]
#
# Static checks for RHOAI 3.5 (aigateway) and 3.4 (kserve.modelsAsService), then folds in
# `scripts/diagnose-maas.sh --json` (read-only without --fix: 11 known-issue checks).
# Functional E2E (deploys a simulator, creates an API key) is scripts/verify-maas.sh -- it MUTATES
# the cluster, so it is not called here; SKILL.md gates it behind user approval.
################################################################################
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
ops_parse_common_flags "$@"
RUN_DIAG=true
for a in "${OPS_ARGS[@]}"; do [ "$a" = "--no-diagnose" ] && RUN_DIAG=false; done

ops_section "MaaS checks"
ops_require_cluster || { ops_summary; exit 1; }

dsc_json="$(k get datasciencecluster -o json | jq '.items[0] // empty')"
case "$RHOAI_MM" in
    3.5|3.6) field='.spec.components.aigateway.modelsAsAService.managementState // .spec.components.aigateway.managementState'
             conds="AIGatewayReady ModelsAsAServiceReady" ;;
    3.4)     field='.spec.components.kserve.modelsAsService.managementState'
             conds="ModelsAsServiceReady" ;;
    *)       record maas version SKIP "RHOAI $RHOAI_MM: MaaS checks cover 3.4/3.5 only (3.3 TP is EOL)"; ops_summary; exit 0 ;;
esac
state="$(echo "$dsc_json" | jq -r "$field // \"unset\"")"
if [ "$state" != "Managed" ]; then
    record maas enabled SKIP "MaaS not enabled in DSC ($state)" "scripts/setup-maas.sh to enable"
    ops_summary; exit 0
fi
record maas enabled PASS "MaaS Managed in DSC"
for c in $conds; do
    st="$(echo "$dsc_json" | jq -r --arg t "$c" '[.status.conditions[]? | select(.type==$t)][0] | "\(.status // "missing")|\(.message // "")"')"
    if [ "${st%%|*}" = "True" ]; then record maas "$c" PASS "$c=True"
    else record maas "$c" FAIL "$c=${st%%|*} ${st#*|}" "ModelsAsAServiceReady stays False until gateway + DB + TLS exist: scripts/setup-maas.sh --diagnose"; fi
done

infra_ns="$(get_maas_infra_namespace 2>/dev/null | tail -1)"
infra_ns="${infra_ns:-redhat-ai-gateway-infra}"

# CRDs
for crd in maassubscriptions.maas.opendatahub.io maasauthpolicies.maas.opendatahub.io maasmodelrefs.maas.opendatahub.io; do
    k get crd "$crd" >/dev/null && record maas "crd-${crd%%.*}" PASS "CRD present" || record maas "crd-${crd%%.*}" FAIL "CRD $crd missing"
done

# maas-api
ready="$(k get deploy maas-api -n "$infra_ns" -o jsonpath='{.status.readyReplicas}/{.spec.replicas}')"
if [[ "$ready" =~ ^([1-9][0-9]*)/\1$ ]]; then record maas maas-api PASS "maas-api $ready in $infra_ns"
else record maas maas-api FAIL "maas-api not ready (${ready:-missing}) in $infra_ns" "oc logs -n $infra_ns deploy/maas-api"; fi

# Database (PostgreSQL 14+, customer-provided)
url="$(k get secret maas-db-config -n "$infra_ns" -o jsonpath='{.data.DB_CONNECTION_URL}')"
[ -n "$url" ] && record maas db-config PASS "maas-db-config has DB_CONNECTION_URL" || \
    record maas db-config FAIL "maas-db-config secret / DB_CONNECTION_URL missing in $infra_ns" "scripts/setup-maas.sh (setup_maas_database; lib/manifests/maas/platform/)"

# Tenant
if [ "$RHOAI_MM" = "3.4" ]; then
    t="$(kjq '[.items[0].status.conditions[]? | select(.type=="Ready")][0].status // "missing"' tenant -n models-as-a-service)"
else
    t="$(kjq '[.status.conditions[]? | select(.type=="Ready")][0].status // "missing"' maastenantconfig default-tenant -n models-as-a-service)"
fi
[ "$t" = "True" ] && record maas tenant PASS "Tenant Ready" || record maas tenant FAIL "Tenant Ready=$t" "oc describe maastenantconfig default-tenant -n models-as-a-service"

# Gateway + Kuadrant
gw="$(k get gateway maas-default-gateway -n openshift-ingress -o json)"
if [ -z "$gw" ]; then
    record maas gateway FAIL "maas-default-gateway missing in openshift-ingress" "scripts/setup-maas.sh (gateway phase)"
else
    prog="$(echo "$gw" | jq -r '[.status.conditions[]? | select(.type=="Programmed")][0].status // "?"')"
    host="$(echo "$gw" | jq -r '[.spec.listeners[]?.hostname // empty] | join(",")')"
    [ "$prog" = "True" ] && record maas gateway PASS "maas-default-gateway Programmed (${host:-no hostname})" || record maas gateway FAIL "maas-default-gateway Programmed=$prog"
    [ -z "$host" ] && record maas gateway-hostname WARN "Gateway listeners have no hostname (RHOAIENG-89775: /v1/tenants may 500)" "docs/TROUBLESHOOTING.md; diagnose-maas Issue 4"
fi
kq="$(kjq '[.items[0].status.conditions[]? | select(.type=="Ready")][0].status // "missing"' kuadrant -n kuadrant-system)"
[ "$kq" = "True" ] && record maas kuadrant PASS "Kuadrant Ready" || record maas kuadrant FAIL "Kuadrant Ready=$kq" "scripts/fix-kuadrant-istio.sh"
atls="$(k get authorino authorino -n kuadrant-system -o jsonpath='{.spec.listener.tls.enabled}')"
[ "$atls" = "true" ] && record maas authorino-tls PASS "Authorino listener TLS enabled" || record maas authorino-tls WARN "Authorino TLS enabled=${atls:-?}" "lib/functions/operators.sh configure_authorino_tls"

# Models published to MaaS
refs="$(k get maasmodelrefs.maas.opendatahub.io -A -o json)"
n="$(echo "$refs" | jq '.items | length')"
if [ "${n:-0}" -eq 0 ]; then
    record maas models WARN "No MaaSModelRefs (nothing published)" "scripts/deploy-maas-model.sh --model simulator"
else
    notready="$(echo "$refs" | jq -r '[.items[] | select(([.status.conditions[]? | select(.type=="Ready" and .status=="True")] | length)==0) | "\(.metadata.namespace)/\(.metadata.name)"] | join(",")')"
    [ -z "$notready" ] && record maas models PASS "$n MaaSModelRef(s) Ready" || record maas models FAIL "MaaSModelRefs not Ready: $notready" "Check the backing LLMInferenceService (check-serving.sh)"
fi
ungoverned="$(k get llminferenceservice -A -o json | jq -r '[.items[] | select(.metadata.labels["maas.opendatahub.io/model"]==null and .metadata.annotations["alpha.maas.opendatahub.io/tiers"]==null) | .metadata.name] | length')"
[ "${ungoverned:-0}" -gt 0 ] && record maas governance INFO "$ungoverned LLMInferenceService(s) without MaaS labels" "scripts/check-maas-security.sh"

# Endpoint must enforce auth (expect 401/403 without a key)
ep="$(k get gateway maas-default-gateway -n openshift-ingress -o jsonpath='{.spec.listeners[0].hostname}')"
[ -z "$ep" ] && ep="maas.$(k get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')"
[ -n "$ep" ] && [[ "$ep" != http* ]] && ep="https://$ep"
if [ -n "$ep" ]; then
    code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 15 "${ep%/}/v1/models")"
    case "$code" in
        401|403) record maas endpoint-auth PASS "${ep%/}/v1/models -> $code without key (auth enforced)" ;;
        200)     record maas endpoint-auth FAIL "${ep%/}/v1/models -> 200 without key (auth NOT enforced)" "Check AuthPolicy maas-gateway-auth; scripts/check-maas-security.sh" ;;
        *)       record maas endpoint-auth FAIL "${ep%/}/v1/models -> HTTP ${code:-timeout}" "Gateway/route problem: scripts/diagnose-maas.sh" ;;
    esac
fi

# Known-issue diagnostics (read-only without --fix)
if $RUN_DIAG; then
    out="$("$OPS_ROOT_DIR/scripts/diagnose-maas.sh" --json 2>/dev/null | sed -n '/^{/,$p')"
    if echo "$out" | jq -e .checks >/dev/null 2>&1; then
        while IFS=$'\t' read -r issue status sev msg; do
            case "$status" in PASS) s=PASS ;; FAIL) s=FAIL ;; SKIP|N/A) s=SKIP ;; *) s=WARN ;; esac
            record maas-diag "$issue" "$s" "[$sev] $msg" "scripts/diagnose-maas.sh (--fix applies the safe fixes: needs user approval)"
        done < <(echo "$out" | jq -r '.checks[] | [.issue, .status, .severity, .message] | @tsv')
    else
        record maas-diag run WARN "diagnose-maas.sh --json produced no parseable output" "Run scripts/diagnose-maas.sh interactively"
    fi
fi

ops_summary
