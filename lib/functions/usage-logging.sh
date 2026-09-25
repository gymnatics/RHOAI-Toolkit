#!/bin/bash
################################################################################
# MaaS Usage-Logging Dashboards (RHOAI 3.5+ only)
################################################################################
# Log-based per-request usage tracking: the gateway emits structured OTLP
# access logs with token counts, user identity, and subscription info. Logs
# are shipped to a LokiStack via an OpenTelemetry Collector. The RHOAI console
# shows admin and user-scoped usage dashboards under Observe & monitor.
#
# Manifests are the source of truth:
#   lib/manifests/observability/loki/           -- Loki Operator subscription
#   lib/manifests/observability/usage-logging/  -- LokiStack CR + Loki S3
#                                                   secret template
#   lib/manifests/storage/{seaweedfs,ceph-rgw,minio}/ -- S3 backend (via
#                                                   lib/functions/storage-backend.sh)
# This function only orchestrates: install order, deploying the S3 backend,
# waiting for CSVs/LokiStack readiness, and patching the Config CR
# (usageLogging: true), which triggers the RHOAI operator to auto-create the
# EnvoyFilter, OTEL Collector, Tenancy Proxy, and Perses Dashboards -- none
# of which should be applied manually.
#
# Usage: source this file, then call setup_maas_usage_logging
# Requires: ROOT_DIR, print_step/print_success/print_info/print_warning (colors.sh)
################################################################################

source "$ROOT_DIR/lib/functions/storage-backend.sh" 2>/dev/null || true

setup_maas_usage_logging() {
    print_step "Setting up MaaS usage-logging dashboards (RHOAI 3.5+)..."

    if ! oc get crd configs.maas.opendatahub.io &>/dev/null; then
        print_warning "configs.maas.opendatahub.io CRD not found -- usage logging requires RHOAI 3.5+ with MaaS enabled. Skipping."
        return 1
    fi

    # Step 1: Loki Operator
    if oc get csv -n openshift-operators-redhat 2>/dev/null | grep -q "loki-operator.*Succeeded"; then
        print_success "Loki Operator already installed"
    else
        print_step "Installing Loki Operator..."
        oc apply -k "$ROOT_DIR/lib/manifests/observability/loki/"
        print_step "Waiting for Loki Operator CSV to succeed..."
        local elapsed=0
        until oc get csv -n openshift-operators-redhat 2>/dev/null | grep -q "loki-operator.*Succeeded"; do
            if [ $elapsed -ge 300 ]; then
                print_warning "Timeout waiting for Loki Operator CSV -- continuing anyway"
                break
            fi
            sleep 10
            elapsed=$((elapsed + 10))
        done
        print_success "Loki Operator installed"
    fi

    # Step 2: S3 storage backend (SeaweedFS by default) + LokiStack
    if oc get lokistack usage -n redhat-ods-monitoring &>/dev/null; then
        print_success "LokiStack 'usage' already exists"
    else
        local usage_ns="redhat-ods-monitoring"
        local usage_bucket="loki"

        print_step "Deploying S3 storage backend (${S3_BACKEND:-seaweedfs}) for usage logging..."
        if type detect_or_select_storage_backend &>/dev/null; then
            detect_or_select_storage_backend "$usage_ns"
            deploy_storage_backend "$usage_ns" "20Gi"
            wait_for_storage "$usage_ns"
            create_storage_bucket "$usage_ns" "$usage_bucket"

            # Generate the Loki-specific S3 secret (different schema than the
            # RHOAI AWS_* data-connection format -- Loki uses its own
            # access_key_id/access_key_secret/bucketnames/endpoint/region keys)
            export S3_ACCESS_KEY="${S3_ACCESS_KEY:-admin}"
            export S3_SECRET_KEY="${S3_SECRET_KEY:-admin123}"
            export BUCKET_NAME="$usage_bucket"
            export S3_ENDPOINT="$(get_storage_endpoint "$usage_ns")"
            envsubst '${S3_ACCESS_KEY} ${S3_SECRET_KEY} ${BUCKET_NAME} ${S3_ENDPOINT}' \
                < "$ROOT_DIR/lib/manifests/observability/usage-logging/loki-s3-secret.yaml.tmpl" \
                | oc apply -n "$usage_ns" -f -
        else
            print_warning "storage-backend.sh not available -- falling back to legacy MinIO manifests"
            oc apply -f "$ROOT_DIR/lib/manifests/observability/usage-logging/minio.yaml" -n "$usage_ns" 2>/dev/null
            oc apply -f "$ROOT_DIR/lib/manifests/observability/usage-logging/minio-secret.yaml" -n "$usage_ns" 2>/dev/null
            oc rollout status deployment/minio-usage-logs -n "$usage_ns" --timeout=120s 2>/dev/null || \
                print_warning "MinIO rollout did not complete in time -- continuing anyway"
        fi

        print_step "Applying LokiStack CR..."
        oc apply -k "$ROOT_DIR/lib/manifests/observability/usage-logging/"

        print_step "Waiting for LokiStack to be ready (this may take a few minutes)..."
        local lk_elapsed=0
        until oc get lokistack usage -n redhat-ods-monitoring \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; do
            if [ $lk_elapsed -ge 300 ]; then
                print_warning "Timeout waiting for LokiStack Ready -- check: oc describe lokistack usage -n redhat-ods-monitoring"
                break
            fi
            sleep 15
            lk_elapsed=$((lk_elapsed + 15))
        done
        print_success "S3 storage + LokiStack deployed"
    fi

    # Step 3: Enable usage logging on the MaaS Config CR. The RHOAI operator
    # auto-creates the EnvoyFilter, OTEL Collector, Tenancy Proxy, and Perses
    # Dashboards from this flag -- do not create them manually.
    local usage_logging_state
    usage_logging_state=$(oc get configs.maas.opendatahub.io default -n models-as-a-service \
        -o jsonpath='{.spec.usageLogging}' 2>/dev/null)
    if [ "$usage_logging_state" = "true" ]; then
        print_info "Usage logging already enabled on Config 'default'"
    else
        print_step "Enabling usage logging on MaaS Config CR..."
        oc patch configs.maas.opendatahub.io default -n models-as-a-service --type=merge \
            -p '{"spec":{"usageLogging":true}}' 2>/dev/null && \
            print_success "Usage logging enabled" || \
            print_warning "Could not patch Config CR -- check: oc get configs.maas.opendatahub.io -n models-as-a-service"
    fi

    print_step "Waiting for auto-created usage-logging resources..."
    local auto_elapsed=0
    while [ $auto_elapsed -lt 120 ]; do
        if oc get envoyfilter maas-model-access-logs -n openshift-ingress &>/dev/null; then
            print_success "EnvoyFilter 'maas-model-access-logs' created"
            break
        fi
        sleep 10
        auto_elapsed=$((auto_elapsed + 10))
    done
    if ! oc get envoyfilter maas-model-access-logs -n openshift-ingress &>/dev/null; then
        print_warning "EnvoyFilter 'maas-model-access-logs' not found yet -- may still be reconciling"
    fi

    print_success "MaaS usage logging configured"
    print_info "Verify: oc get envoyfilter maas-model-access-logs -n openshift-ingress"
    print_info "        oc get opentelemetrycollector usage-logs -n redhat-ods-monitoring"
    print_info "        oc get persesdashboard -n redhat-ods-monitoring | grep usage-logs"
    print_info "Dashboards appear in the RHOAI console under Observe & monitor > Dashboard"
}
