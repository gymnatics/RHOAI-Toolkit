#!/bin/bash
################################################################################
# check-infra.sh -- cluster / infrastructure readiness for RHOAI (read-only)
#
# Usage: check-infra.sh [--aws] [--json] [--quiet] [--timeout N]
#   --aws   also run scripts/check-aws-prerequisites.sh (pre-install AWS account checks)
#
# Requirements encoded here are from "Installing and uninstalling OpenShift AI Self-Managed 3.5",
# section 3.1 Requirements (docs.redhat.com, lastModified 2026-11-06) -- see reference/expected-state.md.
################################################################################
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
ops_parse_common_flags "$@"
RUN_AWS=false
for a in "${OPS_ARGS[@]}"; do [ "$a" = "--aws" ] && RUN_AWS=true; done

ops_section "Infrastructure checks"

# --- local tools -------------------------------------------------------------
for t in oc jq curl git; do
    if command -v "$t" >/dev/null 2>&1; then
        record infra "tool-$t" PASS "$t found"
    else
        record infra "tool-$t" FAIL "$t not installed" "Required by the toolkit (lib/utils/os-compat.sh check_required_tools)"
    fi
done

if $RUN_AWS; then
    if "$OPS_ROOT_DIR/scripts/check-aws-prerequisites.sh" >/dev/null 2>&1; then
        record infra aws-prereqs PASS "scripts/check-aws-prerequisites.sh passed"
    else
        record infra aws-prereqs FAIL "AWS prerequisite check failed" "Run scripts/check-aws-prerequisites.sh interactively; scripts/diagnose-aws-credentials.sh"
    fi
fi

ops_require_cluster || { ops_summary; exit 1; }

# --- identity ----------------------------------------------------------------
user="$(k whoami)"
if [ "$user" = "kube:admin" ]; then
    record infra cluster-user WARN "Logged in as kube:admin" \
        "RHOAI docs require a cluster-admin user from an identity provider, not kubeadmin (scripts/setup-users.sh; lib/functions/install-common.sh admin user)"
else
    record infra cluster-user PASS "Logged in as $user"
fi
if [ "$(k auth can-i '*' '*' --all-namespaces)" = "yes" ]; then
    record infra cluster-admin PASS "User has cluster-admin"
else
    record infra cluster-admin FAIL "User is not cluster-admin" "Installing RHOAI and most checks need cluster-admin"
fi
idp_count="$(kjq '.spec.identityProviders // [] | length' oauth cluster)"
if [ "${idp_count:-0}" -gt 0 ]; then
    record infra identity-provider PASS "$idp_count identity provider(s) configured"
else
    record infra identity-provider FAIL "No identity provider on oauth/cluster" "Required for RHOAI auth: scripts/setup-users.sh (htpasswd)"
fi

# --- OpenShift version / health ---------------------------------------------
if [ -z "$OCP_VERSION" ]; then
    record infra ocp-version WARN "Could not read ClusterVersion"
else
    # 3.5 Supported Configurations: 4.19.9+ to 4.22; the 3.5 install guide text says 4.19 to 4.20 (doc conflict, SC governs)
    if ver_ge "$OCP_VERSION" "4.19.9" && ! ver_ge "$OCP_MINOR" "4.23"; then
        record infra ocp-version PASS "OpenShift $OCP_VERSION (RHOAI 3.5 SC: 4.19.9 to 4.22)"
    else
        record infra ocp-version FAIL "OpenShift $OCP_VERSION outside RHOAI 3.5 supported range 4.19.9 to 4.22" "Check access.redhat.com/articles/rhoai-supported-configs"
    fi
    ver_ge "$OCP_MINOR" "4.20" || record infra ocp-llmd WARN "OpenShift $OCP_MINOR < 4.20: Distributed Inference with llm-d (and MaaS) requires 4.20+" "Use InferenceService (vLLM) instead, or upgrade OCP"
    ver_ge "$OCP_MINOR" "4.22" || record infra ocp-mcp-lco INFO "OpenShift $OCP_MINOR < 4.22: MCP Lifecycle Operator (TP) requires 4.22+"
    ver_ge "$OCP_MINOR" "4.21" && record infra olmv1-catalog INFO "OCP 4.21+: OLMv1 catalog is on by default (TP); web-console installs of NFD/GPU may redirect to ClusterExtensions. CLI Subscriptions (toolkit default) are unaffected"
fi
cv_failing="$(kjq '[.status.conditions[] | select(.type=="Failing" and .status=="True")] | length' clusterversion version)"
cv_progress="$(kjq '[.status.conditions[] | select(.type=="Progressing" and .status=="True")] | length' clusterversion version)"
[ "${cv_failing:-0}" -gt 0 ] && record infra clusterversion FAIL "ClusterVersion reports Failing" "oc describe clusterversion version"
[ "${cv_progress:-0}" -gt 0 ] && record infra clusterversion WARN "Cluster upgrade in progress"
[ "${cv_failing:-0}" -eq 0 ] && [ "${cv_progress:-0}" -eq 0 ] && record infra clusterversion PASS "ClusterVersion healthy"

