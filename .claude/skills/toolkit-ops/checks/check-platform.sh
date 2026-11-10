#!/bin/bash
################################################################################
# check-platform.sh -- RHOAI platform state (read-only)
#
# Usage: check-platform.sh [--json] [--quiet] [--timeout N]
#
# Checks: operator Subscriptions/CSVs + channels, pending InstallPlans, DSCI, DSC phase/conditions,
# upgrade gates, every DSC component vs the toolkit manifest for the detected version
# (lib/manifests/rhoai/datasciencecluster-v3-3X.yaml = source of truth), unhealthy pods in RHOAI
# namespaces, version-specific rules (MCP LCO needs OCP 4.22+, Kueue Managed rejected in 3.5,
# trainer needs JobSet), OdhDashboardConfig flags incl. DP-vs-TP labelling, HardwareProfiles,
# Gateway API ingress, dashboard reachability, S3 backends.
################################################################################
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
ops_parse_common_flags "$@"

ops_section "Platform checks (operators, DSC, dashboard, hardware profiles)"
ops_require_cluster || { ops_summary; exit 1; }

# --- operators ---------------------------------------------------------------
# package|purpose|required-for (required = core toolkit install for 3.4/3.5)
EXPECTED_OPERATORS="rhods-operator|RHOAI operator|required
openshift-cert-manager-operator|cert-manager (KServe, llm-d, Kueue)|required
servicemeshoperator3|Service Mesh 3 (OGX, gateway)|required
leader-worker-set|LWS (llm-d multi-node)|required
rhcl-operator|Connectivity Link (MaaS, llm-d auth)|maas
nfd|Node Feature Discovery|gpu
gpu-operator-certified|NVIDIA GPU Operator|gpu
kueue-operator|Red Hat build of Kueue|optional
jobset-operator|JobSet (Trainer v2)|optional
cluster-observability-operator|COO (Perses dashboards, observability)|optional"

subs_json="$(k get subscriptions.operators.coreos.com -A -o json)"
csv_json="$(k get csv -A -o json)"
while IFS='|' read -r pkg purpose need; do
    sub="$(echo "$subs_json" | jq -c --arg p "$pkg" '[.items[] | select(.spec.name==$p)][0] // empty')"
    if [ -z "$sub" ]; then
        case "$need" in
            required) record operators "$pkg" FAIL "$purpose not subscribed" "scripts/install-rhoai-35.sh installs it (lib/functions/operators.sh)" ;;
            maas|gpu) record operators "$pkg" WARN "$purpose not subscribed (needed for $need)" ;;
            *)        record operators "$pkg" SKIP "$purpose not installed (optional)" ;;
        esac
        continue
    fi
    ns="$(echo "$sub" | jq -r .metadata.namespace)"
    channel="$(echo "$sub" | jq -r .spec.channel)"
    installed="$(echo "$sub" | jq -r '.status.installedCSV // empty')"
    phase="$(echo "$csv_json" | jq -r --arg n "$installed" --arg ns "$ns" '[.items[] | select(.metadata.name==$n and .metadata.namespace==$ns)][0].status.phase // "missing"')"
    if [ "$phase" = "Succeeded" ]; then
        record operators "$pkg" PASS "$installed (channel $channel) Succeeded"
    else
        record operators "$pkg" FAIL "$purpose CSV ${installed:-<none>} phase=$phase (channel $channel)" \
            "scripts/check-operator-install-status.sh; scripts/check-pending-installplans.sh"
    fi
    # Channel rules
    if [ "$pkg" = "rhods-operator" ] && [ "$channel" = "fast-3.x" ]; then
        record operators rhods-channel FAIL "RHOAI subscribed to fast-3.x, which is frozen at 3.3.1" \
            "Use stable-3.5 / eus-3.5 (TRK in docs/COMPATIBILITY-TRACKER.md: install-rhoai-3{4,5}.sh fast-3.x fallback)"
    fi
    if [ "$pkg" = "rhcl-operator" ]; then
        v="$(echo "$installed" | sed -E 's/.*\.v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
        if [[ "$v" =~ ^1\.4\.0$ ]]; then
            record operators rhcl-version FAIL "RHCL $v is deprecated (auth failures, gateway instability)" "Upgrade to RHCL 1.4.1+ (TOOLKIT-CONTEXT Critical Gotchas)"
        elif [[ "$v" =~ ^1\.4\. ]]; then
            record operators rhcl-version WARN "RHCL $v: RHOAIENG-76586 (1.4.x rate limiting / gateway OOM) applies" "scripts/diagnose-maas.sh Issue 6"
        fi
    fi
    if [ "$pkg" = "kueue-operator" ] && [ "$channel" != "stable-v1.3" ]; then
        record operators kueue-channel WARN "Kueue channel $channel: Trainer v2 only works with Kueue 1.3 (RHOAIENG-87625)"
    fi
