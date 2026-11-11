#!/bin/bash
################################################################################
# storage-backend.sh — Pluggable S3-compatible storage backend abstraction
################################################################################
# Provides a unified interface for deploying and managing S3-compatible storage
# backends (SeaweedFS, Ceph RGW/ODF, MinIO). All consumers (KServe, DSPA,
# notebooks, workbenches) interact through standard RHOAI data-connection
# Secrets (AWS_S3_ENDPOINT, AWS_ACCESS_KEY_ID, etc.) — they never need to
# know which backend is running.
#
# Supported backends:
#   seaweedfs  — Default. Lightweight, self-contained S3-compatible store.
#   ceph-rgw   — Uses ODF ObjectBucketClaim; requires OpenShift Data Foundation.
#   minio      — Deprecated legacy backend. Still functional but no longer
#                the default. Will be removed in a future release.
#
# Usage in deploy scripts:
#   source "$ROOT_DIR/lib/functions/storage-backend.sh"
#   deploy_storage_backend "$NAMESPACE" "$BUCKET_NAME"
#   create_data_connection "$NAMESPACE" "$BUCKET_NAME" "$TARGET_NS"
#
# Environment variables:
#   S3_BACKEND           — Override backend (seaweedfs|ceph-rgw|minio)
#   S3_ACCESS_KEY        — Override access key (default: auto-generated or 'admin')
#   S3_SECRET_KEY        — Override secret key (default: auto-generated or 'admin123')
#   S3_STORAGE_SIZE      — Override PVC size (default: 200Gi)
################################################################################

_STORAGE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ -f "$_STORAGE_LIB_DIR/lib/utils/colors.sh" ]; then
    source "$_STORAGE_LIB_DIR/lib/utils/colors.sh" 2>/dev/null || true
fi

# Defaults
_DEFAULT_BACKEND="seaweedfs"
_DEFAULT_ACCESS_KEY="admin"
_DEFAULT_SECRET_KEY="admin123"
_DEFAULT_STORAGE_SIZE="200Gi"
_DEFAULT_REGION="us-east-1"

# Backend-specific constants
_SEAWEEDFS_S3_PORT=8333
_SEAWEEDFS_MASTER_PORT=9333
_SEAWEEDFS_DEPLOY_NAME="seaweedfs"
_SEAWEEDFS_SVC_NAME="seaweedfs-s3"

_CEPH_RGW_PORT=80
_CEPH_OBC_STORAGECLASS="openshift-storage.noobaa.io"

_MINIO_API_PORT=9000
_MINIO_DEPLOY_NAME="minio"
_MINIO_SVC_NAME="minio"

################################################################################
# detect_or_select_storage_backend [--flag VALUE]
#
# Determines the storage backend to use. Priority:
#   1. Explicit --backend flag passed by caller
#   2. S3_BACKEND environment variable
#   3. Auto-detect from existing deployments in namespace
#   4. Default: seaweedfs
#
# Sets: S3_BACKEND (global)
################################################################################
detect_or_select_storage_backend() {
    local explicit_backend=""
    local target_ns="${1:-}"

    # Check CLI override
    if [ -n "${explicit_backend:-}" ]; then
        S3_BACKEND="$explicit_backend"
    # Check env var
    elif [ -n "${S3_BACKEND:-}" ]; then
        : # already set
    # Auto-detect from existing deployments
    elif [ -n "$target_ns" ]; then
        if oc get deployment "$_SEAWEEDFS_DEPLOY_NAME" -n "$target_ns" &>/dev/null; then
            S3_BACKEND="seaweedfs"
        elif oc get objectbucketclaim -n "$target_ns" --no-headers 2>/dev/null | grep -q .; then
            S3_BACKEND="ceph-rgw"
        elif oc get deployment "$_MINIO_DEPLOY_NAME" -n "$target_ns" &>/dev/null; then
            S3_BACKEND="minio"
        else
            S3_BACKEND="$_DEFAULT_BACKEND"
        fi
    else
        S3_BACKEND="$_DEFAULT_BACKEND"
    fi

    # Validate
    case "$S3_BACKEND" in
        seaweedfs|ceph-rgw|minio) ;;
        *)
            echo -e "${RED:-}✗ Unknown storage backend: $S3_BACKEND (valid: seaweedfs, ceph-rgw, minio)${NC:-}" >&2
            return 1
            ;;
    esac

    if [ "$S3_BACKEND" = "minio" ]; then
        echo -e "${YELLOW:-}⚠ MinIO backend is deprecated: quay.io/minio images are no longer anonymously pullable, so the toolkit uses a pinned 2019 ODH build. Use SeaweedFS (S3_BACKEND=seaweedfs).${NC:-}" >&2
    fi

    export S3_BACKEND
}

