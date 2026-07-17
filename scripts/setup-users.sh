#!/bin/bash
################################################################################
# RHOAI User Management Script
# Creates demo users with htpasswd auth, organizes them into groups,
# and optionally creates MaaS subscriptions for those groups.
#
# Usage:
#   ./setup-users.sh                          # 5 users, default groups
#   ./setup-users.sh --num-users 10           # 10 users
#   ./setup-users.sh --num-users 3 --admin-group my-admins --user-group my-users
#   ./setup-users.sh --create-subscription    # also create MaaS subscription
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m'
}

print_step()    { echo -e "${BLUE}[STEP]${NC} $*"; }
print_success() { echo -e "${GREEN}[OK]${NC} $*"; }
print_info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

NUM_USERS=5
ADMIN_GROUP="rhods-admins"
USER_GROUP="rhods-users"
PASSWORD="openshift"
CREATE_SUBSCRIPTION=false
MODEL_NAMESPACE=""
MODEL_NAME=""

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Creates demo users (user1..userN) with htpasswd auth on OpenShift."
    echo "user1 is added to the admin group; user2+ to the regular user group."
    echo ""
    echo "Options:"
    echo "  --num-users <N>          Number of users to create (default: 5)"
    echo "  --admin-group <name>     Admin group name (default: rhods-admins)"
    echo "  --user-group <name>      Regular user group name (default: rhods-users)"
    echo "  --password <pw>          Password for all users (default: openshift)"
    echo "  --create-subscription    Create a MaaS subscription for each group"
    echo "  --model-name <name>      MaaS model name for subscription (required with --create-subscription)"
    echo "  --model-namespace <ns>   MaaS model namespace (required with --create-subscription)"
    echo "  -h, --help               Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --num-users 10 --password demo123"
    echo "  $0 --num-users 5 --admin-group team-leads --user-group developers"
    echo "  $0 --create-subscription --model-name qwen3-8b --model-namespace 0-demo"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --num-users)     NUM_USERS="$2";        shift 2 ;;
        --admin-group)   ADMIN_GROUP="$2";       shift 2 ;;
        --user-group)    USER_GROUP="$2";        shift 2 ;;
        --password)      PASSWORD="$2";          shift 2 ;;
        --create-subscription) CREATE_SUBSCRIPTION=true; shift ;;
        --model-name)    MODEL_NAME="$2";        shift 2 ;;
        --model-namespace) MODEL_NAMESPACE="$2"; shift 2 ;;
        -h|--help)       usage; exit 0 ;;
        *)               print_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if [ "$CREATE_SUBSCRIPTION" = true ] && { [ -z "$MODEL_NAME" ] || [ -z "$MODEL_NAMESPACE" ]; }; then
    print_error "--create-subscription requires --model-name and --model-namespace"
    exit 1
fi

if ! command -v oc &>/dev/null; then
    print_error "'oc' CLI not found"
    exit 1
fi

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run 'oc login' first."
    exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              RHOAI User Management                             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Users to create:${NC}  ${NUM_USERS} (user1 .. user${NUM_USERS})"
echo -e "  ${CYAN}Admin group:${NC}      ${ADMIN_GROUP} (user1)"
echo -e "  ${CYAN}User group:${NC}       ${USER_GROUP} (user2 .. user${NUM_USERS})"
echo -e "  ${CYAN}Password:${NC}         ${PASSWORD}"
if [ "$CREATE_SUBSCRIPTION" = true ]; then
    echo -e "  ${CYAN}MaaS model:${NC}       ${MODEL_NAME} (${MODEL_NAMESPACE})"
fi
echo ""

################################################################################
# Create htpasswd users
################################################################################

print_step "Creating ${NUM_USERS} htpasswd users..."

tmpdir=$(mktemp -d)
htpasswd_file="${tmpdir}/htpasswd"
touch "$htpasswd_file"

if oc get secret htpasswd-secret -n openshift-config &>/dev/null 2>&1; then
    oc get secret htpasswd-secret -n openshift-config -o jsonpath='{.data.htpasswd}' 2>/dev/null \
        | base64 -d > "$htpasswd_file" 2>/dev/null || true
    print_info "Loaded existing htpasswd data"
fi

created=0
for i in $(seq 1 "$NUM_USERS"); do
    username="user${i}"
    if grep -q "^${username}:" "$htpasswd_file" 2>/dev/null; then
        print_info "${username} already exists — skipping"
    else
        if command -v htpasswd &>/dev/null; then
            htpasswd -bB "$htpasswd_file" "$username" "$PASSWORD" 2>/dev/null
        else
            hash=$(openssl passwd -apr1 "$PASSWORD" 2>/dev/null)
            echo "${username}:${hash}" >> "$htpasswd_file"
        fi
        created=$((created + 1))
    fi
done
print_success "Created ${created} new users (${NUM_USERS} total)"

oc create secret generic htpasswd-secret \
    --from-file=htpasswd="$htpasswd_file" \
    -n openshift-config --dry-run=client -o yaml | oc apply -f -
