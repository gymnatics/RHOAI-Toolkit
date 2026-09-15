#!/bin/bash
################################################################################
# MetalLB for non-cloud MaaS Gateway LoadBalancer support
################################################################################
# On non-cloud platforms (BareMetal, OpenStack, None/SNO), there is no cloud
# load-balancer controller to provision external IPs for LoadBalancer Services,
# so the MaaS Gateway's LoadBalancer Service never reaches Programmed=True.
# MetalLB fills this role, assigning an IP from a configured pool.
#
# Manifests are the source of truth (lib/manifests/operators/metallb/) -- this
# function only orchestrates: platform detection, operator install, waiting for
# the CSV, creating the MetalLB operand, deriving an IP for the address pool,
# and creating the passthrough Route so *.apps DNS reaches the Gateway.
#
# Usage: source this file, then call setup_metallb_if_needed
# Requires: ROOT_DIR, print_step/print_success/print_info/print_warning (colors.sh)
################################################################################

# Returns 0 (true) if the cluster platform requires MetalLB (no cloud LB
# controller): BareMetal, OpenStack, or None (includes SNO). Returns 1 for
# cloud platforms (AWS, Azure, GCP, etc.) where the Gateway's LoadBalancer
# Service is provisioned automatically.
platform_needs_metallb() {
    local platform
    platform=$(oc get infrastructure cluster -o jsonpath='{.status.platform}' 2>/dev/null)
    case "$platform" in
        BareMetal|OpenStack|None|"") return 0 ;;
        *) return 1 ;;
    esac
}

# Installs MetalLB (operator + operand + IPAddressPool + L2Advertisement) if the
# platform needs it and it isn't already installed. No-op on cloud platforms.
setup_metallb_if_needed() {
    if ! platform_needs_metallb; then
        print_info "Cloud platform detected -- MetalLB not required (LoadBalancer Services are provisioned automatically)"
        return 0
    fi

    print_step "Non-cloud platform detected -- MetalLB is required for the MaaS Gateway's LoadBalancer Service..."

    if oc get deployment metallb-operator-controller-manager -n metallb-system &>/dev/null; then
        print_success "MetalLB operator already installed"
    else
        print_step "Installing MetalLB operator..."
        if oc get operatorgroup -n metallb-system -o name 2>/dev/null | grep -q .; then
            print_info "Found existing OperatorGroup(s) in metallb-system -- removing to avoid conflict"
            oc delete operatorgroup --all -n metallb-system 2>/dev/null || true
        fi
        oc apply -k "$ROOT_DIR/lib/manifests/operators/metallb/"

        print_step "Waiting for MetalLB operator CSV to succeed..."
        local elapsed=0
        until oc get csv -n metallb-system 2>/dev/null | grep -q "metallb-operator.*Succeeded"; do
            if [ $elapsed -ge 300 ]; then
                print_warning "Timeout waiting for MetalLB operator CSV -- continuing anyway"
                break
            fi
            sleep 10
            elapsed=$((elapsed + 10))
        done
        print_success "MetalLB operator installed"
    fi

    if oc get metallb metallb -n metallb-system &>/dev/null; then
        print_success "MetalLB instance already exists"
    else
        print_step "Creating MetalLB instance..."
        oc apply -f "$ROOT_DIR/lib/manifests/operators/metallb/metallb-instance.yaml"
    fi

    if oc get ipaddresspool maas-gateway-pool -n metallb-system &>/dev/null; then
        print_success "IPAddressPool 'maas-gateway-pool' already exists"
        return 0
    fi

    # Derive an IP one address above the first node's InternalIP. Do NOT reuse a
    # node's own IP -- if a LoadBalancer Service shares the node IP on port 443,
    # kube-proxy iptables rules intercept traffic meant for the OpenShift router
    # (which serves *.apps routes on the same IP:port via hostNetwork), breaking
    # OAuth callbacks, console access, and any in-cluster route traffic.
    # For multi-node clusters or complex networks, this heuristic may need manual
    # adjustment -- see docs/TROUBLESHOOTING.md.
    print_step "Deriving MetalLB IP address pool from node IP..."
    local node_ip
    node_ip=$(oc get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    if [ -z "$node_ip" ]; then
        print_warning "Could not determine node IP -- skipping IPAddressPool creation. Create it manually:"
        print_info "  oc apply -f $ROOT_DIR/lib/manifests/operators/metallb/ip-pool.yaml.tmpl (after envsubst)"
        return 0
    fi

    local metallb_ip
    metallb_ip=$(echo "$node_ip" | awk -F. '{printf "%s.%s.%s.%d", $1, $2, $3, $4+1}')
    export METALLB_IP_RANGE="${metallb_ip}-${metallb_ip}"
    print_info "Node IP: $node_ip -> MetalLB IP: $METALLB_IP_RANGE"

    envsubst '${METALLB_IP_RANGE}' < "$ROOT_DIR/lib/manifests/operators/metallb/ip-pool.yaml.tmpl" | oc apply -f -
    unset METALLB_IP_RANGE

    print_success "MetalLB configured (operator + instance + IP pool)"
}