done <<< "$EXPECTED_OPERATORS"

pending_ip="$(k get installplan -A -o json | jq -r '[.items[] | select(.spec.approved==false) | "\(.metadata.namespace)/\(.metadata.name)"] | join(",")')"
if [ -n "$pending_ip" ]; then
    record operators pending-installplans WARN "Unapproved InstallPlans: $pending_ip" "scripts/check-pending-installplans.sh (approve only if expected)"
else
    record operators pending-installplans PASS "No unapproved InstallPlans"
fi

if [ -z "$RHOAI_CSV_VERSION" ]; then
    record platform rhoai-installed FAIL "RHOAI operator CSV not found in redhat-ods-operator" "Run scripts/install-rhoai-35.sh"
    ops_summary; exit 1
fi
record platform rhoai-version INFO "RHOAI $RHOAI_CSV_VERSION on OpenShift $OCP_VERSION"
case "$RHOAI_MM" in
    3.5) : ;;
    3.4) record platform rhoai-lifecycle WARN "RHOAI 3.4 full support ends 2026-11-16" "Plan upgrade to 3.5 (EUS)";;
    3.3) record platform rhoai-lifecycle FAIL "RHOAI 3.3 is end of life (2026-10-05)" "Upgrade to 3.5";;
    3.6) record platform rhoai-lifecycle WARN "RHOAI 3.6 detected: toolkit has no 3.6 support yet (DSC v3, removed components)" "See TOOLKIT-CONTEXT 3.6 EA preview; /rhoai-version-bump 3.6";;
esac

# --- DSCI / DSC ----------------------------------------------------------------
dsci_phase="$(kjq '.items[0].status.phase // empty' dscinitialization)"
if [ "$dsci_phase" = "Ready" ]; then record platform dsci PASS "DSCInitialization Ready"
else record platform dsci FAIL "DSCInitialization phase=${dsci_phase:-missing}" "oc describe dsci"; fi

dsc_json="$(k get datasciencecluster -o json | jq '.items[0] // empty')"
if [ -z "$dsc_json" ]; then
    record platform dsc FAIL "No DataScienceCluster" "install-rhoai-35.sh creates it from lib/manifests/rhoai/datasciencecluster-v3-35.yaml"
    ops_summary; exit 1
fi
dsc_name="$(echo "$dsc_json" | jq -r .metadata.name)"
dsc_phase="$(echo "$dsc_json" | jq -r '.status.phase // empty')"
reconcile="$(echo "$dsc_json" | jq -r '[.status.conditions[]? | select(.type=="ReconcileComplete")][0].status // empty')"
if [ "$dsc_phase" = "Ready" ]; then
    record platform dsc-phase PASS "DSC $dsc_name phase Ready"
else
    msg="$(echo "$dsc_json" | jq -r '[.status.conditions[]? | select(.type=="Ready")][0].message // ""' | cut -c1-200)"
    record platform dsc-phase FAIL "DSC $dsc_name phase=${dsc_phase:-?} $msg" "oc describe dsc $dsc_name; see per-component results below"
fi
[ -n "$reconcile" ] && { [ "$reconcile" = "True" ] && record platform dsc-reconcile PASS "ReconcileComplete=True" || record platform dsc-reconcile WARN "ReconcileComplete=$reconcile"; }
gate="$(echo "$dsc_json" | jq -r '[.status.conditions[]? | select(.type=="ProvisioningProgress" and .reason=="AdminAckRequired")] | length')"
if [ "${gate:-0}" -gt 0 ]; then
    unacked="$(k get configmap odh-upgrade-acks -n redhat-ods-operator -o json | jq -r '[.data // {} | to_entries[] | select(.value!="true") | .key] | join(",")')"
    record platform upgrade-gates FAIL "Upgrade gates block provisioning (AdminAckRequired): ${unacked:-see odh-upgrade-acks}" \
        "Complete each gate's remediation FIRST, then ack (Upgrading OpenShift AI 3.5 ch.7). Never bulk-ack."
fi

