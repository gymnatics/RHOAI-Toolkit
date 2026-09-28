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
#   clone_if_missing            — standalone: clone ONLY if pod is currently
#                                 Running right now, no create/wait involved.
#                                 Use this at the END of deploy.sh (after all
#                                 other infra steps), so a GPU workbench that
#                                 was still Pending when ensure_workbench ran
#                                 gets a second, later chance to be cloned
#                                 into without needing a full re-run.
#
# Usage in deploy.sh:
#   source "$ROOT_DIR/lib/functions/workbench.sh"
#   ensure_workbench "$NAMESPACE" "my-workbench"
#   ensure_workbench "$NAMESPACE" "gpu-workbench" "pytorch:3.4" "2" "4" "12Gi" "12Gi" "1" "20Gi" "GPU Workbench"
#   # ... rest of deploy.sh (models, pipeline server, etc.) ...
#   clone_if_missing "$NAMESPACE" "gpu-workbench"   # retry near the end
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
#
# NOTE on timeout sizing: 180s is fine for CPU workbenches, but GPU workbenches
# on clusters that provision GPU nodes on-demand (e.g. MachineSet scale-up)
# routinely take 10-15 minutes (EC2 launch + node join + GPU driver install)
# --  ensure_workbench() below auto-selects 600s when gpu_count>0. Pass an
# explicit $3 to override either default.
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

# Clone into a workbench ONLY if its pod is Running right now -- no create,
# no wait/timeout. Intended to be called a second time, later in a deploy.sh
# (after all other infra steps), as a low-cost retry for workbenches (usually
# GPU ones) that were still Pending when ensure_workbench's fixed-timeout
# wait_for_workbench call ran earlier in the same script. Safe to call even
# if the workbench doesn't exist yet or is already cloned (no-ops cleanly).
# Args: $1=namespace $2=workbench_name $3=repo_url(optional) $4=target_dir(optional)
# Returns: 0 if cloned or already-cloned, 1 if pod isn't Running (not an error)
clone_if_missing() {
    local ns="$1"
    local wb_name="$2"
    local repo_url="${3:-$DEFAULT_REPO_URL}"
    local target_dir="${4:-$DEFAULT_REPO_DIR}"
    local pod_name="${wb_name}-0"

    local phase
    phase=$(oc get pod "$pod_name" -n "$ns" -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ "$phase" != "Running" ]; then
        print_info "Workbench $wb_name not Running yet (phase=${phase:-NotFound}) -- skipping clone retry. Re-run this script's deploy, or once it's up run: oc exec ${pod_name} -c ${wb_name} -n ${ns} -- git clone ${repo_url} ${WORKBENCH_HOME}/${target_dir}" 2>/dev/null || true
        return 1
    fi

    clone_repo_in_workbench "$ns" "$wb_name" "$repo_url" "$target_dir"
    check_repo_freshness "$ns" "$wb_name" "$target_dir"
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

    # GPU workbenches routinely need 10-15 min for the node itself to be
    # available (MachineSet scale-up -> EC2 launch -> node join -> GPU driver
    # install) before the pod can even be scheduled -- 180s is only realistic
    # for CPU workbenches landing on already-Ready nodes.
    local wait_timeout=180
    if [ "$gpu_count" -gt 0 ] 2>/dev/null; then
        wait_timeout=600
    fi

    if ! wait_for_workbench "$ns" "$wb_name" "$wait_timeout"; then
        print_warning "Workbench $wb_name not ready after ${wait_timeout}s — git clone will be skipped for now" 2>/dev/null || true
        print_info "This is expected if a GPU node is still provisioning. Once the workbench is Running, either:" 2>/dev/null || true
        print_info "  - Re-run this deploy.sh (clone_if_missing retries near the end), or" 2>/dev/null || true
        print_info "  - Run: ./scripts/clone-toolkit-in-workbenches.sh -n $ns" 2>/dev/null || true
        print_info "  - Or manually: git clone $DEFAULT_REPO_URL" 2>/dev/null || true
        return 0
    fi

    clone_repo_in_workbench "$ns" "$wb_name"
    check_repo_freshness "$ns" "$wb_name"
}
