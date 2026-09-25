#!/bin/bash
################################################################################
# models.sh — Model storage & deployment interactive wrappers
# Extracted from rhoai-toolkit.sh
################################################################################

_MODELS_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_MODELS_MENU_DIR/lib/functions/storage-backend.sh" 2>/dev/null || true

# Detect an existing S3 storage deployment (any backend) in common namespaces.
# Sets: _found_ns, _found_backend
_detect_existing_storage() {
    _found_ns=""
    _found_backend=""
    for ns in model-storage demo; do
        if type detect_or_select_storage_backend &>/dev/null; then
            detect_or_select_storage_backend "$ns" 2>/dev/null
            if oc get deployment "$(get_storage_deploy_name)" -n "$ns" &>/dev/null 2>&1 || \
               oc get objectbucketclaim -n "$ns" --no-headers 2>/dev/null | grep -q .; then
                _found_ns="$ns"
                _found_backend="$S3_BACKEND"
                return 0
            fi
        elif oc get deployment minio -n "$ns" &>/dev/null 2>&1; then
            _found_ns="$ns"
            _found_backend="minio"
            return 0
        fi
    done
    return 1
}

setup_model_storage_interactive() {
    print_header "Setup Model Storage (S3-Compatible)"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    echo ""
    
    if _detect_existing_storage; then
        print_info "S3 storage ($_found_backend) already deployed in namespace: $_found_ns"
        echo ""
        local storage_route
        storage_route=$(oc get route "$(get_storage_service_name)" -n "$_found_ns" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
        if [ -n "$storage_route" ]; then
            echo -e "${CYAN}Storage Endpoint:${NC} https://$storage_route"
        fi
        echo ""
        echo -e "${YELLOW}1)${NC} Re-run setup (create bucket + data connection)"
        echo -e "${YELLOW}2)${NC} Deploy a new backend in a different namespace"
        echo -e "${YELLOW}0)${NC} Back"
        echo ""
        read -p "Select option: " storage_choice
        case $storage_choice in
            1)
                echo ""
                read -p "Bucket name [models]: " bucket
                bucket=${bucket:-models}
                read -p "Data connection namespace [$_found_ns]: " dc_ns
                dc_ns=${dc_ns:-$_found_ns}
                "$SCRIPT_DIR/scripts/setup-model-storage.sh" \
                    --backend "$_found_backend" \
                    --namespace "$_found_ns" \
                    --bucket "$bucket" \
                    --data-connection-ns "$dc_ns"
                return $?
                ;;
            2) ;;
            *) return 0 ;;
        esac
    fi
    
    echo ""
    echo -e "${CYAN}Storage backend:${NC}"
    echo -e "${YELLOW}1)${NC} SeaweedFS ${GREEN}[Recommended, default]${NC}"
    echo -e "${YELLOW}2)${NC} Ceph RGW ${CYAN}[Requires OpenShift Data Foundation]${NC}"
    echo -e "${YELLOW}3)${NC} MinIO ${RED}[Deprecated]${NC}"
    read -p "Select backend [1]: " backend_choice
    local backend
    case "${backend_choice:-1}" in
        2) backend="ceph-rgw" ;;
        3) backend="minio" ;;
        *) backend="seaweedfs" ;;
    esac
    
    echo ""
    read -p "Namespace for storage [model-storage]: " namespace
    namespace=${namespace:-model-storage}
    
    read -p "Storage size [200Gi]: " storage_size
    storage_size=${storage_size:-200Gi}
    
    read -p "Bucket name [models]: " bucket_name
    bucket_name=${bucket_name:-models}
    
    echo ""
    echo -e "${CYAN}Data connections allow RHOAI workbenches and model servers to access S3 storage.${NC}"
    read -p "Create data connection in namespace [$namespace]: " dc_ns
    dc_ns=${dc_ns:-$namespace}
    
    echo ""
    print_step "Running setup-model-storage.sh --backend $backend..."
    echo ""
    
    "$SCRIPT_DIR/scripts/setup-model-storage.sh" \
        --backend "$backend" \
        --namespace "$namespace" \
        --bucket "$bucket_name" \
        --storage-size "$storage_size" \
        --data-connection-ns "$dc_ns"
    
    return $?
}

