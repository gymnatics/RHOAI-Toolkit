#!/bin/bash
################################################################################
# install.sh — Shared installation phase functions for RHOAI 3.x
# Sourced by scripts/install-rhoai.sh after a version profile is loaded.
#
# Requires: version profile variables (RHOAI_VERSION_LABEL, TLS_STRATEGY, etc.)
#           lib/utils/colors.sh
#
# Provides:
#   wait_for_operator             — Wait for operator CSV to reach Succeeded
#   wait_for_pod                  — Wait for pods matching a label to be ready
#   get_cluster_domain            — Detect and export CLUSTER_DOMAIN
#   wait_for_api_server           — Wait for kube API server to respond
#   retry_with_api_wait           — Retry a command with API recovery between attempts
#   recover_router_if_crashlooping — Recover ingress router from CrashLoopBackOff
#   select_rhoai_channel          — Interactive RHOAI channel picker
#   check_prerequisites           — Verify oc, cluster-admin, OCP version
#   create_admin_user             — Create htpasswd admin user + group
#   scale_cluster_nodes           — Scale worker/GPU machinesets
#   install_nfd_operator          — Install Node Feature Discovery operator
#   install_gpu_operator          — Install NVIDIA GPU operator
#   install_kueue_operator        — Install Kueue operator
#   install_certmanager_operator  — Install cert-manager operator
#   install_lws_operator          — Install Leader Worker Set operator
#   install_servicemesh_operator  — Install Service Mesh 3 operator
#   approve_servicemesh_installplans — Approve SM-related InstallPlans
#   approve_rhcl_installplans     — Approve RHCL-related InstallPlans
#   setup_istio_for_kuadrant      — Create Istio/IstioCNI for Kuadrant
#   restart_kuadrant_operator     — Restart Kuadrant to detect Istio
################################################################################

_INSTALL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

################################################################################
# 1. wait_for_operator
################################################################################

wait_for_operator() {
    local operator_name="$1"
    local namespace="$2"
    local timeout="${3:-$WAIT_TIMEOUT}"

    print_step "Waiting for $operator_name operator to be ready in $namespace..."

    local elapsed=0
    local interval=10
    local last_status=""

    while [ $elapsed -lt $timeout ]; do
        local csv_line=$(oc get csv -n "$namespace" 2>/dev/null | grep "$operator_name" | head -1)
        local status=$(echo "$csv_line" | awk '{print $NF}')
        local csv_name=$(echo "$csv_line" | awk '{print $1}')

        if [ "$status" = "Succeeded" ]; then
            print_success "$operator_name operator is ready ($csv_name)"
            return 0
        fi

        if [ -n "$status" ] && [ "$status" != "$last_status" ]; then
            echo "  $operator_name: $status ($csv_name) — ${elapsed}s elapsed"
            last_status="$status"
        elif [ -z "$csv_line" ] && [ $((elapsed % 30)) -eq 0 ] && [ $elapsed -gt 0 ]; then
            echo "  $operator_name: CSV not yet created in $namespace — ${elapsed}s elapsed"
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    print_error "$operator_name operator did not become ready within ${timeout}s"
    local final_csv=$(oc get csv -n "$namespace" 2>/dev/null | grep "$operator_name")
    [ -n "$final_csv" ] && print_info "  Last seen: $final_csv"
    return 1
}

################################################################################
# 2. wait_for_pod
################################################################################

wait_for_pod() {
    local label="$1"
    local namespace="$2"
    local timeout="${3:-300}"

    print_step "Waiting for pods with label $label..."

    local elapsed=0
    local interval=5

    while [ $elapsed -lt $timeout ]; do
        local ready=$(oc get pods -n "$namespace" -l "$label" -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null | grep -c "true" || echo "0")
        local total=$(oc get pods -n "$namespace" -l "$label" --no-headers 2>/dev/null | wc -l | tr -d ' ')

        if [ "$total" -gt 0 ] && [ "$ready" -eq "$total" ]; then
            print_success "Pods are ready"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    print_warning "Pods may not be fully ready"
    return 0
}

################################################################################
# 3. get_cluster_domain
################################################################################

get_cluster_domain() {
    if [ -z "$CLUSTER_DOMAIN" ]; then
        CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null | sed 's/^apps\.//')
        if [ -z "$CLUSTER_DOMAIN" ]; then
            print_error "Could not detect cluster domain. Please specify with --domain"
            exit 1
        fi
    fi
    export CLUSTER_DOMAIN
    print_info "Cluster domain: $CLUSTER_DOMAIN"
}

