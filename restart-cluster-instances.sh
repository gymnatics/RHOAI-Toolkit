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
#   ./restart-cluster-instances.sh              # stop → start (default)
#   ./restart-cluster-instances.sh stop          # stop only
#   ./restart-cluster-instances.sh start         # start only
#   ./restart-cluster-instances.sh status        # show instance status
#   ./restart-cluster-instances.sh schedule      # show auto-stop schedule
#   ./restart-cluster-instances.sh schedule on   # enable daily auto-stop at 00:00
#   ./restart-cluster-instances.sh schedule on 23:30  # set auto-stop at 23:30
#   ./restart-cluster-instances.sh schedule off  # disable auto-stop
#   ./restart-cluster-instances.sh schedule run  # run auto-stop now (used by cron)
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
    info "Phase 1/5: Waiting for API server..."
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
    info "Phase 2/5: Checking for pending kubelet CSRs..."

    if _oc_with_timeout 10 whoami &>/dev/null; then
        success "Auth verified: $(oc whoami 2>/dev/null)"
        _approve_pending_csrs
    else
        echo "  Auth not available (token may be expired after long downtime)"
        echo "  CSR approval deferred to after OAuth recovery"
    fi

    # --- Phase 3: OAuth / Ingress recovery (no auth needed) ---
    info "Phase 3/5: Waiting for OAuth & Ingress..."
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
    info "Phase 4/5: Authenticating & finalizing..."

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
            recover_rhoai_services
            show_access_info
            return 0
        fi
        printf "\r  Operators: %s degraded, %s progressing... (%ds)" "$degraded" "$progressing" "$op_wait"
        sleep 15
        op_wait=$((op_wait + 15))
    done
    echo ""
    warn "Some operators may still be stabilizing"
    recover_rhoai_services
    show_access_info
    return 0
}

################################################################################
# RHOAI post-restart recovery
#
# Fixes two common issues after cluster restart:
#
# 1. Model Catalog DB race condition: model-catalog-postgres re-initializes
#    but the catalog pod starts first, hitting missing tables (locks_rvn, Context).
#    Fix: restart pods in correct order — postgres → catalog → dashboard.
#
# 2. Thanos proxy secret missing: the observability dashboard needs
#    monitoring-thanos-proxy-secret to query Prometheus/Thanos metrics.
#    The secret uses a short-lived token that may expire or get deleted.
#    Fix: recreate the secret with a fresh long-lived SA token.
################################################################################

_wait_for_pod_ready() {
    local label="$1" ns="$2" timeout="${3:-120}"
    oc wait --for=condition=ready pod -l "$label" -n "$ns" --timeout="${timeout}s" &>/dev/null
}

