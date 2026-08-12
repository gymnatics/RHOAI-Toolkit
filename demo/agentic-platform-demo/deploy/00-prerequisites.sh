#!/bin/bash
set -euo pipefail

###############################################################################
# 00-prerequisites.sh
# Install required operators on a fresh ROSA/OCP cluster
# Prerequisites: oc CLI logged in as cluster-admin, cluster is ROSA 4.14+
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh" 2>/dev/null || true

echo "============================================"
echo " Installing Operators & Prerequisites"
echo "============================================"

oc whoami || { echo "ERROR: Not logged into cluster. Run 'oc login' first."; exit 1; }

# --- Red Hat Build of Keycloak (RHBK) Operator ---
echo "[1/8] Installing Red Hat Build of Keycloak operator..."
cat <<'EOF' | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhbk-operator
  namespace: openshift-operators
spec:
  channel: stable-v26
  installPlanApproval: Automatic
  name: rhbk-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# --- Red Hat OpenShift Service Mesh (Istio) ---
echo "[2/8] Installing OpenShift Service Mesh operator..."
cat <<'EOF' | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: servicemeshoperator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: servicemeshoperator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# --- Red Hat OpenShift Serverless (for Knative / KServe) ---
echo "[3/8] Installing OpenShift Serverless operator..."
cat <<'EOF' | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: serverless-operator
  namespace: openshift-serverless
spec:
  channel: stable
  installPlanApproval: Automatic
  name: serverless-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# --- Red Hat OpenShift AI (RHOAI) ---
echo "[4/8] Installing Red Hat OpenShift AI operator..."
cat <<'EOF' | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: rhods-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# --- OpenShift Pipelines (Tekton) ---
echo "[5/8] Installing OpenShift Pipelines operator..."
cat <<'EOF' | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-pipelines-operator
  namespace: openshift-operators
spec:
  channel: latest
  installPlanApproval: Automatic
  name: openshift-pipelines-operator-rh
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# --- SPIRE Operator (from OperatorHub or community) ---
echo "[6/8] Installing SPIFFE/SPIRE operator..."
cat <<'EOF' | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: spire-operator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: spire-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF

# --- Gateway API CRDs (for MCP Gateway / Kuadrant) ---
echo "[7/8] Installing Gateway API CRDs..."
oc apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml 2>/dev/null || \
  echo "  Gateway API CRDs may already exist or need manual install"

# --- KAgenti / Rossoctl Operator ---
echo "[8/8] Installing KAgenti operator..."
cat <<'EOF' | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kagenti-operator
  namespace: openshift-operators
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: kagenti-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF

echo ""
echo "Waiting for operators to install (this may take 3-5 minutes)..."
sleep 30

echo "Checking operator status..."
oc get csv -n openshift-operators --no-headers 2>/dev/null | while read -r line; do
  name=$(echo "$line" | awk '{print $1}')
  phase=$(echo "$line" | awk '{print $NF}')
  echo "  $name -> $phase"
done

echo ""
echo "============================================"
echo " Prerequisites complete."
echo " Verify all operators show 'Succeeded' above."
echo " If any are pending, wait and re-check with:"
echo "   oc get csv -n openshift-operators"
echo "============================================"