degraded="$(kjq '[.items[] | select(any(.status.conditions[]?; (.type=="Degraded" and .status=="True") or (.type=="Available" and .status=="False"))) | .metadata.name] | join(",")' clusteroperators)"
if [ -n "$degraded" ]; then
    record infra clusteroperators FAIL "Degraded/unavailable ClusterOperators: $degraded" "oc get co; restart-cluster-instances.sh after a cluster stop/start"
else
    record infra clusteroperators PASS "All ClusterOperators available"
fi

pending_csr="$(kjq '[.items[] | select((.status.conditions // []) | length == 0)] | length' csr)"
if [ "${pending_csr:-0}" -gt 0 ]; then
    record infra pending-csrs WARN "$pending_csr pending CSR(s)" "scripts/approve-csrs.sh --auto (common after cluster restart)"
else
    record infra pending-csrs PASS "No pending CSRs"
fi

# --- nodes / capacity ---------------------------------------------------------
nodes_json="$(k get nodes -o json)"
not_ready="$(echo "$nodes_json" | jq -r '[.items[] | select(any(.status.conditions[]; .type=="Ready" and .status!="True")) | .metadata.name] | join(",")')"
if [ -n "$not_ready" ]; then
    stopped="$(kjq '[.items[] | select(.metadata.annotations["machine.openshift.io/instance-state"]=="stopped") | .status.nodeRef.name // .metadata.name] | join(",")' machines -n openshift-machine-api)"
    stopped_nr=""; for n in ${not_ready//,/ }; do [[ ",$stopped," == *",$n,"* ]] && stopped_nr+="$n,"; done
    if [ -n "$stopped_nr" ]; then
        record infra nodes-ready FAIL "NotReady because their cloud instances are STOPPED: ${stopped_nr%,}" \
            "Pods on these nodes stay Pending/unavailable (models, DaemonSets -> degraded ClusterOperators). Start them (user approval, costs money): scripts/manage-gpu-nodes.sh start"
    fi
    other="$(for n in ${not_ready//,/ }; do [[ ",$stopped_nr" == *",$n,"* ]] || printf '%s,' "$n"; done)"
    [ -n "$other" ] && record infra nodes-ready FAIL "NotReady nodes: ${other%,}" "oc describe node <name>; scripts/approve-csrs.sh"
fi
[ -z "$not_ready" ] && record infra nodes-ready PASS "All nodes Ready"

# Workers meeting 8 CPU / 32 GiB (requirement: >= 2 such workers; SNO: 32 CPU / 128 GiB)
big_workers="$(echo "$nodes_json" | jq -r '
  def gi: if test("Ki$") then (.[:-2]|tonumber/1048576) elif test("Mi$") then (.[:-2]|tonumber/1024) elif test("Gi$") then (.[:-2]|tonumber) else (tonumber/1073741824) end;
  def cpu: if test("m$") then (.[:-1]|tonumber/1000) else tonumber end;
  [.items[] | select(.metadata.labels["node-role.kubernetes.io/worker"]!=null)
   | select((.status.capacity.cpu|cpu) >= 8 and (.status.capacity.memory|gi) >= 30)] | length')"
node_count="$(echo "$nodes_json" | jq '.items | length')"
if [ "$node_count" -eq 1 ]; then
    record infra capacity INFO "Single-node OpenShift: requires 32 CPU / 128 GiB"
elif [ "${big_workers:-0}" -ge 2 ]; then
    record infra capacity PASS "$big_workers worker(s) with >= 8 CPU / 32 GiB"
else
    record infra capacity FAIL "Only ${big_workers:-0} worker(s) with >= 8 CPU / 32 GiB (need 2)" "Scale a MachineSet: oc scale machineset <name> -n openshift-machine-api --replicas=N"
fi

# --- GPU ----------------------------------------------------------------------
gpu_nodes="$(echo "$nodes_json" | jq -r '[.items[] | select((.status.allocatable["nvidia.com/gpu"] // "0") != "0") | "\(.metadata.name)=\(.status.allocatable["nvidia.com/gpu"])"] | join(",")')"
gpu_labelled="$(echo "$nodes_json" | jq -r '[.items[] | select(.metadata.labels["nvidia.com/gpu.present"]=="true" or .metadata.labels["feature.node.kubernetes.io/pci-10de.present"]=="true") | .metadata.name] | length')"
gpu_ms="$(kjq '[.items[] | select(.metadata.name|test("gpu")) | "\(.metadata.name)=\(.status.readyReplicas // 0)/\(.spec.replicas)"] | join(",")' machinesets -n openshift-machine-api)"
if [ -n "$gpu_nodes" ]; then
    record infra gpu-allocatable PASS "GPU allocatable: $gpu_nodes"
elif [ "${gpu_labelled:-0}" -gt 0 ]; then
    record infra gpu-allocatable FAIL "$gpu_labelled NVIDIA node(s) found but no allocatable nvidia.com/gpu" \
        "GPU Operator not ready: oc get clusterpolicy; oc get pods -n nvidia-gpu-operator; lib/functions/troubleshooting.sh fix_gpu_operator_cuda_compatibility"
elif [ -n "$gpu_ms" ]; then
    record infra gpu-allocatable WARN "No GPU nodes running (GPU MachineSets: $gpu_ms)" "scripts/manage-gpu-nodes.sh start, or oc scale machineset"
else
    record infra gpu-allocatable WARN "No GPU nodes / GPU MachineSets" "GPU demos will not run: scripts/create-gpu-machineset.sh"
fi
if [ -n "$gpu_nodes" ]; then
    untainted="$(echo "$nodes_json" | jq -r '[.items[] | select((.status.allocatable["nvidia.com/gpu"] // "0") != "0") | select(([.spec.taints[]? | select(.key=="nvidia.com/gpu")] | length) == 0) | .metadata.name] | join(",")')"
    if [ -n "$untainted" ]; then
        record infra gpu-taint INFO "GPU nodes without nvidia.com/gpu taint: $untainted (non-GPU pods may land on GPU nodes)"
    else
        record infra gpu-taint PASS "GPU nodes tainted nvidia.com/gpu (HardwareProfiles must tolerate it)"
    fi
fi

# --- GPU contention: Pending GPU pods, who holds the GPUs, stale pods after a restart ----
pods_json="$(k get pods -A -o json)"
gpu_pending="$(echo "$pods_json" | jq -r '[.items[] | select(.status.phase=="Pending")
    | select(any(.spec.containers[]; (.resources.requests["nvidia.com/gpu"] // .resources.limits["nvidia.com/gpu"] // "0") != "0"))
    | "\(.metadata.namespace)/\(.metadata.name)"] | join(",")')"
if [ -n "$gpu_pending" ]; then
    holders="$(echo "$pods_json" | jq -r '[.items[] | select(.spec.nodeName != null and (.status.phase=="Running" or .status.phase=="Unknown"))
        | select(any(.spec.containers[]; (.resources.requests["nvidia.com/gpu"] // .resources.limits["nvidia.com/gpu"] // "0") != "0"))
        | "\(.metadata.namespace)/\(.metadata.name)"] | join(",")')"
    record infra gpu-contention WARN "Pods waiting for a GPU: $(echo "$gpu_pending" | cut -c1-200); GPUs held by: ${holders:-none}" \
        "Free a GPU (stop a workbench/model with user approval) or add GPU nodes; stale holders: scripts/manage-gpu-nodes.sh cleanup"
fi
stale="$(echo "$pods_json" | jq -r '[.items[] | select(.status.phase=="Unknown" or any(.status.containerStatuses[]?, .status.initContainerStatuses[]?; .state.terminated.reason=="ContainerStatusUnknown"))
    | "\(.metadata.namespace)/\(.metadata.name)"] | join(",")')"
[ -n "$stale" ] && record infra stale-pods WARN "Pods in ContainerStatusUnknown/Unknown (left by a node stop; they keep resource requests): $(echo "$stale" | cut -c1-200)" \
    "scripts/manage-gpu-nodes.sh cleanup (deletes them; controllers recreate) - user approval"

# --- storage --------------------------------------------------------------------
default_sc="$(kjq '[.items[] | select(.metadata.annotations["storageclass.kubernetes.io/is-default-class"]=="true") | .metadata.name] | join(",")' storageclass)"
if [ -n "$default_sc" ]; then
    record infra default-storageclass PASS "Default StorageClass: $default_sc"
else
    record infra default-storageclass FAIL "No default StorageClass" "Required by RHOAI; mark one default (oc patch storageclass <n> -p '{\"metadata\":{\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}')"
fi

# --- conflicting installs ----------------------------------------------------
odh="$(kjq '[.items[] | select(.metadata.name|startswith("opendatahub-operator")) | .metadata.name] | join(",")' csv -A)"
if [ -n "$odh" ]; then
    record infra no-odh FAIL "Open Data Hub operator installed ($odh)" "RHOAI requires that ODH is not installed"
else
    record infra no-odh PASS "Open Data Hub not installed"
fi
smcp2="$(kjq '[.items[] | select(.metadata.name|startswith("servicemeshoperator.v2")) | .metadata.name] | join(",")' csv -A)"
[ -n "$smcp2" ] && record infra no-ossm2 WARN "Service Mesh 2 operator present ($smcp2)" "Service Mesh 2 cannot coexist with OCP Gateway API used by RHOAI 3.x"

# --- user workload monitoring (MaaS, llm-d metrics) ----------------------------
uwm="$(k get configmap cluster-monitoring-config -n openshift-monitoring -o jsonpath='{.data.config\.yaml}' | grep -c 'enableUserWorkload: *true')"
if [ "${uwm:-0}" -gt 0 ]; then
    record infra user-workload-monitoring PASS "User Workload Monitoring enabled"
else
    record infra user-workload-monitoring WARN "User Workload Monitoring not enabled" "Required for MaaS and llm-d metrics: lib/manifests/monitoring/ (applied by install-rhoai-35.sh)"
fi

ops_summary