################################################################################
# get_storage_manifest_dir
#
# Returns the absolute path to the manifest directory for the active backend.
################################################################################
get_storage_manifest_dir() {
    echo "$_STORAGE_LIB_DIR/lib/manifests/storage/${S3_BACKEND:-$_DEFAULT_BACKEND}"
}

################################################################################
# get_storage_endpoint NAMESPACE
#
# Returns the in-cluster S3 endpoint URL for the active backend.
################################################################################
get_storage_endpoint() {
    local ns="${1:?namespace required}"

    case "${S3_BACKEND:-$_DEFAULT_BACKEND}" in
        seaweedfs)
            echo "http://${_SEAWEEDFS_SVC_NAME}.${ns}.svc:${_SEAWEEDFS_S3_PORT}"
            ;;
        ceph-rgw)
            # ODF-provisioned endpoint from the OBC's ConfigMap
            local obc_name
            obc_name=$(oc get objectbucketclaim -n "$ns" --no-headers -o custom-columns='NAME:.metadata.name' 2>/dev/null | head -1)
            if [ -n "$obc_name" ]; then
                local host port
                host=$(oc get configmap "$obc_name" -n "$ns" -o jsonpath='{.data.BUCKET_HOST}' 2>/dev/null || echo "")
                port=$(oc get configmap "$obc_name" -n "$ns" -o jsonpath='{.data.BUCKET_PORT}' 2>/dev/null || echo "$_CEPH_RGW_PORT")
                if [ -n "$host" ]; then
                    echo "http://${host}:${port}"
                    return 0
                fi
            fi
            # Fallback: standard ODF S3 route
            echo "http://s3.openshift-storage.svc:${_CEPH_RGW_PORT}"
            ;;
        minio)
            echo "http://${_MINIO_SVC_NAME}.${ns}.svc:${_MINIO_API_PORT}"
            ;;
    esac
}

################################################################################
# get_storage_service_name
#
# Returns the k8s Service name for the active backend's S3 endpoint.
################################################################################
################################################################################
# get_storage_external_endpoint <ns>
#
# HTTPS endpoint (edge-TLS Route) for the active backend, for dashboard-facing
# data connections: the AutoRAG/AutoML UI rejects plain-HTTP S3 connections
# ("S3 Connection must use HTTPS"). Falls back to the internal endpoint when
# the backend has no Route (e.g. Ceph RGW). Pipelines/DSPA keep using
# get_storage_endpoint (in-cluster HTTP).
################################################################################
get_storage_external_endpoint() {
    local ns="${1:?namespace required}"
    local svc host
    svc="$(get_storage_service_name)"
    host=$(oc get route "$svc" -n "$ns" -o jsonpath='{.spec.host}' 2>/dev/null || true)
    if [ -n "$host" ]; then
        echo "https://${host}"
    else
        get_storage_endpoint "$ns"
    fi
}

get_storage_service_name() {
    case "${S3_BACKEND:-$_DEFAULT_BACKEND}" in
        seaweedfs) echo "$_SEAWEEDFS_SVC_NAME" ;;
        ceph-rgw)  echo "s3" ;;
        minio)     echo "$_MINIO_SVC_NAME" ;;
    esac
}

################################################################################
# get_storage_deploy_name
#
# Returns the Deployment/StatefulSet name to check for readiness.
################################################################################
get_storage_deploy_name() {
    case "${S3_BACKEND:-$_DEFAULT_BACKEND}" in
        seaweedfs) echo "$_SEAWEEDFS_DEPLOY_NAME" ;;
        ceph-rgw)  echo "" ;; # no deployment to wait on; ODF manages it
        minio)     echo "$_MINIO_DEPLOY_NAME" ;;
    esac
}

