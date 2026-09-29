#!/bin/bash
################################################################################
# manage-gpu-nodes.sh
#
# Stop/start the underlying AWS EC2 instances behind GPU MachineSets directly,
# instead of scaling the MachineSet to 0/N (which DELETES the Machine and
# EC2 instance, then provisions a brand-new one from scratch on scale-up).
#
# Why this matters: `oc scale machineset --replicas=0` (what
# setup-node-scheduler.sh and the node-scheduler CronJobs do) is fine for
# regular virtualized workers, but for GPU nodes -- especially bare metal
# types like g4dn.metal -- scaling back up means a full fresh boot: PXE/
# hardware allocation, RHCOS ignition, cluster join, NFD discovery, GPU
# Operator driver/toolkit reinitialization, etc. That can take 15-30+
# minutes and, if the node belongs to a custom MachineConfigPool, can
# trigger unrelated MCO churn.
#
# AWS EC2 stop/start instead preserves the EBS root volume, instance ID,
# and node identity -- on start, the same node rejoins in a couple of
# minutes with all prior state (kubelet certs, GPU driver install, etc.)
# intact. No Machine deletion/recreation, no MCO involvement at all.
#
# CAVEATS:
#   - Any LOCAL INSTANCE-STORE (ephemeral NVMe) data is wiped on stop --
#     this only affects ephemeral scratch storage, not the EBS root volume.
#   - Some older/specialized bare metal instance types historically could
#     not be stopped (only rebooted or terminated) due to Nitro hardware
#     allocation guarantees. This script surfaces the AWS API error
#     verbatim if a stop/start call is rejected for that reason.
#   - This script talks to AWS directly (via the `aws` CLI you already
#     have configured), NOT through the OpenShift Machine API. The Machine
#     object is left completely alone -- only the EC2 instance's power
#     state changes.
#
# Usage:
#   ./scripts/manage-gpu-nodes.sh status                       # show state of all GPU nodes
#   ./scripts/manage-gpu-nodes.sh stop                          # stop all GPU instances (all *gpu* MachineSets)
#   ./scripts/manage-gpu-nodes.sh start                         # start all GPU instances, wait for Ready
#   ./scripts/manage-gpu-nodes.sh start --machineset <name>      # only that MachineSet's machines
#   ./scripts/manage-gpu-nodes.sh stop --no-wait                 # fire-and-forget, don't block
#   ./scripts/manage-gpu-nodes.sh start --timeout 900             # cap the Ready-wait at 900s
################################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
}
print_header()  { echo ""; echo -e "${BLUE}== $1 ==${NC}"; }
print_step()    { echo -e "${YELLOW}-> $*${NC}"; }
print_success() { echo -e "${GREEN}[OK] $*${NC}"; }
print_info()    { echo -e "${CYAN}[INFO] $*${NC}"; }
print_warning() { echo -e "${YELLOW}[WARN] $*${NC}"; }
print_error()   { echo -e "${RED}[ERROR] $*${NC}"; }

usage() {
    sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
}

ACTION="${1:-}"
shift || true

MACHINESET_FILTER=""
WAIT=true
TIMEOUT=1800

while [[ $# -gt 0 ]]; do
    case $1 in
        --machineset)  MACHINESET_FILTER="$2"; shift 2 ;;
        --no-wait)     WAIT=false; shift ;;
        --timeout)     TIMEOUT="$2"; shift 2 ;;
        -h|--help)     usage; exit 0 ;;
        *) print_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if [[ "$ACTION" != "status" && "$ACTION" != "stop" && "$ACTION" != "start" ]]; then
    usage
    exit 1
fi

for bin in oc aws jq; do
    if ! command -v "$bin" &>/dev/null; then
        print_error "'$bin' CLI not found. Please install it first."
        exit 1
    fi
done
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run 'oc login' first."
    exit 1
fi
if ! aws sts get-caller-identity &>/dev/null; then
    print_error "AWS CLI is not authenticated. Configure credentials for the account hosting this cluster."
    exit 1
fi

