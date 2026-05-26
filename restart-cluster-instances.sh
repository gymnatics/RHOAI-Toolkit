#!/usr/bin/env bash
################################################################################
# restart-cluster-instances.sh
#
# Gracefully stop and start all OpenShift cluster EC2 instances.
# Detects the cluster's infra ID from metadata or running instances.
#
# Prerequisites:
#   - Run from the directory where OpenShift was installed (openshift-install)
#   - Requires openshift-cluster-install/auth/kubeconfig (with client certificate)
#   - The client certificate authenticates without OAuth, preventing deadlocks
#     when the cluster restarts after long downtime (expired tokens, OAuth down)
#
# Usage:
#   ./restart-cluster-instances.sh          # stop → start (default)
#   ./restart-cluster-instances.sh stop      # stop only
#   ./restart-cluster-instances.sh start     # start only
#   ./restart-cluster-instances.sh status    # show instance status
#
# Environment:
#   KUBECONFIG   Path to kubeconfig with client certificate (auto-detected)
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

export AWS_PAGER=""

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

    if [ -f "$rhoai_info" ]; then
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

_oc_with_timeout() {
    local timeout_sec="${1:-15}"
    shift
    local pid
    oc "$@" &
    pid=$!
    (
        sleep "$timeout_sec"
        kill "$pid" 2>/dev/null
        sleep 3
        kill -9 "$pid" 2>/dev/null
    ) &
    local killer=$!
    if wait "$pid" 2>/dev/null; then
        kill "$killer" 2>/dev/null
        wait "$killer" 2>/dev/null
        return 0
    else
        kill "$killer" 2>/dev/null
        wait "$killer" 2>/dev/null
        return 1
    fi
}

preflight_check() {
    info "Pre-flight: checking kubeconfig..."

    local installer_kc="$BASE_DIR/openshift-cluster-install/auth/kubeconfig"
    if [ -f "$installer_kc" ]; then
        export KUBECONFIG="$installer_kc"
    elif [ -n "${KUBECONFIG:-}" ] && [ -f "$KUBECONFIG" ]; then
        true
    else
        error "No kubeconfig found"
        echo ""
        echo "  This script requires the installer kubeconfig (with client certificate)."
        echo "  Run from the directory where OpenShift was installed, or set:"
        echo "    export KUBECONFIG=/path/to/openshift-cluster-install/auth/kubeconfig"
        return 1
    fi

    local has_cert
    has_cert=$(oc config view --raw -o json 2>/dev/null \
        | jq -r '.users[] | select(.user["client-certificate-data"] != null) | .name' 2>/dev/null \
        | head -1)

    if [ -z "$has_cert" ]; then
        error "No client certificate found in kubeconfig"
        echo ""
        echo "  A kubeconfig with client certificate is required."
        echo "  OAuth tokens cannot authenticate before the cluster fully recovers."
        echo ""
        echo "  Use the installer kubeconfig:"
        echo "    export KUBECONFIG=/path/to/openshift-cluster-install/auth/kubeconfig"
        return 1
    fi

    success "Kubeconfig: $KUBECONFIG"
    info "  Auth: client certificate (works without OAuth)"
    return 0
}

_approve_pending_csrs() {
    local csr_approved=0 csr_round=0
    while [ $csr_round -lt 6 ]; do
        local pending_csrs
        pending_csrs=$(oc get csr --no-headers --request-timeout=15s 2>/dev/null \
            | awk '/Pending/ {print $1}')

        if [ -z "$pending_csrs" ]; then
            [ $csr_round -eq 0 ] && echo "  No pending CSRs"
            break
        fi

        local count
        count=$(echo "$pending_csrs" | wc -l | tr -d ' ')
        echo "  Approving $count pending CSR(s)... (round $((csr_round+1)))"

        while read -r csr_name; do
            [ -z "$csr_name" ] && continue
            if oc adm certificate approve "$csr_name" --request-timeout=10s &>/dev/null; then
                csr_approved=$((csr_approved + 1))
            fi
        done <<< "$pending_csrs"

        sleep 20
        csr_round=$((csr_round + 1))
    done

    if [ $csr_approved -gt 0 ]; then
        success "Approved $csr_approved CSR(s)"
        echo "  Waiting 30s for nodes to reconnect..."
        sleep 30
    fi
}

