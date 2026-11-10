#!/bin/bash
################################################################################
# Manage S3-Compatible Storage on OpenShift
#
# General-purpose S3 storage management CLI. Deploys and manages SeaweedFS
# (or Ceph RGW / MinIO) for any workload — models, pipelines, notebooks,
# datasets, application data, or anything that needs S3-compatible storage.
#
# Subcommands:
#   deploy     Deploy a storage backend into a namespace
#   status     Show storage backends across the cluster
#   info       Show detailed info for a specific deployment
#   bucket     Bucket management (create, list, delete, ls)
#   connect    Create an RHOAI data connection in any namespace
#   delete     Remove a storage backend from a namespace
#
# Usage:
#   ./manage-storage.sh deploy [OPTIONS]
#   ./manage-storage.sh status
#   ./manage-storage.sh info   [-n NAMESPACE]
#   ./manage-storage.sh bucket create BUCKET [-n NAMESPACE]
#   ./manage-storage.sh bucket list   [-n NAMESPACE]
#   ./manage-storage.sh bucket delete BUCKET [-n NAMESPACE]
#   ./manage-storage.sh bucket ls     BUCKET [PREFIX] [-n NAMESPACE]
#   ./manage-storage.sh connect -n STORAGE_NS --target TARGET_NS [--bucket BUCKET] [--name NAME]
#   ./manage-storage.sh delete  [-n NAMESPACE] [--yes]
#
# Deploy Options:
#   --backend BACKEND       seaweedfs (default) | ceph-rgw | minio (deprecated)
#   -n, --namespace NS      Namespace (default: s3-storage)
#   --storage-size SIZE     PVC size (default: 200Gi)
#   --access-key KEY        S3 access key (default: admin)
#   --secret-key KEY        S3 secret key (default: admin123)
#   --bucket BUCKET         Also create this bucket after deploy
#   --connect-to NS         Also create a data connection in NS after deploy
#
# Examples:
#   # Deploy storage for general use
#   ./manage-storage.sh deploy
#
#   # Deploy with custom namespace and size
#   ./manage-storage.sh deploy -n my-storage --storage-size 500Gi
#
#   # Deploy + create bucket + data connection in one command
#   ./manage-storage.sh deploy -n shared-s3 --bucket datasets --connect-to ml-project
#
#   # List all storage deployments on the cluster
#   ./manage-storage.sh status
#
#   # Create additional buckets
#   ./manage-storage.sh bucket create training-data -n shared-s3
#   ./manage-storage.sh bucket create artifacts -n shared-s3
#
#   # List buckets and browse contents
#   ./manage-storage.sh bucket list -n shared-s3
#   ./manage-storage.sh bucket ls models -n shared-s3
#   ./manage-storage.sh bucket ls models Qwen/ -n shared-s3
#
#   # Create data connections in multiple namespaces
#   ./manage-storage.sh connect -n shared-s3 --target team-a --bucket models
#   ./manage-storage.sh connect -n shared-s3 --target team-b --bucket datasets --name my-s3
#
#   # Show endpoint, credentials, PVC size
#   ./manage-storage.sh info -n shared-s3
#
#   # Remove storage
#   ./manage-storage.sh delete -n shared-s3 --yes
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
    BOLD='\033[1m'
    NC='\033[0m'
fi