print_success "htpasswd secret updated"

################################################################################
# Ensure htpasswd identity provider
################################################################################

has_htpasswd=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[?(@.name=="htpasswd")].name}' 2>/dev/null || true)
if [ -z "$has_htpasswd" ]; then
    print_step "Adding htpasswd identity provider to OAuth..."
    oc patch oauth cluster --type=json -p '[{
        "op": "add",
        "path": "/spec/identityProviders/-",
        "value": {
            "name": "htpasswd",
            "type": "HTPasswd",
            "mappingMethod": "claim",
            "htpasswd": {
                "fileData": {
                    "name": "htpasswd-secret"
                }
            }
        }
    }]' 2>/dev/null || {
        oc patch oauth cluster --type=merge -p '{
            "spec": {
                "identityProviders": [{
                    "name": "htpasswd",
                    "type": "HTPasswd",
                    "mappingMethod": "claim",
                    "htpasswd": {
                        "fileData": {
                            "name": "htpasswd-secret"
                        }
                    }
                }]
            }
        }' 2>/dev/null
    }
    print_success "htpasswd identity provider added (OAuth pods will restart)"
else
    print_info "htpasswd identity provider already configured"
fi

################################################################################
# Create groups and assign users
################################################################################

for grp in "$ADMIN_GROUP" "$USER_GROUP"; do
    if ! oc get group "$grp" &>/dev/null 2>&1; then
        print_step "Creating group '${grp}'..."
        oc adm groups new "$grp" 2>/dev/null
    else
        print_info "Group '${grp}' already exists"
    fi
done

admin_users=""
regular_users=""

for i in $(seq 1 "$NUM_USERS"); do
    username="user${i}"
    if [ "$i" -eq 1 ]; then
        oc adm groups add-users "$ADMIN_GROUP" "$username" 2>/dev/null || true
        admin_users="${admin_users:+${admin_users}, }${username}"
    else
        oc adm groups add-users "$USER_GROUP" "$username" 2>/dev/null || true
        regular_users="${regular_users:+${regular_users}, }${username}"
    fi
done

print_success "Group membership configured:"
echo -e "  ${CYAN}${ADMIN_GROUP}:${NC} ${admin_users}"
echo -e "  ${CYAN}${USER_GROUP}:${NC} ${regular_users}"

# Give admin users dashboard access
oc adm policy add-cluster-role-to-user cluster-admin user1 2>/dev/null || true
print_info "user1 granted cluster-admin for dashboard access"

################################################################################
# Optionally create MaaS subscriptions
################################################################################

if [ "$CREATE_SUBSCRIPTION" = true ]; then
    print_step "Creating MaaS subscriptions for groups..."

    for grp in "$ADMIN_GROUP" "$USER_GROUP"; do
        local sub_name="${grp}-sub"
        if oc get maassubscription "$sub_name" -n models-as-a-service &>/dev/null 2>&1; then
            print_info "MaaS subscription '${sub_name}' already exists"
            continue
        fi

        print_step "Creating subscription '${sub_name}' for group '${grp}'..."
        oc apply -f - <<EOF
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSSubscription
metadata:
  name: ${sub_name}
  namespace: models-as-a-service
  annotations:
    openshift.io/display-name: "${grp} subscription"
spec:
  modelRefs:
    - name: ${MODEL_NAME}
      namespace: ${MODEL_NAMESPACE}
      tokenRateLimits:
        - limit: 10000
          window: 5m
  owner:
    groups:
      - name: ${grp}
  priority: 1
EOF

        print_step "Creating auth policy for '${grp}'..."
        oc apply -f - <<EOF
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSAuthPolicy
metadata:
  name: ${grp}-auth
  namespace: models-as-a-service
spec:
  modelRefs:
    - name: ${MODEL_NAME}
      namespace: ${MODEL_NAMESPACE}
  subjects:
    groups:
      - name: ${grp}
EOF
    done

    print_success "MaaS subscriptions and auth policies created"
fi

rm -rf "$tmpdir"

################################################################################
# Summary
################################################################################

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Setup Complete                                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Login as admin:${NC}   oc login -u user1 -p ${PASSWORD}"
echo -e "  ${CYAN}Login as user:${NC}    oc login -u user2 -p ${PASSWORD}"
echo ""
echo -e "  ${YELLOW}MaaS workflow:${NC}"
echo "    1. Users log into dashboard and go to Gen AI studio > API keys"
echo "    2. They select their subscription and generate an API key"
echo "    3. Use the key: curl -H 'Authorization: Bearer <key>' https://maas.apps.<cluster>/..."
echo ""
if [ "$CREATE_SUBSCRIPTION" = false ]; then
    echo -e "  ${YELLOW}To create MaaS subscriptions for these groups, re-run with:${NC}"
    echo "    $0 --create-subscription --model-name <name> --model-namespace <ns>"
    echo ""
fi
echo -e "  ${YELLOW}Note:${NC} Users may take 1-2 minutes to be available after OAuth restart"