################################################################################
# deploy_storage_backend NAMESPACE [STORAGE_SIZE]
#
# Deploys the S3 storage backend into the given namespace. Idempotent.
# Uses S3_ACCESS_KEY / S3_SECRET_KEY env vars or defaults.
################################################################################
deploy_storage_backend() {
    local ns="${1:?namespace required}"
    local storage_size="${2:-${S3_STORAGE_SIZE:-$_DEFAULT_STORAGE_SIZE}}"
    local access_key="${S3_ACCESS_KEY:-$_DEFAULT_ACCESS_KEY}"
    local secret_key="${S3_SECRET_KEY:-$_DEFAULT_SECRET_KEY}"
    local manifest_dir
    manifest_dir="$(get_storage_manifest_dir)"

    detect_or_select_storage_backend "$ns" || return 1

    echo -e "${YELLOW:-}▶ Deploying S3 storage backend: ${S3_BACKEND} in ${ns}${NC:-}"

    # Ensure namespace
    if ! oc get namespace "$ns" &>/dev/null; then
        oc create namespace "$ns"
    fi
    oc label namespace "$ns" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true

    case "$S3_BACKEND" in
        seaweedfs)
            _deploy_seaweedfs "$ns" "$storage_size" "$access_key" "$secret_key" "$manifest_dir"
            ;;
        ceph-rgw)
            _deploy_ceph_rgw "$ns" "$manifest_dir"
            ;;
        minio)
            _deploy_minio "$ns" "$storage_size" "$access_key" "$secret_key" "$manifest_dir"
            ;;
    esac
}

################################################################################
# wait_for_storage NAMESPACE [TIMEOUT]
#
# Waits for the storage backend to become ready.
################################################################################
wait_for_storage() {
    local ns="${1:?namespace required}"
    local timeout="${2:-120}"
    local deploy_name
    deploy_name="$(get_storage_deploy_name)"

    case "${S3_BACKEND:-$_DEFAULT_BACKEND}" in
        ceph-rgw)
            # OBC: wait for the claim to be Bound
            echo -e "${YELLOW:-}▶ Waiting for ObjectBucketClaim to be Bound...${NC:-}"
            local elapsed=0
            while [ $elapsed -lt "$timeout" ]; do
                local phase
                phase=$(oc get objectbucketclaim -n "$ns" --no-headers -o custom-columns='PHASE:.status.phase' 2>/dev/null | head -1)
                if [ "$phase" = "Bound" ]; then
                    echo -e "${GREEN:-}✓ ObjectBucketClaim is Bound${NC:-}"
                    return 0
                fi
                sleep 5
                elapsed=$((elapsed + 5))
                echo "  Waiting... (${elapsed}s)"
            done
            echo -e "${RED:-}✗ Timeout waiting for ObjectBucketClaim${NC:-}" >&2
            return 1
            ;;
        *)
            if [ -z "$deploy_name" ]; then return 0; fi
            echo -e "${YELLOW:-}▶ Waiting for ${deploy_name} in ${ns}...${NC:-}"
            local elapsed=0
            while [ $elapsed -lt "$timeout" ]; do
                local ready
                ready=$(oc get deployment "$deploy_name" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
                if [ "${ready:-0}" -ge 1 ]; then
                    echo -e "${GREEN:-}✓ ${deploy_name} is ready${NC:-}"
                    return 0
                fi
                sleep 5
                elapsed=$((elapsed + 5))
                echo "  Waiting... (${elapsed}s)"
            done
            echo -e "${RED:-}✗ Timeout waiting for ${deploy_name}${NC:-}" >&2
            return 1
            ;;
    esac
}