# Provide print functions if not sourced from colors.sh
type print_step    &>/dev/null || print_step()    { echo -e "${YELLOW}▶ $1${NC}"; }
type print_success &>/dev/null || print_success() { echo -e "${GREEN}✓ $1${NC}"; }
type print_error   &>/dev/null || print_error()   { echo -e "${RED}✗ $1${NC}"; }
type print_info    &>/dev/null || print_info()     { echo -e "${CYAN}ℹ $1${NC}"; }
type print_warning &>/dev/null || print_warning()  { echo -e "${YELLOW}⚠ $1${NC}"; }
type print_header  &>/dev/null || print_header()   {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

source "$BASE_DIR/lib/functions/storage-backend.sh"

# Defaults
DEFAULT_NAMESPACE="s3-storage"

################################################################################
# Helpers
################################################################################

_require_login() {
    if ! oc whoami &>/dev/null; then
        print_error "Not logged into OpenShift. Run 'oc login' first."
        exit 1
    fi
}

_usage() {
    head -70 "$0" | tail -65
    exit 0
}

################################################################################
# Subcommand: deploy
################################################################################
cmd_deploy() {
    local namespace="$DEFAULT_NAMESPACE"
    local bucket=""
    local connect_to=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --backend|--backend=*)
                if [[ "$1" == *=* ]]; then S3_BACKEND="${1#*=}"; else S3_BACKEND="$2"; shift; fi
                shift ;;
            -n|--namespace)  namespace="$2"; shift 2 ;;
            --storage-size)  S3_STORAGE_SIZE="$2"; shift 2 ;;
            --access-key)    S3_ACCESS_KEY="$2"; shift 2 ;;
            --secret-key)    S3_SECRET_KEY="$2"; shift 2 ;;
            --bucket)        bucket="$2"; shift 2 ;;
            --connect-to)    connect_to="$2"; shift 2 ;;
            -h|--help)       _usage ;;
            *) print_error "Unknown deploy option: $1"; exit 1 ;;
        esac
    done

    export S3_BACKEND="${S3_BACKEND:-}"
    export S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
    export S3_SECRET_KEY="${S3_SECRET_KEY:-}"
    export S3_STORAGE_SIZE="${S3_STORAGE_SIZE:-}"

    _require_login

    detect_or_select_storage_backend "$namespace"

    print_header "Deploy S3 Storage (${S3_BACKEND})"
    print_info "Namespace:      $namespace"
    print_info "Backend:        $S3_BACKEND"
    print_info "Storage Size:   ${S3_STORAGE_SIZE:-200Gi}"
    [ -n "$bucket" ]     && print_info "Create Bucket:  $bucket"
    [ -n "$connect_to" ] && print_info "Connect To:     $connect_to"
    echo ""

    deploy_storage_backend "$namespace"
    wait_for_storage "$namespace"

    if [ -n "$bucket" ]; then
        echo ""
        create_storage_bucket "$namespace" "$bucket"
    fi

    if [ -n "$connect_to" ]; then
        echo ""
        create_data_connection "$namespace" "${bucket:-default}" "$connect_to" "S3 Storage ($namespace)"
    fi

    echo ""
    echo -e "${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║                    Deploy Complete                             ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    get_storage_info "$namespace"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  Create a bucket:        $0 bucket create <name> -n $namespace"
    echo "  Create data connection: $0 connect -n $namespace --target <namespace>"
    echo "  Show status:            $0 status"
    echo ""
}

################################################################################
# Subcommand: status
################################################################################
cmd_status() {
    _require_login

    print_header "S3 Storage Backends on Cluster"

    echo -e "${CYAN}Scanning for storage deployments...${NC}"
    echo ""
    echo -e "${BOLD}  BACKEND       NAMESPACE${NC}"
    echo "  ─────────────────────────────────"
    find_all_storage_deployments
    echo ""

    # Also list data connections
    echo -e "${BOLD}  DATA CONNECTIONS (S3 secrets):${NC}"
    echo "  ─────────────────────────────────"
    local dc_list
    dc_list=$(oc get secret --all-namespaces --no-headers 2>/dev/null \
              | grep -E 'aws-connection-' \
              || true)
    if [ -n "$dc_list" ]; then
        echo "$dc_list" | awk '{printf "  %-30s %s\n", $1, $2}'
    else
        echo "  (none found)"
    fi
    echo ""
}

