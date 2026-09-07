#!/bin/bash
################################################################################
# Diagnose MaaS Post-Upgrade Issues (BU Guide's 10-Issue Triage Order)
################################################################################
# Checks a live cluster against the 10 known post-upgrade issues documented in
# the RHOAI MaaS Guide (https://rh-aiservices-bu.github.io/rhoai-maas-guide),
# "Post-Upgrade Troubleshooting (3.4 -> 3.5)" page, plus 3 fixes validated
# against a live RHOAI 3.5 cluster on 2026-09-03.
#
# Usage:
#   ./scripts/diagnose-maas.sh              # report only
#   ./scripts/diagnose-maas.sh --fix        # report + apply safe auto-fixes
#   ./scripts/diagnose-maas.sh --json       # machine-readable output
#
# Safe auto-fixes (--fix):
#   - Issue 5: payload-processing OOM        -> annotate managed=false, bump to 1Gi
#   - Issue 7: WASM auth timeout             -> set AUTH_SERVICE_TIMEOUT=2s
#   - Issue 3: gateway namespace label       -> label required namespaces
# All other issues are reported only -- they require judgment calls (e.g.
# removing MCP Lifecycle Operator disables MCP server support) or upstream
# fixes that don't exist yet (Issue 8).
################################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
}
source "$ROOT_DIR/lib/utils/rhoai-version.sh" 2>/dev/null || true

FIX=false
JSON=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix) FIX=true; shift ;;
        --json) JSON=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--fix] [--json]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Results accumulator: "issue|status|severity|message"
declare -a RESULTS=()
fail_count=0
warn_count=0

record() {
    RESULTS+=("$1|$2|$3|$4")
}

print_step() { [ "$JSON" = false ] && echo -e "${CYAN}▶ $1${NC}"; }
print_fixed() { [ "$JSON" = false ] && echo -e "${GREEN}  ✓ FIXED: $1${NC}"; }

if ! oc whoami &>/dev/null; then
    echo "Not logged in to OpenShift. Run: oc login <cluster-url>" >&2
    exit 1
fi

detect_rhoai_version 2>/dev/null || true
IS_35=false
is_rhoai_35_or_higher 2>/dev/null && IS_35=true
MAAS_API_NS=$(get_maas_infra_namespace 2>/dev/null || echo "redhat-ods-applications")

[ "$JSON" = false ] && echo -e "${BLUE}RHOAI version: ${RHOAI_VERSION:-unknown} | maas-api namespace: ${MAAS_API_NS}${NC}\n"

################################################################################
# Issue 1: MCP Lifecycle Operator OOMKill (RHOAIENG-82694)
################################################################################
print_step "[1/10] MCP Lifecycle Operator OOM..."
if [ "$IS_35" = true ]; then
    mcp_pods=$(oc get pods -n redhat-ods-applications -o name 2>/dev/null | grep mcp-lifecycle || true)
    if [ -z "$mcp_pods" ]; then
        record "mcp-lifecycle-oom" "N/A" "-" "MCP Lifecycle Operator not found (mcplifecycleoperator may be Removed)"
    else
        max_restarts=0
        while IFS= read -r pod; do
            [ -z "$pod" ] && continue
            r=$(oc get "$pod" -n redhat-ods-applications -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo 0)
            [ "$r" -gt "$max_restarts" ] 2>/dev/null && max_restarts=$r
        done <<< "$mcp_pods"
        dsc_degraded=$(oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null | grep -c "mcplifecycleoperator" 2>/dev/null)
        dsc_degraded="${dsc_degraded:-0}"
        if [ "$dsc_degraded" -gt 0 ]; then
            record "mcp-lifecycle-oom" "FAIL" "Medium" "DSC reports mcplifecycleoperator degraded; pod restarts=$max_restarts. Workaround: oc patch datasciencecluster default-dsc --type=merge -p '{\"spec\":{\"components\":{\"mcplifecycleoperator\":{\"managementState\":\"Removed\"}}}}'"
        elif [ "$max_restarts" -gt 3 ]; then
            record "mcp-lifecycle-oom" "AT_RISK" "Medium" "Pod restarts=$max_restarts (elevated, but stabilized -- DSC not currently reporting degraded)"
        else
            record "mcp-lifecycle-oom" "PASS" "-" "Pod restarts=$max_restarts (healthy)"
        fi
    fi
else
    record "mcp-lifecycle-oom" "N/A" "-" "MCP Lifecycle Operator is RHOAI 3.5+ only"
fi

