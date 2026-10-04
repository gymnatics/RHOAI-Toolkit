#!/bin/bash
################################################################################
# create-restricted-client-admin.sh
#
# Creates a cluster-admin identity for a client/customer that CANNOT change
# worker/control-plane node counts (MachineSet, Machine, ControlPlaneMachineSet,
# MachineHealthCheck, MachineAutoscaler, ClusterAutoscaler) or delete Node
# objects. Everything else (projects, workloads, operator installs, RBAC,
# cluster-wide config, etc.) remains full cluster-admin.
#
# How it works:
#   RBAC alone cannot do "cluster-admin except X" because cluster-admin is a
#   single wildcard rule. Instead this script:
#     1. Binds the built-in `cluster-admin` ClusterRole to the client user
#        (real cluster-admin RBAC — nothing else is restricted).
#     2. Applies a ValidatingAdmissionPolicy (lib/manifests/rbac/restricted-admin/)
#        that hard-denies mutations to machine-api/autoscaling resources and
#        Node deletion for anyone NOT in the "infra-owners" group or a
#        system: service account. This runs at the admission layer, after
#        RBAC, so it can't be bypassed by having more RBAC permissions.
#     3. Adds the current caller (or --owner-user) to "infra-owners" as the
#        break-glass identity that is exempt from the deny policy.
#
# Usage:
#   ./scripts/create-restricted-client-admin.sh --client-user client-admin --client-password 'S3cret!'
#   ./scripts/create-restricted-client-admin.sh --client-user client-admin --client-password 'S3cret!' --owner-user admin
#   ./scripts/create-restricted-client-admin.sh --test --client-user client-admin   # verify the deny policy works
#   ./scripts/create-restricted-client-admin.sh --remove --client-user client-admin # undo (see notes at bottom)
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'
}
print_header()  { echo ""; echo -e "${BLUE}== $1 ==${NC}"; }
print_step()    { echo -e "${YELLOW}▶${NC} $*"; }
print_success() { echo -e "${GREEN}✓${NC} $*"; }
print_info()    { echo -e "${CYAN}ℹ${NC} $*"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
print_error()   { echo -e "${RED}✗${NC} $*"; }

source "$ROOT_DIR/lib/functions/user-management.sh"

CLIENT_USER=""
CLIENT_PASSWORD=""
OWNER_USER=""
OWNER_GROUP="infra-owners"
IDP_NAME="htpasswd"
MODE="create"   # create | test | remove

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --client-user <name>       Username to create for the client (required for create/remove)
  --client-password <pw>     Password for the client user (required for create)
  --owner-user <name>        Your own break-glass identity, exempt from the deny
                              policy (default: current 'oc whoami')
  --owner-group <name>       Exempt group name (default: infra-owners)
  --idp-name <name>          htpasswd IdP name (default: htpasswd)
  --test                     Verify the deny policy blocks the client user
                              (requires --client-user; you must still be
                              logged in as a cluster-admin to impersonate)
  --remove                   Remove the client's ClusterRoleBinding (does NOT
                              remove the deny policy or the htpasswd entry —
                              see notes printed at the end)
  -h, --help                 Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --client-user)     CLIENT_USER="$2"; shift 2 ;;
        --client-password) CLIENT_PASSWORD="$2"; shift 2 ;;
        --owner-user)       OWNER_USER="$2"; shift 2 ;;
        --owner-group)      OWNER_GROUP="$2"; shift 2 ;;
        --idp-name)         IDP_NAME="$2"; shift 2 ;;
        --test)             MODE="test"; shift ;;
        --remove)           MODE="remove"; shift ;;
        -h|--help)          usage; exit 0 ;;
        *) print_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if ! command -v oc &>/dev/null; then
    print_error "'oc' CLI not found"
    exit 1
fi
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run 'oc login' first (as a cluster-admin)."
    exit 1
fi

OWNER_USER="${OWNER_USER:-$(oc whoami)}"