################################################################################
# Subcommand: info
################################################################################
cmd_info() {
    local namespace="$DEFAULT_NAMESPACE"

    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace) namespace="$2"; shift 2 ;;
            -h|--help)      _usage ;;
            *) namespace="$1"; shift ;;
        esac
    done

    _require_login

    print_header "Storage Info: ${namespace}"
    get_storage_info "$namespace"

    echo ""
    echo -e "${BOLD}Buckets:${NC}"
    list_storage_buckets "$namespace" 2>/dev/null || echo "  (could not list buckets)"

    echo ""
    echo -e "${BOLD}Data connections pointing here:${NC}"
    local endpoint
    endpoint="$(get_storage_endpoint "$namespace" 2>/dev/null || echo "")"
    if [ -n "$endpoint" ]; then
        oc get secret --all-namespaces --no-headers 2>/dev/null \
            | grep -E 'aws-connection-' \
            | while read -r ns name rest; do
                local ep_val
                ep_val=$(oc get secret "$name" -n "$ns" -o jsonpath='{.data.AWS_S3_ENDPOINT}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
                if [ "$ep_val" = "$endpoint" ]; then
                    local bkt
                    bkt=$(oc get secret "$name" -n "$ns" -o jsonpath='{.data.AWS_S3_BUCKET}' 2>/dev/null | base64 -d 2>/dev/null || echo "?")
                    printf "  %-30s %-30s bucket=%s\n" "$ns" "$name" "$bkt"
                fi
            done
    else
        echo "  (storage not found in $namespace)"
    fi
    echo ""
}

################################################################################
# Subcommand: bucket
################################################################################
cmd_bucket() {
    local action="${1:-}"
    shift 2>/dev/null || true

    case "$action" in
        create) cmd_bucket_create "$@" ;;
        list)   cmd_bucket_list "$@" ;;
        delete) cmd_bucket_delete "$@" ;;
        ls)     cmd_bucket_ls "$@" ;;
        ""|--help|-h)
            echo "Usage: $0 bucket <create|list|delete|ls> [OPTIONS]"
            echo ""
            echo "  create BUCKET [-n NAMESPACE]           Create a new bucket"
            echo "  list          [-n NAMESPACE]           List all buckets"
            echo "  delete BUCKET [-n NAMESPACE] [--yes]   Delete a bucket"
            echo "  ls     BUCKET [PREFIX] [-n NAMESPACE]  List bucket contents"
            exit 0
            ;;
        *) print_error "Unknown bucket action: $action"; exit 1 ;;
    esac
}

cmd_bucket_create() {
    local namespace="$DEFAULT_NAMESPACE"
    local bucket=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace) namespace="$2"; shift 2 ;;
            -*) print_error "Unknown option: $1"; exit 1 ;;
            *)  bucket="$1"; shift ;;
        esac
    done

    if [ -z "$bucket" ]; then
        print_error "Bucket name required. Usage: $0 bucket create <name> [-n namespace]"
        exit 1
    fi

    _require_login
    detect_or_select_storage_backend "$namespace" 2>/dev/null || true
    print_step "Creating bucket '$bucket' in $namespace ($S3_BACKEND)"
    create_storage_bucket "$namespace" "$bucket"
}

cmd_bucket_list() {
    local namespace="$DEFAULT_NAMESPACE"

    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace) namespace="$2"; shift 2 ;;
            -*) print_error "Unknown option: $1"; exit 1 ;;
            *)  namespace="$1"; shift ;;
        esac
    done

    _require_login
    detect_or_select_storage_backend "$namespace" 2>/dev/null || true
    echo -e "${BOLD}Buckets in ${namespace} (${S3_BACKEND}):${NC}"
    list_storage_buckets "$namespace"
}

cmd_bucket_delete() {
    local namespace="$DEFAULT_NAMESPACE"
    local bucket=""
    local yes=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace) namespace="$2"; shift 2 ;;
            --yes|-y)       yes=true; shift ;;
            -*) print_error "Unknown option: $1"; exit 1 ;;
            *)  bucket="$1"; shift ;;
        esac
    done

    if [ -z "$bucket" ]; then
        print_error "Bucket name required. Usage: $0 bucket delete <name> [-n namespace]"
        exit 1
    fi

    _require_login
    detect_or_select_storage_backend "$namespace" 2>/dev/null || true

    if [ "$yes" != true ]; then
        echo -e "${RED}WARNING: This will permanently delete bucket '${bucket}' and all its contents.${NC}"
        read -p "Are you sure? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            return 0
        fi
    fi

    delete_storage_bucket "$namespace" "$bucket"
}

