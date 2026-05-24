#!/usr/bin/env bash
################################################################################
# restart-cluster-instances.sh
#
# Gracefully stop and start all OpenShift cluster EC2 instances.
# Detects the cluster's infra ID from metadata or running instances.
#
# Usage:
#   ./scripts/restart-cluster-instances.sh          # stop → start (default)
#   ./scripts/restart-cluster-instances.sh stop      # stop only
#   ./scripts/restart-cluster-instances.sh start     # start only
#   ./scripts/restart-cluster-instances.sh status    # show instance status
#
# Environment:
#   AWS_REGION   Override region (auto-detected from metadata if not set)
################################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Support running from project root or scripts/ subdirectory
if [ -f "$SCRIPT_DIR/openshift-cluster-install/metadata.json" ]; then
    BASE_DIR="$SCRIPT_DIR"
elif [ -f "$SCRIPT_DIR/../openshift-cluster-install/metadata.json" ]; then
    BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    BASE_DIR="$SCRIPT_DIR"
fi
METADATA_FILE="$BASE_DIR/openshift-cluster-install/metadata.json"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${CYAN}▶ $1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $1${NC}"; }
error()   { echo -e "${RED}✗ $1${NC}"; }

detect_cluster() {
    local infra_id="" region=""

    if [ -f "$METADATA_FILE" ]; then
        infra_id=$(jq -r '.infraID // empty' "$METADATA_FILE" 2>/dev/null)
        region=$(jq -r '.aws.region // empty' "$METADATA_FILE" 2>/dev/null)
    fi

    if [ -z "$infra_id" ]; then
        warn "metadata.json not found, detecting from AWS tags..."
        infra_id=$(aws ec2 describe-instances \
            --filters "Name=tag:Name,Values=openshift-cluster-*" "Name=instance-state-name,Values=running,stopped" \
            --query 'Reservations[0].Instances[0].Tags[?Key==`Name`].Value | [0]' \
            --output text 2>/dev/null | sed 's/\(openshift-cluster-[a-z0-9]*\).*/\1/')
    fi

    if [ -z "$infra_id" ]; then
        error "Could not detect cluster infra ID"
        exit 1
    fi

    INFRA_ID="$infra_id"
    AWS_REGION="${AWS_REGION:-${region:-us-east-2}}"
    export AWS_DEFAULT_REGION="$AWS_REGION"
}

get_instance_ids() {
    local state_filter="${1:-running,stopped,stopping,pending}"
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${INFRA_ID}-*" \
                  "Name=instance-state-name,Values=$state_filter" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text
}

show_status() {
    info "Cluster instances ($INFRA_ID) in $AWS_REGION:"
    echo ""
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${INFRA_ID}-*" \
        --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,Name:Tags[?Key==`Name`].Value|[0],Type:InstanceType}' \
        --output table
}

stop_instances() {
    local ids
    ids=$(get_instance_ids "running")

    if [ -z "$ids" ]; then
        warn "No running instances found"
        return 0
    fi

    local count
    count=$(echo "$ids" | wc -w | tr -d ' ')
    info "Stopping $count instances..."

    # shellcheck disable=SC2086
    aws ec2 stop-instances --instance-ids $ids --output text > /dev/null

    info "Waiting for all instances to reach 'stopped' state..."
    # shellcheck disable=SC2086
    aws ec2 wait instance-stopped --instance-ids $ids
    success "All $count instances stopped"
}

start_instances() {
    local ids
    ids=$(get_instance_ids "stopped")

    if [ -z "$ids" ]; then
        warn "No stopped instances found"
        return 0
    fi

    local count
    count=$(echo "$ids" | wc -w | tr -d ' ')
    info "Starting $count instances..."

    # shellcheck disable=SC2086
    aws ec2 start-instances --instance-ids $ids --output text > /dev/null

    info "Waiting for all instances to reach 'running' state..."
    # shellcheck disable=SC2086
    aws ec2 wait instance-running --instance-ids $ids
    success "All $count instances started"
}