# Expected component states from the toolkit manifest for this version
case "$RHOAI_MM" in
    3.5) dsc_manifest="lib/manifests/rhoai/datasciencecluster-v3-35.yaml" ;;
    3.4) dsc_manifest="lib/manifests/rhoai/datasciencecluster-v3-34.yaml" ;;
    *)   dsc_manifest="" ;;
esac
expected=""
if [ -n "$dsc_manifest" ] && [ -f "$OPS_ROOT_DIR/$dsc_manifest" ]; then
    expected="$(awk '/^  components:/{c=1;next} c&&/^  [a-z]/{c=0} c&&/^    [a-z][a-zA-Z]*:$/{comp=$1; sub(":","",comp)} c&&/^      managementState:/{print comp"="$2}' "$OPS_ROOT_DIR/$dsc_manifest")"
fi
conds="$(echo "$dsc_json" | jq -c '[.status.conditions[]? | {t:(.type|ascii_downcase), s:.status, m:(.message // "")}]')"
for comp in $(echo "$dsc_json" | jq -r '.spec.components | keys[]'); do
    live="$(echo "$dsc_json" | jq -r --arg c "$comp" '.spec.components[$c].managementState // "unset"')"
    want="$(echo "$expected" | awk -F= -v c="$comp" '$1==c{print $2}')"
    installed="$(echo "$dsc_json" | jq -r --arg c "$comp" '.status.installedComponents[$c] // empty')"
    cond="$(echo "$conds" | jq -r --arg c "${comp}ready" '[.[] | select(.t==$c)][0] | if . then "\(.s)|\(.m)" else empty end')"
    if [ -n "$want" ] && [ "$want" != "$live" ]; then
        record dsc "$comp" WARN "managementState=$live but toolkit manifest ($dsc_manifest) says $want" "Drift from source of truth: re-apply manifest or document why"
    fi
    if [ "$live" = "Managed" ]; then
        if [ "${cond%%|*}" = "False" ]; then
            record dsc "$comp" FAIL "Managed but ${comp}Ready=False: ${cond#*|}" "oc get pods -n redhat-ods-applications | grep -i ${comp}; then /rhoai-knowledge for the component prerequisites"
        elif [ "$installed" = "false" ]; then
            record dsc "$comp" FAIL "Managed but status.installedComponents.$comp=false"
        else
            record dsc "$comp" PASS "Managed${cond:+, ready=${cond%%|*}}"
        fi
    else
        record dsc "$comp" INFO "$live"
    fi
done

# Version-specific component rules (sources: reference/expected-state.md)
mcp_state="$(echo "$dsc_json" | jq -r '.spec.components.mcplifecycleoperator.managementState // "unset"')"
if [ "$mcp_state" = "Managed" ] && ! ver_ge "$OCP_MINOR" "4.22"; then
    record dsc mcplifecycleoperator-ocp FAIL "mcplifecycleoperator Managed on OCP $OCP_MINOR; docs require OpenShift 4.22+ (TP)" \
        "Set to Removed on <4.22 (Working with the MCP catalog 3.5 §2.3). Toolkit sets Managed in datasciencecluster-v3-35.yaml"
fi
kueue_state="$(echo "$dsc_json" | jq -r '.spec.components.kueue.managementState // "unset"')"
# Managing OpenShift AI 3.5 ch.8: Managed (embedded Kueue) is deprecated; with the Red Hat build of Kueue
# operator also installed, OpenShift AI stops reconciliation. Unmanaged requires that operator.
if [ "$kueue_state" = "Managed" ]; then
    if echo "$subs_json" | jq -e '.items[] | select(.spec.name=="kueue-operator")' >/dev/null; then
        record dsc kueue-state FAIL "kueue Managed AND kueue-operator installed: OpenShift AI stops reconciliation (conflicting controllers)" \
            "Migrate: set Removed, then Unmanaged (Upgrading OpenShift AI 3.5 ch.5.1 'Migrating from embedded Kueue')"
    else
        record dsc kueue-state WARN "kueue Managed (embedded Kueue) is deprecated" "Migrate to Unmanaged + Red Hat build of Kueue operator"
    fi
fi
if [ "$kueue_state" = "Unmanaged" ] && ! echo "$subs_json" | jq -e '.items[] | select(.spec.name=="kueue-operator")' >/dev/null; then
    record dsc kueue-operator FAIL "kueue Unmanaged but kueue-operator not installed" "lib/manifests/operators/kueue-subscription.yaml"