################################################################################
# create_storage_bucket NAMESPACE BUCKET_NAME
#
# Creates a bucket in the S3 backend. Uses aws-cli (generic, not mc).
# For ceph-rgw, bucket is auto-created by the OBC — this is a no-op.
################################################################################
create_storage_bucket() {
    local ns="${1:?namespace required}"
    local bucket="${2:?bucket name required}"
    local access_key="${S3_ACCESS_KEY:-$_DEFAULT_ACCESS_KEY}"
    local secret_key="${S3_SECRET_KEY:-$_DEFAULT_SECRET_KEY}"

    case "${S3_BACKEND:-$_DEFAULT_BACKEND}" in
        ceph-rgw)
            echo -e "${CYAN:-}ℹ Ceph RGW: bucket auto-created by ObjectBucketClaim${NC:-}"
            return 0
            ;;
        *)
            local endpoint
            endpoint="$(get_storage_endpoint "$ns")"
            local manifest_dir
            manifest_dir="$(get_storage_manifest_dir)"

            echo -e "${YELLOW:-}▶ Creating bucket: ${bucket}${NC:-}"

            # Delete previous job if exists and wait for it to be fully gone
            oc delete job/create-bucket -n "$ns" --ignore-not-found --wait=true 2>/dev/null || true

            export S3_ACCESS_KEY="$access_key"
            export S3_SECRET_KEY="$secret_key"
            export BUCKET_NAME="$bucket"
            export S3_ENDPOINT="$endpoint"
            envsubst '${S3_ACCESS_KEY} ${S3_SECRET_KEY} ${BUCKET_NAME} ${S3_ENDPOINT}' \
                < "$manifest_dir/create-bucket-job.yaml.tmpl" | oc create -n "$ns" -f -

            if oc wait --for=condition=complete job/create-bucket -n "$ns" --timeout=120s 2>/dev/null; then
                echo -e "${GREEN:-}✓ Bucket '${bucket}' ready${NC:-}"
            else
                echo -e "${YELLOW:-}⚠ Bucket creation did not complete in 120s${NC:-}" >&2
                oc logs job/create-bucket -n "$ns" 2>/dev/null | tail -5
            fi
            oc delete job/create-bucket -n "$ns" --ignore-not-found 2>/dev/null || true
            ;;
    esac
}

################################################################################
# create_data_connection STORAGE_NS BUCKET_NAME TARGET_NS [DISPLAY_NAME]
#
# Creates the RHOAI data-connection Secrets in TARGET_NS pointing at the
# storage backend running in STORAGE_NS. Creates both aws-connection-minio
# (compat) and aws-connection-my-storage.
################################################################################
create_data_connection() {
    local storage_ns="${1:?storage namespace required}"
    local bucket="${2:?bucket name required}"
    local target_ns="${3:-$storage_ns}"
    local display_name="${4:-S3 Model Storage}"
    local access_key="${S3_ACCESS_KEY:-$_DEFAULT_ACCESS_KEY}"
    local secret_key="${S3_SECRET_KEY:-$_DEFAULT_SECRET_KEY}"

    echo -e "${YELLOW:-}▶ Creating RHOAI data connection in ${target_ns}${NC:-}"

    # Ensure target namespace
    if ! oc get namespace "$target_ns" &>/dev/null; then
        oc create namespace "$target_ns"
        oc label namespace "$target_ns" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true
    fi

    local endpoint
    case "${S3_BACKEND:-$_DEFAULT_BACKEND}" in
        ceph-rgw)
            endpoint="$(get_storage_endpoint "$storage_ns")"
            # OBC auto-generates credentials; read them
            local obc_name
            obc_name=$(oc get objectbucketclaim -n "$storage_ns" --no-headers -o custom-columns='NAME:.metadata.name' 2>/dev/null | head -1)
            if [ -n "$obc_name" ]; then
                access_key=$(oc get secret "$obc_name" -n "$storage_ns" -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' 2>/dev/null | base64 -d 2>/dev/null || echo "$access_key")
                secret_key=$(oc get secret "$obc_name" -n "$storage_ns" -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' 2>/dev/null | base64 -d 2>/dev/null || echo "$secret_key")
                bucket=$(oc get configmap "$obc_name" -n "$storage_ns" -o jsonpath='{.data.BUCKET_NAME}' 2>/dev/null || echo "$bucket")
            fi
            ;;
        *)
            endpoint="$(get_storage_endpoint "$storage_ns")"
            ;;
    esac

    # Optional overrides (env): DATA_CONNECTION_NAME (default aws-connection-minio),
    # DATA_CONNECTION_ENDPOINT (e.g. the HTTPS Route from get_storage_external_endpoint -- the dashboard
    # AutoRAG/AutoML UI rejects http:// connections), DATA_CONNECTION_COMPAT=false to skip the
    # aws-connection-my-storage alias.
    [ -n "${DATA_CONNECTION_ENDPOINT:-}" ] && endpoint="$DATA_CONNECTION_ENDPOINT"

    local manifest_dir
    manifest_dir="$(get_storage_manifest_dir)"

    export CONNECTION_NAME="${DATA_CONNECTION_NAME:-aws-connection-minio}"
    export S3_ACCESS_KEY="$access_key"
    export S3_SECRET_KEY="$secret_key"
    export S3_ENDPOINT="$endpoint"
    export BUCKET_NAME="$bucket"
    export DISPLAY_NAME="$display_name"
    export NAMESPACE="$storage_ns"

    # Primary data connection
    envsubst '${CONNECTION_NAME} ${S3_ACCESS_KEY} ${S3_SECRET_KEY} ${S3_ENDPOINT} ${BUCKET_NAME} ${DISPLAY_NAME} ${NAMESPACE}' \
        < "$manifest_dir/data-connection.yaml.tmpl" | oc apply -n "$target_ns" -f -

    # Compatibility alias (aws-connection-my-storage) used by InferenceService templates -- same template
    if [ "${DATA_CONNECTION_COMPAT:-true}" = "true" ]; then
        CONNECTION_NAME="aws-connection-my-storage" DISPLAY_NAME="${display_name} (compat)" \
            envsubst '${CONNECTION_NAME} ${S3_ACCESS_KEY} ${S3_SECRET_KEY} ${S3_ENDPOINT} ${BUCKET_NAME} ${DISPLAY_NAME} ${NAMESPACE}' \
            < "$manifest_dir/data-connection.yaml.tmpl" | oc apply -n "$target_ns" -f -
    fi

    echo -e "${GREEN:-}✓ Data connections created in ${target_ns}${NC:-}"
}

