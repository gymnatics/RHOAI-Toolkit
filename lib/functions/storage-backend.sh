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
        echo -e "${YELLOW:-}⚠ MinIO backend is deprecated. Consider migrating to SeaweedFS (--backend=seaweedfs).${NC:-}" >&2
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

            # Delete previous job if exists
            oc delete job/create-bucket -n "$ns" --ignore-not-found 2>/dev/null || true

            export S3_ACCESS_KEY="$access_key"
            export S3_SECRET_KEY="$secret_key"
            export BUCKET_NAME="$bucket"
            export S3_ENDPOINT="$endpoint"
            envsubst '${S3_ACCESS_KEY} ${S3_SECRET_KEY} ${BUCKET_NAME} ${S3_ENDPOINT}' \
                < "$manifest_dir/create-bucket-job.yaml.tmpl" | oc apply -n "$ns" -f -

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

    local manifest_dir
    manifest_dir="$(get_storage_manifest_dir)"

    export S3_ACCESS_KEY="$access_key"
    export S3_SECRET_KEY="$secret_key"
    export S3_ENDPOINT="$endpoint"
    export BUCKET_NAME="$bucket"
    export DISPLAY_NAME="$display_name"
    export NAMESPACE="$storage_ns"

    # Primary data connection
    envsubst '${S3_ACCESS_KEY} ${S3_SECRET_KEY} ${S3_ENDPOINT} ${BUCKET_NAME} ${DISPLAY_NAME} ${NAMESPACE}' \
        < "$manifest_dir/data-connection.yaml.tmpl" | oc apply -n "$target_ns" -f -

    # Compatibility alias (aws-connection-my-storage) used by InferenceService templates
    _create_compat_data_connection "$target_ns" "$endpoint" "$access_key" "$secret_key" "$bucket" "$display_name"

    echo -e "${GREEN:-}✓ Data connections created in ${target_ns}${NC:-}"
}

################################################################################
# Internal helpers
################################################################################

_create_compat_data_connection() {
    local ns="$1" endpoint="$2" access_key="$3" secret_key="$4" bucket="$5" display_name="$6"

    cat <<EOF | oc apply -n "$ns" -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: aws-connection-my-storage
  labels:
    opendatahub.io/dashboard: "true"
    opendatahub.io/managed: "true"
  annotations:
    opendatahub.io/connection-type: s3
    openshift.io/display-name: "${display_name} (compat)"
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: "${access_key}"
  AWS_SECRET_ACCESS_KEY: "${secret_key}"
  AWS_S3_ENDPOINT: "${endpoint}"
  AWS_S3_BUCKET: "${bucket}"
  AWS_DEFAULT_REGION: "us-east-1"
EOF
}

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
