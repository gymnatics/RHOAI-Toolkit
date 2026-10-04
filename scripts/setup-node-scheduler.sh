#!/bin/bash
################################################################################
# setup-node-scheduler.sh
#
# Deploys CronJob-based worker node scheduling: scale worker MachineSets up
# during business hours and down outside them. Saves AWS costs on sandbox/demo
# clusters by terminating EC2 instances off-hours.
#
# The 3 control-plane nodes (mastersSchedulable: true) keep the cluster API
# reachable 24/7 — only worker capacity is affected.
#
# Usage:
#   ./scripts/setup-node-scheduler.sh                  # Apply (default 8am-6pm Mon-Fri Asia/Singapore)
#   ./scripts/setup-node-scheduler.sh --trigger up     # Manual: scale workers up now
#   ./scripts/setup-node-scheduler.sh --trigger down   # Manual: scale workers down now
#   ./scripts/setup-node-scheduler.sh --status         # Show CronJob status & next runs
#   ./scripts/setup-node-scheduler.sh --remove         # Remove all node-scheduler resources
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'
}
print_header()  { echo ""; echo -e "${BLUE}== $1 ==${NC}"; }
print_step()    { echo -e "${YELLOW}▶${NC} $*"; }
print_success() { echo -e "${GREEN}✓${NC} $*"; }
print_info()    { echo -e "${CYAN}ℹ${NC} $*"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
print_error()   { echo -e "${RED}✗${NC} $*"; }

MODE="apply"
TRIGGER_ACTION=""
EXTEND_DURATION=""

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --trigger up|down    Manually trigger a scale-up or scale-down right now
  --extend <duration>  Hold off the next scale-down (e.g. 1h, 2h, 30m).
                        The 6 PM CronJob will skip if the hold is still active.
                        Useful when working past normal hours.
  --hold-status        Show whether a hold is currently active
  --cancel-hold        Cancel an active hold (next scale-down proceeds normally)
  --status             Show CronJob status, last run, and current MachineSet state
  --remove             Remove all node-scheduler resources from the cluster
  -h, --help           Show this help

Schedule defaults (edit the CronJob manifests to change):
  Scale up:    8:00 AM Mon-Fri  Asia/Singapore (UTC+8)
  Scale down:  6:00 PM Mon-Fri  Asia/Singapore (UTC+8)
  Weekend:     stays scaled down from Friday 6 PM to Monday 8 AM

Manifests: lib/manifests/node-scheduler/
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --trigger)       MODE="trigger"; TRIGGER_ACTION="$2"; shift 2 ;;
        --extend)        MODE="extend"; EXTEND_DURATION="$2"; shift 2 ;;
        --hold-status)   MODE="hold-status"; shift ;;
        --cancel-hold)   MODE="cancel-hold"; shift ;;
        --status)        MODE="status"; shift ;;
        --remove)        MODE="remove"; shift ;;
        -h|--help)       usage; exit 0 ;;
        *) print_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if ! command -v oc &>/dev/null; then
    print_error "'oc' CLI not found"
    exit 1
fi
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run 'oc login' first."
    exit 1
fi

NS="node-scheduler"