################################################################################
# Internal helpers
################################################################################


################################################################################
# list_storage_buckets NAMESPACE
#
# Lists all S3 buckets in the storage backend. Runs a one-shot aws-cli pod.
# For ceph-rgw, lists ObjectBucketClaims.
################################################################################
list_storage_buckets() {
    local ns="${1:?namespace required}"
    local access_key="${S3_ACCESS_KEY:-$_DEFAULT_ACCESS_KEY}"
    local secret_key="${S3_SECRET_KEY:-$_DEFAULT_SECRET_KEY}"

    detect_or_select_storage_backend "$ns" 2>/dev/null || true

    case "${S3_BACKEND:-$_DEFAULT_BACKEND}" in
        ceph-rgw)
            echo -e "${CYAN:-}ℹ Ceph RGW buckets (ObjectBucketClaims):${NC:-}"
            oc get objectbucketclaim -n "$ns" --no-headers 2>/dev/null \
                | awk '{printf "  %s (phase: %s)\n", $1, $NF}'
            ;;
        *)
            local endpoint
            endpoint="$(get_storage_endpoint "$ns")"
            oc run s3-list-buckets --rm -i --restart=Never -n "$ns" \
                --image=docker.io/amazon/aws-cli:latest \
                --env="AWS_ACCESS_KEY_ID=$access_key" \
                --env="AWS_SECRET_ACCESS_KEY=$secret_key" \
                --env="AWS_DEFAULT_REGION=us-east-1" \
                -- s3 ls --endpoint-url "$endpoint" 2>/dev/null \
                | sed 's/^/  /'
            ;;
    esac
}

