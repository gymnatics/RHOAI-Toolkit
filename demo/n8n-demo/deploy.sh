#!/bin/bash
################################################################################
# Deploy n8n Workflow Automation
################################################################################
# Deploys n8n to OpenShift in its own namespace.
#
# Usage:
#   ./deploy.sh                    # Deploy to n8n namespace
#   ./deploy.sh -n my-namespace    # Deploy to custom namespace
#   ./deploy.sh --delete           # Remove deployment
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$ROOT_DIR/lib/utils/colors.sh"
source "$ROOT_DIR/lib/utils/common.sh"
source "$ROOT_DIR/lib/utils/os-compat.sh"

NAMESPACE="n8n"
# Positional namespace still works (./deploy.sh my-ns); a leading flag (e.g. --delete) is not a namespace
[[ -n "${1:-}" && "${1:-}" != -* ]] && NAMESPACE="$1"
DELETE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        --delete) DELETE_MODE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [-n namespace] [--delete]"
            exit 0
            ;;
        *) shift ;;
    esac
done

print_header "n8n Workflow Automation"

if [ "$DELETE_MODE" = true ]; then
    print_step "Removing n8n from $NAMESPACE..."
    export NAMESPACE N8N_ENCRYPTION_KEY="placeholder"
    envsubst < "$SCRIPT_DIR/manifests/n8n.yaml" | oc delete -f - --ignore-not-found 2>/dev/null
    print_success "n8n removed"
    exit 0
fi

if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift. Run: oc login <cluster-url>"
    exit 1
fi

ensure_namespace "$NAMESPACE"

print_step "Granting anyuid SCC (required for n8n container)..."
oc adm policy add-scc-to-user anyuid -z default -n "$NAMESPACE" 2>/dev/null || true

export NAMESPACE
export N8N_ENCRYPTION_KEY
# Reuse the key from an existing deployment: n8n stores it in /home/node/.n8n/config on the PVC,
# and a new key on redeploy makes the pod crash with "Mismatching encryption keys".
_n8n_key_b64=$(oc get secret n8n-secret -n "$NAMESPACE" -o jsonpath='{.data.N8N_ENCRYPTION_KEY}' 2>/dev/null || true)
N8N_ENCRYPTION_KEY=""
[ -n "$_n8n_key_b64" ] && N8N_ENCRYPTION_KEY=$(base64_decode "$_n8n_key_b64" 2>/dev/null || true)
if [ -n "$N8N_ENCRYPTION_KEY" ]; then
    print_info "Reusing existing N8N_ENCRYPTION_KEY from secret n8n-secret"
else
    N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
fi

print_step "Deploying n8n..."
envsubst < "$SCRIPT_DIR/manifests/n8n.yaml" | oc apply -f -

print_step "Waiting for n8n deployment..."
oc rollout status deployment/n8n -n "$NAMESPACE" --timeout=120s 2>/dev/null || true

N8N_URL="https://$(oc get route n8n -n "$NAMESPACE" -o jsonpath='{.status.ingress[0].host}' 2>/dev/null)"
echo ""
print_success "n8n deployed successfully"
print_info "URL: $N8N_URL"
print_info "Create your admin account on first login"