download_hf_model_interactive() {
    print_header "Download Model from HuggingFace"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    echo ""
    
    local minio_ns=""
    if _detect_existing_storage; then
        minio_ns="$_found_ns"
    fi
    
    if [ -z "$minio_ns" ]; then
        print_warning "No S3 storage backend found. Please set up model storage first."
        echo ""
        echo "Run option 4 (Setup Model Storage) to deploy one."
        return 1
    fi
    
    print_info "Found S3 storage ($_found_backend) in namespace: $minio_ns"
    echo ""
    
    echo -e "${CYAN}Popular models:${NC}"
    echo "  - Qwen/Qwen3-8B"
    echo "  - Qwen/Qwen2.5-7B-Instruct"
    echo "  - meta-llama/Llama-3.1-8B-Instruct (requires HF token)"
    echo "  - mistralai/Mistral-7B-Instruct-v0.3"
    echo ""
    read -p "Model name (e.g., Qwen/Qwen3-8B): " model_name
    
    if [ -z "$model_name" ]; then
        print_error "Model name is required"
        return 1
    fi
    
    local needs_token=false
    if [[ "$model_name" == *"llama"* ]] || [[ "$model_name" == *"Llama"* ]]; then
        needs_token=true
    fi
    
    local hf_token=""
    if [ "$needs_token" = true ]; then
        echo ""
        print_warning "This model may require a HuggingFace token."
        echo "Get your token from: https://huggingface.co/settings/tokens"
        read -p "HuggingFace token (leave empty to skip): " hf_token
    else
        echo ""
        read -p "HuggingFace token (optional, for gated models): " hf_token
    fi
    
    echo ""
    read -p "Namespace for download job [$minio_ns]: " job_ns
    job_ns=${job_ns:-$minio_ns}
    
    if ! oc get secret aws-connection-my-storage -n "$job_ns" &>/dev/null && \
       ! oc get secret aws-connection-minio -n "$job_ns" &>/dev/null; then
        print_warning "No data connection found in namespace '$job_ns'"
        echo ""
        echo "Creating data connection..."
        "$SCRIPT_DIR/scripts/setup-model-storage.sh" \
            --namespace "$minio_ns" \
            --data-connection-ns "$job_ns" 2>/dev/null || true
    fi
    
    echo ""
    print_step "Starting download..."
    echo ""
    echo -e "${CYAN}This may take a while depending on model size.${NC}"
    echo "You can monitor progress with:"
    echo "  oc logs -f job/download-models-s3 -n $job_ns"
    echo ""
    
    NAMESPACE="$job_ns" MINIO_NAMESPACE="$minio_ns" HF_TOKEN="$hf_token" \
        "$SCRIPT_DIR/scripts/download-model.sh" s3 "$model_name"
    
    local result=$?
    
    if [ $result -eq 0 ]; then
        echo ""
        print_success "Model downloaded successfully!"
        echo ""
        echo -e "${CYAN}To deploy this model:${NC}"
        echo "  1. Go to RHOAI Dashboard → Data Science Projects"
        echo "  2. Create/select a project"
        echo "  3. Deploy model with:"
        echo "     - Data connection: S3 Model Storage"
        echo "     - Path: $model_name"
        echo ""
        echo "  Or use CLI:"
        echo "     storageUri: s3://models/$model_name/"
    fi
    
    return $result
}

deploy_model_from_menu() {
    print_header "Deploy Model"
    
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo ""
        echo "Please log in first:"
        echo "  oc login <cluster-url>"
        return 1
    fi
    
    print_success "Connected to cluster: $(oc whoami --show-server)"
    
    if [ ! -f "$SCRIPT_DIR/lib/functions/model-deployment.sh" ]; then
        print_error "Model deployment library not found"
        echo ""
        echo "Expected: $SCRIPT_DIR/lib/functions/model-deployment.sh"
        return 1
    fi
    
    if [ ! -f "$SCRIPT_DIR/lib/utils/colors.sh" ]; then
        print_error "Colors library not found"
        return 1
    fi
    
    source "$SCRIPT_DIR/lib/utils/colors.sh"
    source "$SCRIPT_DIR/lib/functions/model-deployment.sh"
    
    echo ""
    deploy_model_interactive
    
    return $?
}