################################################################################
# list_bucket_contents NAMESPACE BUCKET [PREFIX]
#
# Lists objects inside a bucket, optionally filtered by prefix.
################################################################################
list_bucket_contents() {
    local ns="${1:?namespace required}"
    local bucket="${2:?bucket name required}"
    local prefix="${3:-}"
    local access_key="${S3_ACCESS_KEY:-$_DEFAULT_ACCESS_KEY}"
    local secret_key="${S3_SECRET_KEY:-$_DEFAULT_SECRET_KEY}"

    detect_or_select_storage_backend "$ns" 2>/dev/null || true

    local endpoint
    endpoint="$(get_storage_endpoint "$ns")"
    local path="s3://${bucket}/"
    [ -n "$prefix" ] && path="s3://${bucket}/${prefix}"

    oc run s3-list-objects --rm -i --restart=Never -n "$ns" \
        --image=docker.io/amazon/aws-cli:latest \
        --env="AWS_ACCESS_KEY_ID=$access_key" \
        --env="AWS_SECRET_ACCESS_KEY=$secret_key" \
        --env="AWS_DEFAULT_REGION=us-east-1" \
        -- s3 ls "$path" --endpoint-url "$endpoint" --human-readable 2>/dev/null \
        | sed 's/^/  /'
}

################################################################################
# delete_storage_bucket NAMESPACE BUCKET_NAME
#
# Deletes an S3 bucket and all its contents. Runs a one-shot aws-cli pod.
# For ceph-rgw, deletes the ObjectBucketClaim.
################################################################################
delete_storage_bucket() {
    local ns="${1:?namespace required}"
    local bucket="${2:?bucket name required}"
    local access_key="${S3_ACCESS_KEY:-$_DEFAULT_ACCESS_KEY}"
    local secret_key="${S3_SECRET_KEY:-$_DEFAULT_SECRET_KEY}"

    detect_or_select_storage_backend "$ns" 2>/dev/null || true

    case "${S3_BACKEND:-$_DEFAULT_BACKEND}" in
        ceph-rgw)
            echo -e "${YELLOW:-}▶ Deleting ObjectBucketClaim: ${bucket}${NC:-}"
            oc delete objectbucketclaim "$bucket" -n "$ns" --ignore-not-found
            ;;
        *)
            local endpoint
            endpoint="$(get_storage_endpoint "$ns")"
            echo -e "${YELLOW:-}▶ Deleting bucket: ${bucket} (and all contents)${NC:-}"

            oc delete job/delete-bucket -n "$ns" --ignore-not-found 2>/dev/null || true
            oc run delete-bucket --rm -i --restart=Never -n "$ns" \
                --image=docker.io/amazon/aws-cli:latest \
                --env="AWS_ACCESS_KEY_ID=$access_key" \
                --env="AWS_SECRET_ACCESS_KEY=$secret_key" \
                --env="AWS_DEFAULT_REGION=us-east-1" \
                -- s3 rb "s3://${bucket}" --force --endpoint-url "$endpoint" 2>/dev/null

            if [ $? -eq 0 ]; then
                echo -e "${GREEN:-}✓ Bucket '${bucket}' deleted${NC:-}"
            else
                echo -e "${RED:-}✗ Failed to delete bucket '${bucket}'${NC:-}" >&2
                return 1
            fi
            ;;
    esac
}

################################################################################
# get_storage_info NAMESPACE
#
# Prints a summary of the storage backend: type, endpoint, credentials,
# external URL, PVC usage.
################################################################################
get_storage_info() {
    local ns="${1:?namespace required}"

    detect_or_select_storage_backend "$ns" 2>/dev/null || return 1

    local endpoint svc_name deploy_name
    endpoint="$(get_storage_endpoint "$ns")"
    svc_name="$(get_storage_service_name)"
    deploy_name="$(get_storage_deploy_name)"

    echo -e "${CYAN:-}Backend:${NC:-}       ${S3_BACKEND}"
    echo -e "${CYAN:-}Namespace:${NC:-}     ${ns}"
    echo -e "${CYAN:-}Internal URL:${NC:-}  ${endpoint}"
    echo -e "${CYAN:-}Service:${NC:-}       ${svc_name}"

    if [ "$S3_BACKEND" != "ceph-rgw" ]; then
        local ext_route
        ext_route=$(oc get route "$svc_name" -n "$ns" -o jsonpath='{.spec.host}' 2>/dev/null || echo "<none>")
        echo -e "${CYAN:-}External URL:${NC:-}  https://${ext_route}"
        echo -e "${CYAN:-}Access Key:${NC:-}    ${S3_ACCESS_KEY:-$_DEFAULT_ACCESS_KEY}"
        echo -e "${CYAN:-}Secret Key:${NC:-}    ${S3_SECRET_KEY:-$_DEFAULT_SECRET_KEY}"
    fi

    # PVC usage (if applicable)
    if [ -n "$deploy_name" ]; then
        local ready
        ready=$(oc get deployment "$deploy_name" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        echo -e "${CYAN:-}Status:${NC:-}        ${ready:-0} replica(s) ready"

        local pvc_name pvc_capacity
        case "$S3_BACKEND" in
            seaweedfs) pvc_name="seaweedfs-data" ;;
            minio)     pvc_name="minio-data" ;;
        esac
        if [ -n "${pvc_name:-}" ]; then
            pvc_capacity=$(oc get pvc "$pvc_name" -n "$ns" -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null || echo "unknown")
            echo -e "${CYAN:-}PVC Size:${NC:-}      ${pvc_capacity}"
        fi
    fi
}