fi
trainer_state="$(echo "$dsc_json" | jq -r '.spec.components.trainer.managementState // "unset"')"
if [ "$trainer_state" = "Managed" ] && ! echo "$subs_json" | jq -e '.items[] | select(.spec.name=="jobset-operator")' >/dev/null; then
    record dsc trainer-jobset FAIL "trainer Managed but JobSet operator not installed" "lib/manifests/operators/jobset-subscription.yaml"
fi

# --- unhealthy pods in RHOAI namespaces ------------------------------------------
for ns in redhat-ods-operator redhat-ods-applications redhat-ods-monitoring redhat-ai-gateway-infra; do
    k get ns "$ns" >/dev/null || continue
    pj="$(k get pods -n "$ns" -o json)"
    bad="$(echo "$pj" | jq -r '[.items[] | select(.status.phase!="Running" and .status.phase!="Succeeded") | "\(.metadata.name)(\(.status.phase))"] + [.items[] | select(.status.phase=="Running") | select(any(.status.containerStatuses[]?; .ready==false)) | "\(.metadata.name)(notready)"] | unique | join(",")')"
    restarty="$(echo "$pj" | jq -r '[.items[] | select(.status.phase=="Running") | ([.status.containerStatuses[]? | .restartCount] | max // 0) as $r | select($r > 5) | "\(.metadata.name)(\($r), last: \([.status.containerStatuses[]?.lastState.terminated.reason // empty] | first // "?"))"] | join(",")')"
    if [ -n "$bad" ]; then
        record pods "$ns" FAIL "Unhealthy pods: $(echo "$bad" | cut -c1-300)" "oc describe pod -n $ns <pod>; oc logs -n $ns <pod> --previous"
    else
        record pods "$ns" PASS "All pods Running and Ready"
    fi
    [ -n "$restarty" ] && record pods "$ns-restarts" WARN "Ready but restarted often: $(echo "$restarty" | cut -c1-300)" "oc logs -n $ns <pod> --previous (OOMKilled -> limits; Error -> logs)"
done

# --- dashboard ----------------------------------------------------------------------
dcfg="$(k get odhdashboardconfig odh-dashboard-config -n redhat-ods-applications -o json)"
if [ -z "$dcfg" ]; then
    record dashboard config FAIL "OdhDashboardConfig odh-dashboard-config not found"
else
    flags="$(echo "$dcfg" | jq -c '.spec.dashboardConfig // {}')"
    # DP per 3.5 release notes ch.4 (TRK-001: toolkit enables these under a TP label)
    for f in agentsCatalog agentConfigManagement agentOpsDeploy; do
        [ "$(echo "$flags" | jq -r --arg f "$f" '.[$f] // false')" = "true" ] && \
            record dashboard "flag-$f" WARN "$f=true is a Developer Preview feature (unsupported)" "Label as DP to users; TRK-001 in docs/COMPATIBILITY-TRACKER.md"
    done
    if [ "$RHOAI_MM" = "3.5" ] && [ "$(echo "$flags" | jq -r 'has("maasAuthPolicies")')" = "true" ]; then
        record dashboard flag-maasAuthPolicies FAIL "maasAuthPolicies set on 3.5 (removed; CEL webhook rejects updates)" "Remove the field"
    fi
    [ "$(echo "$flags" | jq -r 'has("mlflow")')" = "true" ] && record dashboard flag-mlflow INFO "mlflow flag is deprecated since 3.4 (MLflow follows DSC mlflowoperator)"
    # Toolkit-expected flags (lib/manifests/rhoai/odh-dashboard-config-patch.yaml)
    missing=""
    while read -r key val; do
        if ! ver_ge "$RHOAI_MM" "3.5" && [[ " agentsCatalog agentOps agentConfigManagement gpuaas " == *" $key "* ]]; then continue; fi
        live="$(echo "$flags" | jq -r --arg f "$key" 'if has($f) then .[$f]|tostring else "unset" end')"
        [ "$live" != "$val" ] && missing+="$key=$live(want $val) "
    done < <(awk '/^  dashboardConfig:/{c=1;next} c&&/^    [a-zA-Z]+: (true|false)$/{gsub(":","",$1); print $1, $2}' "$OPS_ROOT_DIR/lib/manifests/rhoai/odh-dashboard-config-patch.yaml")
    if [ -n "$missing" ]; then
        record dashboard flags WARN "Differs from toolkit patch: $missing" "scripts/enable-dashboard-features.sh (or flags intentionally changed)"
    else
        record dashboard flags PASS "Dashboard flags match lib/manifests/rhoai/odh-dashboard-config-patch.yaml"
    fi
fi
dash_url="$(get_dashboard_url 2>/dev/null | tail -1)"
if [ -n "$dash_url" ] && ! [[ "$dash_url" =~ ^https?://[^/.]+\.[^/]+\.[^/]+ ]]; then
    record dashboard reachable FAIL "Malformed dashboard URL '$dash_url' (cluster domain not resolved)" "oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'"
elif [ -n "$dash_url" ]; then
    code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 15 "$dash_url")"
    case "$code" in
        200|302|303|401|403) record dashboard reachable PASS "$dash_url -> HTTP $code" ;;
        *) record dashboard reachable FAIL "$dash_url -> HTTP ${code:-timeout}" "oc get gateway -A; oc get httproute -n redhat-ods-applications" ;;
    esac
fi

# --- Gateway API ingress --------------------------------------------------------------
gw="$(k get gateway -A -o json | jq -r '[.items[] | "\(.metadata.namespace)/\(.metadata.name)=\([.status.conditions[]? | select(.type=="Programmed")][0].status // "?")"] | join(",")')"
if [ -z "$gw" ]; then
    record gateway gateways WARN "No Gateway API gateways found"
elif echo "$gw" | grep -q '=False\|=?'; then
    record gateway gateways FAIL "Gateways not Programmed: $gw" "oc describe gateway -n <ns> <name>; scripts/fix-kuadrant-istio.sh"
else
    record gateway gateways PASS "Gateways Programmed: $gw"
fi

# --- hardware profiles -------------------------------------------------------------------
hwp="$(k get hardwareprofiles.infrastructure.opendatahub.io -A -o json)"
total="$(echo "$hwp" | jq '.items | length')"
if [ "${total:-0}" -eq 0 ]; then
    record hwprofile present WARN "No HardwareProfiles" "scripts/create-hardware-profile-quick.sh --all"
else
    bad="$(echo "$hwp" | jq -r '[.items[] | select(any(.spec.identifiers[]?; .identifier=="nvidia.com/gpu"))
        | select(([.spec.scheduling.node.tolerations[]? | select(.key=="nvidia.com/gpu" and .operator=="Exists" and ((.value // "") == ""))] | length) == 0)
        | "\(.metadata.namespace)/\(.metadata.name)"] | join(",")')"
    gpu_total="$(echo "$hwp" | jq '[.items[] | select(any(.spec.identifiers[]?; .identifier=="nvidia.com/gpu"))] | length')"
    kueue_ns="$(k get ns -l kueue.openshift.io/managed=true -o json | jq -r '[.items[].metadata.name] | join(",")')"
    if [ -n "$kueue_ns" ]; then
        record hwprofile kueue-namespaces INFO "Kueue-managed namespaces ($kueue_ns): workloads there need a hardware profile with a local queue, not node selectors/tolerations" \
            "Managing OpenShift AI 3.5 ch.8 restrictions; toolkit gpu-profile uses tolerations"
    fi
    if [ -n "$bad" ]; then
        record hwprofile gpu-tolerations FAIL "GPU profiles without nvidia.com/gpu Exists toleration (empty value): $bad" \
            "scripts/fix-hardware-profile.sh; TROUBLESHOOTING 'HardwareProfile toleration value must be empty'"
    else
        record hwprofile gpu-tolerations PASS "$total profile(s), $gpu_total GPU profile(s) tolerate nvidia.com/gpu"
    fi
fi

# --- S3 backends -------------------------------------------------------------------------
s3="$(k get deploy -A -o json | jq -r '[.items[] | select(.metadata.name|test("^(seaweedfs|minio)")) | "\(.metadata.namespace)/\(.metadata.name)=\(.status.readyReplicas // 0)/\(.spec.replicas)"] | join(",")')"
if [ -z "$s3" ]; then
    record storage s3-backend INFO "No in-cluster SeaweedFS/MinIO (pipelines, model storage, AutoRAG need S3)" "scripts/setup-model-storage.sh --backend seaweedfs"
elif echo "$s3" | grep -qE '=0/'; then
    record storage s3-backend FAIL "S3 backend not ready: $s3" "scripts/manage-storage.sh"
else
    record storage s3-backend PASS "S3 backends: $s3"
fi

ops_summary
