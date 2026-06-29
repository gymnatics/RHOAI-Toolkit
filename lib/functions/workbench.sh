#!/bin/bash
################################################################################
# workbench.sh — Create and manage RHOAI workbenches programmatically
################################################################################
# Provides:
#   create_workbench            — create Notebook CR + PVC if not exists
#   wait_for_workbench          — wait for workbench pod to be Running
#   clone_repo_in_workbench     — git clone into workbench via oc exec
#   check_repo_freshness        — warn if cloned repo is behind remote
#   ensure_workbench            — all-in-one: create + wait + clone + check
#
# Usage in deploy.sh:
#   source "$ROOT_DIR/lib/functions/workbench.sh"
#   ensure_workbench "$NAMESPACE" "my-workbench"
#   ensure_workbench "$NAMESPACE" "gpu-workbench" "pytorch:3.4" "2" "4" "12Gi" "12Gi" "1" "20Gi" "GPU Workbench"
################################################################################

_WB_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_WB_LIB_DIR/lib/utils/colors.sh" 2>/dev/null || true

DEFAULT_REPO_URL="https://github.com/gymnatics/RHOAI-Toolkit.git"
DEFAULT_REPO_DIR="RHOAI-Toolkit"
WORKBENCH_HOME="/opt/app-root/src"

# Create a workbench (Notebook CR + PVC) if it doesn't already exist.
# Args: $1=namespace $2=name $3=image $4=cpu_req $5=cpu_lim $6=mem_req $7=mem_lim
#       $8=gpu_count $9=pvc_size $10=display_name
create_workbench() {
    local ns="$1"
    local wb_name="$2"
    local image="${3:-s2i-generic-data-science-notebook:3.4}"
    local cpu_req="${4:-2}"
    local cpu_lim="${5:-2}"
    local mem_req="${6:-4Gi}"
    local mem_lim="${7:-4Gi}"
    local gpu_count="${8:-0}"
    local pvc_size="${9:-20Gi}"
    local display_name="${10:-$wb_name}"

    if oc get notebook "$wb_name" -n "$ns" &>/dev/null; then
        print_info "Workbench '$wb_name' already exists in $ns" 2>/dev/null || true
        return 0
    fi

    print_step "Creating workbench '$wb_name' in $ns..." 2>/dev/null || true

    # Look up hardware profile resourceVersion
    local hp_name="default-profile"
    local hp_rv=""
    local image_display="Jupyter | Data Science | CPU | Python 3.12"

    if [ "$gpu_count" -gt 0 ] 2>/dev/null; then
        hp_name="gpu-profile"
        image_display="Jupyter | PyTorch | GPU | Python 3.12"
    fi

    hp_rv=$(oc get hardwareprofile "$hp_name" -n redhat-ods-applications \
        -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null || echo "")

    # Ensure notebook-env ConfigMap exists (envFrom requires it)
    if ! oc get configmap notebook-env -n "$ns" &>/dev/null; then
        oc create configmap notebook-env --from-literal=NAMESPACE="$ns" \
            -n "$ns" --dry-run=client -o yaml | oc apply -f - &>/dev/null
    fi

    # Select template based on GPU
    local template_dir="$_WB_LIB_DIR/lib/manifests/workbench"
    local template="$template_dir/notebook-template.yaml"
    if [ "$gpu_count" -gt 0 ] 2>/dev/null; then
        template="$template_dir/notebook-gpu-template.yaml"
    fi

    if [ ! -f "$template" ]; then
        print_error "Workbench template not found: $template" 2>/dev/null || true
        return 1
    fi

    export NAMESPACE="$ns"
    export WORKBENCH_NAME="$wb_name"
    export WORKBENCH_IMAGE="$image"
    export CPU_REQUEST="$cpu_req"
    export CPU_LIMIT="$cpu_lim"
    export MEMORY_REQUEST="$mem_req"
    export MEMORY_LIMIT="$mem_lim"
    export GPU_COUNT="$gpu_count"
    export PVC_SIZE="$pvc_size"
    export DISPLAY_NAME="$display_name"
    export HARDWARE_PROFILE_NAME="$hp_name"
    export HARDWARE_PROFILE_RV="${hp_rv:-0}"
    export IMAGE_DISPLAY_NAME="$image_display"

    envsubst < "$template" | oc apply -f - 2>/dev/null

    local rc=$?
    unset WORKBENCH_NAME WORKBENCH_IMAGE CPU_REQUEST CPU_LIMIT \
          MEMORY_REQUEST MEMORY_LIMIT GPU_COUNT PVC_SIZE DISPLAY_NAME \
          HARDWARE_PROFILE_NAME HARDWARE_PROFILE_RV IMAGE_DISPLAY_NAME

    if [ $rc -eq 0 ]; then
        print_success "Workbench '$wb_name' created in $ns" 2>/dev/null || true
    else
        print_error "Failed to create workbench '$wb_name'" 2>/dev/null || true
        return 1
    fi
}