_recover_thanos_secret() {
    local dash_ns="redhat-ods-applications"

    if ! oc get namespace "$dash_ns" &>/dev/null; then
        return 0
    fi

    local obs_enabled
    obs_enabled=$(oc get odhdashboardconfig odh-dashboard-config -n "$dash_ns" \
        -o jsonpath='{.spec.dashboardConfig.observabilityDashboard}' 2>/dev/null || echo "")
    if [ "$obs_enabled" != "true" ]; then
        return 0
    fi

    echo "  Checking Thanos proxy secret..."

    if oc get secret monitoring-thanos-proxy-secret -n "$dash_ns" &>/dev/null; then
        local token thanos_host http_code
        token=$(oc get secret monitoring-thanos-proxy-secret -n "$dash_ns" \
            -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
        thanos_host=$(oc get route thanos-querier -n openshift-monitoring \
            -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

        if [ -n "$token" ] && [ -n "$thanos_host" ]; then
            http_code=$(curl -sk --connect-timeout 5 --max-time 10 -o /dev/null -w "%{http_code}" \
                -H "Authorization: Bearer ${token}" \
                "https://${thanos_host}/api/v1/query?query=up" 2>/dev/null || echo "000")
            if [ "$http_code" -eq 200 ] 2>/dev/null; then
                success "  Thanos proxy secret valid (HTTP 200)"
                return 0
            fi
            warn "  Thanos proxy secret exists but token is invalid (HTTP $http_code)"
        else
            warn "  Thanos proxy secret exists but is incomplete"
        fi
        oc delete secret monitoring-thanos-proxy-secret -n "$dash_ns" &>/dev/null || true
    else
        warn "  Thanos proxy secret missing"
    fi

    echo "  Recreating monitoring-thanos-proxy-secret..."
    local new_token thanos_host
    new_token=$(oc create token rhods-dashboard -n "$dash_ns" --duration=87600h 2>/dev/null || echo "")
    thanos_host=$(oc get route thanos-querier -n openshift-monitoring \
        -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

    if [ -z "$new_token" ] || [ -z "$thanos_host" ]; then
        warn "  Could not generate token or find Thanos route"
        return 0
    fi

    cat <<EOF | oc apply -f - &>/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: monitoring-thanos-proxy-secret
  namespace: ${dash_ns}
  labels:
    app.kubernetes.io/part-of: rhods-dashboard
    opendatahub.io/dashboard: "true"
type: Opaque
stringData:
  token: "${new_token}"
  url: "https://${thanos_host}"
EOF

    if [ $? -eq 0 ]; then
        success "  Thanos proxy secret created"
        return 1  # signal dashboard restart needed
    else
        warn "  Failed to create Thanos proxy secret"
        return 0
    fi
}

_recover_model_catalog_db() {
    local ns="rhoai-model-registries"

    if ! oc get namespace "$ns" &>/dev/null; then
        return 0
    fi

    local catalog_pods
    catalog_pods=$(oc get pods -n "$ns" -l app.kubernetes.io/name=model-catalog --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$catalog_pods" -eq 0 ]; then
        return 0
    fi

    echo "  Checking Model Catalog DB..."

    if ! oc logs deployment/model-catalog -n "$ns" -c catalog --tail=30 2>/dev/null \
        | grep -q 'relation .* does not exist'; then
        success "  Model Catalog DB is healthy"
        return 0
    fi

    warn "  Model Catalog DB schema missing (race condition after restart)"
    echo "  Restarting pods: postgres → catalog"

    echo "    [1/2] Restarting model-catalog-postgres..."
    oc delete pods -l app.kubernetes.io/name=model-catalog-postgres -n "$ns" --wait=false &>/dev/null || true
    if _wait_for_pod_ready "app.kubernetes.io/name=model-catalog-postgres" "$ns" 120; then
        success "    model-catalog-postgres is ready"
    else
        warn "    model-catalog-postgres did not become ready in 120s"
        return 0
    fi

    echo "    [2/2] Restarting model-catalog..."
    oc delete pods -l app.kubernetes.io/name=model-catalog -l 'app.kubernetes.io/name!=model-catalog-postgres' \
        -n "$ns" --wait=false &>/dev/null || true
    sleep 5
    if _wait_for_pod_ready "app.kubernetes.io/instance=model-catalog" "$ns" 180; then
        success "    model-catalog is ready"
    else
        warn "    model-catalog did not become ready in 180s"
        return 0
    fi

    sleep 3
    if oc logs deployment/model-catalog -n "$ns" -c catalog --tail=20 2>/dev/null \
        | grep -q 'relation .* does not exist'; then
        warn "  DB errors persist — may need manual intervention"
        echo "  Try: oc delete pods -n $ns --all"
        return 0
    fi

    local model_count
    model_count=$(oc logs deployment/model-catalog -n "$ns" -c catalog --tail=5 2>/dev/null \
        | grep -oE 'loaded [0-9]+ models' | tail -1 || echo "")
    if [ -n "$model_count" ]; then
        success "  Model Catalog recovered ($model_count)"
    else
        success "  Model Catalog DB recovered"
    fi
    return 1  # signal dashboard restart needed
}

recover_rhoai_services() {
    local dash_ns="redhat-ods-applications"

    if ! oc get namespace "$dash_ns" &>/dev/null; then
        return 0
    fi

    info "Phase 5/5: Recovering RHOAI services..."

    local need_dashboard_restart=false

    _recover_thanos_secret  || need_dashboard_restart=true
    _recover_model_catalog_db || need_dashboard_restart=true

    if [ "$need_dashboard_restart" = true ]; then
        echo "  Restarting dashboard to apply fixes..."
        oc delete pods -l app.kubernetes.io/part-of=rhods-dashboard -n "$dash_ns" --wait=false &>/dev/null || true
        _wait_for_pod_ready "app.kubernetes.io/part-of=rhods-dashboard" "$dash_ns" 180 || true
        success "  Dashboard restarted"
    fi
}

################################################################################
# Schedule management (AWS EventBridge + SSM auto-stop)
#
# Uses AWS-native scheduling so the cluster stops even when your laptop is
# asleep.  Resources created:
#   - IAM Role:        EventBridge-SSM-StopEC2
#   - SSM Document:    StopOpenShiftCluster
#   - EventBridge Rule: openshift-cluster-autostop
################################################################################

EB_RULE_NAME="openshift-cluster-autostop"
EB_ROLE_NAME="EventBridge-SSM-StopEC2"
EB_SSM_DOC="StopOpenShiftCluster"

_local_to_utc() {
    local hour="$1" minute="$2"
    if command -v python3 &>/dev/null; then
        python3 -c "
from datetime import datetime, timezone
import time
local = datetime.now().replace(hour=$hour, minute=$minute, second=0, microsecond=0)
utc = local.astimezone(timezone.utc)
print(f'{utc.hour} {utc.minute}')
"
    else
        local tz_offset offset_hr offset_min sign offset_total_min
        tz_offset=$(date +%z)
        sign="${tz_offset:0:1}"
        offset_hr=$((10#${tz_offset:1:2}))
        offset_min=$((10#${tz_offset:3:2}))
        offset_total_min=$(( offset_hr * 60 + offset_min ))
        [ "$sign" = "-" ] && offset_total_min=$(( -offset_total_min ))
        local total_min=$(( hour * 60 + minute - offset_total_min ))
        [ "$total_min" -lt 0 ] && total_min=$((total_min + 1440))
        [ "$total_min" -ge 1440 ] && total_min=$((total_min - 1440))
        echo "$(( total_min / 60 )) $(( total_min % 60 ))"
    fi
}

_get_aws_account_id() {
    aws sts get-caller-identity --query 'Account' --output text 2>/dev/null
}

_ensure_iam_role() {
    if aws iam get-role --role-name "$EB_ROLE_NAME" &>/dev/null; then
        return 0
    fi

    info "Creating IAM role $EB_ROLE_NAME..."
    aws iam create-role --role-name "$EB_ROLE_NAME" \
        --assume-role-policy-document '{
          "Version": "2012-10-17",
          "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": ["events.amazonaws.com","ssm.amazonaws.com"]},
            "Action": "sts:AssumeRole"
          }]
        }' --no-cli-pager &>/dev/null

    aws iam put-role-policy --role-name "$EB_ROLE_NAME" \
        --policy-name StopEC2Policy \
        --policy-document '{
          "Version": "2012-10-17",
          "Statement": [
            {"Effect":"Allow","Action":["ec2:DescribeInstances","ec2:StopInstances","ec2:DescribeTags"],"Resource":"*"},
            {"Effect":"Allow","Action":["ssm:StartAutomationExecution","ssm:GetAutomationExecution"],"Resource":"*"}
          ]
        }' --no-cli-pager &>/dev/null

    sleep 5
    success "IAM role created"
}

_ensure_ssm_document() {
    if aws ssm describe-document --name "$EB_SSM_DOC" &>/dev/null 2>&1; then
        return 0
    fi

    info "Creating SSM document $EB_SSM_DOC..."
    aws ssm create-document --name "$EB_SSM_DOC" \
        --document-type Automation \
        --document-format YAML \
        --content "$(cat <<'SSMDOC'
description: Stop OpenShift cluster EC2 instances by InfraID tag
schemaVersion: '0.3'
assumeRole: '{{AutomationAssumeRole}}'
parameters:
  InfraID:
    type: String
    description: Cluster infra ID prefix (e.g. openshift-cluster-knd9q)
  AutomationAssumeRole:
    type: String
    description: IAM role ARN
mainSteps:
  - name: getInstances
    action: aws:executeAwsApi
    inputs:
      Service: ec2
      Api: DescribeInstances
      Filters:
        - Name: tag:Name
          Values: ['{{InfraID}}-*']
        - Name: instance-state-name
          Values: [running]
    outputs:
      - Name: ids
        Selector: '$.Reservations..Instances..InstanceId'
        Type: StringList
  - name: stopInstances
    action: aws:executeAwsApi
    inputs:
      Service: ec2
      Api: StopInstances
      InstanceIds: '{{getInstances.ids}}'
    onFailure: Continue
SSMDOC
)" --no-cli-pager &>/dev/null
    success "SSM document created"
}

_get_schedule_info() {
    local rule_state
    rule_state=$(aws events describe-rule --name "$EB_RULE_NAME" \
        --query 'State' --output text 2>/dev/null || true)
    case "$rule_state" in
        ENABLED)  echo "active" ;;
        DISABLED) echo "disabled" ;;
        *)        echo "none" ;;
    esac
}