################################################################################
# Discover target Machines: those in MachineSets matching the filter
# (default: any MachineSet with "gpu" in its name -- same convention used
# by lib/manifests/node-scheduler/scale-script-configmap.yaml).
################################################################################
get_target_machinesets() {
    if [ -n "$MACHINESET_FILTER" ]; then
        echo "$MACHINESET_FILTER"
    else
        oc get machinesets -n openshift-machine-api -o jsonpath='{.items[*].metadata.name}' 2>/dev/null \
            | tr ' ' '\n' | grep -i gpu || true
    fi
}

# Returns TSV: machineset<TAB>machine<TAB>instanceId<TAB>az<TAB>region
get_target_machines() {
    local ms
    for ms in $(get_target_machinesets); do
        oc get machines -n openshift-machine-api \
            -l "machine.openshift.io/cluster-api-machineset=${ms}" \
            -o json 2>/dev/null | jq -r --arg ms "$ms" '
                .items[] | select(.spec.providerID != null) |
                (.spec.providerID | split("/")) as $p |
                [$ms, .metadata.name, $p[-1], $p[-2], .spec.providerSpec.value.placement.region] | @tsv
            '
    done
}

get_region() {
    oc get machines -n openshift-machine-api -o jsonpath='{.items[0].spec.providerSpec.value.placement.region}' 2>/dev/null
}

instance_state() {
    local instance_id="$1" region="$2"
    aws ec2 describe-instances --region "$region" --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null
}

node_for_instance() {
    local instance_id="$1"
    oc get nodes -o json 2>/dev/null | jq -r --arg id "$instance_id" \
        '.items[] | select(.spec.providerID | endswith($id)) | .metadata.name'
}