# Wait for a workbench pod to reach Running state.
# Args: $1=namespace $2=workbench_name $3=timeout_seconds(default 180)
# Returns: 0 if Running, 1 on timeout
wait_for_workbench() {
    local ns="$1"
    local wb_name="$2"
    local timeout="${3:-180}"

    if ! oc get notebook "$wb_name" -n "$ns" &>/dev/null; then
        return 1
    fi

    local pod_name="${wb_name}-0"
    local elapsed=0
    local interval=10

    print_step "Waiting for workbench pod $pod_name..." 2>/dev/null || true

    while [ $elapsed -lt $timeout ]; do
        local phase
        phase=$(oc get pod "$pod_name" -n "$ns" -o jsonpath='{.status.phase}' 2>/dev/null)
        if [ "$phase" = "Running" ]; then
            print_success "Workbench $wb_name is running" 2>/dev/null || true
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    print_warning "Timeout waiting for workbench $wb_name (${timeout}s)" 2>/dev/null || true
    return 1
}

# Clone a git repo into a workbench via oc exec. Skips if already cloned.
# Args: $1=namespace $2=workbench_name $3=repo_url(optional) $4=target_dir(optional)
clone_repo_in_workbench() {
    local ns="$1"
    local wb_name="$2"
    local repo_url="${3:-$DEFAULT_REPO_URL}"
    local target_dir="${4:-$DEFAULT_REPO_DIR}"
    local pod_name="${wb_name}-0"

    if ! oc get pod "$pod_name" -n "$ns" -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Running"; then
        print_warning "Workbench pod $pod_name is not running — skipping git clone" 2>/dev/null || true
        return 1
    fi

    local exists
    exists=$(oc exec "$pod_name" -c "$wb_name" -n "$ns" -- \
        bash -c "[ -d '${WORKBENCH_HOME}/${target_dir}/.git' ] && echo yes || echo no" 2>/dev/null)

    if [ "$exists" = "yes" ]; then
        print_info "Repo $target_dir already cloned in workbench $wb_name" 2>/dev/null || true
        return 0
    fi

    print_step "Cloning $repo_url into workbench $wb_name..." 2>/dev/null || true
    oc exec "$pod_name" -c "$wb_name" -n "$ns" -- \
        bash -c "cd '${WORKBENCH_HOME}' && git clone '${repo_url}' '${target_dir}'" 2>/dev/null

    if [ $? -eq 0 ]; then
        print_success "Repo cloned into $wb_name:${WORKBENCH_HOME}/${target_dir}" 2>/dev/null || true
    else
        print_warning "Git clone failed — clone manually in the workbench terminal" 2>/dev/null || true
        return 1
    fi
}

# Check if the cloned repo is behind the remote and print a warning.
# Args: $1=namespace $2=workbench_name $3=target_dir(optional)
check_repo_freshness() {
    local ns="$1"
    local wb_name="$2"
    local target_dir="${3:-$DEFAULT_REPO_DIR}"
    local pod_name="${wb_name}-0"

    if ! oc get pod "$pod_name" -n "$ns" -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Running"; then
        return 0
    fi

    local behind
    behind=$(oc exec "$pod_name" -c "$wb_name" -n "$ns" -- \
        bash -c "cd '${WORKBENCH_HOME}/${target_dir}' 2>/dev/null && \
                 git fetch --quiet 2>/dev/null && \
                 git rev-list --count HEAD..origin/main 2>/dev/null" 2>/dev/null || echo "0")

    if [ -n "$behind" ] && [ "$behind" -gt 0 ] 2>/dev/null; then
        print_warning "Repo in $wb_name is $behind commit(s) behind remote. Run 'git pull' in the workbench to update." 2>/dev/null || true
    fi
}

# All-in-one: create workbench (if missing) -> wait -> clone repo -> check freshness.
# Args: same as create_workbench
ensure_workbench() {
    local ns="$1"
    local wb_name="$2"
    local image="${3:-s2i-generic-data-science-notebook:3.4}"
    local cpu_req="${4:-2}"
    local cpu_lim="${5:-2}"
    local mem_req="${6:-4Gi}"
    local mem_lim="${7:-4Gi}"
    local gpu_count="${8:-0}"
    local pvc_size="${9:-20Gi}"
    local display_name="${10:-$wb_name}"

    [ -z "$ns" ] || [ -z "$wb_name" ] && {
        print_error "ensure_workbench requires namespace and workbench name" 2>/dev/null || true
        return 1
    }

    create_workbench "$ns" "$wb_name" "$image" "$cpu_req" "$cpu_lim" \
        "$mem_req" "$mem_lim" "$gpu_count" "$pvc_size" "$display_name"

    if ! wait_for_workbench "$ns" "$wb_name" 180; then
        print_warning "Workbench $wb_name not ready — git clone will be skipped" 2>/dev/null || true
        print_info "Once the workbench is running, clone the repo manually:" 2>/dev/null || true
        print_info "  git clone $DEFAULT_REPO_URL" 2>/dev/null || true
        return 0
    fi

    clone_repo_in_workbench "$ns" "$wb_name"
    check_repo_freshness "$ns" "$wb_name"
}
