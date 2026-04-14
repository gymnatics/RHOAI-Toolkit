#!/bin/bash
################################################################################
# Add / Manage Custom Serving Runtimes in RHOAI
#
# Supports:
#   - Apply runtimes directly to the cluster (oc apply)
#   - Generate YAML for import via the RHOAI Dashboard UI
#   - Export YAML files for version control or bulk import
#   - List currently installed runtimes
#
# Runtime Catalog:
#   vllm-community  - Community vLLM (vllm/vllm-openai)
#   vllm-omni       - vLLM-Omni multimodal (FLUX, SD3, audio)
#   vllm-redhat     - Red Hat vLLM (RHAIIS, registry.redhat.io)
#   custom          - Custom image and args
#
# Usage:
#   ./add-serving-runtime.sh                          # Interactive mode
#   ./add-serving-runtime.sh --preset omni            # Apply vLLM-Omni
#   ./add-serving-runtime.sh --preset omni --print    # Print YAML only
#   ./add-serving-runtime.sh --list                   # Show installed runtimes
#   ./add-serving-runtime.sh --export-all ./runtimes  # Export all catalog YAML
#
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$BASE_DIR/lib/manifests/templates"

# Source utilities
if [ -f "$BASE_DIR/lib/utils/colors.sh" ]; then
    source "$BASE_DIR/lib/utils/colors.sh"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BLUE='\033[0;34m'; NC='\033[0m'
    print_header()  { echo -e "\n${BLUE}═══ $1 ═══${NC}"; }
    print_step()    { echo -e "${YELLOW}▶ $1${NC}"; }
    print_success() { echo -e "${GREEN}✓ $1${NC}"; }
    print_error()   { echo -e "${RED}✗ $1${NC}"; }
    print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
    print_info()    { echo -e "${CYAN}ℹ $1${NC}"; }
fi

# ── Runtime Catalog (bash 3 compatible) ──────────────────────────────────────
# Each catalog entry is stored as pipe-delimited fields:
#   key|name|image|display|template|description|default_version|shm_size

CATALOG_ENTRIES=(
    "vllm-community|vllm-community|vllm/vllm-openai|vLLM Community|servingruntime-vllm-community.yaml.tmpl|Community vLLM for text LLMs (Qwen, Llama, Mistral, etc.)|v0.18.0|12Gi"
    "vllm-omni|vllm-omni|vllm/vllm-omni|vLLM-Omni (Multimodal)|servingruntime-vllm-omni.yaml.tmpl|Multimodal inference: image gen (FLUX, SD3), audio, video|v0.18.0|12Gi"
    "vllm-redhat|vllm-rhaiis|registry.redhat.io/rhaiis/vllm-cuda-rhel9|Red Hat vLLM (RHAIIS)|servingruntime-vllm-redhat.yaml.tmpl|Official Red Hat supported vLLM image|3.2.5|2Gi"
)

catalog_field() {
    local entry="$1" field_idx="$2"
    echo "$entry" | cut -d'|' -f"$field_idx"
}

catalog_get() {
    local target_key="$1" field_idx="$2"
    for entry in "${CATALOG_ENTRIES[@]}"; do
        local key
        key=$(catalog_field "$entry" 1)
        if [ "$key" = "$target_key" ]; then
            catalog_field "$entry" "$field_idx"
            return 0
        fi
    done
    return 1
}

# Field indices: 1=key, 2=name, 3=image, 4=display, 5=template, 6=description, 7=default_version, 8=shm_size

# ── Defaults ─────────────────────────────────────────────────────────────────

PRESET=""
ACTION=""                    # apply (default), print, export, list
VLLM_VERSION=""
RUNTIME_NAME=""
DISPLAY_NAME=""
SHM_SIZE=""
EXPORT_DIR=""
NAMESPACE="redhat-ods-applications"
CUSTOM_IMAGE=""

# ── Argument Parsing ─────────────────────────────────────────────────────────

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Modes:
  (default)           Apply the runtime to the cluster via oc apply
  --print             Print the YAML to stdout (for copy-paste into RHOAI UI)
  --export FILE       Export YAML to a file
  --export-all DIR    Export all catalog runtimes as YAML files to a directory
  --list              List installed ServingRuntimes on the cluster

Runtime Selection:
  --preset PRESET     Use a catalog preset:
                        vllm-community  Community vLLM (text LLMs)
                        vllm-omni       vLLM-Omni (multimodal: FLUX, SD3, audio)
                        vllm-redhat     Red Hat vLLM (RHAIIS, supported)
  --image IMAGE       Custom container image (e.g., vllm/vllm-openai:v0.20.0)