_get_current_schedule_time() {
    local cron_expr
    cron_expr=$(aws events describe-rule --name "$EB_RULE_NAME" \
        --query 'ScheduleExpression' --output text 2>/dev/null || true)
    if [ -z "$cron_expr" ] || [ "$cron_expr" = "None" ]; then
        echo "00:00"
        return
    fi
    local utc_min utc_hr
    utc_min=$(echo "$cron_expr" | sed -n 's/cron(\([0-9]*\) .*/\1/p')
    utc_hr=$(echo "$cron_expr" | sed -n 's/cron([0-9]* \([0-9]*\) .*/\1/p')
    if [ -z "$utc_hr" ]; then
        echo "00:00"
        return
    fi
    if command -v python3 &>/dev/null; then
        python3 -c "
from datetime import datetime, timezone
import time
utc = datetime.now(timezone.utc).replace(hour=$utc_hr, minute=$utc_min, second=0)
local = utc.astimezone()
print(f'{local.hour:02d}:{local.minute:02d}')
"
    else
        printf "%02d:%02d" "$utc_hr" "$utc_min"
    fi
}

schedule_status() {
    local state sched_time
    state=$(_get_schedule_info)
    sched_time=$(_get_current_schedule_time)
    echo ""
    case "$state" in
        active)
            success "Auto-stop schedule: ACTIVE (daily at ${sched_time} local time)"
            echo "  Backend: AWS EventBridge (runs even when laptop is off)"
            echo ""
            echo "  Rule: $EB_RULE_NAME"
            aws events describe-rule --name "$EB_RULE_NAME" \
                --query '{Schedule:ScheduleExpression,State:State}' \
                --output table 2>/dev/null | sed 's/^/    /'
            echo ""
            echo "  Change time:  $0 schedule on HH:MM"
            echo "  Disable:      $0 schedule off"
            ;;
        disabled)
            warn "Auto-stop schedule: DISABLED (rule exists but inactive)"
            echo ""
            echo "  Enable with: $0 schedule on [HH:MM]"
            ;;
        none)
            info "Auto-stop schedule: NOT REGISTERED"
            echo ""
            echo "  Register with: $0 schedule on [HH:MM]  (default: 00:00 local)"
            echo "  Uses AWS EventBridge — works even when laptop is off"
            ;;
    esac
    echo ""
}