################################################################################
# find_all_storage_deployments
#
# Scans the cluster for any known S3 storage backends (SeaweedFS, MinIO,
# Ceph RGW OBCs) and prints each namespace + backend type.
################################################################################
find_all_storage_deployments() {
    local found=false

    # SeaweedFS
    local sw_ns
    sw_ns=$(oc get deployment -l app.kubernetes.io/name=seaweedfs --all-namespaces --no-headers 2>/dev/null \
            | awk '{print $1}')
    for ns in $sw_ns; do
        echo "  seaweedfs   $ns"
        found=true
    done

    # MinIO
    local minio_ns
    minio_ns=$(oc get deployment -l app=minio --all-namespaces --no-headers 2>/dev/null \
               | awk '{print $1}')
    # Also check by deploy name (some old installs lack labels)
    local minio_ns2
    minio_ns2=$(oc get deployment minio --all-namespaces --no-headers 2>/dev/null \
                | awk '{print $1}')
    for ns in $(echo "$minio_ns $minio_ns2" | tr ' ' '\n' | sort -u); do
        echo "  minio       $ns"
        found=true
    done

    # Ceph RGW (ObjectBucketClaims)
    local obc_ns
    obc_ns=$(oc get objectbucketclaim --all-namespaces --no-headers 2>/dev/null \
             | awk '{print $1}' | sort -u)
    for ns in $obc_ns; do
        echo "  ceph-rgw    $ns"
        found=true
    done

    if [ "$found" = false ]; then
        echo "  (none found)"
    fi
}

################################################################################
# delete_storage_backend NAMESPACE
#
# Removes the S3 storage backend from a namespace. Deletes deployments,
# services, routes, PVCs, and secrets.
################################################################################
delete_storage_backend() {
    local ns="${1:?namespace required}"

    detect_or_select_storage_backend "$ns" 2>/dev/null || return 1

    echo -e "${YELLOW:-}▶ Removing ${S3_BACKEND} storage from ${ns}${NC:-}"

    case "$S3_BACKEND" in
        seaweedfs)
            oc delete route seaweedfs-s3 seaweedfs-admin -n "$ns" --ignore-not-found 2>/dev/null || true
            oc delete service seaweedfs-s3 -n "$ns" --ignore-not-found 2>/dev/null || true
            oc delete deployment seaweedfs -n "$ns" --ignore-not-found 2>/dev/null || true
            oc delete secret seaweedfs-s3-config -n "$ns" --ignore-not-found 2>/dev/null || true
            oc delete pvc seaweedfs-data -n "$ns" --ignore-not-found 2>/dev/null || true
            ;;
        minio)
            oc delete route minio minio-ui -n "$ns" --ignore-not-found 2>/dev/null || true
            oc delete service minio -n "$ns" --ignore-not-found 2>/dev/null || true
            oc delete deployment minio -n "$ns" --ignore-not-found 2>/dev/null || true
            oc delete secret minio-secret -n "$ns" --ignore-not-found 2>/dev/null || true
            oc delete pvc minio-data -n "$ns" --ignore-not-found 2>/dev/null || true
            ;;
        ceph-rgw)
            oc delete objectbucketclaim --all -n "$ns" --ignore-not-found 2>/dev/null || true
            ;;
    esac

    # Remove data connections
    oc delete secret aws-connection-minio aws-connection-my-storage -n "$ns" --ignore-not-found 2>/dev/null || true

    echo -e "${GREEN:-}✓ ${S3_BACKEND} removed from ${ns}${NC:-}"
}