Configuration:
  --version VERSION   Image version tag (e.g., v0.18.0, latest, 3.2.5)
  --name NAME         Runtime name (k8s metadata.name)
  --display-name TXT  Display name in RHOAI dashboard
  --shm-size SIZE     Shared memory size (default varies by runtime)
  --namespace NS      Target namespace (default: redhat-ods-applications)

Examples:
  $0                                              # Interactive mode
  $0 --preset vllm-omni                           # Apply vLLM-Omni directly
  $0 --preset vllm-omni --print                   # Print YAML for RHOAI UI import
  $0 --preset vllm-community --version latest     # Community vLLM latest
  $0 --export-all ./runtime-yamls                 # Export all catalog YAMLs
  $0 --list                                       # Show installed runtimes
  $0 --image myregistry/my-vllm:1.0 --name my-runtime --print
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --preset)       PRESET="$2"; shift 2 ;;
        --version)      VLLM_VERSION="$2"; shift 2 ;;
        --name)         RUNTIME_NAME="$2"; shift 2 ;;
        --display-name) DISPLAY_NAME="$2"; shift 2 ;;
        --shm-size)     SHM_SIZE="$2"; shift 2 ;;
        --namespace)    NAMESPACE="$2"; shift 2 ;;
        --image)        CUSTOM_IMAGE="$2"; shift 2 ;;
        --print)        ACTION="print"; shift ;;
        --export)       ACTION="export"; EXPORT_DIR="$2"; shift 2 ;;
        --export-all)   ACTION="export-all"; EXPORT_DIR="$2"; shift 2 ;;
        --list)         ACTION="list"; shift ;;
        -h|--help)      show_help ;;
        *)              print_error "Unknown option: $1"; echo "Run $0 --help for usage."; exit 1 ;;
    esac
done

# ── Utility Functions ────────────────────────────────────────────────────────

check_oc_login() {
    if ! oc whoami &>/dev/null; then
        print_error "Not logged into OpenShift. Run 'oc login' first."
        exit 1
    fi
}

