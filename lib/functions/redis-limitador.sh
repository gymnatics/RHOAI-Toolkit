#!/bin/bash
################################################################################
# Redis for Limitador -- rate-limit counter persistence
################################################################################
# Manifests are the source of truth (lib/manifests/observability/redis/) --
# this function only orchestrates: applying the kustomize directory, creating
# the Redis connection Secret (imperative, no credentials to template), and
# patching the Limitador CR to use redis-cached storage.
#
# Usage: source this file, then call setup_redis_limitador
# Requires: ROOT_DIR, print_step/print_success/print_info (colors.sh)
################################################################################

setup_redis_limitador() {
    print_step "Configuring Redis for Limitador rate-limit persistence..."

    if oc get deployment limitador-redis -n kuadrant-system &>/dev/null; then
        print_info "Limitador Redis already deployed"
    else
        print_step "Deploying Redis + EnvoyFilters for Limitador..."
        oc apply -k "$ROOT_DIR/lib/manifests/observability/redis/"
        oc rollout status deployment/limitador-redis -n kuadrant-system --timeout=60s 2>/dev/null || true
        print_success "Redis deployed"
    fi

    if ! oc get secret limitador-redis-config -n kuadrant-system &>/dev/null; then
        oc create secret generic limitador-redis-config \
            --from-literal=URL="redis://limitador-redis.kuadrant-system.svc.cluster.local:6379" \
            -n kuadrant-system
    fi

    local current_storage
    current_storage=$(oc get limitador limitador -n kuadrant-system \
        -o jsonpath='{.spec.storage.redis-cached}' 2>/dev/null || true)
    if [ -z "$current_storage" ]; then
        print_step "Configuring Limitador with redis-cached storage..."
        oc patch limitador limitador -n kuadrant-system --type=merge -p '{
            "spec": {
                "storage": {
                    "redis-cached": {
                        "configSecretRef": {
                            "name": "limitador-redis-config"
                        },
                        "options": {
                            "flush-period": 500,
                            "max-cached": 10000,
                            "batch-size": 100,
                            "response-timeout": 500
                        }
                    }
                }
            }
        }'
        print_success "Limitador configured with Redis-cached storage"
    else
        print_info "Limitador already using redis-cached storage"
    fi

    # Restart gateway to pick up the EnvoyFilters and clear the WASM span buffer.
    print_step "Restarting MaaS gateway to apply Redis + EnvoyFilters..."
    oc rollout restart deployment/maas-default-gateway-openshift-gateway-controller \
        -n openshift-ingress 2>/dev/null || true
    sleep 10

    print_success "Redis for Limitador configured (persistence + health check + timeout fix)"
}