show_access_info() {
    local rhoai_info="$BASE_DIR/rhoai-info.txt"
    local cluster_info="$BASE_DIR/cluster-info.txt"

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    Access Information                          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Show RHOAI dashboard URL from rhoai-info.txt
    if [ -f "$rhoai_info" ]; then
        local dashboard_url
        dashboard_url=$(grep -A1 'RHOAI DASHBOARD' "$rhoai_info" | grep -v DASHBOARD | head -1)
        [ -z "$dashboard_url" ] && dashboard_url=$(grep '^URL:' "$rhoai_info" | head -1)

        echo -e "  ${GREEN}RHOAI Dashboard:${NC}"
        grep '^URL:' "$rhoai_info" | head -1 | sed 's/^/    /'
        echo ""
        echo -e "  ${GREEN}GenAI Playground:${NC}"
        grep 'Playground:' "$rhoai_info" | head -1 | sed 's/^/    /'
        echo ""
        local model_lines
        model_lines=$(sed -n '/# --- DEPLOYED MODELS/,/# --- END DEPLOYED MODELS/p' "$rhoai_info" 2>/dev/null | grep -v '^#' | grep -v '^\s*$')
        if [ -n "$model_lines" ] && ! echo "$model_lines" | grep -q 'no models'; then
            echo -e "  ${GREEN}Deployed Models:${NC}"
            echo "$model_lines" | sed 's/^/  /'
        fi
    fi

    # Show OpenShift console URL from cluster-info.txt
    if [ -f "$cluster_info" ]; then
        echo ""
        echo -e "  ${GREEN}OpenShift Console:${NC}"
        grep '^URL:' "$cluster_info" | head -1 | sed 's/^/    /'
    fi

    echo ""
}

wait_for_cluster() {
    local kubeconfig="$BASE_DIR/openshift-cluster-install/auth/kubeconfig"
    if [ ! -f "$kubeconfig" ]; then
        warn "kubeconfig not found, skipping cluster health check"
        return 0
    fi

    export KUBECONFIG="$kubeconfig"
    info "Waiting for OpenShift API to become available..."

    local max_wait=300 elapsed=0
    while [ $elapsed -lt $max_wait ]; do
        if oc get nodes &>/dev/null; then
            success "OpenShift API is responding"
            echo ""
            info "Node status:"
            oc get nodes --no-headers 2>/dev/null | while read -r line; do
                echo "  $line"
            done

            echo ""
            info "Waiting for cluster operators to stabilize (up to 5 min)..."
            local op_wait=0
            while [ $op_wait -lt 300 ]; do
                local degraded progressing
                degraded=$(oc get co --no-headers 2>/dev/null | awk '$5=="True"' | wc -l | tr -d ' ')
                progressing=$(oc get co --no-headers 2>/dev/null | awk '$4=="True"' | wc -l | tr -d ' ')
                if [ "$degraded" -eq 0 ] && [ "$progressing" -eq 0 ]; then
                    success "All cluster operators are stable"
                    show_access_info
                    return 0
                fi
                printf "\r  Operators: %s degraded, %s progressing... (%ds)" "$degraded" "$progressing" "$op_wait"
                sleep 15
                op_wait=$((op_wait + 15))
            done
            echo ""
            warn "Some operators may still be stabilizing"
            show_access_info
            return 0
        fi
        printf "\r  Waiting for API... (%ds/%ds)" "$elapsed" "$max_wait"
        sleep 10
        elapsed=$((elapsed + 10))
    done

    echo ""
    warn "API not ready after ${max_wait}s. Cluster may need more time."
}

main() {
    local action="${1:-restart}"

    detect_cluster
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          OpenShift Cluster Instance Manager                    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Cluster:  $INFRA_ID"
    echo "  Region:   $AWS_REGION"
    echo "  Action:   $action"
    echo ""

    case "$action" in
        stop)
            show_status
            echo ""
            read -p "Stop all instances? [y/N]: " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }
            stop_instances
            echo ""
            show_status
            ;;
        start)
            show_status
            echo ""
            start_instances
            echo ""
            show_status
            echo ""
            wait_for_cluster
            ;;
        restart)
            show_status
            echo ""
            read -p "Restart all instances (stop → start)? [y/N]: " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }
            echo ""
            stop_instances
            echo ""
            start_instances
            echo ""
            show_status
            echo ""
            wait_for_cluster
            ;;
        status)
            show_status
            ;;
        *)
            echo "Usage: $0 [stop|start|restart|status]"
            exit 1
            ;;
    esac
}

main "$@"
