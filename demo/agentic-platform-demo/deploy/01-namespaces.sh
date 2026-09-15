#!/bin/bash
set -euo pipefail

###############################################################################
# 01-namespaces.sh
# Create all namespaces, ServiceAccounts, Roles, and RoleBindings
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

echo "============================================"
echo " Creating Namespaces & RBAC"
echo "============================================"

# --- Create namespaces ---
for ns in "$NS_AGENT" "$NS_KEYCLOAK" "$NS_MCP" "$NS_KAGENTI" "$NS_DIFY" "$NS_REGISTRY"; do
  oc get namespace "$ns" &>/dev/null || oc create namespace "$ns"
  echo "  ✓ Namespace: $ns"
done

# --- Label namespaces for Istio injection ---
oc label namespace "$NS_AGENT" istio.io/dataplane-mode=ambient --overwrite
echo "  ✓ Istio ambient label on $NS_AGENT"

# --- ServiceAccounts in team1 ---
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: loan-agent
  namespace: ${NS_AGENT}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: grafana
  namespace: ${NS_AGENT}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: loki
  namespace: ${NS_AGENT}
EOF
echo "  ✓ ServiceAccounts created"

# --- RBAC for loan-agent (needs to read ConfigMaps, Secrets) ---
cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: loan-agent-role
  namespace: ${NS_AGENT}
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: loan-agent-binding
  namespace: ${NS_AGENT}
subjects:
- kind: ServiceAccount
  name: loan-agent
  namespace: ${NS_AGENT}
roleRef:
  kind: Role
  name: loan-agent-role
  apiGroup: rbac.authorization.k8s.io
EOF
echo "  ✓ RBAC for loan-agent"

# --- RBAC for Kiali (cluster-reader for service mesh visibility) ---
oc adm policy add-cluster-role-to-user cluster-reader \
  system:serviceaccount:${NS_ISTIO}:kiali-service-account 2>/dev/null || true
echo "  ✓ Kiali cluster-reader role"

# --- Allow Grafana to pull images ---
oc adm policy add-scc-to-user anyuid -z grafana -n "${NS_AGENT}" 2>/dev/null || true
oc adm policy add-scc-to-user anyuid -z default -n "${NS_AGENT}" 2>/dev/null || true
echo "  ✓ SCC policies"

# --- NetworkPolicy: allow all within team1 (demo purposes) ---
cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-team1
  namespace: ${NS_AGENT}
spec:
  podSelector: {}
  ingress:
  - {}
  egress:
  - {}
  policyTypes:
  - Ingress
  - Egress
EOF
echo "  ✓ NetworkPolicy (allow-all for demo)"

echo ""
echo "============================================"
echo " Namespaces & RBAC complete."
echo "============================================"
