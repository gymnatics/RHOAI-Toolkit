#!/bin/bash
################################################################################
# Shared Install Functions -- Common to RHOAI 3.4 and 3.5 Installers
################################################################################
# Extracted from install-rhoai-34.sh / install-rhoai-35.sh: these 29 functions
# were verified byte-for-byte identical between the two installers (Sep 2026
# unification pass). Covers logging helpers, operator wait/retry helpers,
# prerequisite operator installs (NFD/GPU/Kueue/cert-manager/LWS), node
# scaling, admin user creation, RHOAI operator install, gateway TLS/passthrough
# routes, hardware profile creation, COO/UIPlugins observability setup,
# Grafana + native Observe dashboards, MCP catalog prerequisites, and demo
# user provisioning.
#
# Sourced by install-rhoai-34.sh and install-rhoai-35.sh. Not version-specific
# -- if a function here ever needs to diverge between versions, move it back
# out into the version-specific script rather than adding branching here.
################################################################################

print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

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

    # Create rhods-admins group and add admin
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

    oc apply -f "$ROOT_DIR/lib/manifests/operators/nfd-operator.yaml"
    wait_for_operator "nfd" "openshift-nfd"

    print_step "Creating NFD instance..."
    oc apply -f "$ROOT_DIR/lib/manifests/operators/nfd-instance.yaml"

    print_success "NFD Operator installed"
}

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

    oc apply -f "$ROOT_DIR/lib/manifests/operators/gpu-operator.yaml"
    wait_for_operator "gpu-operator" "nvidia-gpu-operator"

    print_step "Creating ClusterPolicy..."
    oc apply -f "$ROOT_DIR/lib/manifests/operators/gpu-clusterpolicy.yaml"

    print_success "GPU Operator installed"
}

install_kueue_operator() {
    print_step "Installing Red Hat Build of Kueue Operator..."

    if oc get csv -n openshift-operators 2>/dev/null | grep -q kueue; then
        print_info "Kueue Operator already installed"
        return 0
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/operators/kueue-subscription.yaml"
    wait_for_operator "kueue" "openshift-operators"

    print_success "Kueue Operator installed"
}

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

    oc apply -f "$ROOT_DIR/lib/manifests/operators/certmanager-operatorgroup.yaml"
    oc apply -f "$ROOT_DIR/lib/manifests/operators/certmanager-subscription.yaml"
    wait_for_operator "cert-manager" "cert-manager-operator"

    print_success "cert-manager Operator installed"
}

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

    oc apply -f "$ROOT_DIR/lib/manifests/operators/lws-operatorgroup.yaml"
    oc apply -f "$ROOT_DIR/lib/manifests/operators/lws-subscription.yaml"
    wait_for_operator "leader-worker-set" "openshift-lws-operator"

    oc apply -f "$ROOT_DIR/lib/manifests/operators/lws-operator-cr.yaml"

    print_success "LWS Operator installed"
}

enable_user_workload_monitoring() {
    print_step "Enabling User Workload Monitoring..."

    oc apply -f "$ROOT_DIR/lib/manifests/monitoring/cluster-monitoring-config.yaml"

    print_success "User Workload Monitoring enabled"
}

install_coo_operator() {
    print_step "Installing Cluster Observability Operator (COO)..."

    if oc get csv -n openshift-cluster-observability-operator 2>/dev/null | grep -q "cluster-observability-operator.*Succeeded"; then
        print_info "COO already installed"
        return 0
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/observability/coo-namespace.yaml"
    oc apply -f "$ROOT_DIR/lib/manifests/observability/coo-operatorgroup.yaml"
    oc apply -f "$ROOT_DIR/lib/manifests/observability/coo-subscription.yaml"

    print_step "Waiting for COO operator to be ready..."
    local elapsed=0
    while [ $elapsed -lt 180 ]; do
        if oc get csv -n openshift-cluster-observability-operator 2>/dev/null | grep -q "cluster-observability-operator.*Succeeded"; then
            print_success "COO operator installed (Perses CRDs available)"
            return 0
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done

    print_warning "COO operator not ready after 180s (may still be installing)"
}