################################################################################
# --test mode: prove the deny policy blocks the client from resizing workers
################################################################################
if [ "$MODE" = "test" ]; then
    if [ -z "$CLIENT_USER" ]; then
        print_error "--test requires --client-user"
        exit 1
    fi
    print_header "Testing deny policy for '$CLIENT_USER'"

    target_ms=$(oc get machinesets -n openshift-machine-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$target_ms" ]; then
        print_error "No MachineSets found in openshift-machine-api — cannot test"
        exit 1
    fi
    print_info "Using MachineSet: $target_ms"

    print_step "Attempting to scale '$target_ms' as '$CLIENT_USER' (server-side dry-run, no actual change)..."
    if oc patch machineset "$target_ms" -n openshift-machine-api \
        --type=merge -p '{"spec":{"replicas":99}}' \
        --dry-run=server --as="$CLIENT_USER" 2>&1 | tee /tmp/restricted-admin-test.out | grep -qi "denied"; then
        print_success "BLOCKED as expected — the deny policy is working:"
        cat /tmp/restricted-admin-test.out
    else
        print_error "NOT blocked — the request went through. Check the policy is applied:"
        cat /tmp/restricted-admin-test.out
        exit 1
    fi

    print_step "Confirming a normal action (e.g. listing pods) still works for '$CLIENT_USER'..."
    if oc get pods -A --as="$CLIENT_USER" &>/dev/null; then
        print_success "Client can still use normal cluster-admin capabilities"
    else
        print_warning "Client could not list pods — check their ClusterRoleBinding"
    fi
    exit 0
fi

################################################################################
# --remove mode
################################################################################
if [ "$MODE" = "remove" ]; then
    if [ -z "$CLIENT_USER" ]; then
        print_error "--remove requires --client-user"
        exit 1
    fi
    print_header "Removing cluster-admin binding for '$CLIENT_USER'"
    oc delete clusterrolebinding "${CLIENT_USER}-cluster-admin" 2>/dev/null || true
    print_success "Removed ClusterRoleBinding '${CLIENT_USER}-cluster-admin'"
    print_info "The htpasswd entry and the deny policy were left in place."
    print_info "To also remove the deny policy: oc delete -k lib/manifests/rbac/restricted-admin/"
    exit 0
fi

################################################################################
# --create (default) mode
################################################################################
if [ -z "$CLIENT_USER" ] || [ -z "$CLIENT_PASSWORD" ]; then
    print_error "--client-user and --client-password are required"
    usage
    exit 1
fi

print_header "1/4 — Exempt group for break-glass owner"
if ! oc get group "$OWNER_GROUP" &>/dev/null 2>&1; then
    oc adm groups new "$OWNER_GROUP" >/dev/null
    print_success "Created group '$OWNER_GROUP'"
else
    print_info "Group '$OWNER_GROUP' already exists"
fi
oc adm groups add-users "$OWNER_GROUP" "$OWNER_USER" >/dev/null 2>&1 || true
print_success "'$OWNER_USER' added to '$OWNER_GROUP' (exempt from the deny policy)"

print_header "2/4 — Applying deny policy (ValidatingAdmissionPolicy)"
oc apply -k "$ROOT_DIR/lib/manifests/rbac/restricted-admin/"
print_success "Machine-API / node-scaling deny policy applied"

print_header "3/4 — Creating client user '$CLIENT_USER'"
create_users "$CLIENT_USER" "$CLIENT_PASSWORD" "$IDP_NAME"

print_header "4/4 — Granting cluster-admin to '$CLIENT_USER'"
crb_name="${CLIENT_USER}-cluster-admin"
oc create clusterrolebinding "$crb_name" \
    --clusterrole=cluster-admin \
    --user="$CLIENT_USER" \
    --dry-run=client -o yaml | oc apply -f - >/dev/null
print_success "ClusterRoleBinding '$crb_name' -> cluster-admin"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Restricted Client Admin Ready                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Client login:${NC}   oc login -u ${CLIENT_USER} -p '<password>'"
echo -e "  ${CYAN}Console:${NC}        (same console URL, choose IdP '${IDP_NAME}' if prompted)"
echo -e "  ${CYAN}Access level:${NC}   cluster-admin, EXCEPT MachineSet/Machine/ControlPlaneMachineSet/"
echo -e "                     MachineHealthCheck/MachineAutoscaler/ClusterAutoscaler edits"
echo -e "                     and Node deletion (blocked by admission policy)"
echo -e "  ${CYAN}Break-glass:${NC}    '${OWNER_USER}' is in group '${OWNER_GROUP}' and is NOT restricted"
echo ""
echo -e "  ${YELLOW}Verify it worked:${NC}"
echo "    ./scripts/create-restricted-client-admin.sh --test --client-user ${CLIENT_USER}"
echo ""
echo -e "  ${YELLOW}Note:${NC} the client-facing IdP login may take 1-2 min after OAuth restarts."
