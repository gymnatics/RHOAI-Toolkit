#!/bin/bash
################################################################################
# pipeline-server.sh — Data Science Pipelines Application (DSPA) setup
# Extracted from lib/functions/rhoai.sh during the Oct 2026 modularization
# (Priority 3 of the consolidated toolkit plan).
################################################################################

# Use a local variable to avoid overwriting caller's SCRIPT_DIR
_PIPELINE_SERVER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_PIPELINE_SERVER_LIB_DIR/lib/utils/colors.sh" 2>/dev/null || true
source "$_PIPELINE_SERVER_LIB_DIR/lib/utils/common.sh" 2>/dev/null || true
source "$_PIPELINE_SERVER_LIB_DIR/lib/functions/storage-backend.sh" 2>/dev/null || true

################################################################################
# Pipeline Server Setup
################################################################################

# Setup Data Science Pipelines Application (DSPA) with S3 storage.
# Per RHAIE 3.3 Guide Chapter 1: configuring a pipeline server requires S3 storage.
# Offers: reuse existing MinIO or deploy new one.
# Usage: setup_pipeline_server [namespace]
setup_pipeline_server() {
    local target_ns="${1:-}"
    
    print_header "Setup Pipeline Server"
    echo "  Per RHAIE 3.3 Guide: Data Science Pipelines with S3 storage"
    echo "  (Steps already completed will be skipped)"
    echo ""
    
    ############################################################################
    # Step 1: Check aipipelines is enabled in DSC
    ############################################################################
    print_step "Step 1: Checking aipipelines component in DSC..."
    
    local pipelines_state=$(oc get datasciencecluster default-dsc -o jsonpath='{.spec.components.aipipelines.managementState}' 2>/dev/null || echo "")
    
    if [ "$pipelines_state" = "Managed" ]; then
        print_success "aipipelines already Managed in DSC [SKIP]"
    else
        print_step "Enabling aipipelines in DataScienceCluster..."
        oc patch datasciencecluster default-dsc --type=merge -p '{
            "spec": {
                "components": {
                    "aipipelines": {
                        "managementState": "Managed"
                    }
                }
            }
        }'
        print_success "aipipelines enabled in DSC"
        sleep 10
    fi
    
    ############################################################################
    # Step 2: Select target namespace
    ############################################################################
    if [ -z "$target_ns" ]; then
        echo ""
        print_step "Step 2: Select project namespace for pipeline server"
        
        local current_project=$(oc project -q 2>/dev/null)
        echo "  Current project: $current_project"
        echo ""
        read -p "Deploy pipeline server in namespace [$current_project]: " target_ns
        target_ns="${target_ns:-$current_project}"
    fi
    
    if ! oc get namespace "$target_ns" &>/dev/null; then
        print_warning "Namespace '$target_ns' does not exist"
        read -p "Create it? (Y/n): " create_ns
        if [[ ! "$create_ns" =~ ^[Nn]$ ]]; then
            oc new-project "$target_ns" 2>/dev/null || oc create namespace "$target_ns"
            oc label namespace "$target_ns" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true
            print_success "Namespace '$target_ns' created"
        else
            return 1
        fi
    fi
    
    # Ensure dashboard label
    oc label namespace "$target_ns" opendatahub.io/dashboard=true --overwrite 2>/dev/null || true
    
    ############################################################################
    # Step 3: Check if DSPA already exists
    ############################################################################
    print_step "Step 3: Checking for existing pipeline server..."
    
    if oc get dspa -n "$target_ns" -o name &>/dev/null 2>&1; then
        local existing_dspa=$(oc get dspa -n "$target_ns" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ -n "$existing_dspa" ]; then
            local dspa_ready=$(oc get dspa "$existing_dspa" -n "$target_ns" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
            if [ "$dspa_ready" = "True" ]; then
                print_success "Pipeline server '$existing_dspa' already running [SKIP]"
                _show_pipeline_server_summary "$target_ns" "$existing_dspa"
                return 0
            else
                print_warning "DSPA '$existing_dspa' exists but not ready"
                print_info "Checking status..."
                oc get dspa "$existing_dspa" -n "$target_ns" -o jsonpath='{.status.conditions}' 2>/dev/null | python3 -m json.tool 2>/dev/null | head -20
                echo ""
                read -p "Delete and recreate? (y/N): " recreate
                if [[ "$recreate" =~ ^[Yy]$ ]]; then
                    oc delete dspa "$existing_dspa" -n "$target_ns"
                    sleep 5
                else
                    return 0
                fi
            fi
        fi
    fi
    
    ############################################################################
    # Step 4: S3 Storage Configuration
    ############################################################################
    echo ""
    print_step "Step 4: S3 Storage for Pipeline Artifacts"
    echo ""
    echo -e "${BLUE}Pipeline server requires S3-compatible storage for artifacts.${NC}"
    echo ""
    
    # Detect existing S3-compatible storage deployments (SeaweedFS -- the
    # toolkit default since the MinIO->SeaweedFS migration -- or legacy
    # MinIO). Build arrays for a numbered picker below, so users select an
    # entry instead of free-typing a namespace/name pair.
    local minio_deployments=$(oc get deployment -A --no-headers 2>/dev/null | awk 'tolower($2) ~ /minio|seaweedfs/ {print $1 "\t" $2}')
    local -a detect_ns=() detect_dep=() detect_svc=() detect_port=()

    if [ -n "$minio_deployments" ]; then
        echo -e "${CYAN}Existing S3 storage deployments found:${NC}"
        while IFS=$'\t' read -r ns name; do
            [ -z "$ns" ] && continue
            local minio_svc=$(oc get svc -n "$ns" --no-headers 2>/dev/null | grep -iE "minio|seaweedfs" | grep -v console | awk '{print $1}' | head -1)
            minio_svc="${minio_svc:-minio}"
            local minio_port=$(oc get svc "$minio_svc" -n "$ns" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
            minio_port="${minio_port:-9000}"
            echo "  $((${#detect_ns[@]} + 1))) $ns / $name  (service: $minio_svc, port: $minio_port)"
            detect_ns+=("$ns")
            detect_dep+=("$name")
            detect_svc+=("$minio_svc")
            detect_port+=("$minio_port")
        done <<< "$minio_deployments"
        echo ""
    fi
    
    echo -e "${YELLOW}Storage options:${NC}"
    echo "  1) SeaweedFS / external S3 (recommended -- toolkit default; auto-deployed in"
    echo "     '$target_ns' via storage-backend.sh if not already present)"
    echo "  2) Built-in MinIO + MariaDB (operator-managed; legacy quay.io/opendatahub/minio"
    echo "     2019 image -- 41 known CVEs in base OS libs, single frozen tag, no updates"
    echo "     since 2022. See docs/guides/S3-BACKEND-MIGRATION.md)"
    echo "  3) Use a different existing external S3 (manual entry)"
    echo "  4) Deploy standalone MinIO in this namespace (deprecated)"
    echo ""
    read -p "Select option [1]: " storage_choice
    storage_choice="${storage_choice:-1}"
    
    local s3_endpoint=""
    local s3_bucket="mlpipeline"
    local s3_access_key=""
    local s3_secret_key=""
    local s3_scheme="http"
    local s3_host=""
    local s3_port="9000"
    local credentials_secret_name="pipelines-s3-credentials"
    local use_builtin_storage=false
    local dspa_name="pipelines-definition"
    
    if [ "$storage_choice" = "2" ]; then
        # Built-in MinIO + MariaDB managed by the DSPA operator
        use_builtin_storage=true
        echo ""
        print_info "DSPA operator will deploy MinIO and MariaDB automatically"
        print_warning "This uses the legacy quay.io/opendatahub/minio 2019 image (41 known CVEs)"
        print_info "Recommended only for quick dev/testing where SeaweedFS isn't warranted"
        echo ""
        
        read -p "  MinIO PVC size [10Gi]: " minio_pvc_size
        minio_pvc_size="${minio_pvc_size:-10Gi}"
        
        read -p "  MariaDB PVC size [10Gi]: " mariadb_pvc_size
        mariadb_pvc_size="${mariadb_pvc_size:-10Gi}"
        
    elif [ "$storage_choice" = "3" ]; then
        # Reuse existing external S3 -- pick from the detected list above rather
        # than free-typing a host, which invites pasting the "ns / name" display
        # format verbatim as the hostname (an easy, hard-to-notice mistake: it
        # silently produces an invalid host and empty credentials instead of an
        # error, and the DSPA just sits at Ready=False with no clear reason).
        echo ""
        local minio_ns="" minio_svc=""

        if [ "${#detect_ns[@]}" -gt 0 ]; then
            echo -e "${CYAN}Select which S3 storage to use:${NC}"
            local i=1
            while [ "$i" -le "${#detect_ns[@]}" ]; do
                echo "  $i) ${detect_ns[$((i-1))]} / ${detect_dep[$((i-1))]}"
                i=$((i+1))
            done
            echo "  m) Enter connection details manually"
            echo ""
            read -p "Select [1]: " s3_choice
            s3_choice="${s3_choice:-1}"
        else
            s3_choice="m"
        fi

        if [[ "$s3_choice" =~ ^[0-9]+$ ]] && [ "$s3_choice" -ge 1 ] && [ "$s3_choice" -le "${#detect_ns[@]}" ]; then
            minio_ns="${detect_ns[$((s3_choice-1))]}"
            minio_svc="${detect_svc[$((s3_choice-1))]}"
            s3_port="${detect_port[$((s3_choice-1))]}"
            s3_host="${minio_svc}.${minio_ns}.svc.cluster.local"
            print_success "Using $s3_host:$s3_port"
        else
            echo ""
            print_info "Hostname only -- no namespace, no slashes. Example: minio-service.minio.svc.cluster.local"
            read -p "  S3 host: " s3_host
            read -p "  S3 port [$s3_port]: " input_port
            s3_port="${input_port:-$s3_port}"
            read -p "  S3 scheme (http/https) [$s3_scheme]: " input_scheme
            s3_scheme="${input_scheme:-$s3_scheme}"
        fi

        read -p "  Pipeline bucket name [$s3_bucket]: " input_bucket
        s3_bucket="${input_bucket:-$s3_bucket}"

        # Auto-detect credentials from a secret in the same namespace. Checks
        # several common key-naming conventions (AWS_*, lowercase accesskey/
        # secretkey, and MinIO's own minio_root_user/minio_root_password).
        if [ -n "$minio_ns" ]; then
            local detected_secret=$(oc get secret -n "$minio_ns" --no-headers 2>/dev/null | grep -E "minio|aws-connection" | awk '{print $1}' | head -1)
            if [ -n "$detected_secret" ]; then
                for key_pair in "AWS_ACCESS_KEY_ID:AWS_SECRET_ACCESS_KEY" "accesskey:secretkey" "minio_root_user:minio_root_password"; do
                    local ak_field="${key_pair%%:*}" sk_field="${key_pair##*:}"
                    s3_access_key=$(oc get secret "$detected_secret" -n "$minio_ns" -o jsonpath="{.data.${ak_field}}" 2>/dev/null | base64 -d 2>/dev/null)
                    s3_secret_key=$(oc get secret "$detected_secret" -n "$minio_ns" -o jsonpath="{.data.${sk_field}}" 2>/dev/null | base64 -d 2>/dev/null)
                    [ -n "$s3_access_key" ] && [ -n "$s3_secret_key" ] && break
                done
                if [ -n "$s3_access_key" ] && [ -n "$s3_secret_key" ]; then
                    print_success "Auto-detected credentials from secret '$detected_secret' in $minio_ns"
                fi
            fi
        fi

        if [ -z "$s3_access_key" ] || [ -z "$s3_secret_key" ]; then
            echo ""
            print_warning "Could not auto-detect credentials"
            read -p "  S3 access key: " s3_access_key
            read -p "  S3 secret key: " s3_secret_key
        fi

        # Best-effort: ensure the bucket exists so the DSPA doesn't fail later.
        # Uses a generic aws-cli Job via storage-backend.sh when available;
        # falls back to exec'ing into a MinIO/SeaweedFS pod for legacy compat.
        if [ -n "$minio_ns" ]; then
            local s3_ep="${s3_scheme}://${s3_host}:${s3_port}"
            local _bucket_ok=false

            # Try generic aws-cli Job approach first (works with any S3 backend)
            if type create_storage_bucket &>/dev/null; then
                export S3_ACCESS_KEY="$s3_access_key"
                export S3_SECRET_KEY="$s3_secret_key"
                export S3_ENDPOINT="$s3_ep"
                export S3_BACKEND="${S3_BACKEND:-minio}"
                if create_storage_bucket "$minio_ns" "$s3_bucket" 2>/dev/null; then
                    _bucket_ok=true
                fi
            fi

            # Fallback: exec mc inside a MinIO pod (deprecated, MinIO-only)
            if [ "$_bucket_ok" = false ]; then
                local minio_pod=$(oc get pod -n "$minio_ns" -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                [ -z "$minio_pod" ] && minio_pod=$(oc get pod -n "$minio_ns" --no-headers 2>/dev/null | grep -iE "minio|seaweedfs" | awk '{print $1}' | head -1)
                if [ -n "$minio_pod" ]; then
                    if oc exec "$minio_pod" -n "$minio_ns" -- sh -c "mc alias set local ${s3_ep} '${s3_access_key}' '${s3_secret_key}' >/dev/null 2>&1 && mc mb --ignore-existing local/${s3_bucket} >/dev/null 2>&1" 2>/dev/null; then
                        _bucket_ok=true
                    fi
                fi
            fi

            if [ "$_bucket_ok" = true ]; then
                print_success "Bucket '$s3_bucket' ready"
            else
                print_warning "Could not confirm/create bucket '$s3_bucket' automatically"
                print_info "Create it manually if the pipeline server fails to start: aws --endpoint-url ${s3_ep} s3 mb s3://$s3_bucket"
            fi
        fi

        print_success "Using external S3: $s3_host:$s3_port (bucket: $s3_bucket)"

    elif [ "$storage_choice" = "4" ]; then
        # Deploy standalone MinIO
        echo ""
        print_step "Deploying standalone MinIO in '$target_ns'..."
        
        s3_host="minio.${target_ns}.svc.cluster.local"
        s3_access_key="minio"
        s3_secret_key=$(head -c 16 /dev/urandom 2>/dev/null | base64 | tr -dc 'a-zA-Z0-9' | head -c 16 || echo "minio$(date +%s | tail -c 8)")
        
        read -p "  MinIO password (leave empty for auto-generated): " user_secret
        if [ -n "$user_secret" ]; then
            s3_secret_key="$user_secret"
        fi
        
        read -p "  Storage size [50Gi]: " storage_size
        storage_size="${storage_size:-50Gi}"
        
        export STORAGE_SIZE="$storage_size"
        export S3_ACCESS_KEY="$s3_access_key"
        export S3_SECRET_KEY="$s3_secret_key"
        envsubst '${STORAGE_SIZE} ${S3_ACCESS_KEY} ${S3_SECRET_KEY}' \
            < "$_PIPELINE_SERVER_LIB_DIR/lib/manifests/pipeline/minio-pipelines.yaml" | oc apply -f - -n "$target_ns"
        unset STORAGE_SIZE S3_ACCESS_KEY S3_SECRET_KEY
        
        # Wait for MinIO
        print_step "Waiting for MinIO to be ready..."
        local elapsed=0
        while [ $elapsed -lt 90 ]; do
            if oc get pods -n "$target_ns" -l app=minio -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
                print_success "MinIO is ready"
                break
            fi
            sleep 5
            elapsed=$((elapsed + 5))
        done
        
        print_info "MinIO credentials: $s3_access_key / $s3_secret_key"

    else
        # Default (storage_choice = 1, or unrecognized input): SeaweedFS /
        # whatever S3_BACKEND is configured, auto-deployed in this namespace
        # via storage-backend.sh if not already present. This matches the
        # toolkit's default S3 backend (lib/functions/storage-backend.sh) and
        # is the path verified end-to-end against a live DSPA + SeaweedFS
        # (ObjectStoreAvailable=True, pipeline run succeeded, artifact
        # round-tripped through S3) during the DSPA MinIO investigation --
        # see docs/guides/S3-BACKEND-MIGRATION.md.
        echo ""
        if type detect_or_select_storage_backend &>/dev/null && type deploy_storage_backend &>/dev/null; then
            detect_or_select_storage_backend "$target_ns"
            print_step "Setting up S3 storage (${S3_BACKEND}) in '$target_ns'..."
            deploy_storage_backend "$target_ns"
            wait_for_storage "$target_ns"
            create_storage_bucket "$target_ns" "$s3_bucket"

            s3_access_key="${S3_ACCESS_KEY:-admin}"
            s3_secret_key="${S3_SECRET_KEY:-admin123}"
            local _ep _hostport
            _ep="$(get_storage_endpoint "$target_ns")"
            s3_scheme="${_ep%%://*}"
            _hostport="${_ep#*://}"
            s3_host="${_hostport%%:*}"
            s3_port="${_hostport##*:}"
            print_success "Using ${S3_BACKEND} at $s3_host:$s3_port (bucket: $s3_bucket)"
        else
            print_warning "storage-backend.sh not available -- falling back to built-in MinIO"
            use_builtin_storage=true
            minio_pvc_size="10Gi"
            mariadb_pvc_size="10Gi"
        fi
    fi
    
    ############################################################################
    # Step 5: Create DSPA
    ############################################################################
    if [ "$use_builtin_storage" = true ]; then
        # Built-in approach: DSPA operator manages MinIO + MariaDB
        print_step "Step 5: Creating DataSciencePipelinesApplication (built-in storage)..."
        
        export DSPA_NAME="$dspa_name"
        export MARIADB_PVC_SIZE="$mariadb_pvc_size"
        export MINIO_PVC_SIZE="$minio_pvc_size"
        envsubst '${DSPA_NAME} ${MARIADB_PVC_SIZE} ${MINIO_PVC_SIZE}' \
            < "$_PIPELINE_SERVER_LIB_DIR/lib/manifests/pipeline/dspa-builtin.yaml" | oc apply -f - -n "$target_ns"
        unset DSPA_NAME MARIADB_PVC_SIZE MINIO_PVC_SIZE
    else
        # External storage approach: create credentials secret first
        print_step "Step 5: Creating S3 credentials secret..."
        
        if oc get secret "$credentials_secret_name" -n "$target_ns" &>/dev/null; then
            print_success "Credentials secret already exists [SKIP]"
        else
            export CREDENTIALS_SECRET_NAME="$credentials_secret_name"
            export S3_ACCESS_KEY="$s3_access_key"
            export S3_SECRET_KEY="$s3_secret_key"
            envsubst '${CREDENTIALS_SECRET_NAME} ${S3_ACCESS_KEY} ${S3_SECRET_KEY}' \
                < "$_PIPELINE_SERVER_LIB_DIR/lib/manifests/pipeline/dspa-credentials-secret.yaml" | oc apply -f - -n "$target_ns"
            unset CREDENTIALS_SECRET_NAME S3_ACCESS_KEY S3_SECRET_KEY
            print_success "Credentials secret created"
        fi
        
        print_step "Step 6: Creating DataSciencePipelinesApplication..."
        
        export DSPA_NAME="$dspa_name"
        export S3_HOST="$s3_host"
        export S3_PORT="$s3_port"
        export S3_BUCKET="$s3_bucket"
        export S3_SCHEME="$s3_scheme"
        export CREDENTIALS_SECRET_NAME="$credentials_secret_name"
        envsubst '${DSPA_NAME} ${S3_HOST} ${S3_PORT} ${S3_BUCKET} ${S3_SCHEME} ${CREDENTIALS_SECRET_NAME}' \
            < "$_PIPELINE_SERVER_LIB_DIR/lib/manifests/pipeline/dspa-external.yaml" | oc apply -f - -n "$target_ns"
        unset DSPA_NAME S3_HOST S3_PORT S3_BUCKET S3_SCHEME CREDENTIALS_SECRET_NAME
    fi
    
    ############################################################################
    # Wait for pipeline server to be ready
    ############################################################################
    print_step "Waiting for pipeline server to be ready..."
    local elapsed=0
    while [ $elapsed -lt 180 ]; do
        local ready=$(oc get dspa "$dspa_name" -n "$target_ns" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$ready" = "True" ]; then
            print_success "Pipeline server is ready!"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        if [ $((elapsed % 15)) -eq 0 ]; then
            local reason=$(oc get dspa "$dspa_name" -n "$target_ns" -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)
            echo "  Waiting... status: ${reason:-pending} (${elapsed}s elapsed)"
        fi
    done
    
    if [ $elapsed -ge 180 ]; then
        print_warning "Pipeline server may not be fully ready yet"
        print_info "Check: oc get dspa $dspa_name -n $target_ns -o yaml"
    fi
    
    _show_pipeline_server_summary "$target_ns" "$dspa_name"
}

# Internal helper: display pipeline server summary
_show_pipeline_server_summary() {
    local target_ns="$1"
    local dspa_name="${2:-pipelines-definition}"
    
    echo ""
    print_header "Pipeline Server Summary"
    echo ""
    echo -e "${BLUE}Namespace:${NC}     $target_ns"
    echo -e "${BLUE}DSPA Name:${NC}     $dspa_name"
    echo ""
    
    # Get route
    local pipeline_route=$(oc get route "ds-pipeline-${dspa_name}" -n "$target_ns" -o jsonpath='{.spec.host}' 2>/dev/null)
    if [ -n "$pipeline_route" ]; then
        echo -e "${BLUE}Pipeline API:${NC}  https://$pipeline_route"
    else
        echo -e "${BLUE}Pipeline API:${NC}  (route not yet available, check: oc get route -n $target_ns)"
    fi
    echo ""
    
    # Pods
    echo -e "${CYAN}Pods:${NC}"
    oc get pods -n "$target_ns" --no-headers 2>/dev/null | grep -E "ds-pipeline|mariadb|minio" | sed 's/^/  /'
    echo ""
    
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Next Steps:${NC}"
    echo ""
    echo "  1. Import a pipeline via Dashboard:"
    echo "     Projects → $target_ns → Pipelines → Import pipeline"
    echo ""
    echo "  2. Import via Python SDK:"
    echo "     from kfp import Client"
    echo "     token = !oc whoami -t"
    if [ -n "$pipeline_route" ]; then
        echo "     client = Client(host='https://$pipeline_route', existing_token=token[0], ssl_ca_cert=False)"
    else
        echo "     client = Client(host='https://ds-pipeline-${dspa_name}-${target_ns}.apps.<cluster>', existing_token=token[0])"
    fi
    echo "     client.list_pipelines()"
    echo ""
    echo "  3. Compile + upload a pipeline:"
    echo "     from kfp import compiler, dsl"
    echo "     compiler.Compiler().compile(my_pipeline, 'pipeline.yaml')"
    echo "     client.upload_pipeline('pipeline.yaml', pipeline_name='my-pipeline')"
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

