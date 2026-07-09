#!/bin/bash
################################################################################
# fix-grafana-db.sh - Fix Grafana SQLite DB migration errors
#
# Fixes CrashLoopBackOff caused by schema mismatch and restores
# GrafanaDashboard/Datasource CRs from ArgoCD git source.
#
# Usage: ./fix-grafana-db.sh [namespace] [deployment] [pvc]
################################################################################

set -e

NS="${1:-grafana}"
DEPLOY="${2:-grafana-deployment}"
PVC="${3:-grafana-pvc}"
DBPOD="grafana-db-fix-$$"

log() { echo -e "\033[0;36m▶ $1\033[0m"; }
ok()  { echo -e "\033[0;32m✓ $1\033[0m"; }
err() { echo -e "\033[0;31m✗ $1\033[0m"; }

trap 'oc delete pod "$DBPOD" -n "$NS" --grace-period=0 --force 2>/dev/null || true' EXIT

oc whoami &>/dev/null || { err "Not logged in. Run 'oc login' first."; exit 1; }

# --- Phase 1: Fix DB ---
log "Scaling down $DEPLOY..."
oc scale deployment "$DEPLOY" -n "$NS" --replicas=0
sleep 5

log "Creating debug pod..."
oc run "$DBPOD" -n "$NS" --image=docker.io/alpine:3.20 --restart=Never \
  --overrides="{
    \"spec\":{
      \"securityContext\":{\"runAsUser\":0},
      \"containers\":[{
        \"name\":\"$DBPOD\",
        \"image\":\"docker.io/alpine:3.20\",
        \"command\":[\"sleep\",\"300\"],
        \"volumeMounts\":[{\"name\":\"data\",\"mountPath\":\"/var/lib/grafana\"}]
      }],
      \"volumes\":[{\"name\":\"data\",\"persistentVolumeClaim\":{\"claimName\":\"$PVC\"}}]
    }
  }" 2>/dev/null
oc wait pod/"$DBPOD" -n "$NS" --for=condition=Ready --timeout=120s

log "Removing stale grafana.db..."
oc exec "$DBPOD" -n "$NS" -- rm -f /var/lib/grafana/grafana.db
ok "DB removed"

log "Scaling up $DEPLOY..."
oc scale deployment "$DEPLOY" -n "$NS" --replicas=1

log "Waiting for Grafana (up to 90s)..."
READY=""
for _ in $(seq 1 9); do
  sleep 10
  READY=$(oc get pods -n "$NS" -l app=grafana \
    -o jsonpath='{.items[0].status.containerStatuses[?(@.name=="grafana")].ready}' 2>/dev/null) || true
  [ "$READY" = "true" ] && break
done

if [ "$READY" != "true" ]; then
  err "Grafana not ready. Check: oc logs -n $NS \$(oc get pod -n $NS -l app=grafana -o name | head -1) -c grafana"
  exit 1
fi
ok "Grafana is running"

# --- Phase 2: Restore auth secret + dashboard/datasource ---
log "Checking grafana-auth-secret..."
if ! oc get secret grafana-auth-secret -n "$NS" &>/dev/null; then
  log "Creating grafana-auth-secret (ServiceAccount token)..."
  cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: grafana-auth-secret
  namespace: $NS
  annotations:
    kubernetes.io/service-account.name: grafana-sa
type: kubernetes.io/service-account-token
EOF
  sleep 3
  ok "grafana-auth-secret created"
else
  ok "grafana-auth-secret already exists"
fi

log "Checking GrafanaDatasource and GrafanaDashboard CRs..."
NEED_RESTORE=false
oc get grafanadatasources.grafana.integreatly.org -n "$NS" 2>/dev/null | grep -q . || NEED_RESTORE=true
oc get grafanadashboards.grafana.integreatly.org -n "$NS" 2>/dev/null | grep -q . || NEED_RESTORE=true

if [ "$NEED_RESTORE" = true ]; then
  ARGOCD_REPO=$(oc get applications.argoproj.io -n openshift-gitops -o json 2>/dev/null \
    | python3 -c "
import json,sys
for app in json.load(sys.stdin).get('items',[]):
  if app['metadata']['name']=='grafana':
    src=app['spec'].get('source',{})
    print(src.get('repoURL',''))
    print(src.get('path',''))
" 2>/dev/null)

  REPO_URL=$(echo "$ARGOCD_REPO" | head -1)
  REPO_PATH=$(echo "$ARGOCD_REPO" | tail -1)

  if [ -n "$REPO_URL" ] && [ -n "$REPO_PATH" ]; then
    log "Cloning from ArgoCD source: $REPO_URL ($REPO_PATH)..."
    TMPDIR=$(mktemp -d)
    git clone --depth 1 "$REPO_URL" "$TMPDIR/repo" 2>/dev/null

    TPLDIR="$TMPDIR/repo/$REPO_PATH/templates"
    for f in "$TPLDIR/datasource.yaml" "$TPLDIR/dashboard.yaml"; do
      if [ -f "$f" ]; then
        # Render Helm template escapes: {{ "{{" }} → {{ and {{ "}}" }} → }}
        sed 's/{{ "{{" }}/{{/g; s/{{ "}}" }}/}}/g' "$f" \
          | oc apply -n "$NS" -f - && ok "Applied $(basename "$f")"
      fi
    done
    rm -rf "$TMPDIR"
  else
    log "No ArgoCD source found. Apply dashboard/datasource CRs manually."
  fi
else
  ok "GrafanaDatasource and GrafanaDashboard CRs already exist"
fi

# --- Summary ---
echo ""
log "=== Result ==="
oc get pods -n "$NS" -l app=grafana --no-headers
oc get grafanadatasources.grafana.integreatly.org -n "$NS" --no-headers 2>/dev/null
oc get grafanadashboards.grafana.integreatly.org -n "$NS" --no-headers 2>/dev/null
ROUTE=$(oc get route -n "$NS" -o jsonpath='{.items[0].spec.host}' 2>/dev/null) || true
[ -n "$ROUTE" ] && ok "URL: https://$ROUTE"
