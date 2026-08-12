#!/bin/bash
################################################################################
# install-rhoai.sh — Unified RHOAI 3.x Installer
#
# Single entry point for all RHOAI 3.x installations. Loads a version profile
# (lib/versions/rhoai-{34,33}.conf) to configure version-specific behavior,
# then runs the same ordered phases regardless of version.
#
# Usage:
#   ./install-rhoai.sh --channel stable-3.4
#   ./install-rhoai.sh --channel stable-3.3 --skip-prerequisites
#   ./install-rhoai.sh                        # interactive channel selection
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'
}

################################################################################
# Default Options (superset of all version-specific flags)
################################################################################

SKIP_PREREQUISITES=false
SKIP_RHCL=false
SKIP_MAAS=false
SKIP_NODE_SCALING=false
SKIP_MAAS_DB=false
SKIP_ADMIN_USER=false
ENABLE_LLMD=true
ENABLE_VLLM_MAAS=false
ENABLE_OBSERVABILITY=false
DEPLOY_GRAFANA=false
POSTGRES_CONNECTION=""
CLUSTER_DOMAIN=""
WAIT_TIMEOUT=600
RHOAI_CHANNEL=""
CREATE_ADMIN_USER=""
SETUP_PIPELINES=false
PIPELINE_NAMESPACE=""
SETUP_USERS=false
NUM_USERS=5
ADMIN_GROUP="rhods-admins"
USER_GROUP="rhods-users"
USER_PASSWORD="openshift"

################################################################################
# Usage
################################################################################

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Unified RHOAI 3.x installer. Detects the target version from the"
    echo "selected channel and loads the appropriate version profile."
    echo ""
    echo "Core Options:"
    echo "  --channel <channel>       RHOAI channel (e.g., stable-3.4, stable-3.3, fast-3.x)"
    echo "  --domain <domain>         Cluster domain (auto-detected if omitted)"
    echo "  --timeout <seconds>       Operator wait timeout (default: 600)"
    echo "  --skip-prerequisites      Skip NFD, GPU, Kueue, cert-manager operators"
    echo "  --skip-rhcl               Skip RHCL/Kuadrant (no MaaS/llm-d auth)"
    echo "  --skip-maas               Skip MaaS configuration"
    echo "  --skip-node-scaling       Skip automatic worker/GPU node scaling"
    echo "  --no-llmd                 Don't configure llm-d/LWS"
    echo ""
    echo "RHOAI 3.4+ Options (ignored on older versions):"
    echo "  --skip-admin-user         Skip creating htpasswd admin user"
    echo "  --enable-vllm-maas        Enable vLLM runtime for MaaS (TP)"
    echo "  --enable-observability    Enable MaaS observability dashboard (TP)"
    echo "  --deploy-grafana          Deploy standalone Grafana with dashboards"
    echo "  --postgres-connection <url>  External PostgreSQL for MaaS"
    echo "  --skip-maas-db            Skip MaaS PostgreSQL setup"
    echo "  --setup-pipelines         Deploy a pipeline server (DSPA)"
    echo "  --pipeline-namespace <ns> Namespace for pipeline server"
    echo "  --setup-users             Create demo users (user1..userN)"
    echo "  --num-users <N>           Number of demo users (default: 5)"
    echo "  --admin-group <name>      Admin group (default: rhods-admins)"
    echo "  --user-group <name>       User group (default: rhods-users)"
    echo "  --user-password <pw>      Demo user password (default: openshift)"
    echo ""
    echo "  -h, --help                Show this help"
}

################################################################################
# Version Detection
################################################################################