################################################################################
# --extend <duration>  (e.g. 1h, 2h, 30m, 90m)
################################################################################
if [ "$MODE" = "extend" ]; then
    if [ -z "$EXTEND_DURATION" ]; then
        print_error "--extend requires a duration (e.g. 1h, 2h, 30m)"
        exit 1
    fi

    # Parse duration to seconds
    local_val="${EXTEND_DURATION%[hHmM]}"
    local_unit="${EXTEND_DURATION: -1}"
    case "$local_unit" in
        h|H) local_secs=$((local_val * 3600)) ;;
        m|M) local_secs=$((local_val * 60)) ;;
        *)   local_secs=$((EXTEND_DURATION * 60)) ;;  # default to minutes
    esac

    # Calculate holdUntil as UTC ISO-8601 timestamp
    if date -u -d "+${local_secs} seconds" +%Y-%m-%dT%H:%M:%SZ &>/dev/null; then
        hold_until=$(date -u -d "+${local_secs} seconds" +%Y-%m-%dT%H:%M:%SZ)
    else
        hold_until=$(date -u -v+${local_secs}S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
    fi

    if [ -z "$hold_until" ]; then
        print_error "Could not compute hold timestamp from '$EXTEND_DURATION'"
        exit 1
    fi

    oc create configmap node-scheduler-hold \
        --from-literal=holdUntil="$hold_until" \
        -n "$NS" --dry-run=client -o yaml | oc apply -f - >/dev/null

    print_success "Scale-down held until $hold_until (${EXTEND_DURATION} from now)"
    print_info "The 6 PM CronJob will check this and skip if the hold is still active."
    print_info "Cancel early: $0 --cancel-hold"
    exit 0
fi

################################################################################
# --hold-status
################################################################################
if [ "$MODE" = "hold-status" ]; then
    hold_until=$(oc get configmap node-scheduler-hold -n "$NS" \
        -o jsonpath='{.data.holdUntil}' 2>/dev/null || true)
    if [ -z "$hold_until" ]; then
        print_info "No hold is active. The next scale-down will proceed normally."
    else
        now_epoch=$(date -u +%s)
        if date -u -d "$hold_until" +%s &>/dev/null; then
            hold_epoch=$(date -u -d "$hold_until" +%s)
        else
            hold_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$hold_until" +%s 2>/dev/null || echo 0)
        fi
        if [ "$now_epoch" -lt "$hold_epoch" ]; then
            remaining=$(( (hold_epoch - now_epoch) / 60 ))
            print_warning "HOLD ACTIVE — scale-down will be skipped until $hold_until ($remaining min remaining)"
        else
            print_info "Hold expired at $hold_until. Next scale-down will proceed normally."
        fi
    fi
    exit 0
fi

################################################################################
# --cancel-hold
################################################################################
if [ "$MODE" = "cancel-hold" ]; then
    if oc delete configmap node-scheduler-hold -n "$NS" 2>/dev/null; then
        print_success "Hold cancelled. Next scale-down will proceed normally."
    else
        print_info "No hold was active."
    fi
    exit 0
fi

################################################################################
# --status
################################################################################
if [ "$MODE" = "status" ]; then
    print_header "Node Scheduler Status"
    echo -e "${CYAN}CronJobs:${NC}"
    oc get cronjobs -n "$NS" -o wide 2>/dev/null || print_warning "No CronJobs found"
    echo ""
    echo -e "${CYAN}Recent Jobs:${NC}"
    oc get jobs -n "$NS" --sort-by=.metadata.creationTimestamp 2>/dev/null | tail -6 || true
    echo ""
    echo -e "${CYAN}MachineSets:${NC}"
    oc get machinesets -n openshift-machine-api \
        -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.replicas,READY:.status.readyReplicas'
    exit 0
fi

################################################################################
# --remove
################################################################################
if [ "$MODE" = "remove" ]; then
    print_header "Removing Node Scheduler"
    oc delete -k "$ROOT_DIR/lib/manifests/node-scheduler/" --ignore-not-found 2>&1
    print_success "Node scheduler removed"
    print_warning "Worker MachineSets are left at their current replica counts — scale manually if needed."
    exit 0
fi

################################################################################
# --trigger up|down
################################################################################
if [ "$MODE" = "trigger" ]; then
    if [ "$TRIGGER_ACTION" != "up" ] && [ "$TRIGGER_ACTION" != "down" ]; then
        print_error "--trigger requires 'up' or 'down'"
        exit 1
    fi
    if ! oc get namespace "$NS" &>/dev/null 2>&1; then
        print_error "Namespace '$NS' not found. Run this script without flags first to deploy."
        exit 1
    fi

    local_cj="worker-scale${TRIGGER_ACTION}"
    job_name="manual-${TRIGGER_ACTION}-$(date +%s)"
    print_step "Creating manual job from CronJob '$local_cj'..."
    oc create job --from="cronjob/${local_cj}" "$job_name" -n "$NS"
    print_step "Waiting for job to complete..."
    if oc wait --for=condition=complete "job/$job_name" -n "$NS" --timeout=120s 2>&1; then
        echo ""
        oc logs "job/$job_name" -n "$NS" 2>&1
        print_success "Manual scale-${TRIGGER_ACTION} complete"
    else
        print_error "Job did not complete in time. Check logs:"
        oc logs "job/$job_name" -n "$NS" 2>&1
        exit 1
    fi
    oc delete job "$job_name" -n "$NS" 2>/dev/null || true
    exit 0
fi

################################################################################
# apply (default)
################################################################################
print_header "Deploying Node Scheduler"
print_info "Schedule: workers up at 8:00 AM, down at 6:00 PM Mon-Fri (Asia/Singapore)"
echo ""

oc apply -k "$ROOT_DIR/lib/manifests/node-scheduler/"

echo ""
print_success "Node scheduler deployed!"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Node Scheduler Active                             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Scale up:${NC}     8:00 AM Mon-Fri (Asia/Singapore)"
echo -e "  ${CYAN}Scale down:${NC}   6:00 PM Mon-Fri (Asia/Singapore)"
echo -e "  ${CYAN}Weekend:${NC}      scaled down from Fri 6 PM to Mon 8 AM"
echo ""
echo -e "  ${YELLOW}Manual override:${NC}"
echo "    $0 --trigger up       # bring workers online now"
echo "    $0 --trigger down     # take workers offline now"
echo ""
echo -e "  ${YELLOW}Need to work late?${NC}"
echo "    $0 --extend 2h        # hold off scale-down for 2 hours"
echo "    $0 --extend 30m       # hold off scale-down for 30 minutes"
echo "    $0 --hold-status      # check if a hold is active"
echo "    $0 --cancel-hold      # cancel hold, resume normal schedule"
echo ""
echo -e "  ${YELLOW}Check status:${NC}"
echo "    $0 --status"
echo ""