setup_observability_uiplugins() {
    print_step "Setting up observability UIPlugins..."

    if ! oc get crd uiplugins.observability.openshift.io &>/dev/null 2>&1; then
        print_warning "UIPlugin CRD not found — COO may not be installed yet"
        return 0
    fi

    if oc get uiplugin dashboards &>/dev/null 2>&1; then
        local dash_avail
        dash_avail=$(oc get uiplugin dashboards -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$dash_avail" = "True" ]; then
            print_info "UIPlugin 'dashboards' already available [SKIP]"
        fi
    else
        oc apply -f - <<'EOF'
apiVersion: observability.openshift.io/v1alpha1
kind: UIPlugin
metadata:
  name: dashboards
spec:
  type: Dashboards
EOF
    fi

    oc apply -f - <<'EOF'
apiVersion: observability.openshift.io/v1alpha1
kind: UIPlugin
metadata:
  name: monitoring
spec:
  type: Monitoring
  monitoring:
    perses:
      enabled: true
EOF

    local elapsed=0
    while [ $elapsed -lt 60 ]; do
        local mon_avail
        mon_avail=$(oc get uiplugin monitoring -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$mon_avail" = "True" ]; then
            print_success "UIPlugins ready (dashboards + monitoring with Perses)"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    print_warning "UIPlugin 'monitoring' not yet Available — check: oc get uiplugin monitoring -o yaml"
}

configure_gateway_telemetry() {
    print_step "Configuring gateway telemetry for MaaS usage metrics..."

    oc apply -f "$ROOT_DIR/lib/manifests/observability/gateway-telemetry-policy.yaml" 2>/dev/null || \
        print_warning "TelemetryPolicy CRD not available (RHCL may need upgrade)"
    oc apply -f "$ROOT_DIR/lib/manifests/observability/istio-gateway-telemetry.yaml" 2>/dev/null || \
        print_warning "Istio Telemetry CRD not available"

    print_success "Gateway telemetry configured"
}

install_rhoai_operator() {
    print_step "Installing Red Hat OpenShift AI Operator..."

    oc create namespace redhat-ods-operator 2>/dev/null || true

    if oc get csv -n redhat-ods-operator 2>/dev/null | grep -q rhods; then
        print_info "RHOAI Operator already installed"
        return 0
    fi

    if [ -z "$RHOAI_CHANNEL" ]; then
        select_rhoai_channel
    else
        print_info "Using specified channel: $RHOAI_CHANNEL"
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/rhoai/rhoai-operatorgroup.yaml"

    print_step "Creating RHOAI subscription with channel: $RHOAI_CHANNEL"
    export RHOAI_CHANNEL
    envsubst '${RHOAI_CHANNEL}' < "$ROOT_DIR/lib/manifests/rhoai/rhoai-subscription.yaml" | oc apply -f -

    wait_for_operator "rhods" "redhat-ods-operator"

    print_success "RHOAI Operator installed (channel: $RHOAI_CHANNEL)"
}

setup_mcp_catalog_prerequisites() {
    local namespace="${1:?Namespace required}"

    print_step "Setting up MCP Catalog prerequisites in $namespace..."

    if ! oc get sa mcp-viewer -n "$namespace" &>/dev/null; then
        print_step "Creating mcp-viewer ServiceAccount..."
        oc create serviceaccount mcp-viewer -n "$namespace"
        oc create clusterrolebinding "mcp-viewer-${namespace}" \
            --clusterrole=view \
            --serviceaccount="${namespace}:mcp-viewer" 2>/dev/null || true
        print_success "mcp-viewer ServiceAccount + view ClusterRoleBinding created"
    else
        print_success "mcp-viewer ServiceAccount already exists [SKIP]"
    fi

    if ! oc get configmap openshift-mcp-server-config -n "$namespace" &>/dev/null; then
        print_step "Creating openshift-mcp-server-config ConfigMap..."
        cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: openshift-mcp-server-config
  namespace: $namespace
data:
  config.toml: |
    port = "8080"
    read_only = true
    stateless = true
    toolsets = ["core", "config", "openshift"]
EOF
        print_success "openshift-mcp-server-config ConfigMap created"
    else
        print_success "openshift-mcp-server-config ConfigMap already exists [SKIP]"
    fi
}

create_gateway_tls_secret() {
    if oc get secret default-gateway-tls -n openshift-ingress &>/dev/null; then
        print_success "default-gateway-tls secret already exists"
        return 0
    fi

    print_step "Creating default-gateway-tls secret for gateway HTTPS listeners..."

    # Strategy 0: If no ClusterIssuer exists, try to set up TLS automatically
    local issuer
    issuer=$(oc get clusterissuers -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -z "$issuer" ] && [ -f "$ROOT_DIR/scripts/setup-letsencrypt-tls.sh" ]; then
        print_info "No ClusterIssuer found. Running Let's Encrypt TLS setup..."
        "$ROOT_DIR/scripts/setup-letsencrypt-tls.sh" letsencrypt 2>/dev/null || \
            "$ROOT_DIR/scripts/setup-letsencrypt-tls.sh" selfsigned 2>/dev/null || true
        issuer=$(oc get clusterissuers -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    fi

    # Strategy 1: Use cert-manager Certificate CR if a ClusterIssuer exists
    if [ -n "$issuer" ]; then
        print_info "Found ClusterIssuer '$issuer' — creating Certificate CR..."
        export ISSUER_NAME="$issuer"
        envsubst '${CLUSTER_DOMAIN} ${ISSUER_NAME}' < "$ROOT_DIR/lib/manifests/rhcl/gateway-tls-certificate.yaml" | oc_apply_retry
        print_step "Waiting for cert-manager to generate TLS secret..."
        local wait=0
        while [ $wait -lt 120 ]; do
            if oc get secret default-gateway-tls -n openshift-ingress &>/dev/null; then
                print_success "default-gateway-tls created by cert-manager"
                return 0
            fi
            sleep 5
            wait=$((wait + 5))
        done
        print_warning "cert-manager did not create secret within 120s"
    fi

    # Strategy 2: Copy from existing wildcard cert (e.g. Let's Encrypt or router default)
    local wildcard_secrets=("apps-wildcard-tls" "cert-manager-ingress-cert" "router-certs-default")
    for src in "${wildcard_secrets[@]}"; do
        if oc get secret "$src" -n openshift-ingress &>/dev/null 2>&1; then
            local cert_cn
            cert_cn=$(oc get secret "$src" -n openshift-ingress -o jsonpath='{.data.tls\.crt}' 2>/dev/null \
                | base64 -d 2>/dev/null | openssl x509 -noout -subject 2>/dev/null || true)
            if echo "$cert_cn" | grep -q "${CLUSTER_DOMAIN}"; then
                print_info "Copying wildcard cert from '$src'..."
                local tmpdir_cert
                tmpdir_cert=$(mktemp -d)
                oc get secret "$src" -n openshift-ingress -o jsonpath='{.data.tls\.crt}' | base64 -d > "$tmpdir_cert/tls.crt"
                oc get secret "$src" -n openshift-ingress -o jsonpath='{.data.tls\.key}' | base64 -d > "$tmpdir_cert/tls.key"
                oc create secret tls default-gateway-tls \
                    --cert="$tmpdir_cert/tls.crt" --key="$tmpdir_cert/tls.key" \
                    -n openshift-ingress --dry-run=client -o yaml | \
                    oc label --local -f - app.kubernetes.io/managed-by=rhoai-toolkit --dry-run=client -o yaml | \
                    oc apply -f -
                rm -rf "$tmpdir_cert"
                print_success "default-gateway-tls created from '$src'"
                return 0
            fi
        fi
    done

    # Strategy 3: Check openshift-ingress-operator for router-ca
    if oc get secret router-ca -n openshift-ingress-operator &>/dev/null 2>&1; then
        print_info "Using OpenShift router-ca to generate self-signed gateway cert..."
        local ca_crt ca_key
        ca_crt=$(oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.crt}' | base64 -d)
        ca_key=$(oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.key}' | base64 -d)
        local tmpdir
        tmpdir=$(mktemp -d)
        echo "$ca_crt" > "$tmpdir/ca.crt"
        echo "$ca_key" > "$tmpdir/ca.key"
        openssl req -new -newkey rsa:2048 -nodes \
            -keyout "$tmpdir/tls.key" -out "$tmpdir/tls.csr" \
            -subj "/CN=*.apps.${CLUSTER_DOMAIN}" \
            -addext "subjectAltName=DNS:*.apps.${CLUSTER_DOMAIN},DNS:apps.${CLUSTER_DOMAIN}" 2>/dev/null
        openssl x509 -req -in "$tmpdir/tls.csr" -CA "$tmpdir/ca.crt" -CAkey "$tmpdir/ca.key" \
            -CAcreateserial -out "$tmpdir/tls.crt" -days 365 \
            -extfile <(printf "subjectAltName=DNS:*.apps.${CLUSTER_DOMAIN},DNS:apps.${CLUSTER_DOMAIN}") 2>/dev/null
        oc create secret tls default-gateway-tls \
            --cert="$tmpdir/tls.crt" --key="$tmpdir/tls.key" \
            -n openshift-ingress 2>/dev/null
        rm -rf "$tmpdir"
        print_success "default-gateway-tls created (signed by router-ca)"
        return 0
    fi

    print_error "Could not create default-gateway-tls — no cert-manager, wildcard cert, or router-ca found"
    print_info "Create it manually: oc create secret tls default-gateway-tls --cert=tls.crt --key=tls.key -n openshift-ingress"
    return 1
}

create_gateway_passthrough_routes() {
    # The *.apps.<cluster> wildcard DNS points to the default OpenShift Router,
    # but gateway pods get their own LoadBalancer. A passthrough Route bridges them.
    local gateways=("maas-default-gateway:maas" "openshift-ai-inference:inference-gateway")

    for entry in "${gateways[@]}"; do
        local gw_name="${entry%%:*}"
        local hostname_prefix="${entry##*:}"
        local route_name="${gw_name}-passthrough"
        local hostname="${hostname_prefix}.apps.${CLUSTER_DOMAIN}"

        if oc get route "$route_name" -n openshift-ingress &>/dev/null; then
            print_info "Passthrough route '$route_name' already exists"
            continue
        fi

        local svc_name
        svc_name=$(oc get svc -n openshift-ingress -l "gateway.networking.k8s.io/gateway-name=${gw_name}" \
            -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

        if [ -z "$svc_name" ]; then
            print_warning "No service found for gateway '$gw_name' — skipping passthrough route"
            continue
        fi

        print_step "Creating passthrough route: ${hostname} → ${svc_name}..."
        export ROUTE_NAME="$route_name"
        export HOSTNAME="$hostname"
        export SERVICE_NAME="$svc_name"
        envsubst '${ROUTE_NAME} ${HOSTNAME} ${SERVICE_NAME}' \
            < "$ROOT_DIR/lib/manifests/rhcl/gateway-passthrough-route.yaml" | oc_apply_retry
    done
    print_success "Gateway passthrough routes configured"
}

create_hardware_profile() {
    print_step "Creating default GPU hardware profile..."

    oc apply -f "$ROOT_DIR/lib/manifests/rhoai/hardware-profile-gpu.yaml"

    print_success "Hardware profile created"
}

deploy_observe_dashboards() {
    print_step "Deploying dashboards to OpenShift Observe tab..."

    local dashboard_dir="$ROOT_DIR/lib/manifests/dashboards"
    local namespace="openshift-config-managed"

    local cm_names="nvidia-dcgm-exporter-dashboard vllm-performance-dashboard vllm-advanced-dashboard"
    local cm_files="dcgm-exporter-dashboard.json vllm-performance-ocp.json vllm-advanced-ocp.json"

    local i=1
    for cm_name in $cm_names; do
        local file
        file=$(echo "$cm_files" | cut -d' ' -f"$i")
        i=$((i + 1))
        if [ ! -f "$dashboard_dir/$file" ]; then
            print_warning "Dashboard file not found: $dashboard_dir/$file"
            continue
        fi

        if oc get configmap "$cm_name" -n "$namespace" &>/dev/null; then
            print_info "Dashboard '$cm_name' already exists [SKIP]"
            continue
        fi

        oc create configmap "$cm_name" \
            -n "$namespace" \
            --from-file="$dashboard_dir/$file"

        oc label configmap "$cm_name" \
            -n "$namespace" \
            "console.openshift.io/dashboard=true" --overwrite

        oc label configmap "$cm_name" \
            -n "$namespace" \
            "console.openshift.io/odc-dashboard=true" --overwrite
    done

    print_success "Dashboards deployed -> Observe > Dashboards"
}

deploy_grafana_monitoring() {
    print_step "Deploying Grafana monitoring stack..."

    local grafana_ns="monitoring"
    oc create namespace "$grafana_ns" 2>/dev/null || true

    if oc get deployment grafana -n "$grafana_ns" &>/dev/null; then
        print_info "Grafana already deployed [SKIP]"
    else
        oc apply -f "$ROOT_DIR/lib/manifests/grafana/grafana-deployment.yaml" -n "$grafana_ns"
        print_step "Waiting for Grafana pod..."
        oc wait --for=condition=ready pod -l app=grafana -n "$grafana_ns" --timeout=120s 2>/dev/null || true
        print_success "Grafana deployed"
    fi

    oc apply -f "$ROOT_DIR/lib/manifests/grafana/prometheus-token.yaml" 2>/dev/null || true

    local token=""
    local retries=0
    while [ $retries -lt 6 ] && [ -z "$token" ]; do
        token=$(oc get secret grafana-prometheus-token -n openshift-monitoring \
            -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null)
        [ -z "$token" ] && sleep 5 && retries=$((retries + 1))
    done

    if [ -z "$token" ]; then
        token=$(oc create token prometheus-k8s -n openshift-monitoring --duration=87600h 2>/dev/null || true)
    fi

    if [ -z "$token" ]; then
        print_warning "Could not get Prometheus token for Grafana datasource"
        return 0
    fi

    local grafana_route
    grafana_route=$(oc get route grafana -n "$grafana_ns" -o jsonpath='{.spec.host}' 2>/dev/null)

    if [ -n "$grafana_route" ]; then
        print_step "Configuring Prometheus datasource..."
        curl -sk -X POST "https://${grafana_route}/api/datasources" \
            -u admin:admin \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"Prometheus\",
                \"type\": \"prometheus\",
                \"url\": \"https://thanos-querier.openshift-monitoring.svc:9091\",
                \"access\": \"proxy\",
                \"isDefault\": true,
                \"jsonData\": {
                    \"httpHeaderName1\": \"Authorization\",
                    \"tlsSkipVerify\": true
                },
                \"secureJsonData\": {
                    \"httpHeaderValue1\": \"Bearer ${token}\"
                }
            }" &>/dev/null && print_success "Prometheus datasource configured" \
            || print_info "Datasource may already exist"

        for dashboard_file in "$ROOT_DIR"/lib/manifests/grafana/*-dashboard.json; do
            [ -f "$dashboard_file" ] || continue
            local dash_name
            dash_name=$(basename "$dashboard_file" .json)
            print_step "Importing dashboard: $dash_name..."
            local dash_json
            dash_json=$(cat "$dashboard_file")
            curl -sk -X POST "https://${grafana_route}/api/dashboards/db" \
                -u admin:admin \
                -H "Content-Type: application/json" \
                -d "{\"dashboard\": ${dash_json}, \"overwrite\": true}" &>/dev/null \
                && print_success "  Imported: $dash_name" \
                || print_warning "  Failed to import: $dash_name"
        done
    fi

    get_cluster_domain
    export CLUSTER_DOMAIN
    envsubst '${CLUSTER_DOMAIN}' < "$ROOT_DIR/lib/manifests/monitoring/consolelinks-grafana.yaml" | oc apply -f - 2>/dev/null || true
    envsubst '${CLUSTER_DOMAIN}' < "$ROOT_DIR/lib/manifests/monitoring/odhapplication-grafana.yaml" | oc apply -f - 2>/dev/null || true

    print_success "Grafana monitoring stack deployed"
    if [ -n "$grafana_route" ]; then
        print_info "Grafana URL: https://${grafana_route}"
        print_info "Dashboards: GPU Metrics (DCGM), vLLM Inference, vLLM Advanced"
    fi
}

setup_demo_users() {
    local num_users="${1:-5}"
    local admin_group="${2:-rhods-admins}"
    local user_group="${3:-rhods-users}"
    local password="${4:-openshift}"

    print_step "Setting up ${num_users} demo users with groups '${admin_group}' and '${user_group}'..."

    # Ensure htpasswd is available
    if ! command -v htpasswd &>/dev/null; then
        if command -v python3 &>/dev/null; then
            _htpasswd_add() {
                local file="$1" user="$2" pass="$3"
                local hash
                hash=$(python3 -c "import bcrypt; print(bcrypt.hashpw('${pass}'.encode(), bcrypt.gensalt()).decode())" 2>/dev/null) || \
                hash=$(python3 -c "import passlib.hash; print(passlib.hash.bcrypt.hash('${pass}'))" 2>/dev/null) || \
                hash=$(openssl passwd -apr1 "${pass}" 2>/dev/null)
                echo "${user}:${hash}" >> "$file"
            }
        else
            print_error "htpasswd or python3 required for user creation"
            return 1
        fi
    fi

    local tmpdir
    tmpdir=$(mktemp -d)
    local htpasswd_file="${tmpdir}/htpasswd"
    touch "$htpasswd_file"

    # Collect existing htpasswd data if it exists
    if oc get secret htpasswd-secret -n openshift-config &>/dev/null 2>&1; then
        oc get secret htpasswd-secret -n openshift-config -o jsonpath='{.data.htpasswd}' 2>/dev/null \
            | base64 -d > "$htpasswd_file" 2>/dev/null || true
    fi

    local admin_users=""
    local regular_users=""

    for i in $(seq 1 "$num_users"); do
        local username="user${i}"
        if grep -q "^${username}:" "$htpasswd_file" 2>/dev/null; then
            print_info "User '${username}' already exists in htpasswd — skipping"
        else
            if command -v htpasswd &>/dev/null; then
                htpasswd -bB "$htpasswd_file" "$username" "$password" 2>/dev/null
            else
                _htpasswd_add "$htpasswd_file" "$username" "$password"
            fi
            print_info "Created user '${username}'"
        fi

        if [ "$i" -eq 1 ]; then
            admin_users="${username}"
        else
            regular_users="${regular_users:+${regular_users},}${username}"
        fi
    done

    # Create/update htpasswd secret
    oc create secret generic htpasswd-secret \
        --from-file=htpasswd="$htpasswd_file" \
        -n openshift-config --dry-run=client -o yaml | oc apply -f -

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
        print_info "OAuth will restart — users may take 1-2 minutes to become available"
    fi

    # Create groups
    for grp in "$admin_group" "$user_group"; do
        if ! oc get group "$grp" &>/dev/null 2>&1; then
            print_step "Creating group '${grp}'..."
            oc adm groups new "$grp" 2>/dev/null || true
        fi
    done

    # Add user1 to admin group, rest to user group
    if [ -n "$admin_users" ]; then
        print_step "Adding ${admin_users} to '${admin_group}' (admin)..."
        oc adm groups add-users "$admin_group" "$admin_users" 2>/dev/null || true
        # Give cluster-admin to admin users for RHOAI dashboard access
        oc adm policy add-cluster-role-to-user cluster-admin "$admin_users" 2>/dev/null || true
    fi

    if [ -n "$regular_users" ]; then
        local IFS=','
        for u in $regular_users; do
            oc adm groups add-users "$user_group" "$u" 2>/dev/null || true
        done
        unset IFS
        print_step "Added ${num_users-1} users to '${user_group}' (regular)"
    fi

    rm -rf "$tmpdir"

    print_success "Demo users created:"
    echo -e "  ${CYAN}Admin group (${admin_group}):${NC} ${admin_users}"
    echo -e "  ${CYAN}User group (${user_group}):${NC} ${regular_users}"
    echo -e "  ${CYAN}Password:${NC} ${password}"
    echo -e "  ${CYAN}Login:${NC} oc login -u user1 -p ${password}"
    echo ""
    echo -e "  ${YELLOW}Note:${NC} When creating MaaS Subscriptions, set owner group to '${admin_group}' or '${user_group}'"
    echo -e "  ${YELLOW}Note:${NC} Users may take 1-2 minutes to be available after OAuth restart"
}


################################################################################
# Tier 2 -- required a small parameterization pass to become identical
# (RHOAI_VERSION_LABEL / RHOAI_MAX_VALIDATED_OCP / MAAS_INFRA_NS variables,
# set per-version at the top of install-rhoai-{34,35}.sh) before extraction.
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

    if [[ "$ocp_version" < "4.19" ]]; then
        print_error "RHOAI ${RHOAI_VERSION_LABEL} requires OpenShift 4.19 or later. Current: $ocp_version"
        exit 1
    fi

    if [ -n "$RHOAI_MAX_VALIDATED_OCP" ] && [[ "$ocp_version" > "$RHOAI_MAX_VALIDATED_OCP" ]]; then
        print_warning "RHOAI ${RHOAI_VERSION_LABEL} is validated up to OCP ${RHOAI_MAX_VALIDATED_OCP}. Current: $ocp_version (proceeding anyway)"
    fi

    if [ "$ENABLE_LLMD" = true ] && [[ "$ocp_version" < "4.20" ]]; then
        print_warning "Distributed inference with llm-d requires OCP 4.20+. Current: $ocp_version"
        print_warning "llm-d will be installed but multi-node inference may not work correctly."
    fi

    print_success "Prerequisites check passed"
}

create_thanos_proxy_secret() {
    local dash_ns="redhat-ods-applications"

    if ! oc get namespace "$dash_ns" &>/dev/null; then
        return 0
    fi

    # Always create the secret — it's harmless when observabilityDashboard is off,
    # and required immediately when someone enables it later via the menu.
    # Previously this was gated on observabilityDashboard=true, which caused the
    # secret to be missing when the flag was enabled post-install.
    print_step "Creating Thanos proxy secret for observability dashboard..."

    if oc get secret monitoring-thanos-proxy-secret -n "$dash_ns" &>/dev/null; then
        local existing_token thanos_host http_code
        existing_token=$(oc get secret monitoring-thanos-proxy-secret -n "$dash_ns" \
            -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
        thanos_host=$(oc get route thanos-querier -n openshift-monitoring \
            -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
        if [ -n "$existing_token" ] && [ -n "$thanos_host" ]; then
            http_code=$(curl -sk --connect-timeout 5 --max-time 10 -o /dev/null -w "%{http_code}" \
                -H "Authorization: Bearer ${existing_token}" \
                "https://${thanos_host}/api/v1/query?query=up" 2>/dev/null || echo "000")
            if [ "$http_code" -eq 200 ] 2>/dev/null; then
                print_success "Thanos proxy secret valid (HTTP 200)"
                return 0
            fi
        fi
        oc delete secret monitoring-thanos-proxy-secret -n "$dash_ns" &>/dev/null || true
    fi

    local new_token thanos_host
    new_token=$(oc create token rhods-dashboard -n "$dash_ns" --duration=87600h 2>/dev/null || echo "")
    thanos_host=$(oc get route thanos-querier -n openshift-monitoring \
        -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

    if [ -z "$new_token" ] || [ -z "$thanos_host" ]; then
        print_warning "Could not generate token or find Thanos route"
        return 0
    fi

    oc apply -f - <<EOF
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

    print_success "Thanos proxy secret created (10-year token)"
}

create_inference_gateway() {
    print_step "Creating openshift-ai-inference Gateway (direct model access, outside MaaS)..."

    get_cluster_domain

    print_step "Creating openshift-ai-inference gateway..."
    if ! oc get gatewayclass openshift-ai-inference &>/dev/null; then
        oc_apply_retry -f "$ROOT_DIR/lib/manifests/rhcl/gatewayclass-ai-inference.yaml"
    fi

    export CERT_NAME="default-gateway-tls"
    envsubst '${CLUSTER_DOMAIN} ${CERT_NAME}' < "$ROOT_DIR/lib/manifests/rhcl/gateway-inference.yaml" | oc_apply_retry

    # Create passthrough Routes so *.apps.<cluster> wildcard DNS reaches both
    # gateways (each gets its own LoadBalancer ELB, but *.apps.<cluster> DNS
    # points to the default OpenShift Router).
    create_gateway_passthrough_routes

    print_step "Waiting for GatewayClass and Gateway readiness..."
    oc wait --for=condition=Accepted gatewayclass/openshift-default --timeout=120s 2>/dev/null || \
        print_warning "openshift-default GatewayClass not yet Accepted"
    oc wait --for=condition=Programmed gateway/openshift-ai-inference -n openshift-ingress --timeout=120s 2>/dev/null || \
        print_warning "openshift-ai-inference gateway not yet Programmed"

    print_success "Gateways created"
    print_info "MaaS endpoint: https://maas.apps.${CLUSTER_DOMAIN}"
    print_info "Inference endpoint: https://inference-gateway.apps.${CLUSTER_DOMAIN}"
}

create_mlflow_server() {
    print_step "Creating MLflow server instance..."

    if oc get mlflow mlflow &>/dev/null 2>&1; then
        local mlflow_ready=$(oc get mlflow mlflow -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$mlflow_ready" = "True" ]; then
            print_success "MLflow server already exists and is ready"
            return 0
        fi
        print_info "MLflow server exists but not yet ready"
        return 0
    fi

    if ! oc get crd mlflows.mlflow.opendatahub.io &>/dev/null 2>&1; then
        print_warning "MLflow CRD not found — MLflow operator may not be ready yet"
        print_info "You can create it later: oc apply -f <mlflow-cr.yaml>"
        return 0
    fi

    if oc get deployment postgres -n "$MAAS_INFRA_NS" &>/dev/null; then
        print_info "Using existing PostgreSQL (in $MAAS_INFRA_NS) for MLflow backend..."
        local pg_pod
        pg_pod=$(oc get pods -n "$MAAS_INFRA_NS" -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ -n "$pg_pod" ]; then
            oc exec "$pg_pod" -n "$MAAS_INFRA_NS" -- bash -c \
                'PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='"'"'mlflow'"'"'" | grep -q 1 || \
                 PGPASSWORD=$POSTGRES_PASSWORD psql -U postgres -c "CREATE DATABASE mlflow OWNER maas;"' 2>/dev/null || true
        fi

        local pg_url
        pg_url=$(oc get secret maas-db-config -n "$MAAS_INFRA_NS" \
            -o jsonpath='{.data.DB_CONNECTION_URL}' 2>/dev/null | base64 -d 2>/dev/null | sed 's|/maas|/mlflow|')

        if [ -n "$pg_url" ]; then
            oc create secret generic mlflow-db-credentials \
                --from-literal=database-url="$pg_url" \
                -n redhat-ods-applications \
                --dry-run=client -o yaml | oc apply -f - 2>/dev/null

            oc apply -f - <<'EOF'
apiVersion: mlflow.opendatahub.io/v1
kind: MLflow
metadata:
  name: mlflow
spec:
  replicas: 1
  backendStoreUriFrom:
    name: mlflow-db-credentials
    key: database-url
  serveArtifacts: true
  artifactsDestination: "file:///mlflow/artifacts"
  storage:
    size: 10Gi
EOF
            print_info "MLflow configured with PostgreSQL backend"
        else
            print_warning "Could not read PostgreSQL URL, falling back to SQLite"
            oc apply -f "$ROOT_DIR/lib/manifests/rhoai/mlflow-cr.yaml"
        fi
    else
        oc apply -f "$ROOT_DIR/lib/manifests/rhoai/mlflow-cr.yaml"
        print_info "MLflow configured with SQLite backend (PVC)"
    fi

    print_step "Waiting for MLflow server to be ready..."
    local wait=0
    while [ $wait -lt 180 ]; do
        local ready=$(oc get mlflow mlflow -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$ready" = "True" ]; then
            local url=$(oc get mlflow mlflow -o jsonpath='{.status.url}' 2>/dev/null)
            print_success "MLflow server is ready: ${url}"
            return 0
        fi
        sleep 10
        wait=$((wait + 10))
    done

    print_warning "MLflow server not ready yet (may still be starting) — check: oc get mlflow mlflow"
}