schedule_on() {
    local time_arg="${1:-00:00}"
    local hour minute

    if ! echo "$time_arg" | grep -qE '^[0-9]{1,2}:[0-9]{2}$'; then
        error "Invalid time format: $time_arg (expected HH:MM)"
        return 1
    fi
    hour=$(echo "$time_arg" | cut -d: -f1)
    minute=$(echo "$time_arg" | cut -d: -f2)

    if [ "$hour" -gt 23 ] || [ "$minute" -gt 59 ] 2>/dev/null; then
        error "Invalid time: $time_arg"
        return 1
    fi

    local utc_parts utc_hr utc_min
    utc_parts=$(_local_to_utc "$hour" "$minute")
    utc_hr=$(echo "$utc_parts" | awk '{print $1}')
    utc_min=$(echo "$utc_parts" | awk '{print $2}')

    local account_id
    account_id=$(_get_aws_account_id)
    if [ -z "$account_id" ]; then
        error "Cannot determine AWS account ID — check AWS credentials"
        return 1
    fi

    local role_arn="arn:aws:iam::${account_id}:role/${EB_ROLE_NAME}"

    _ensure_iam_role
    _ensure_ssm_document

    local state
    state=$(_get_schedule_info)

    aws events put-rule \
        --name "$EB_RULE_NAME" \
        --schedule-expression "cron($utc_min $utc_hr * * ? *)" \
        --state ENABLED \
        --description "Auto-stop OpenShift cluster $INFRA_ID daily at $(printf '%02d:%02d' "$hour" "$minute") local" \
        --no-cli-pager &>/dev/null

    local input_json
    input_json=$(printf '{"InfraID":["%s"],"AutomationAssumeRole":["%s"]}' "$INFRA_ID" "$role_arn")

    aws events put-targets \
        --rule "$EB_RULE_NAME" \
        --targets "[{
          \"Id\": \"stop-openshift-cluster\",
          \"Arn\": \"arn:aws:ssm:${AWS_REGION}:${account_id}:automation-definition/${EB_SSM_DOC}\",
          \"RoleArn\": \"${role_arn}\",
          \"Input\": $(printf '%s' "$input_json" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo "\"$input_json\"")
        }]" --no-cli-pager &>/dev/null

    local local_time
    local_time=$(printf '%02d:%02d' "$hour" "$minute")

    if [ "$state" = "none" ]; then
        success "Auto-stop schedule CREATED and ENABLED (daily at ${local_time} local → ${utc_hr}:$(printf '%02d' "$utc_min") UTC)"
    else
        success "Auto-stop schedule UPDATED and ENABLED (daily at ${local_time} local → ${utc_hr}:$(printf '%02d' "$utc_min") UTC)"
    fi
    echo "  Backend: AWS EventBridge (runs even when laptop is off)"
    echo ""
}

