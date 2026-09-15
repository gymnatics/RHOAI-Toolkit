#!/bin/bash
################################################################################
# RHCL (Red Hat Connectivity Link) / Kuadrant / Service Mesh / Istio bootstrap
################################################################################
# Shared fresh-install logic for RHCL's Kubernetes-Gateway-API dependency
# chain, used by install-rhoai-34.sh, install-rhoai-35.sh, and (via
# scripts/setup-maas.sh's phase1_rhcl/phase2_gateway) the standalone MaaS
# add-on path.
#
# This was previously duplicated (byte-for-byte identical, except for
# restart_kuadrant_operator's wait strategy) between install-rhoai-34.sh and
# install-rhoai-35.sh. setup-maas.sh's own phase1_rhcl/phase2_gateway used a
# simpler approve_servicemesh_installplans() and had NO equivalent of
# install_servicemesh_operator()/setup_istio_for_kuadrant()/
# restart_kuadrant_operator() at all -- notably missing the fix below for a
# real, hard-won bug:
#
#   OCP 4.20 ships the ingress operator with an EOL ISTIO_VERSION (observed:
#   v1.26.8) that Service Mesh 3.4.0+ no longer supports. Since the ingress
#   operator creates Istio CRs for GatewayClasses, a stale ISTIO_VERSION here
#   breaks GatewayClass reconciliation for the MaaS/inference gateways.
#   setup_istio_for_kuadrant() detects and patches this automatically.
#
# Usage: source this file, then call (in order):
#   install_servicemesh_operator   # Service Mesh 3 (OLM dependency of RHCL)
#   setup_istio_for_kuadrant       # Istio + IstioCNI + ISTIO_VERSION fix + GatewayClass
#   restart_kuadrant_operator      # after Kuadrant CR exists, so it detects Istio
#
# Requires: ROOT_DIR, print_step/print_success/print_info/print_warning
# (lib/utils/colors.sh), wait_for_api_server (this file).
################################################################################

# Wait for the API server to respond (used after Istio/Sail webhook
# registration, which can briefly bounce the API server).
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

install_servicemesh_operator() {
    print_step "Installing OpenShift Service Mesh 3 Operator..."

    if oc get csv -n openshift-operators 2>/dev/null | grep -q "servicemeshoperator3.*Succeeded"; then
        print_info "Service Mesh 3 Operator already installed and ready"
    else
        if ! oc get subscription servicemeshoperator3 -n openshift-operators &>/dev/null; then
            oc apply -f "$ROOT_DIR/lib/manifests/operators/servicemesh3-subscription.yaml"
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

setup_istio_for_kuadrant() {
    print_step "Setting up Istio for Kuadrant..."

    oc create namespace istio-system 2>/dev/null || true
    oc create namespace istio-cni 2>/dev/null || true

    if oc get istio default -n istio-system &>/dev/null; then
        print_info "Istio instance already exists in istio-system"
    else
        local istio_version=$(oc get istio -A -o jsonpath='{.items[0].spec.version}' 2>/dev/null || echo "v1.30.1")

        print_step "Creating IstioCNI..."
        export ISTIO_VERSION="$istio_version"
        envsubst '${ISTIO_VERSION}' < "$ROOT_DIR/lib/manifests/rhcl/istiocni.yaml" | oc apply -f -

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
        envsubst '${ISTIO_VERSION}' < "$ROOT_DIR/lib/manifests/rhcl/istio.yaml" | oc apply -f -

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

    # Fix OCP ingress operator if its ISTIO_VERSION doesn't match a supported version.
    # OCP 4.20 ships with ISTIO_VERSION=v1.26.2 which is EOL in Service Mesh 3.4.0+.
    # The ingress operator creates Istio CRs for GatewayClasses, so the version must be valid.
    local ingress_istio_ver
    ingress_istio_ver=$(oc get deployment ingress-operator -n openshift-ingress-operator \
        -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="ISTIO_VERSION")].value}' 2>/dev/null)
    if [ -n "$ingress_istio_ver" ]; then
        local istio_version_needed
        istio_version_needed=$(oc get istio -A -o jsonpath='{.items[0].spec.version}' 2>/dev/null || echo "v1.30.1")
        if [ "$ingress_istio_ver" != "$istio_version_needed" ]; then
            # Check if the ingress operator's version is actually supported by the SM operator
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

    if ! oc get gatewayclass openshift-default &>/dev/null; then
        print_step "Creating openshift-default GatewayClass..."
        local attempt=1
        while [ $attempt -le 3 ]; do
            if oc apply -f "$ROOT_DIR/lib/manifests/rhcl/gatewayclass-default.yaml"; then
                break
            fi
            print_warning "GatewayClass creation failed (attempt $attempt/3), waiting for API server..."
            wait_for_api_server 60
            attempt=$((attempt + 1))
        done
    fi

    print_success "Istio setup complete for Kuadrant"
}

restart_kuadrant_operator() {
    print_step "Restarting Kuadrant operator to detect Istio..."

    local pod_name=$(oc get pods -n kuadrant-system -o name 2>/dev/null | grep kuadrant-operator-controller)
    if [ -n "$pod_name" ]; then
        oc delete $pod_name -n kuadrant-system 2>/dev/null || true
        sleep 20
    fi

    print_step "Waiting for Kuadrant to be ready..."
    if oc wait --for=condition=Ready kuadrant/kuadrant -n kuadrant-system --timeout=180s 2>/dev/null; then
        print_success "Kuadrant is ready"
    else
        print_warning "Kuadrant may not be fully ready. Check: oc get kuadrant -n kuadrant-system"
        local kuadrant_reason=$(oc get kuadrant kuadrant -n kuadrant-system \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)
        [ -n "$kuadrant_reason" ] && print_info "  Reason: $kuadrant_reason"
    fi
}