################################################################################
# status
################################################################################
do_status() {
    print_header "GPU Node Status (AWS instance power state, not just OpenShift)"
    local region
    region=$(get_region)
    printf "%-45s %-22s %-20s %-14s %-10s\n" "MACHINESET" "MACHINE" "NODE" "INSTANCE" "AWS-STATE"
    local found=false
    while IFS=$'\t' read -r ms machine instance_id az mregion; do
        [ -z "$machine" ] && continue
        found=true
        local r="${mregion:-$region}"
        local state node ready
        state=$(instance_state "$instance_id" "$r")
        node=$(node_for_instance "$instance_id")
        if [ -n "$node" ]; then
            ready=$(oc get node "$node" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            [ "$ready" = "True" ] && node="$node (Ready)" || node="$node (NotReady)"
        else
            node="(no Node - not joined)"
        fi
        printf "%-45s %-22s %-20s %-14s %-10s\n" "$ms" "$machine" "$node" "$instance_id" "${state:-unknown}"
    done < <(get_target_machines)
    if [ "$found" = false ]; then
        print_warning "No GPU MachineSets found (looked for MachineSets with 'gpu' in the name; use --machineset to target a specific one)"
    fi
}

################################################################################
# stop
################################################################################
do_stop() {
    print_header "Stopping GPU EC2 instances (Machine objects are left intact)"
    local any=false
    while IFS=$'\t' read -r ms machine instance_id az mregion; do
        [ -z "$machine" ] && continue
        any=true
        local r="${mregion:-$(get_region)}"
        local state
        state=$(instance_state "$instance_id" "$r")
        if [ "$state" = "stopped" ] || [ "$state" = "stopping" ]; then
            print_info "$machine ($instance_id) already $state, skipping"
            continue
        fi
        if [ "$state" != "running" ]; then
            print_warning "$machine ($instance_id) is '$state' (not running), skipping"
            continue
        fi
        print_step "Stopping $machine ($instance_id) in $r..."
        if aws ec2 stop-instances --region "$r" --instance-ids "$instance_id" --output text 2>&1 | sed 's/^/    /'; then
            print_success "Stop requested for $instance_id"
        else
            print_error "Failed to stop $instance_id -- see AWS error above (some bare metal types cannot be stopped, only terminated)"
        fi
    done < <(get_target_machines)

    if [ "$any" = false ]; then
        print_warning "No matching GPU machines found."
        return
    fi

    if [ "$WAIT" = true ]; then
        print_step "Waiting for instances to report 'stopped' (timeout ${TIMEOUT}s)..."
        local elapsed=0
        while [ $elapsed -lt "$TIMEOUT" ]; do
            local all_stopped=true
            while IFS=$'\t' read -r ms machine instance_id az mregion; do
                [ -z "$machine" ] && continue
                local r="${mregion:-$(get_region)}"
                local state
                state=$(instance_state "$instance_id" "$r")
                [ "$state" != "stopped" ] && all_stopped=false
            done < <(get_target_machines)
            [ "$all_stopped" = true ] && { print_success "All targeted instances are stopped"; return; }
            sleep 15
            elapsed=$((elapsed + 15))
            echo "   ...waited ${elapsed}s"
        done
        print_warning "Timeout waiting for all instances to stop (check 'status')"
    fi
}

################################################################################
# start
################################################################################
do_start() {
    print_header "Starting GPU EC2 instances (same Machine/Node identity as before stop)"
    local any=false
    declare -a started_ids=()
    while IFS=$'\t' read -r ms machine instance_id az mregion; do
        [ -z "$machine" ] && continue
        any=true
        local r="${mregion:-$(get_region)}"
        local state
        state=$(instance_state "$instance_id" "$r")
        if [ "$state" = "running" ] || [ "$state" = "pending" ]; then
            print_info "$machine ($instance_id) already $state, skipping"
            continue
        fi
        if [ "$state" != "stopped" ]; then
            print_warning "$machine ($instance_id) is '$state' (not stopped) -- if this is 'terminated' or the instance is missing entirely, the Machine was deleted and needs a fresh MachineSet scale-up instead (see scripts/create-gpu-machineset.sh), not start-instances."
            continue
        fi
        print_step "Starting $machine ($instance_id) in $r..."
        if aws ec2 start-instances --region "$r" --instance-ids "$instance_id" --output text 2>&1 | sed 's/^/    /'; then
            print_success "Start requested for $instance_id"
            started_ids+=("$instance_id:$r")
        else
            print_error "Failed to start $instance_id -- see AWS error above"
        fi
    done < <(get_target_machines)

    if [ "$any" = false ]; then
        print_warning "No matching GPU machines found."
        return
    fi

    if [ "$WAIT" = true ] && [ ${#started_ids[@]} -gt 0 ]; then
        print_step "Waiting for instances to report AWS state 'running' (timeout ${TIMEOUT}s)..."
        local elapsed=0
        while [ $elapsed -lt "$TIMEOUT" ]; do
            local all_running=true
            local pair
            for pair in "${started_ids[@]}"; do
                local id="${pair%%:*}" r="${pair##*:}"
                local state
                state=$(instance_state "$id" "$r")
                [ "$state" != "running" ] && all_running=false
            done
            [ "$all_running" = true ] && break
            sleep 15
            elapsed=$((elapsed + 15))
            echo "   ...waited ${elapsed}s (AWS instance state)"
        done

        print_step "Waiting for the corresponding Node(s) to report Ready (timeout ${TIMEOUT}s)..."
        elapsed=0
        while [ $elapsed -lt "$TIMEOUT" ]; do
            local all_ready=true
            local pair
            for pair in "${started_ids[@]}"; do
                local id="${pair%%:*}"
                local node ready
                node=$(node_for_instance "$id")
                if [ -z "$node" ]; then
                    all_ready=false
                    continue
                fi
                ready=$(oc get node "$node" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
                [ "$ready" != "True" ] && all_ready=false
            done
            [ "$all_ready" = true ] && { print_success "All targeted nodes are Ready"; return; }
            sleep 15
            elapsed=$((elapsed + 15))
            echo "   ...waited ${elapsed}s (Node Ready)"
        done
        print_warning "Timeout waiting for Nodes to become Ready (check 'status'; this can take longer for bare metal on first boot after a long stop)"
    fi
}

case "$ACTION" in
    status) do_status ;;
    stop)   do_stop ;;
    start)  do_start ;;
esac