################################################################################
# Internal helpers — deployment backends
################################################################################

_deploy_seaweedfs() {
    local ns="$1" storage_size="$2" access_key="$3" secret_key="$4" manifest_dir="$5"
    local deploy_name="$_SEAWEEDFS_DEPLOY_NAME"

    if oc get deployment "$deploy_name" -n "$ns" &>/dev/null; then
        echo -e "${CYAN:-}ℹ SeaweedFS already deployed in ${ns}${NC:-}"
        return 0
    fi

    export S3_ACCESS_KEY="$access_key"
    export S3_SECRET_KEY="$secret_key"
    export STORAGE_SIZE="$storage_size"

    envsubst '${S3_ACCESS_KEY} ${S3_SECRET_KEY}' \
        < "$manifest_dir/seaweedfs-secret.yaml.tmpl" | oc apply -n "$ns" -f -
    envsubst '${STORAGE_SIZE}' \
        < "$manifest_dir/seaweedfs-pvc.yaml.tmpl" | oc apply -n "$ns" -f -
    oc apply -n "$ns" -f "$manifest_dir/seaweedfs-deployment.yaml"
    oc apply -n "$ns" -f "$manifest_dir/seaweedfs-service.yaml"
    oc apply -n "$ns" -f "$manifest_dir/seaweedfs-routes.yaml"

    echo -e "${GREEN:-}✓ SeaweedFS deployed${NC:-}"
}

_deploy_ceph_rgw() {
    local ns="$1" manifest_dir="$2"

    # Check ODF prerequisite
    if ! oc get crd storageclusters.ocs.openshift.io &>/dev/null; then
        echo -e "${RED:-}✗ OpenShift Data Foundation (ODF) is not installed.${NC:-}" >&2
        echo -e "${RED:-}  Ceph RGW backend requires ODF. Install it first or use --backend=seaweedfs.${NC:-}" >&2
        return 1
    fi

    local obc_count
    obc_count=$(oc get objectbucketclaim -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "${obc_count:-0}" -ge 1 ]; then
        echo -e "${CYAN:-}ℹ ObjectBucketClaim already exists in ${ns}${NC:-}"
        return 0
    fi

    export NAMESPACE="$ns"
    export OBC_STORAGECLASS="$_CEPH_OBC_STORAGECLASS"
    envsubst '${NAMESPACE} ${OBC_STORAGECLASS}' \
        < "$manifest_dir/ceph-rgw-objectbucketclaim.yaml.tmpl" | oc apply -n "$ns" -f -

    echo -e "${GREEN:-}✓ ObjectBucketClaim created — ODF will auto-provision bucket + credentials${NC:-}"
}

_deploy_minio() {
    local ns="$1" storage_size="$2" access_key="$3" secret_key="$4" manifest_dir="$5"
    local deploy_name="$_MINIO_DEPLOY_NAME"

    if oc get deployment "$deploy_name" -n "$ns" &>/dev/null; then
        echo -e "${CYAN:-}ℹ MinIO already deployed in ${ns}${NC:-}"
        return 0
    fi

    # For backward compat, map the standard keys to MinIO-specific env vars
    export MINIO_USER="$access_key"
    export MINIO_PASSWORD="$secret_key"
    export STORAGE_SIZE="$storage_size"

    envsubst '${MINIO_USER} ${MINIO_PASSWORD}' \
        < "$manifest_dir/minio-secret.yaml.tmpl" | oc apply -n "$ns" -f -
    envsubst '${STORAGE_SIZE}' \
        < "$manifest_dir/minio-pvc.yaml.tmpl" | oc apply -n "$ns" -f -
    oc apply -n "$ns" -f "$manifest_dir/minio-deployment.yaml"
    oc apply -n "$ns" -f "$manifest_dir/minio-service.yaml"
    oc apply -n "$ns" -f "$manifest_dir/minio-routes.yaml"

    echo -e "${GREEN:-}✓ MinIO deployed (deprecated — consider migrating to SeaweedFS)${NC:-}"
}