schedule_off() {
    local state
    state=$(_get_schedule_info)

    case "$state" in
        active)
            aws events disable-rule --name "$EB_RULE_NAME" --no-cli-pager &>/dev/null
            success "Auto-stop schedule DISABLED"
            echo "  Re-enable with: $0 schedule on [HH:MM]"
            ;;
        disabled)
            warn "Auto-stop schedule is already disabled"
            ;;
        none)
            warn "No auto-stop schedule registered"
            echo "  Register with: $0 schedule on [HH:MM]"
            ;;
    esac
    echo ""
}

schedule_delete() {
    local state
    state=$(_get_schedule_info)

    if [ "$state" = "none" ]; then
        warn "No EventBridge schedule exists"
        echo ""
        return
    fi

    aws events remove-targets --rule "$EB_RULE_NAME" \
        --ids "stop-openshift-cluster" --no-cli-pager &>/dev/null || true
    aws events delete-rule --name "$EB_RULE_NAME" --no-cli-pager &>/dev/null || true
    success "EventBridge rule deleted"

    read -p "Also delete SSM document and IAM role? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        aws ssm delete-document --name "$EB_SSM_DOC" --no-cli-pager &>/dev/null || true
        aws iam delete-role-policy --role-name "$EB_ROLE_NAME" \
            --policy-name StopEC2Policy &>/dev/null || true
        aws iam delete-role --role-name "$EB_ROLE_NAME" &>/dev/null || true
        success "SSM document and IAM role deleted"
    fi
    echo ""
}

_cleanup_legacy_crontab() {
    local legacy_tag="RHOAI-AUTOSTOP"
    if crontab -l 2>/dev/null | grep -q "$legacy_tag"; then
        warn "Removing legacy crontab entry (migrated to EventBridge)..."
        crontab -l 2>/dev/null | grep -v "$legacy_tag" | crontab - 2>/dev/null || true
        success "Legacy crontab entry removed"
    fi
}

schedule_run() {
    echo ""
    echo "========================================"
    echo "  Auto-stop triggered at $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "========================================"
    detect_cluster
    echo "  Cluster: $INFRA_ID  Region: $AWS_REGION"
    stop_instances
    echo "  Completed at $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "========================================"
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

    local sched_state
    sched_state=$(_get_schedule_info)
    case "$sched_state" in
        active)   echo -e "  Schedule: ${GREEN}Auto-stop at $(_get_current_schedule_time) daily (active)${NC}" ;;
        disabled) echo -e "  Schedule: ${YELLOW}Auto-stop registered (disabled)${NC}" ;;
    esac
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
        schedule)
            _cleanup_legacy_crontab
            local sub="${2:-}"
            case "$sub" in
                on)     schedule_on "${3:-00:00}" ;;
                off)    schedule_off ;;
                delete) schedule_delete ;;
                run)    schedule_run ;;
                *)      schedule_status ;;
            esac
            return 0
            ;;
        *)
            echo "Usage: $0 [stop|start|restart|status|schedule [on [HH:MM]|off|delete|run]]"
            exit 1
            ;;
    esac
}

main "$@"