cmd_bucket_ls() {
    local namespace="$DEFAULT_NAMESPACE"
    local bucket=""
    local prefix=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace) namespace="$2"; shift 2 ;;
            -*) print_error "Unknown option: $1"; exit 1 ;;
            *)
                if [ -z "$bucket" ]; then
                    bucket="$1"
                else
                    prefix="$1"
                fi
                shift
                ;;
        esac
    done

    if [ -z "$bucket" ]; then
        print_error "Bucket name required. Usage: $0 bucket ls <bucket> [prefix] [-n namespace]"
        exit 1
    fi

    _require_login
    detect_or_select_storage_backend "$namespace" 2>/dev/null || true
    echo -e "${BOLD}Contents of s3://${bucket}/${prefix} in ${namespace}:${NC}"
    list_bucket_contents "$namespace" "$bucket" "$prefix"
}

################################################################################
# Subcommand: connect
################################################################################
cmd_connect() {
    local namespace="$DEFAULT_NAMESPACE"
    local target=""
    local bucket="default"
    local display_name=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)  namespace="$2"; shift 2 ;;
            --target)        target="$2"; shift 2 ;;
            --bucket)        bucket="$2"; shift 2 ;;
            --name)          display_name="$2"; shift 2 ;;
            -h|--help)
                echo "Usage: $0 connect -n STORAGE_NS --target TARGET_NS [--bucket BUCKET] [--name DISPLAY_NAME]"
                exit 0
                ;;
            *) print_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$target" ]; then
        print_error "--target namespace is required"
        echo "Usage: $0 connect -n $namespace --target <target-namespace> [--bucket <bucket>]"
        exit 1
    fi

    _require_login
    detect_or_select_storage_backend "$namespace" 2>/dev/null || true

    local label="${display_name:-S3 Storage ($namespace/$bucket)}"
    print_step "Creating data connection in '$target' → $S3_BACKEND in '$namespace' (bucket: $bucket)"
    create_data_connection "$namespace" "$bucket" "$target" "$label"
    echo ""
    print_success "Data connection created. Workloads in '$target' can now access S3."
    echo ""
    echo -e "${CYAN}Secret created:${NC} aws-connection-minio, aws-connection-my-storage"
    echo -e "${CYAN}Namespace:${NC}      $target"
    echo -e "${CYAN}Bucket:${NC}         $bucket"
    echo -e "${CYAN}Storage:${NC}        $S3_BACKEND in $namespace"
}

################################################################################
# Subcommand: delete
################################################################################
cmd_delete() {
    local namespace="$DEFAULT_NAMESPACE"
    local yes=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace) namespace="$2"; shift 2 ;;
            --yes|-y)       yes=true; shift ;;
            -h|--help)      _usage ;;
            *) print_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    _require_login
    detect_or_select_storage_backend "$namespace" 2>/dev/null || true

    echo -e "${CYAN}Storage backend:${NC} $S3_BACKEND in $namespace"
    if [ "$yes" != true ]; then
        echo -e "${RED}WARNING: This will remove the storage backend, PVC (all data), and data connections.${NC}"
        read -p "Are you sure? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            return 0
        fi
    fi

    delete_storage_backend "$namespace"
}

################################################################################
# Main dispatch
################################################################################
subcommand="${1:-}"
shift 2>/dev/null || true

case "$subcommand" in
    deploy)  cmd_deploy "$@" ;;
    status)  cmd_status "$@" ;;
    info)    cmd_info "$@" ;;
    bucket)  cmd_bucket "$@" ;;
    connect) cmd_connect "$@" ;;
    delete)  cmd_delete "$@" ;;
    -h|--help|"")
        echo ""
        echo -e "${BOLD}manage-storage.sh — General-purpose S3 storage management${NC}"
        echo ""
        echo "Subcommands:"
        echo "  deploy     Deploy a storage backend (SeaweedFS/Ceph RGW/MinIO)"
        echo "  status     Show all storage backends on the cluster"
        echo "  info       Detailed info for a specific deployment"
        echo "  bucket     Bucket management (create, list, delete, ls)"
        echo "  connect    Create an RHOAI data connection in any namespace"
        echo "  delete     Remove a storage backend"
        echo ""
        echo "Run '$0 <subcommand> --help' for details."
        echo ""
        echo "Quick start:"
        echo "  $0 deploy -n shared-s3 --bucket models --connect-to my-project"
        echo ""
        exit 0
        ;;
    *)
        print_error "Unknown subcommand: $subcommand"
        echo "Run '$0 --help' for usage."
        exit 1
        ;;
esac