################################################################################
# Issue 2: ExternalModel Migration - dotted secret names (RHOAIENG-89784)
################################################################################
print_step "[2/10] ExternalModel migration (dotted secret names)..."
old_ext_models=$(oc get externalmodel.maas.opendatahub.io -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$old_ext_models" -eq 0 ] 2>/dev/null; then
    record "external-model-migration" "N/A" "-" "No externalmodel.maas.opendatahub.io resources found"
else
    dotted_secrets=$(oc get secrets -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name' --no-headers 2>/dev/null \
        | awk '$2 ~ /\./ && $2 !~ /^sh\.helm/ && $2 !~ /dockercfg/ && $2 !~ /^builder-/ && $2 !~ /^deployer-/ && $2 !~ /token-/ {print}' | wc -l | tr -d ' ')
    if [ "$IS_35" = true ]; then
        record "external-model-migration" "FAIL" "Medium" "$old_ext_models legacy ExternalModel(s) found on 3.5+ -- must be manually recreated as ExternalProvider+ExternalModel (inference.opendatahub.io). Dotted secrets found: $dotted_secrets (see docs/TROUBLESHOOTING.md)"
    else
        record "external-model-migration" "PASS" "-" "$old_ext_models ExternalModel(s) using correct 3.4 API (maas.opendatahub.io)"
    fi
fi

################################################################################
# Issue 3: Gateway Namespace Label (RHOAIENG-83207)
################################################################################
print_step "[3/10] Gateway namespace label..."
gw_selector=$(oc get gateway maas-default-gateway -n openshift-ingress -o jsonpath='{.spec.listeners[0].allowedRoutes.namespaces.from}' 2>/dev/null)
if [ -z "$gw_selector" ]; then
    record "gateway-namespace-label" "N/A" "-" "maas-default-gateway not found"
elif [ "$gw_selector" = "All" ]; then
    record "gateway-namespace-label" "WARN" "Low" "Gateway uses 'from: All' (insecure default) -- namespace labels not enforced. Consider hardening to 'from: Selector'."
else
    missing_ns=()
    for ns in redhat-ods-applications "$MAAS_API_NS" models-as-a-service; do
        label=$(oc get namespace "$ns" -o jsonpath='{.metadata.labels.maas\.opendatahub\.io/gateway-access}' 2>/dev/null)
        [ "$label" != "true" ] && missing_ns+=("$ns")
    done
    if [ ${#missing_ns[@]} -eq 0 ]; then
        record "gateway-namespace-label" "PASS" "-" "Required namespaces are labeled maas.opendatahub.io/gateway-access=true"
    else
        record "gateway-namespace-label" "FAIL" "Low" "Missing gateway-access label on: ${missing_ns[*]}"
        if [ "$FIX" = true ]; then
            for ns in "${missing_ns[@]}"; do
                oc label namespace "$ns" maas.opendatahub.io/gateway-access=true --overwrite &>/dev/null
            done
            print_fixed "Labeled namespaces: ${missing_ns[*]}"
        fi
    fi
fi

################################################################################
# Issue 4: Gateway Hostname Discovery (RHOAIENG-89775)
################################################################################
print_step "[4/10] Gateway hostname discovery..."
gw_hostname=$(oc get gateway maas-default-gateway -n openshift-ingress -o jsonpath='{.spec.listeners[0].hostname}' 2>/dev/null)
gw_programmed=$(oc get gateway maas-default-gateway -n openshift-ingress -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
if [ -z "$gw_hostname" ]; then
    record "gateway-hostname-discovery" "FAIL" "High" "Gateway spec.listeners[].hostname is empty -- maas-api /v1/tenants may return 500. Set explicit hostname (see docs/TROUBLESHOOTING.md Issue 4)."
elif [ "$gw_programmed" != "True" ]; then
    record "gateway-hostname-discovery" "AT_RISK" "High" "Gateway hostname set ($gw_hostname) but Programmed != True"
else
    record "gateway-hostname-discovery" "PASS" "-" "Gateway hostname=$gw_hostname, Programmed=True"
fi

################################################################################
# Issue 5: Payload-Processing OOMKill (RHOAIENG-88898)
################################################################################
print_step "[5/10] Payload-processing OOM..."
pp_limit=$(oc get deployment payload-processing -n openshift-ingress -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)
if [ -z "$pp_limit" ]; then
    record "payload-processing-oom" "N/A" "-" "payload-processing deployment not found"
else
    pp_limit_mi=$(echo "$pp_limit" | grep -oE '^[0-9]+')
    pp_unit=$(echo "$pp_limit" | grep -oE '[A-Za-z]+$')
    if [ "$pp_unit" = "Mi" ] && [ "${pp_limit_mi:-0}" -le 256 ] 2>/dev/null; then
        record "payload-processing-oom" "FAIL" "High" "Memory limit is $pp_limit (known-bad default) -- OOMKills under load"
        if [ "$FIX" = true ]; then
            oc annotate deployment payload-processing -n openshift-ingress opendatahub.io/managed=false --overwrite &>/dev/null
            oc set resources deployment payload-processing -n openshift-ingress --limits=memory=1Gi --requests=memory=256Mi &>/dev/null
            oc rollout status deployment payload-processing -n openshift-ingress --timeout=60s &>/dev/null
            print_fixed "payload-processing memory limit -> 1Gi (annotated opendatahub.io/managed=false)"
        fi
    else
        record "payload-processing-oom" "PASS" "-" "Memory limit is $pp_limit (above the risky 256Mi default)"
    fi
fi

################################################################################
# Issue 6: RHCL 1.4.x Rate Limiting and Gateway OOM (RHOAIENG-76586)
################################################################################
print_step "[6/10] RHCL 1.4.x rate limiting / gateway OOM..."
rhcl_csv=$(oc get csv -A --no-headers 2>/dev/null | grep rhcl-operator | head -1 | awk '{print $2}')
gw_deploy=$(oc get deployments -n openshift-ingress -o name 2>/dev/null | grep maas-default-gateway | head -1)
gw_mem=""
[ -n "$gw_deploy" ] && gw_mem=$(oc get "$gw_deploy" -n openshift-ingress -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)
if [[ "$rhcl_csv" == *"1.4."* ]]; then
    if [ "$gw_mem" = "2Gi" ] || [[ "$gw_mem" > "1Gi" ]]; then
        record "rhcl-14x-oom" "PASS" "-" "RHCL $rhcl_csv installed, gateway memory=$gw_mem (sufficient)"
    else
        record "rhcl-14x-oom" "FAIL" "Medium" "RHCL $rhcl_csv installed but gateway memory=${gw_mem:-unset} (< 2Gi recommended). Apply gateway-resources.yaml ConfigMap + parametersRef."
    fi
else
    record "rhcl-14x-oom" "N/A" "-" "RHCL version: ${rhcl_csv:-not found} (not 1.4.x)"
fi

################################################################################
# Issue 7: WASM Auth Timeout Under Load (RHOAIENG-71638)
################################################################################
print_step "[7/10] WASM auth timeout..."
timeout_val=$(oc get subscription rhcl-operator -n openshift-operators -o jsonpath='{.spec.config.env[?(@.name=="AUTH_SERVICE_TIMEOUT")].value}' 2>/dev/null)
if [ -z "$timeout_val" ]; then
    record "wasm-auth-timeout" "FAIL" "Medium" "AUTH_SERVICE_TIMEOUT not set (using risky 200ms default) -- causes HTTP 500/503 under concurrent load"
    if [ "$FIX" = true ]; then
        oc patch subscription rhcl-operator -n openshift-operators --type=merge \
            -p '{"spec":{"config":{"env":[{"name":"AUTH_SERVICE_TIMEOUT","value":"2s"}]}}}' &>/dev/null
        oc wait --for=jsonpath='{.status.state}'=AtLatestKnown subscription/rhcl-operator \
            -n openshift-operators --timeout=120s &>/dev/null || true
        print_fixed "AUTH_SERVICE_TIMEOUT=2s set on rhcl-operator subscription"
    fi
else
    record "wasm-auth-timeout" "PASS" "-" "AUTH_SERVICE_TIMEOUT=$timeout_val"
fi

################################################################################
# Issue 8: Envoy ext_proc Body Corruption (OSSM-15498) -- no workaround exists
################################################################################
print_step "[8/10] Envoy ext_proc body corruption..."
gw_pod=$(oc get pods -n openshift-ingress -l gateway.istio.io/managed=istio.io-gateway-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$gw_pod" ]; then
    record "envoy-extproc-corruption" "N/A" "-" "Gateway pod not found"
else
    envoy_ver=$(oc exec "$gw_pod" -n openshift-ingress -c istio-proxy -- envoy --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -z "$envoy_ver" ]; then
        record "envoy-extproc-corruption" "WARN" "Low" "Could not determine Envoy version -- monitor for ext_proc body corruption (no upstream fix yet, tracked as OSSM-15498)"
    else
        record "envoy-extproc-corruption" "WARN" "Low" "Envoy $envoy_ver detected. No workaround exists for chained ext_proc corruption below 1.37.1 -- tracked as OSSM-15498"
    fi
fi

################################################################################
# Issue 9: Token Rate Limiting Default Too Low (RHOAIENG-89785)
################################################################################
print_step "[9/10] Token rate limiting defaults..."
low_limit_subs=$(oc get maassubscription -A -o json 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    print(0); sys.exit()
count = 0
for item in data.get('items', []):
    for ref in item.get('spec', {}).get('modelRefs', []):
        for trl in ref.get('tokenRateLimits', []):
            limit = trl.get('limit', 0)
            window = trl.get('window', '')
            # Normalize to per-hour equivalent for the '1000/hr' default check
            if window == '1h' and limit <= 1000:
                count += 1
            elif window == '1m' and limit <= 17:  # ~1000/hr
                count += 1
print(count)
" 2>/dev/null || echo 0)
total_subs=$(oc get maassubscription -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$total_subs" -eq 0 ] 2>/dev/null; then
    record "token-rate-limit-default" "N/A" "-" "No MaaSSubscriptions found"
elif [ "${low_limit_subs:-0}" -gt 0 ] 2>/dev/null; then
    record "token-rate-limit-default" "WARN" "Low" "$low_limit_subs of $total_subs subscription(s) use the problematic ~1000 tokens/hr default -- consider raising (see BU Issue 9)"
else
    record "token-rate-limit-default" "PASS" "-" "$total_subs subscription(s), none using the problematic 1000/hr default"
fi

################################################################################
# Issue 10: Duplicate AI Playground Endpoints (RHOAIENG-89786)
################################################################################
print_step "[10/10] Duplicate Playground endpoints (LlamaStackDistribution)..."
lsd_count=$(oc get llamastackdistribution -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
ogx_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.ogx.managementState}' 2>/dev/null)
if [ "${lsd_count:-0}" -gt 0 ] 2>/dev/null && [ "$ogx_state" = "Managed" ]; then
    record "duplicate-playground-endpoints" "FAIL" "Low" "$lsd_count leftover LlamaStackDistribution(s) found with OGX Managed -- may cause duplicate/broken Playground endpoints. Fix: oc delete llamastackdistribution -n <model-ns> --all"
else
    record "duplicate-playground-endpoints" "PASS" "-" "No leftover LlamaStackDistribution found (or OGX not Managed)"
fi

################################################################################
# Output
################################################################################

for r in "${RESULTS[@]}"; do
    IFS='|' read -r _issue status _severity _message <<< "$r"
    case "$status" in
        FAIL) fail_count=$((fail_count + 1)) ;;
        AT_RISK|WARN) warn_count=$((warn_count + 1)) ;;
    esac
done

if [ "$JSON" = true ]; then
    python3 -c "
import json, sys
results = []
for line in sys.argv[1:]:
    parts = line.split('|', 3)
    results.append({'issue': parts[0], 'status': parts[1], 'severity': parts[2], 'message': parts[3]})
print(json.dumps({'rhoai_version': '${RHOAI_VERSION:-unknown}', 'maas_api_namespace': '${MAAS_API_NS}', 'checks': results}, indent=2))
" "${RESULTS[@]}"
else
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  MaaS Diagnostic Summary                                        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    for r in "${RESULTS[@]}"; do
        IFS='|' read -r issue status severity message <<< "$r"
        case "$status" in
            PASS) icon="${GREEN}✓ PASS   ${NC}" ;;
            FAIL) icon="${RED}✗ FAIL   ${NC}" ;;
            AT_RISK) icon="${YELLOW}⚠ AT RISK${NC}" ;;
            WARN) icon="${YELLOW}⚠ WARN   ${NC}" ;;
            N/A) icon="${CYAN}- N/A    ${NC}" ;;
            *) icon="? UNKNOWN" ;;
        esac
        echo -e "$icon [$severity] $issue"
        echo "           $message"
        echo ""
    done
    echo -e "${BLUE}────────────────────────────────────────────────────────────────${NC}"
    echo -e "Failures: ${RED}${fail_count}${NC}  Warnings: ${YELLOW}${warn_count}${NC}  Total checks: ${#RESULTS[@]}"
    if [ "$FIX" = false ] && [ $fail_count -gt 0 ]; then
        echo ""
        echo -e "${CYAN}Re-run with --fix to auto-apply safe fixes (payload-processing OOM, WASM timeout, gateway labels).${NC}"
    fi
    echo ""
fi

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi
exit 0
