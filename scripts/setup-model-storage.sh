#!/bin/bash
################################################################################
# Setup Model Storage (S3-Compatible Backend + RHOAI Data Connection)
#
# Deploys an S3-compatible storage backend and creates RHOAI data connections
# for storing and serving models downloaded from HuggingFace.
#
# Supported backends:
#   seaweedfs  — Default. Lightweight, self-contained S3-compatible store.
#   ceph-rgw   — Uses ODF ObjectBucketClaim. Requires OpenShift Data Foundation.
#   minio      — Deprecated legacy backend. Will be removed in a future release.
#
# Usage:
#   ./setup-model-storage.sh [OPTIONS]
#
# Options:
#   --backend BACKEND       Storage backend: seaweedfs|ceph-rgw|minio (default: seaweedfs)
#   -n, --namespace NAME    Namespace for storage (default: model-storage)
#   -b, --bucket NAME       Bucket name (default: models)
#   --storage-size SIZE     PVC size (default: 200Gi)
#   --access-key KEY        S3 access key (default: admin)
#   --secret-key KEY        S3 secret key (default: admin123)
#   --skip-data-connection  Skip creating RHOAI data connection
#   --data-connection-ns NS Namespace for data connection (default: same as storage)
#   -h, --help              Show this help
#
# Legacy flags (deprecated, only with --backend=minio):
#   --minio-user USER       Alias for --access-key
#   --minio-password PASS   Alias for --secret-key
#
# Examples:
#   ./setup-model-storage.sh                                    # SeaweedFS (default)
#   ./setup-model-storage.sh --backend=ceph-rgw                 # Ceph/ODF
#   ./setup-model-storage.sh --backend=minio                    # MinIO (deprecated)
#   ./setup-model-storage.sh -n demo -b my-models               # Custom ns/bucket
#   ./setup-model-storage.sh --storage-size 500Gi               # Larger storage
#
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source utilities
if [ -f "$BASE_DIR/lib/utils/colors.sh" ]; then
    source "$BASE_DIR/lib/utils/colors.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    BOLD='\033[1m'
fi

source "$BASE_DIR/lib/functions/storage-backend.sh"

print_step() { echo -e "${YELLOW}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Defaults
NAMESPACE="model-storage"
BUCKET_NAME="models"
SKIP_DATA_CONNECTION=false
DATA_CONNECTION_NS=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --backend|--backend=*)
            if [[ "$1" == *=* ]]; then
                S3_BACKEND="${1#*=}"
            else
                S3_BACKEND="$2"
                shift
            fi
            shift
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -b|--bucket)
            BUCKET_NAME="$2"
            shift 2
            ;;
        --storage-size)
            S3_STORAGE_SIZE="$2"
            shift 2
            ;;
        --access-key)
            S3_ACCESS_KEY="$2"
            shift 2
            ;;
        --secret-key)
            S3_SECRET_KEY="$2"
            shift 2
            ;;
        --minio-user)
            print_warning "--minio-user is deprecated. Use --access-key instead."
            S3_ACCESS_KEY="$2"
            shift 2
            ;;
        --minio-password)
            print_warning "--minio-password is deprecated. Use --secret-key instead."
            S3_SECRET_KEY="$2"
            shift 2
            ;;
        --skip-data-connection)
            SKIP_DATA_CONNECTION=true
            shift
            ;;
        --data-connection-ns)
            DATA_CONNECTION_NS="$2"
            shift 2
            ;;
        -h|--help)
            head -45 "$0" | tail -40
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

export S3_BACKEND="${S3_BACKEND:-}"
export S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
export S3_SECRET_KEY="${S3_SECRET_KEY:-}"
export S3_STORAGE_SIZE="${S3_STORAGE_SIZE:-}"
DATA_CONNECTION_NS="${DATA_CONNECTION_NS:-$NAMESPACE}"

# Resolve backend (auto-detect or use default)
detect_or_select_storage_backend "$NAMESPACE"

echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║           Model Storage Setup (${S3_BACKEND})${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
print_info "Backend:        $S3_BACKEND"
print_info "Namespace:      $NAMESPACE"
print_info "Bucket:         $BUCKET_NAME"
print_info "Storage Size:   ${S3_STORAGE_SIZE:-200Gi}"
print_info "Data Connection: ${DATA_CONNECTION_NS}"
echo ""

# Check oc login
if ! oc whoami &>/dev/null; then
    print_error "Not logged into OpenShift. Run 'oc login' first."
    exit 1
fi

# Get cluster domain
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "")
if [ -z "$CLUSTER_DOMAIN" ]; then
    print_error "Could not determine cluster domain"
    exit 1
fi

################################################################################
# Step 1: Deploy storage backend
################################################################################
deploy_storage_backend "$NAMESPACE"

################################################################################
# Step 2: Wait for readiness
################################################################################
wait_for_storage "$NAMESPACE"

################################################################################
# Step 3: Create bucket
################################################################################
print_step "Creating bucket: $BUCKET_NAME"
create_storage_bucket "$NAMESPACE" "$BUCKET_NAME"

################################################################################
# Step 4: Create RHOAI Data Connection
################################################################################
if [ "$SKIP_DATA_CONNECTION" = false ]; then
    create_data_connection "$NAMESPACE" "$BUCKET_NAME" "$DATA_CONNECTION_NS" "S3 Model Storage"
fi

################################################################################
# Summary
################################################################################
ENDPOINT="$(get_storage_endpoint "$NAMESPACE")"
SVC_NAME="$(get_storage_service_name)"

echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                    Setup Complete!                             ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Storage Details:${NC}"
echo "  Backend:       $S3_BACKEND"
echo "  Namespace:     $NAMESPACE"
echo "  Internal URL:  $ENDPOINT"
echo "  Service:       $SVC_NAME"
echo "  Bucket:        $BUCKET_NAME"

if [ "$S3_BACKEND" != "ceph-rgw" ]; then
    local_route=$(oc get route "${SVC_NAME}" -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "<none>")
    echo "  External URL:  https://$local_route"
    echo "  Access Key:    ${S3_ACCESS_KEY:-admin}"
    echo "  Secret Key:    ${S3_SECRET_KEY:-admin123}"
fi

echo ""
echo -e "${CYAN}RHOAI Data Connection:${NC}"
echo "  Namespace:     $DATA_CONNECTION_NS"
echo "  Secret Name:   aws-connection-minio"
echo "  Also:          aws-connection-my-storage (for script compatibility)"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Download model from HuggingFace:"
echo "     NAMESPACE=$DATA_CONNECTION_NS ./scripts/download-model.sh s3 Qwen/Qwen3-8B"
echo ""
echo "  2. Deploy model using storageUri:"
echo "     storageUri: s3://${BUCKET_NAME}/<model-name>/"
echo ""
echo "  3. Or use the RHOAI dashboard to create a model server"
echo "     with the 'S3 Model Storage' data connection"
echo ""