resolve_version_profile() {
    local channel="$1"

    # Determine the major.minor version from the channel name or cluster metadata
    local version=""

    case "$channel" in
        *3.4*|stable-3.4)
            version="34"
            ;;
        *3.3*|stable-3.3)
            version="33"
            ;;
        fast-3.x|stable-3.x)
            # Rolling channel — resolve from the cluster's packagemanifest
            local csv_version
            csv_version=$(oc get packagemanifest rhods-operator -n openshift-marketplace \
                -o jsonpath="{.status.channels[?(@.name==\"${channel}\")].currentCSV}" 2>/dev/null)

            if [ -n "$csv_version" ]; then
                if echo "$csv_version" | grep -q "3\.4"; then
                    version="34"
                elif echo "$csv_version" | grep -q "3\.3"; then
                    version="33"
                fi
            fi

            if [ -z "$version" ]; then
                print_info "Could not resolve version from channel '$channel', defaulting to 3.4"
                version="34"
            fi
            ;;
        "")
            # Channel not specified yet — will be selected interactively later.
            # Default to 3.4 profile; if the user picks a 3.3 channel during
            # interactive selection, we reload the profile.
            version="34"
            ;;
        *)
            # Unknown channel pattern — try to resolve from cluster
            local csv_version
            csv_version=$(oc get packagemanifest rhods-operator -n openshift-marketplace \
                -o jsonpath="{.status.channels[?(@.name==\"${channel}\")].currentCSV}" 2>/dev/null)

            if [ -n "$csv_version" ]; then
                if echo "$csv_version" | grep -q "3\.4"; then
                    version="34"
                elif echo "$csv_version" | grep -q "3\.3"; then
                    version="33"
                fi
            fi

            if [ -z "$version" ]; then
                print_warning "Unknown channel '$channel' — defaulting to 3.4 profile"
                version="34"
            fi
            ;;
    esac

    local profile="$ROOT_DIR/lib/versions/rhoai-${version}.conf"
    if [ ! -f "$profile" ]; then
        print_error "Version profile not found: $profile"
        exit 1
    fi

    source "$profile"
    print_info "Loaded version profile: RHOAI $RHOAI_VERSION_LABEL"
}