################################################################################
# 4. wait_for_api_server
################################################################################

wait_for_api_server() {
    local max_wait=${1:-120}
    local elapsed=0
    local interval=5
    while [ $elapsed -lt $max_wait ]; do
        if oc get nodes &>/dev/null; then
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        echo "  Waiting for API server... (${elapsed}s/${max_wait}s)"
    done
    print_warning "API server did not respond within ${max_wait}s"
    return 1
}

################################################################################
# 5. retry_with_api_wait
################################################################################

retry_with_api_wait() {
    local max_retries=${1:-3}
    shift
    local attempt=1
    while [ $attempt -le $max_retries ]; do
        if "$@" 2>/dev/null; then
            return 0
        fi
        print_warning "Command failed (attempt $attempt/$max_retries), waiting for API server..."
        wait_for_api_server 60
        attempt=$((attempt + 1))
    done
    print_error "Command failed after $max_retries attempts: $*"
    return 1
}

################################################################################
# 6. recover_router_if_crashlooping
################################################################################

recover_router_if_crashlooping() {
    local router_status
    router_status=$(oc get pods -n openshift-ingress -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default \
        -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)

    if [ "$router_status" = "CrashLoopBackOff" ]; then
        print_warning "Router pod is in CrashLoopBackOff (caused by API server restart)"
        print_step "Deleting stuck router pod to reset backoff..."
        oc delete pod -n openshift-ingress \
            -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default \
            --wait=false 2>/dev/null || true
        sleep 10
        local new_status
        new_status=$(oc get pods -n openshift-ingress \
            -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default \
            -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
        if [ "$new_status" = "Running" ]; then
            print_success "Router pod recovered"
        else
            print_info "Router pod restarting (status: $new_status) — it should recover shortly"
        fi
    fi
}

################################################################################
# 7. select_rhoai_channel
################################################################################

select_rhoai_channel() {
    print_step "Fetching available RHOAI channels from cluster..."

    local channels_raw=$(oc get packagemanifest rhods-operator -n openshift-marketplace \
        -o jsonpath='{.status.channels[*].name}' 2>/dev/null)

    if [ -z "$channels_raw" ]; then
        print_warning "Unable to fetch RHOAI channels from cluster"
        print_info "Using default channel: fast-3.x"
        RHOAI_CHANNEL="fast-3.x"
        return 0
    fi

    local default_channel=$(oc get packagemanifest rhods-operator -n openshift-marketplace \
        -o jsonpath='{.status.defaultChannel}' 2>/dev/null)

    local channels=()
    while IFS= read -r channel; do
        [ -n "$channel" ] && channels+=("$channel")
    done < <(echo "$channels_raw" | tr ' ' '\n' | sort -V)

    if [ ${#channels[@]} -eq 0 ]; then
        print_warning "No channels found, using default: fast-3.x"
        RHOAI_CHANNEL="fast-3.x"
        return 0
    fi

    echo ""
    echo -e "${CYAN}Available RHOAI Channels:${NC}"
    echo ""

    local stable_channels=()
    local fast_channels=()
    local other_channels=()

    for channel in "${channels[@]}"; do
        if [[ "$channel" == stable* ]]; then
            stable_channels+=("$channel")
        elif [[ "$channel" == fast* ]]; then
            fast_channels+=("$channel")
        else
            other_channels+=("$channel")
        fi
    done

    local idx=1
    local channel_map=()

    if [ ${#fast_channels[@]} -gt 0 ]; then
        echo -e "${MAGENTA}Fast Channels (Latest/Preview):${NC}"
        for channel in "${fast_channels[@]}"; do
            local marker=""
            [ "$channel" = "$default_channel" ] && marker=" ${GREEN}[default]${NC}"
            echo -e "  ${YELLOW}$idx)${NC} $channel$marker"
            channel_map+=("$channel")
            ((idx++))
        done
        echo ""
    fi

    if [ ${#stable_channels[@]} -gt 0 ]; then
        echo -e "${MAGENTA}Stable Channels:${NC}"
        for channel in "${stable_channels[@]}"; do
            local marker=""
            [ "$channel" = "$default_channel" ] && marker=" ${GREEN}[default]${NC}"
            echo -e "  ${YELLOW}$idx)${NC} $channel$marker"
            channel_map+=("$channel")
            ((idx++))
        done
        echo ""
    fi

    if [ ${#other_channels[@]} -gt 0 ]; then
        echo -e "${MAGENTA}Other Channels:${NC}"
        for channel in "${other_channels[@]}"; do
            local marker=""
            [ "$channel" = "$default_channel" ] && marker=" ${GREEN}[default]${NC}"
            echo -e "  ${YELLOW}$idx)${NC} $channel$marker"
            channel_map+=("$channel")
            ((idx++))
        done
        echo ""
    fi

    echo -e "${CYAN}Channel Types:${NC}"
    echo "  • fast-3.x   : RHOAI 3.x (latest features, GenAI, MaaS)"
    echo "  • stable-X.Y : Specific version streams (e.g., stable-3.4)"
    echo "  • stable     : Production-ready releases"
    echo ""

    local default_idx=1
    for i in "${!channel_map[@]}"; do
        if [ "${channel_map[$i]}" = "fast-3.x" ]; then
            default_idx=$((i + 1))
            break
        elif [ "${channel_map[$i]}" = "$default_channel" ]; then
            default_idx=$((i + 1))
        fi
    done

    local max_idx=${#channel_map[@]}
    local choice=""

    while true; do
        read -p "Select channel (1-$max_idx) [default: $default_idx - ${channel_map[$((default_idx - 1))]}]: " choice
        choice=$(echo "$choice" | tr -d '[:space:]')

        if [ -z "$choice" ]; then
            choice=$default_idx
            break
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$max_idx" ]; then
            break
        else
            print_error "Invalid selection. Please enter a number between 1 and $max_idx"
        fi
    done

    RHOAI_CHANNEL="${channel_map[$((choice - 1))]}"
    print_success "Selected channel: $RHOAI_CHANNEL"
}

################################################################################
# 8. check_prerequisites
################################################################################

check_prerequisites() {
    print_step "Checking prerequisites..."

    if ! command -v oc &> /dev/null; then
        print_error "oc CLI not found. Please install OpenShift CLI."
        exit 1
    fi

    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift cluster. Please run 'oc login' first."
        exit 1
    fi

    if ! oc auth can-i create clusterrole &> /dev/null; then
        print_error "You need cluster-admin privileges to install RHOAI."
        exit 1
    fi

    local ocp_version=$(oc version -o json 2>/dev/null | jq -r '.openshiftVersion' | cut -d. -f1,2)
    print_info "OpenShift version: $ocp_version"

    if [[ "$ocp_version" < "$OCP_MIN_VERSION" ]]; then
        print_error "$RHOAI_VERSION_LABEL requires OpenShift $OCP_MIN_VERSION or later. Current: $ocp_version"
        exit 1
    fi

    if [ "$ENABLE_LLMD" = true ] && [[ "$ocp_version" < "4.20" ]]; then
        print_warning "Distributed inference with llm-d requires OCP 4.20+. Current: $ocp_version"
        print_warning "llm-d will be installed but multi-node inference may not work correctly."
    fi

    print_success "Prerequisites check passed"
}

################################################################################
# 9. create_admin_user
################################################################################

create_admin_user() {
    local admin_user="admin"
    local admin_pass='R3dh4t1!'

    # Check if admin user already exists in htpasswd
    local admin_exists=false
    if oc get secret htpasswd-secret -n openshift-config &>/dev/null; then
        if oc get secret htpasswd-secret -n openshift-config \
            -o jsonpath='{.data.htpasswd}' 2>/dev/null | base64 -d 2>/dev/null | grep -q "^${admin_user}:"; then
            admin_exists=true
        fi
    fi

    if [ "$admin_exists" = true ]; then
        print_info "Admin user '$admin_user' already exists — skipping creation"
        # Ensure group membership is correct even if user already exists
        if ! oc get group "$ADMIN_GROUP" &>/dev/null 2>&1; then
            oc adm groups new "$ADMIN_GROUP" 2>/dev/null || true
        fi
        oc adm groups add-users "$ADMIN_GROUP" "$admin_user" 2>/dev/null || true
        return 0
    fi

    print_step "Creating OAuth admin user '$admin_user'..."

    if ! command -v htpasswd &>/dev/null; then
        print_error "htpasswd CLI not found. Install httpd-tools (RHEL) or apache2-utils (Debian)."
        return 1
    fi

    # Pull existing htpasswd data (preserve other users)
    local htpasswd_tmp
    htpasswd_tmp=$(mktemp)

    if oc get secret htpasswd-secret -n openshift-config &>/dev/null; then
        oc get secret htpasswd-secret -n openshift-config \
            -o jsonpath='{.data.htpasswd}' | base64 -d > "$htpasswd_tmp" 2>/dev/null || true
    fi

    htpasswd -bB "$htpasswd_tmp" "$admin_user" "$admin_pass"
    print_success "User '$admin_user' added to htpasswd"

    # Update secret
    oc create secret generic htpasswd-secret \
        --from-file=htpasswd="$htpasswd_tmp" \
        -n openshift-config --dry-run=client -o yaml | oc apply -f -
    rm -f "$htpasswd_tmp"

    # Ensure htpasswd identity provider is configured
    local has_htpasswd
    has_htpasswd=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[?(@.name=="htpasswd")].name}' 2>/dev/null || true)
    if [ -z "$has_htpasswd" ]; then
        print_step "Adding htpasswd identity provider to OAuth..."
        oc patch oauth cluster --type=json -p '[{
            "op": "add",
            "path": "/spec/identityProviders/-",
            "value": {
                "name": "htpasswd",
                "type": "HTPasswd",
                "mappingMethod": "claim",
                "htpasswd": {
                    "fileData": {
                        "name": "htpasswd-secret"
                    }
                }
            }
        }]' 2>/dev/null || {
            oc patch oauth cluster --type=merge -p '{
                "spec": {
                    "identityProviders": [{
                        "name": "htpasswd",
                        "type": "HTPasswd",
                        "mappingMethod": "claim",
                        "htpasswd": {
                            "fileData": {
                                "name": "htpasswd-secret"
                            }
                        }
                    }]
                }
            }' 2>/dev/null
        }
        print_success "htpasswd identity provider configured"
    else
        print_info "htpasswd identity provider already configured"
    fi

    # Grant cluster-admin
    oc adm policy add-cluster-role-to-user cluster-admin "$admin_user" 2>/dev/null || true
    print_success "cluster-admin granted to '$admin_user'"

    # Create admin group and add admin
    if ! oc get group "$ADMIN_GROUP" &>/dev/null 2>&1; then
        oc adm groups new "$ADMIN_GROUP" 2>/dev/null || true
    fi
    oc adm groups add-users "$ADMIN_GROUP" "$admin_user" 2>/dev/null || true
    print_info "User '$admin_user' added to group '$ADMIN_GROUP'"

    # Don't switch sessions — continue using kube:admin for stability
    # The OAuth config change triggers an API server rollout; avoid disruption
    # by staying on the current session. User can log in as 'admin' later.
    print_success "Admin user created. Continuing installation as $(oc whoami)"
    print_info "Log in as '$admin_user' after installation: oc login -u $admin_user -p '$admin_pass'"
    echo ""

    # Wait briefly for the OAuth rollout to settle, then recover router if needed
    print_step "Waiting for API server to stabilize after OAuth change..."
    sleep 10
    wait_for_api_server 90
    recover_router_if_crashlooping
    print_success "Cluster stable — continuing installation"
}

################################################################################
# 10. scale_cluster_nodes
################################################################################

scale_cluster_nodes() {
    print_step "Checking and scaling cluster nodes..."

    local worker_ms=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[?(@.spec.template.metadata.labels.machine\.openshift\.io/cluster-api-machine-role=="worker")].metadata.name}' 2>/dev/null | awk '{print $1}')

    if [ -z "$worker_ms" ]; then
        print_warning "No worker machineset found, skipping node scaling"
        return 0
    fi

    local current_replicas=$(oc get machineset "$worker_ms" -n openshift-machine-api -o jsonpath='{.spec.replicas}' 2>/dev/null)
    print_info "Worker machineset: $worker_ms (current replicas: $current_replicas)"

    if [ "$current_replicas" -lt 2 ]; then
        print_step "Scaling worker nodes to 2..."
        oc scale machineset "$worker_ms" -n openshift-machine-api --replicas=2
        print_success "Worker machineset scaled to 2 replicas"
    else
        print_info "Worker nodes already at $current_replicas replicas"
    fi

    local gpu_ms=$(oc get machineset -n openshift-machine-api -o name 2>/dev/null | grep -i gpu | head -1)

    if [ -n "$gpu_ms" ]; then
        print_info "GPU machineset already exists: $gpu_ms"
        local gpu_replicas=$(oc get "$gpu_ms" -n openshift-machine-api -o jsonpath='{.spec.replicas}' 2>/dev/null)
        if [ "$gpu_replicas" -eq 0 ]; then
            print_step "Scaling GPU machineset to 1..."
            oc scale "$gpu_ms" -n openshift-machine-api --replicas=1
            print_success "GPU machineset scaled to 1 replica"
        fi
    else
        print_step "Creating GPU machineset..."
        if [ -f "$ROOT_DIR/scripts/create-gpu-machineset.sh" ]; then
            local az=$(oc get machineset "$worker_ms" -n openshift-machine-api -o jsonpath='{.spec.template.spec.providerSpec.value.placement.availabilityZone}' 2>/dev/null)
            "$ROOT_DIR/scripts/create-gpu-machineset.sh" --instance-type g6e.xlarge --az "$az" --replicas 1 --apply
            print_success "GPU machineset created and scaled to 1 replica"
        else
            print_warning "GPU machineset script not found, skipping GPU node creation"
        fi
    fi

    print_info "Nodes are scaling in the background. Installation will continue."
    print_info "Check node status with: oc get nodes"
}

################################################################################
# 11. install_nfd_operator
################################################################################

install_nfd_operator() {
    print_step "Installing Node Feature Discovery (NFD) Operator..."

    if oc get csv -n openshift-nfd 2>/dev/null | grep -q nfd; then
        print_info "NFD Operator already installed"
        return 0
    fi

    oc create namespace openshift-nfd 2>/dev/null || true

    local og_count=$(oc get operatorgroup -n openshift-nfd -o name 2>/dev/null | wc -l | tr -d ' ')
    if [ "$og_count" -gt 0 ]; then
        print_info "Found $og_count existing OperatorGroup(s) in openshift-nfd namespace"
        oc delete operatorgroup --all -n openshift-nfd 2>/dev/null || true
        sleep 2
    fi

    oc apply -f "$_INSTALL_LIB_DIR/lib/manifests/operators/nfd-operator.yaml"
    wait_for_operator "nfd" "openshift-nfd"

    print_step "Creating NFD instance..."
    oc apply -f "$_INSTALL_LIB_DIR/lib/manifests/operators/nfd-instance.yaml"

    print_success "NFD Operator installed"
}

################################################################################
# 12. install_gpu_operator
################################################################################

install_gpu_operator() {
    print_step "Installing NVIDIA GPU Operator..."

    if oc get csv -n nvidia-gpu-operator 2>/dev/null | grep -q gpu-operator; then
        print_info "GPU Operator already installed"
        return 0
    fi

    oc create namespace nvidia-gpu-operator 2>/dev/null || true

    local og_count=$(oc get operatorgroup -n nvidia-gpu-operator -o name 2>/dev/null | wc -l | tr -d ' ')
    if [ "$og_count" -gt 0 ]; then
        print_info "Found $og_count existing OperatorGroup(s) in nvidia-gpu-operator namespace"
        oc delete operatorgroup --all -n nvidia-gpu-operator 2>/dev/null || true
        sleep 2
    fi

    oc apply -f "$_INSTALL_LIB_DIR/lib/manifests/operators/gpu-operator.yaml"
    wait_for_operator "gpu-operator" "nvidia-gpu-operator"

    print_step "Creating ClusterPolicy..."
    oc apply -f "$_INSTALL_LIB_DIR/lib/manifests/operators/gpu-clusterpolicy.yaml"

    print_success "GPU Operator installed"
}

################################################################################
# 13. install_kueue_operator
################################################################################

install_kueue_operator() {
    print_step "Installing Red Hat Build of Kueue Operator..."

    if oc get csv -n openshift-operators 2>/dev/null | grep -q kueue; then
        print_info "Kueue Operator already installed"
        return 0
    fi

    oc apply -f "$_INSTALL_LIB_DIR/lib/manifests/operators/kueue-subscription.yaml"
    wait_for_operator "kueue" "openshift-operators"

    print_success "Kueue Operator installed"
}

################################################################################
# 14. install_certmanager_operator
################################################################################

install_certmanager_operator() {
    print_step "Installing cert-manager Operator..."

    if oc get csv -n cert-manager-operator 2>/dev/null | grep -q cert-manager; then
        print_info "cert-manager Operator already installed"
        return 0
    fi

    oc create namespace cert-manager-operator 2>/dev/null || true

    local og_count=$(oc get operatorgroup -n cert-manager-operator -o name 2>/dev/null | wc -l | tr -d ' ')
    if [ "$og_count" -gt 0 ]; then
        print_info "Found $og_count existing OperatorGroup(s) in cert-manager-operator namespace"
        oc delete operatorgroup --all -n cert-manager-operator 2>/dev/null || true
        sleep 2
    fi

    oc apply -f "$_INSTALL_LIB_DIR/lib/manifests/operators/certmanager-operatorgroup.yaml"
    oc apply -f "$_INSTALL_LIB_DIR/lib/manifests/operators/certmanager-subscription.yaml"
    wait_for_operator "cert-manager" "cert-manager-operator"

    print_success "cert-manager Operator installed"
}

################################################################################
# 15. install_lws_operator
################################################################################

install_lws_operator() {
    print_step "Installing Leader Worker Set (LWS) Operator..."

    if oc get csv -n openshift-lws-operator 2>/dev/null | grep -q "leader-worker-set"; then
        print_info "LWS Operator already installed"
        return 0
    fi

    oc create namespace openshift-lws-operator 2>/dev/null || true

    local og_count=$(oc get operatorgroup -n openshift-lws-operator -o name 2>/dev/null | wc -l | tr -d ' ')
    if [ "$og_count" -gt 0 ]; then
        print_info "Found $og_count existing OperatorGroup(s) in openshift-lws-operator namespace"
        oc delete operatorgroup --all -n openshift-lws-operator 2>/dev/null || true
        sleep 2
    fi

    oc apply -f "$_INSTALL_LIB_DIR/lib/manifests/operators/lws-operatorgroup.yaml"
    oc apply -f "$_INSTALL_LIB_DIR/lib/manifests/operators/lws-subscription.yaml"
    wait_for_operator "leader-worker-set" "openshift-lws-operator"

    # Create LWS instance — use manifest file when available, inline YAML otherwise
    if [ "${LWS_CR_USE_MANIFEST:-true}" = "true" ] && [ -f "$_INSTALL_LIB_DIR/lib/manifests/operators/lws-operator-cr.yaml" ]; then
        oc apply -f "$_INSTALL_LIB_DIR/lib/manifests/operators/lws-operator-cr.yaml"
    else
        oc apply -f - <<EOF
apiVersion: operator.openshift.io/v1
kind: LeaderWorkerSetOperator
metadata:
  name: cluster
  namespace: openshift-lws-operator
spec:
  managementState: Managed
  logLevel: Normal
  operatorLogLevel: Normal
EOF
    fi

    print_success "LWS Operator installed"
}

################################################################################
# 16. install_servicemesh_operator
################################################################################

install_servicemesh_operator() {
    print_step "Installing OpenShift Service Mesh 3 Operator..."

    if oc get csv -n openshift-operators 2>/dev/null | grep -q "servicemeshoperator3.*Succeeded"; then
        print_info "Service Mesh 3 Operator already installed and ready"
    else
        if ! oc get subscription servicemeshoperator3 -n openshift-operators &>/dev/null; then
            # Use manifest file when available, inline YAML otherwise
            if [ "${SM3_USE_MANIFEST:-true}" = "true" ] && [ -f "$_INSTALL_LIB_DIR/lib/manifests/operators/servicemesh3-subscription.yaml" ]; then
                oc apply -f "$_INSTALL_LIB_DIR/lib/manifests/operators/servicemesh3-subscription.yaml"
            else
                oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: servicemeshoperator3
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Manual
  name: servicemeshoperator3
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
            fi
        fi

        print_step "Waiting for Service Mesh InstallPlan to be created..."
        local ip_wait=0
        local ip_timeout=60
        while [ $ip_wait -lt $ip_timeout ]; do
            local has_plan=$(oc get installplan -n openshift-operators -o json 2>/dev/null | \
                jq -r '[.items[] | select(.spec.approved == false) | select(.spec.clusterServiceVersionNames[] | test("servicemesh|kiali"))] | length' 2>/dev/null)
            if [ -n "$has_plan" ] && [ "$has_plan" -gt 0 ]; then
                print_info "Found pending InstallPlan(s)"
                break
            fi
            sleep 5
            ip_wait=$((ip_wait + 5))
        done

        approve_servicemesh_installplans

        print_step "Waiting for Service Mesh operator to be ready..."
        local timeout=300
        local elapsed=0
        until oc get csv -n openshift-operators 2>/dev/null | grep -q "servicemeshoperator3.*Succeeded"; do
            if [ $elapsed -ge $timeout ]; then
                print_warning "Service Mesh operator not ready after ${timeout}s (continuing anyway)"
                break
            fi
            approve_servicemesh_installplans 2>/dev/null || true
            sleep 10
            elapsed=$((elapsed + 10))
        done
    fi

    approve_servicemesh_installplans 2>/dev/null || true

    print_success "Service Mesh 3 Operator installed"
}

################################################################################
# 17. approve_servicemesh_installplans
################################################################################

approve_servicemesh_installplans() {
    local approved_any=false

    local all_pending=$(oc get installplan -n openshift-operators --no-headers 2>/dev/null | awk '{print $1}')
    for plan in $all_pending; do
        local is_approved=$(oc get installplan "$plan" -n openshift-operators -o jsonpath='{.spec.approved}' 2>/dev/null)
        if [ "$is_approved" = "false" ]; then
            local csv_names=$(oc get installplan "$plan" -n openshift-operators -o jsonpath='{.spec.clusterServiceVersionNames[*]}' 2>/dev/null)
            if echo "$csv_names" | grep -qiE "servicemesh|kiali|sail"; then
                print_step "Approving InstallPlan: $plan (CSVs: $csv_names)"
                oc patch installplan "$plan" -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
                print_success "Approved InstallPlan: $plan"
                approved_any=true
            fi
        fi
    done

    if [ "$approved_any" = true ]; then
        sleep 10
    fi
}

################################################################################
# 18. approve_rhcl_installplans
################################################################################

approve_rhcl_installplans() {
    local all_pending=$(oc get installplan -n openshift-operators --no-headers 2>/dev/null | awk '{print $1}')
    for plan in $all_pending; do
        local is_approved=$(oc get installplan "$plan" -n openshift-operators -o jsonpath='{.spec.approved}' 2>/dev/null)
        if [ "$is_approved" = "false" ]; then
            local csv_names=$(oc get installplan "$plan" -n openshift-operators -o jsonpath='{.spec.clusterServiceVersionNames[*]}' 2>/dev/null)
            if echo "$csv_names" | grep -qiE "rhcl|authorino|limitador|dns-operator"; then
                print_step "Approving RHCL InstallPlan: $plan"
                print_info "  CSVs: $csv_names"
                oc patch installplan "$plan" -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
                print_success "Approved InstallPlan: $plan"
            fi
        fi
    done
}

################################################################################
# 19. setup_istio_for_kuadrant
################################################################################

setup_istio_for_kuadrant() {
    print_step "Setting up Istio for Kuadrant..."

    oc create namespace istio-system 2>/dev/null || true
    oc create namespace istio-cni 2>/dev/null || true

    if oc get istio default -n istio-system &>/dev/null; then
        print_info "Istio instance already exists in istio-system"
    else
        local istio_version=$(oc get istio -A -o jsonpath='{.items[0].spec.version}' 2>/dev/null || echo "${ISTIO_FALLBACK_VERSION:-v1.30.1}")

        print_step "Creating IstioCNI..."
        if [ -f "$_INSTALL_LIB_DIR/lib/manifests/rhcl/istiocni.yaml" ]; then
            export ISTIO_VERSION="$istio_version"
            envsubst '${ISTIO_VERSION}' < "$_INSTALL_LIB_DIR/lib/manifests/rhcl/istiocni.yaml" | oc apply -f -
        else
            oc apply -f - <<EOF
apiVersion: sailoperator.io/v1
kind: IstioCNI
metadata:
  name: default
  namespace: istio-system
spec:
  namespace: istio-cni
  version: $istio_version
EOF
        fi

        print_step "Waiting for IstioCNI to be ready..."
        local elapsed=0
        local timeout=120
        while [ $elapsed -lt $timeout ]; do
            local cni_ready=$(oc get istiocni default -n istio-cni -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            if [ "$cni_ready" = "True" ]; then
                print_success "IstioCNI is ready"
                break
            fi
            sleep 10
            elapsed=$((elapsed + 10))
            echo "  Waiting for IstioCNI... (${elapsed}s elapsed)"
        done

        print_step "Creating Istio instance in istio-system..."
        if [ -f "$_INSTALL_LIB_DIR/lib/manifests/rhcl/istio.yaml" ]; then
            export ISTIO_VERSION="$istio_version"
            envsubst '${ISTIO_VERSION}' < "$_INSTALL_LIB_DIR/lib/manifests/rhcl/istio.yaml" | oc apply -f -
        else
            oc apply -f - <<EOF
apiVersion: sailoperator.io/v1
kind: Istio
metadata:
  name: default
  namespace: istio-system
spec:
  namespace: istio-system
  version: $istio_version
EOF
        fi

        print_step "Waiting for Istio to be healthy..."
        elapsed=0
        timeout=180
        while [ $elapsed -lt $timeout ]; do
            local istio_status=$(oc get istio default -n istio-system -o jsonpath='{.status.state}' 2>/dev/null)
            if [ "$istio_status" = "Healthy" ]; then
                print_success "Istio is healthy"
                break
            fi
            sleep 10
            elapsed=$((elapsed + 10))
            echo "  Waiting for Istio... Status: $istio_status (${elapsed}s elapsed)"
        done
    fi

    # API server may bounce during Istio/Sail webhook registration
    wait_for_api_server 90

    # Optionally fix OCP ingress operator ISTIO_VERSION mismatch
    if [ "${FEATURE_INGRESS_ISTIO_PATCH:-false}" = "true" ]; then
        local ingress_istio_ver
        ingress_istio_ver=$(oc get deployment ingress-operator -n openshift-ingress-operator \
            -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="ISTIO_VERSION")].value}' 2>/dev/null)
        if [ -n "$ingress_istio_ver" ]; then
            local istio_version_needed
            istio_version_needed=$(oc get istio -A -o jsonpath='{.items[0].spec.version}' 2>/dev/null || echo "${ISTIO_FALLBACK_VERSION:-v1.30.1}")
            if [ "$ingress_istio_ver" != "$istio_version_needed" ]; then
                local sm_pod
                sm_pod=$(oc get pods -n openshift-operators --no-headers 2>/dev/null | grep servicemesh-operator | head -1 | awk '{print $1}')
                if [ -n "$sm_pod" ]; then
                    local supported_versions
                    supported_versions=$(oc logs "$sm_pod" -n openshift-operators 2>/dev/null \
                        | grep "config loaded" | grep -oE '"v[0-9]+\.[0-9]+\.[0-9]+"' | tr -d '"' | sort -u)
                    if [ -n "$supported_versions" ] && ! echo "$supported_versions" | grep -q "^${ingress_istio_ver}$"; then
                        print_warning "OCP ingress operator has ISTIO_VERSION=$ingress_istio_ver (unsupported by SM operator)"
                        print_step "Patching ingress operator to ISTIO_VERSION=$istio_version_needed..."
                        oc set env deployment/ingress-operator -n openshift-ingress-operator \
                            ISTIO_VERSION="$istio_version_needed" 2>/dev/null
                        print_success "Ingress operator patched"
                        sleep 10
                    fi
                fi
            fi
        fi
    fi

    if ! oc get gatewayclass openshift-default &>/dev/null; then
        print_step "Creating openshift-default GatewayClass..."
        if [ -f "$_INSTALL_LIB_DIR/lib/manifests/rhcl/gatewayclass-default.yaml" ]; then
            local attempt=1
            while [ $attempt -le 3 ]; do
                if oc apply -f "$_INSTALL_LIB_DIR/lib/manifests/rhcl/gatewayclass-default.yaml"; then
                    break
                fi
                print_warning "GatewayClass creation failed (attempt $attempt/3), waiting for API server..."
                wait_for_api_server 60
                attempt=$((attempt + 1))
            done
        else
            oc apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: openshift-default
spec:
  controllerName: openshift.io/gateway-controller/v1
EOF
        fi
    fi

    print_success "Istio setup complete for Kuadrant"
}

################################################################################
# 20. restart_kuadrant_operator
################################################################################

restart_kuadrant_operator() {
    print_step "Restarting Kuadrant operator to detect Istio..."

    local pod_name=$(oc get pods -n kuadrant-system -o name 2>/dev/null | grep kuadrant-operator-controller)
    if [ -n "$pod_name" ]; then
        oc delete $pod_name -n kuadrant-system 2>/dev/null || true
        sleep 20
    fi

    print_step "Waiting for Kuadrant to be ready..."
    local elapsed=0
    local timeout=120
    while [ $elapsed -lt $timeout ]; do
        local kuadrant_ready=$(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        local kuadrant_reason=$(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)

        if [ "$kuadrant_ready" = "True" ]; then
            print_success "Kuadrant is ready"
            return 0
        fi

        sleep 10
        elapsed=$((elapsed + 10))
        echo "  Waiting for Kuadrant... Reason: $kuadrant_reason (${elapsed}s elapsed)"
    done

    print_warning "Kuadrant may not be fully ready. Check: oc get kuadrant -n kuadrant-system"
}