deploy_predictive_model_interactive() {
    print_header "Deploy Predictive Model (CPU)"

    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo "  oc login <cluster-url>"
        return 1
    fi

    source "$SCRIPT_DIR/lib/utils/colors.sh"
    source "$SCRIPT_DIR/lib/functions/model-deployment.sh"

    echo -e "${YELLOW}Available data science projects:${NC}"
    oc get projects -l opendatahub.io/dashboard=true --no-headers 2>/dev/null | awk '{print "  " $1}'
    echo ""
    read -rp "Namespace to deploy in: " target_ns
    if [ -z "$target_ns" ]; then
        print_error "Namespace is required"
        return 1
    fi
    if ! oc get project "$target_ns" &>/dev/null; then
        print_error "Project '$target_ns' does not exist"
        return 1
    fi

    echo ""
    echo -e "${YELLOW}Model format:${NC}"
    echo "  1) sklearn"
    echo "  2) xgboost"
    echo "  3) lightgbm"
    echo "  4) onnx"
    echo "  5) mlflow"
    read -rp "Select format [1]: " fmt_choice
    local model_format
    case "${fmt_choice:-1}" in
        1) model_format="sklearn" ;;
        2) model_format="xgboost" ;;
        3) model_format="lightgbm" ;;
        4) model_format="onnx" ;;
        5) model_format="mlflow" ;;
        *) model_format="sklearn" ;;
    esac

    echo ""
    read -rp "Model name (InferenceService name) [my-model]: " model_name
    model_name="${model_name:-my-model}"

    echo ""
    echo -e "${YELLOW}S3 path to model artifacts (e.g. s3://models/my-model/):${NC}"

    # List buckets/prefixes via a generic aws-cli pod against the target
    # namespace's data-connection secret (works with any S3 backend --
    # SeaweedFS, Ceph RGW, MinIO -- unlike execing into a storage pod's
    # filesystem, which only worked for MinIO's flat /data/<bucket> layout).
    local dc_secret=""
    for cand in aws-connection-my-storage aws-connection-minio; do
        if oc get secret "$cand" -n "$target_ns" &>/dev/null; then
            dc_secret="$cand"
            break
        fi
    done
    if [ -n "$dc_secret" ]; then
        local _ak _sk _ep
        _ak=$(oc get secret "$dc_secret" -n "$target_ns" -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' 2>/dev/null | base64 -d 2>/dev/null)
        _sk=$(oc get secret "$dc_secret" -n "$target_ns" -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' 2>/dev/null | base64 -d 2>/dev/null)
        _ep=$(oc get secret "$dc_secret" -n "$target_ns" -o jsonpath='{.data.AWS_S3_ENDPOINT}' 2>/dev/null | base64 -d 2>/dev/null)
        if [ -n "$_ep" ]; then
            echo -e "${CYAN}Available paths in S3:${NC}"
            oc run s3-list --rm -i --restart=Never -n "$target_ns" \
                --image=docker.io/amazon/aws-cli:latest \
                --env="AWS_ACCESS_KEY_ID=$_ak" --env="AWS_SECRET_ACCESS_KEY=$_sk" \
                --env="AWS_DEFAULT_REGION=us-east-1" \
                -- s3 ls --recursive --endpoint-url "$_ep" 2>/dev/null | awk '{print "  s3://" $NF}' || true
            echo ""
        fi
    fi

    read -rp "Storage URI: " storage_uri
    if [ -z "$storage_uri" ]; then
        print_error "Storage URI is required (e.g. s3://models/my-model/)"
        return 1
    fi

    echo ""
    echo -e "${YELLOW}Available data connections in $target_ns:${NC}"
    oc get secret -n "$target_ns" -l opendatahub.io/dashboard=true --no-headers 2>/dev/null | awk '{print "  " $1}' || true
    local default_dc="aws-connection-minio"
    if oc get secret aws-connection-minio -n "$target_ns" &>/dev/null; then
        echo ""
        echo -e "${CYAN}Default: $default_dc${NC}"
    fi
    read -rp "Data connection secret [$default_dc]: " data_conn
    data_conn="${data_conn:-$default_dc}"

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  Deployment Summary                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "  ${BLUE}Name:${NC}            $model_name"
    echo -e "  ${BLUE}Namespace:${NC}       $target_ns"
    echo -e "  ${BLUE}Format:${NC}          $model_format"
    echo -e "  ${BLUE}Storage URI:${NC}     $storage_uri"
    echo -e "  ${BLUE}Data Connection:${NC} $data_conn"
    echo ""
    read -rp "Deploy? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Cancelled"
        return 0
    fi

    deploy_predictive_model "$model_name" "$target_ns" "$storage_uri" \
        --format "$model_format" \
        --data-connection "$data_conn"
}