################################################################################
# Main
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-prerequisites)   SKIP_PREREQUISITES=true; shift ;;
            --skip-rhcl)            SKIP_RHCL=true; shift ;;
            --skip-node-scaling)    SKIP_NODE_SCALING=true; shift ;;
            --skip-maas)            SKIP_MAAS=true; shift ;;
            --skip-maas-db)         SKIP_MAAS_DB=true; shift ;;
            --skip-admin-user)      SKIP_ADMIN_USER=true; shift ;;
            --no-llmd)              ENABLE_LLMD=false; shift ;;
            --enable-vllm-maas)     ENABLE_VLLM_MAAS=true; shift ;;
            --enable-observability) ENABLE_OBSERVABILITY=true; shift ;;
            --deploy-grafana)       DEPLOY_GRAFANA=true; shift ;;
            --channel)              RHOAI_CHANNEL="$2"; shift 2 ;;
            --domain)               CLUSTER_DOMAIN="$2"; shift 2 ;;
            --timeout)              WAIT_TIMEOUT="$2"; shift 2 ;;
            --postgres-connection)  POSTGRES_CONNECTION="$2"; shift 2 ;;
            --setup-pipelines)      SETUP_PIPELINES=true; shift ;;
            --pipeline-namespace)   SETUP_PIPELINES=true; PIPELINE_NAMESPACE="$2"; shift 2 ;;
            --setup-users)          SETUP_USERS=true; shift ;;
            --num-users)            SETUP_USERS=true; NUM_USERS="$2"; shift 2 ;;
            --admin-group)          ADMIN_GROUP="$2"; shift 2 ;;
            --user-group)           USER_GROUP="$2"; shift 2 ;;
            --user-password)        USER_PASSWORD="$2"; shift 2 ;;
            -h|--help)              usage; exit 0 ;;
            *)                      print_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    # Load version profile based on channel
    resolve_version_profile "$RHOAI_CHANNEL"

    # Source shared phase functions
    source "$ROOT_DIR/lib/functions/install.sh"

    # Banner
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║          RHOAI ${RHOAI_VERSION_LABEL} Installation                                ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # ── Phase 1: Prerequisites ────────────────────────────────────────────
    check_prerequisites
    get_cluster_domain

    # ── Phase 2: Admin User (3.4+) ────────────────────────────────────────
    if [ "$FEATURE_ADMIN_USER" = true ]; then
        if [ "$SKIP_ADMIN_USER" = true ]; then
            print_info "Skipping admin user creation (--skip-admin-user)"
        elif [ "$CREATE_ADMIN_USER" = "yes" ]; then
            create_admin_user
        else
            echo ""
            echo -e "${CYAN}Would you like to create an htpasswd admin user?${NC}"
            echo -e "  This creates user ${YELLOW}'admin'${NC} with password ${YELLOW}'R3dh4t1!'${NC} and cluster-admin role."
            echo -e "  You can skip this if you already have an identity provider configured."
            echo ""
            read -p "Create admin user? (Y/n): " admin_choice
            admin_choice=${admin_choice:-Y}
            if [[ "$admin_choice" =~ ^[Yy]$ ]]; then
                create_admin_user
            else
                print_info "Skipping admin user creation"
            fi
        fi
    fi

    # ── Phase 3: Node Scaling ─────────────────────────────────────────────
    if [ "$SKIP_NODE_SCALING" = false ]; then
        scale_cluster_nodes
    else
        print_info "Skipping node scaling (--skip-node-scaling)"
    fi

    # ── Phase 4: Prerequisite Operators ───────────────────────────────────
    if [ "$SKIP_PREREQUISITES" = false ]; then
        install_nfd_operator
        install_gpu_operator
        install_kueue_operator
        install_certmanager_operator

        if [ "$ENABLE_LLMD" = true ]; then
            install_lws_operator
        fi
    fi

    # ── Phase 5: RHCL / Istio / Gateways ─────────────────────────────────
    if [ "$SKIP_RHCL" = false ] && [ "$SKIP_MAAS" = false ]; then
        install_rhcl_operator
        create_inference_gateway
    elif [ "$SKIP_RHCL" = false ]; then
        install_rhcl_operator
    else
        print_info "Skipping RHCL/MaaS (--skip-rhcl or --skip-maas)"
    fi

    # ── Phase 6: Monitoring ───────────────────────────────────────────────
    enable_user_workload_monitoring

    # ── Phase 7: RHOAI Operator + DSC ─────────────────────────────────────
    install_rhoai_operator
    create_datasciencecluster

    # ── Phase 8: Dashboard + Hardware Profile ─────────────────────────────
    enable_dashboard_features
    if [ "$FEATURE_MCP_LIFECYCLE" = true ]; then
        install_mcp_lifecycle_operator
    fi
    create_hardware_profile
    if [ "$FEATURE_MLFLOW" = true ]; then
        create_mlflow_server
    fi

    # ── Phase 9: MaaS DB / TLS / Rate Limiting ───────────────────────────
    if [ "$SKIP_RHCL" = false ] && [ "$SKIP_MAAS" = false ]; then
        if [ "$FEATURE_MAAS_DB" = true ]; then
            if [ "$SKIP_MAAS_DB" = false ]; then
                setup_maas_database
            else
                print_info "Skipping MaaS DB setup (--skip-maas-db)"
                if ! oc get secret maas-db-config -n redhat-ods-applications &>/dev/null; then
                    print_warning "maas-db-config secret not found — MaaS Tenant will show Degraded"
                    print_info "Create it with: oc create secret generic maas-db-config \\"
                    print_info "  --from-literal=DB_CONNECTION_URL='postgresql://user:pass@host:5432/db?sslmode=require' \\"
                    print_info "  -n redhat-ods-applications"
                fi
            fi
        fi
        if [ "$FEATURE_MAAS_TLS" = true ]; then
            configure_maas_tls
        fi
        if [ "$FEATURE_MAAS_RATE_LIMITING" = true ]; then
            configure_maas_rate_limiting
        fi
        if [ "$FEATURE_MAAS_VERIFY" = true ]; then
            verify_maas_deployment
        fi
    fi

    # ── Phase 10: Observability ───────────────────────────────────────────
    if [ "$FEATURE_OBSERVABILITY" = true ]; then
        install_coo_operator
        setup_observability_uiplugins
        setup_observability_perses
        create_thanos_proxy_secret
        deploy_observe_dashboards
    fi

    if [ "$FEATURE_GRAFANA" = true ] && [ "${DEPLOY_GRAFANA:-false}" = true ]; then
        deploy_grafana_monitoring
    fi

    if [ "$FEATURE_GATEWAY_TELEMETRY" = true ] && [ "$ENABLE_OBSERVABILITY" = true ]; then
        configure_gateway_telemetry
    fi

    # ── Phase 11: Optional Pipelines / Demo Users ─────────────────────────
    if [ "$FEATURE_PIPELINE_SERVER" = true ] && [ "$SETUP_PIPELINES" = true ]; then
        if type setup_pipeline_server &>/dev/null; then
            setup_pipeline_server "$PIPELINE_NAMESPACE"
        else
            source "$ROOT_DIR/lib/functions/rhoai.sh" 2>/dev/null || true
            if type setup_pipeline_server &>/dev/null; then
                setup_pipeline_server "$PIPELINE_NAMESPACE"
            else
                print_warning "setup_pipeline_server not available — source lib/functions/rhoai.sh"
            fi
        fi
    fi

    if [ "$FEATURE_DEMO_USERS" = true ] && [ "$SETUP_USERS" = true ]; then
        setup_demo_users "$NUM_USERS" "$ADMIN_GROUP" "$USER_GROUP" "$USER_PASSWORD"
    fi

    # ── Phase 12: Summary ─────────────────────────────────────────────────
    print_install_summary
}

main "$@"
exit 0