list_installed_runtimes() {
    check_oc_login
    echo ""
    print_header "Installed ServingRuntimes"
    echo ""

    local ns="$NAMESPACE"
    local count
    count=$(oc get servingruntime -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')

    if [ "$count" = "0" ] || [ -z "$count" ]; then
        print_warning "No ServingRuntimes found in $ns"
    else
        printf "  ${CYAN}%-30s %-45s %s${NC}\n" "NAME" "DISPLAY NAME" "DASHBOARD"
        printf "  %-30s %-45s %s\n" "----" "------------" "---------"

        local names
        names=$(oc get servingruntime -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
        while IFS= read -r name; do
            [ -z "$name" ] && continue
            local display dashboard_label
            display=$(oc get servingruntime "$name" -n "$ns" -o jsonpath='{.metadata.annotations.openshift\.io/display-name}' 2>/dev/null)
            if [ -z "$display" ]; then
                display=$(oc get servingruntime "$name" -n "$ns" -o jsonpath='{.metadata.annotations.opendatahub\.io/template-display-name}' 2>/dev/null)
            fi
            display="${display:--}"
            dashboard_label=$(oc get servingruntime "$name" -n "$ns" -o jsonpath='{.metadata.labels.opendatahub\.io/dashboard}' 2>/dev/null)
            if [ "$dashboard_label" = "true" ]; then
                dashboard_label="${GREEN}✓ visible${NC}"
            else
                dashboard_label="${YELLOW}hidden${NC}"
            fi
            printf "  %-30s %-45s " "$name" "$display"
            echo -e "$dashboard_label"
        done <<< "$names"
    fi

    echo ""
    print_info "Dashboard-visible runtimes have label: opendatahub.io/dashboard=true"
    print_info "Import via Dashboard: Settings → Serving runtimes → Add serving runtime"
    echo ""
}

resolve_runtime_config() {
    local catalog_key="$1"

    if [ -n "$catalog_key" ] && [ "$catalog_key" != "custom" ]; then
        RUNTIME_NAME="${RUNTIME_NAME:-$(catalog_get "$catalog_key" 2)}"
        DISPLAY_NAME="${DISPLAY_NAME:-$(catalog_get "$catalog_key" 4)}"
        SHM_SIZE="${SHM_SIZE:-$(catalog_get "$catalog_key" 8)}"
        local default_ver
        default_ver=$(catalog_get "$catalog_key" 7)
        VLLM_VERSION="${VLLM_VERSION:-$default_ver}"

        # Append version to default display name
        local base_display
        base_display=$(catalog_get "$catalog_key" 4)
        if [ "$DISPLAY_NAME" = "$base_display" ]; then
            DISPLAY_NAME="${DISPLAY_NAME} ${VLLM_VERSION}"
        fi
    fi

    RUNTIME_NAME="${RUNTIME_NAME:-custom-runtime}"
    DISPLAY_NAME="${DISPLAY_NAME:-Custom ServingRuntime}"
    SHM_SIZE="${SHM_SIZE:-12Gi}"
    VLLM_VERSION="${VLLM_VERSION:-latest}"
}

generate_yaml() {
    local catalog_key="$1"
    local tmpl_file=""

    if [ -n "$catalog_key" ] && [ "$catalog_key" != "custom" ]; then
        local tmpl_name
        tmpl_name=$(catalog_get "$catalog_key" 5)
        tmpl_file="$TEMPLATES_DIR/$tmpl_name"
    fi

    if [ -n "$tmpl_file" ] && [ -f "$tmpl_file" ]; then
        NAME="$RUNTIME_NAME" \
        VERSION="$VLLM_VERSION" \
        DISPLAY="$DISPLAY_NAME" \
        SHM_SIZE="$SHM_SIZE" \
        envsubst '${NAME} ${VERSION} ${DISPLAY} ${SHM_SIZE}' < "$tmpl_file" | grep -v '^#'
    elif [ -n "$CUSTOM_IMAGE" ]; then
        generate_custom_yaml
    else
        print_error "No template found for '$catalog_key' and no --image specified"
        return 1
    fi
}

generate_custom_yaml() {
    cat <<EOF
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: ${RUNTIME_NAME}
  annotations:
    opendatahub.io/apiProtocol: REST
    opendatahub.io/recommended-accelerators: '["nvidia.com/gpu"]'
    opendatahub.io/template-display-name: "${DISPLAY_NAME}"
    openshift.io/display-name: "${DISPLAY_NAME}"
  labels:
    opendatahub.io/dashboard: "true"
spec:
  annotations:
    prometheus.io/path: /metrics
    prometheus.io/port: "8080"
  containers:
    - name: kserve-container
      image: ${CUSTOM_IMAGE}
      args:
        - --model
        - /mnt/models
        - --port
        - "8080"
      env:
        - name: HF_HOME
          value: /tmp/hf_home
      ports:
        - containerPort: 8080
          protocol: TCP
      volumeMounts:
        - name: shm
          mountPath: /dev/shm
  multiModel: false
  supportedModelFormats:
    - autoSelect: true
      name: vLLM
  volumes:
    - name: shm
      emptyDir:
        medium: Memory
        sizeLimit: ${SHM_SIZE}
EOF
}

# ── Actions ──────────────────────────────────────────────────────────────────

do_apply() {
    local catalog_key="$1"
    check_oc_login

    resolve_runtime_config "$catalog_key"

    echo ""
    print_step "Creating ServingRuntime: $RUNTIME_NAME"
    print_info "Display Name: $DISPLAY_NAME"
    print_info "Namespace:    $NAMESPACE"
    if [ -n "$CUSTOM_IMAGE" ]; then
        print_info "Image:        $CUSTOM_IMAGE"
    elif [ "$catalog_key" != "custom" ] && [ -n "$catalog_key" ]; then
        local img
        img=$(catalog_get "$catalog_key" 3)
        print_info "Image:        ${img}:$VLLM_VERSION"
    fi
    echo ""

    if oc get servingruntime "$RUNTIME_NAME" -n "$NAMESPACE" &>/dev/null; then
        print_warning "ServingRuntime '$RUNTIME_NAME' already exists in $NAMESPACE"
        read -p "Replace it? (y/N): " replace
        if [[ ! "$replace" =~ ^[Yy]$ ]]; then
            echo "Aborted."
            return 0
        fi
        oc delete servingruntime "$RUNTIME_NAME" -n "$NAMESPACE" --ignore-not-found
    fi

    local yaml
    yaml=$(generate_yaml "$catalog_key")
    echo "$yaml" | oc apply -n "$NAMESPACE" -f -

    echo ""
    print_success "ServingRuntime '$RUNTIME_NAME' created in $NAMESPACE!"
    echo ""
    print_info "It will now appear as '${DISPLAY_NAME}' in the RHOAI dashboard."
    print_info "Select it when deploying a model under 'Serving runtime'."
    echo ""
}

do_print() {
    local catalog_key="$1"
    resolve_runtime_config "$catalog_key"

    local yaml
    yaml=$(generate_yaml "$catalog_key")

    echo ""
    print_header "ServingRuntime YAML — $DISPLAY_NAME"
    echo ""
    echo -e "${CYAN}To import in the RHOAI Dashboard:${NC}"
    echo -e "${CYAN}  Dashboard → Settings → Serving runtimes → Add serving runtime${NC}"
    echo -e "${CYAN}  → Start from scratch → Paste the YAML below${NC}"
    echo ""
    echo "---"
    echo "$yaml"
    echo ""
    print_info "Tip: Save to a file with --export flag: $0 --preset ${catalog_key:-custom} --export runtime.yaml"
    echo ""
}

do_export() {
    local catalog_key="$1"
    local outfile="$EXPORT_DIR"

    resolve_runtime_config "$catalog_key"

    local yaml
    yaml=$(generate_yaml "$catalog_key")

    local outdir
    outdir=$(dirname "$outfile")
    [ -n "$outdir" ] && [ "$outdir" != "." ] && mkdir -p "$outdir"

    echo "$yaml" > "$outfile"
    echo ""
    print_success "Exported to: $outfile"
    print_info "Import in RHOAI Dashboard: Settings → Serving runtimes → Add serving runtime"
    echo ""
}

do_export_all() {
    local outdir="$EXPORT_DIR"
    mkdir -p "$outdir"

    echo ""
    print_header "Exporting all catalog runtimes"
    echo ""

    for entry in "${CATALOG_ENTRIES[@]}"; do
        local key rt_name
        key=$(catalog_field "$entry" 1)
        rt_name=$(catalog_field "$entry" 2)
        local display
        display=$(catalog_field "$entry" 4)

        # Reset per iteration
        RUNTIME_NAME="" DISPLAY_NAME="" SHM_SIZE="" VLLM_VERSION=""
        resolve_runtime_config "$key"

        local outfile="$outdir/servingruntime-${rt_name}.yaml"
        local yaml
        yaml=$(generate_yaml "$key")
        echo "$yaml" > "$outfile"
        print_success "  ${display} → $outfile"
    done

    echo ""
    print_info "Import any of these in the RHOAI Dashboard:"
    print_info "  Settings → Serving runtimes → Add serving runtime → Start from scratch"
    echo ""
}

# ── Interactive Mode ─────────────────────────────────────────────────────────

interactive_mode() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           Manage Serving Runtimes                              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "What would you like to do?"
    echo ""
    echo -e "  ${YELLOW}1)${NC} Add a serving runtime to the cluster  ${GREEN}(oc apply)${NC}"
    echo -e "  ${YELLOW}2)${NC} Generate YAML for RHOAI Dashboard UI  ${GREEN}(copy-paste)${NC}"
    echo -e "  ${YELLOW}3)${NC} Export all runtime YAMLs to files"
    echo -e "  ${YELLOW}4)${NC} List installed serving runtimes"
    echo ""
    read -p "Select an option [1-4]: " action_choice

    case $action_choice in
        1) ACTION="apply" ;;
        2) ACTION="print" ;;
        3) ACTION="export-all" ;;
        4) list_installed_runtimes; return ;;
        *) print_error "Invalid choice"; return 1 ;;
    esac

    if [ "$ACTION" = "export-all" ]; then
        read -p "Export directory [./runtime-yamls]: " EXPORT_DIR
        EXPORT_DIR="${EXPORT_DIR:-./runtime-yamls}"
        do_export_all
        return
    fi

    echo ""
    echo -e "${MAGENTA}Select a runtime:${NC}"
    echo ""

    local i=1
    for entry in "${CATALOG_ENTRIES[@]}"; do
        local key display desc image
        key=$(catalog_field "$entry" 1)
        display=$(catalog_field "$entry" 4)
        desc=$(catalog_field "$entry" 6)
        image=$(catalog_field "$entry" 3)

        local marker=""
        if [ "$key" = "vllm-omni" ]; then marker=" ${GREEN}[Multimodal]${NC}"; fi
        if [ "$key" = "vllm-redhat" ]; then marker=" ${GREEN}[Supported]${NC}"; fi
        echo -e "  ${YELLOW}${i})${NC} ${display}${marker}"
        echo -e "     ${desc}"
        echo -e "     Image: ${image}"
        echo ""
        i=$((i + 1))
    done
    echo -e "  ${YELLOW}${i})${NC} Custom image"
    echo "     Provide your own container image and settings"
    echo ""

    local max_catalog=${#CATALOG_ENTRIES[@]}
    read -p "Select a runtime [1-${i}]: " runtime_choice

    local selected_key=""
    if [ "$runtime_choice" -ge 1 ] 2>/dev/null && [ "$runtime_choice" -le "$max_catalog" ] 2>/dev/null; then
        local idx=$((runtime_choice - 1))
        selected_key=$(catalog_field "${CATALOG_ENTRIES[$idx]}" 1)
    elif [ "$runtime_choice" = "$i" ]; then
        selected_key="custom"
        read -p "Container image (e.g., vllm/vllm-openai:v0.20.0): " CUSTOM_IMAGE
        if [ -z "$CUSTOM_IMAGE" ]; then
            print_error "Image is required"
            return 1
        fi
        read -p "Runtime name [custom-runtime]: " RUNTIME_NAME
        RUNTIME_NAME="${RUNTIME_NAME:-custom-runtime}"
        read -p "Display name [Custom Runtime]: " DISPLAY_NAME
        DISPLAY_NAME="${DISPLAY_NAME:-Custom Runtime}"
    else
        print_error "Invalid choice"
        return 1
    fi

    # Ask for version override for catalog runtimes
    if [ "$selected_key" != "custom" ] && [ -n "$selected_key" ]; then
        local default_ver
        default_ver=$(catalog_get "$selected_key" 7)
        read -p "Version [$default_ver]: " user_ver
        if [ -n "$user_ver" ]; then
            VLLM_VERSION="$user_ver"
        fi
    fi

    if [ "$ACTION" = "apply" ]; then
        do_apply "$selected_key"
    elif [ "$ACTION" = "print" ]; then
        do_print "$selected_key"
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    case "$ACTION" in
        list)
            list_installed_runtimes
            return
            ;;
        export-all)
            do_export_all
            return
            ;;
    esac

    # Resolve preset to catalog key
    local catalog_key=""
    if [ -n "$PRESET" ]; then
        case "$PRESET" in
            vllm-community|community) catalog_key="vllm-community" ;;
            vllm-omni|omni)           catalog_key="vllm-omni" ;;
            vllm-redhat|redhat|rhaiis) catalog_key="vllm-redhat" ;;
            # Legacy preset aliases
            qwen3.5)
                catalog_key="vllm-community"
                VLLM_VERSION="${VLLM_VERSION:-v0.18.0}"
                RUNTIME_NAME="${RUNTIME_NAME:-vllm-community-v0.18}"
                DISPLAY_NAME="${DISPLAY_NAME:-vLLM Community v0.18 (Qwen3.5)}"
                ;;
            latest)
                catalog_key="vllm-community"
                VLLM_VERSION="${VLLM_VERSION:-latest}"
                RUNTIME_NAME="${RUNTIME_NAME:-vllm-community-latest}"
                DISPLAY_NAME="${DISPLAY_NAME:-vLLM Community (Latest)}"
                ;;
            *)
                print_error "Unknown preset: $PRESET"
                echo ""
                echo "Available presets:"
                for entry in "${CATALOG_ENTRIES[@]}"; do
                    local key desc
                    key=$(catalog_field "$entry" 1)
                    desc=$(catalog_field "$entry" 6)
                    echo "  $key  - $desc"
                done
                echo ""
                echo "Legacy aliases: qwen3.5, latest"
                exit 1
                ;;
        esac
    fi

    if [ -z "$catalog_key" ] && [ -n "$CUSTOM_IMAGE" ]; then
        catalog_key="custom"
    fi

    # Non-interactive with preset/image
    if [ -n "$catalog_key" ]; then
        case "$ACTION" in
            print)
                do_print "$catalog_key"
                ;;
            export)
                if [ -z "$EXPORT_DIR" ]; then
                    print_error "--export requires a file path"
                    exit 1
                fi
                do_export "$catalog_key"
                ;;
            *)
                do_apply "$catalog_key"
                ;;
        esac
        return
    fi

    # Interactive mode
    interactive_mode
}

main "$@"