wait_for_cluster() {
    local api_url cluster_domain pw_file oauth_url
    api_url=$(oc config view --raw -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "")
    if [ -z "$api_url" ]; then
        error "Could not read API URL from kubeconfig"
        return 0
    fi
    cluster_domain=$(echo "$api_url" | sed 's|https://api\.||;s|:6443||')
    pw_file="$BASE_DIR/openshift-cluster-install/auth/kubeadmin-password"
    oauth_url="https://oauth-openshift.apps.${cluster_domain}/.well-known/oauth-authorization-server"

    # --- Phase 1: API server healthz (no auth needed) ---
    info "Phase 1/4: Waiting for API server..."
    echo "  API: $api_url"

    local max_wait=300 elapsed=0
    while [ $elapsed -lt $max_wait ]; do
        local health
        health=$(curl -sk --connect-timeout 5 --max-time 10 "${api_url}/healthz" 2>/dev/null || echo "")
        if [ "$health" = "ok" ]; then
            break
        fi
        printf "\r  API server... (%ds/%ds)" "$elapsed" "$max_wait"
        sleep 10
        elapsed=$((elapsed + 10))
    done

    if [ "$health" != "ok" ]; then
        echo ""
        warn "API not ready after ${max_wait}s. Cluster may need more time."
        show_access_info
        return 0
    fi
    echo ""
    success "API server is healthy"

    # --- Phase 2: CSR approval (if auth is available) ---
    info "Phase 2/4: Checking for pending kubelet CSRs..."

    if _oc_with_timeout 10 whoami &>/dev/null; then
        success "Auth verified: $(oc whoami 2>/dev/null)"
        _approve_pending_csrs
    else
        echo "  Auth not available (token may be expired after long downtime)"
        echo "  CSR approval deferred to after OAuth recovery"
    fi

    # --- Phase 3: OAuth / Ingress recovery (no auth needed) ---
    info "Phase 3/4: Waiting for OAuth & Ingress..."
    echo "  OAuth: $oauth_url"

    local oauth_wait=0 oauth_max=600
    while [ $oauth_wait -lt $oauth_max ]; do
        local http_code
        http_code=$(curl -sk --connect-timeout 5 --max-time 10 -o /dev/null -w "%{http_code}" "$oauth_url" 2>/dev/null || echo "000")
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 500 ] 2>/dev/null; then
            break
        fi
        printf "\r  OAuth recovering... (%ds/%ds, HTTP %s)" "$oauth_wait" "$oauth_max" "$http_code"
        sleep 15
        oauth_wait=$((oauth_wait + 15))
    done

    if [ "$oauth_wait" -ge "$oauth_max" ]; then
        echo ""
        warn "OAuth not ready after ${oauth_max}s."
        echo "  Check: curl -sk $oauth_url"
        show_access_info
        return 0
    fi
    echo ""
    success "OAuth & Ingress responding"

    # --- Phase 4: Login + finalize ---
    info "Phase 4/4: Authenticating & finalizing..."

    if ! _oc_with_timeout 10 whoami &>/dev/null; then
        if [ -f "$pw_file" ]; then
            local password
            password=$(cat "$pw_file")
            if _oc_with_timeout 20 login "$api_url" -u kubeadmin -p "$password" --insecure-skip-tls-verify=true 2>/dev/null; then
                success "Logged in as kubeadmin"
            else
                warn "Auto-login failed. Login manually:"
                echo "  oc login $api_url"
                show_access_info
                return 0
            fi
        else
            warn "Not authenticated. Login manually:"
            echo "  oc login $api_url"
            show_access_info
            return 0
        fi
    else
        success "Authenticated as $(oc whoami 2>/dev/null)"
    fi

    # Approve any remaining/new CSRs after login
    info "Checking for remaining pending CSRs..."
    _approve_pending_csrs

    echo ""
    info "Node status:"
    oc get nodes --no-headers --request-timeout=15s 2>/dev/null | while read -r line; do
        echo "  $line"
    done

    echo ""
    info "Waiting for cluster operators to stabilize (up to 5 min)..."
    local op_wait=0
    while [ $op_wait -lt 300 ]; do
        local degraded progressing
        degraded=$(oc get co --no-headers --request-timeout=15s 2>/dev/null | awk '$5=="True"' | wc -l | tr -d ' ')
        progressing=$(oc get co --no-headers --request-timeout=15s 2>/dev/null | awk '$4=="True"' | wc -l | tr -d ' ')
        if [ "$degraded" -eq 0 ] && [ "$progressing" -eq 0 ]; then
            echo ""
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
            preflight_check || exit 1
            echo ""
            show_status
            echo ""
            start_instances
            echo ""
            show_status
            echo ""
            wait_for_cluster
            ;;
        restart)
            preflight_check || exit 1
            echo ""
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
