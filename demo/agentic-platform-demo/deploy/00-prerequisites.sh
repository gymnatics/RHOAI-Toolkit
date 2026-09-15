#!/bin/bash
set -euo pipefail

###############################################################################
# 00-prerequisites.sh
# Install required operators on a fresh ROSA/OCP 4.19+ cluster
# Prerequisites: oc CLI logged in as cluster-admin
#
# NOTE: RHBK operator installs in its own namespace (keycloak) with
#       OwnNamespace OperatorGroup — AllNamespaces mode is not supported.
#       SPIRE and KAgenti operators are NOT available in the catalog.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh" 2>/dev/null || true

echo "============================================"
echo " Installing Operators & Prerequisites"
echo "============================================"

oc whoami || { echo "ERROR: Not logged into cluster. Run 'oc login' first."; exit 1; }

# --- Create required namespaces first ---
echo "[0/6] Creating prerequisite namespaces..."
oc create namespace keycloak 2>/dev/null || true
oc create namespace openshift-serverless 2>/dev/null || true

# --- Red Hat Build of Keycloak (RHBK) Operator ---
# Must install in OwnNamespace mode in the 'keycloak' namespace
echo "[1/6] Installing Red Hat Build of Keycloak operator (keycloak ns)..."
cat <<'EOF' | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: keycloak-og
  namespace: keycloak
spec:
  targetNamespaces:
  - keycloak
EOF

cat <<'EOF' | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhbk-operator
  namespace: keycloak
spec:
  channel: stable-v26
  installPlanApproval: Automatic
  name: rhbk-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# --- Red Hat OpenShift Service Mesh (Istio) ---
echo "[2/6] Installing OpenShift Service Mesh operator..."
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
echo "[3/6] Installing OpenShift Serverless operator..."
cat <<'EOF' | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: serverless-og
  namespace: openshift-serverless
spec: {}
EOF

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
echo "[4/6] Installing Red Hat OpenShift AI operator..."
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
echo "[5/6] Installing OpenShift Pipelines operator..."
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

# --- Gateway API CRDs (for MCP Gateway / Kuadrant) ---
echo "[6/6] Installing Gateway API CRDs..."
oc apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml 2>/dev/null || \
  echo "  Gateway API CRDs may already exist or need manual install"

# NOTE: SPIRE operator and KAgenti operator are NOT available in the OCP catalog.
#       SPIRE identity is simulated via logs. KAgenti/Rossoctl is deployed manually
#       from ghcr.io images (see 04-kagenti.yaml).

echo ""
echo "Waiting for operators to install (this may take 3-5 minutes)..."
sleep 30

# --- Auto-approve any pending install plans ---
echo "Checking for pending install plans..."
for ns in keycloak openshift-serverless openshift-operators; do
  PENDING_PLANS=$(oc get installplan -n "$ns" -o jsonpath='{.items[?(@.spec.approved==false)].metadata.name}' 2>/dev/null || true)
  for plan in $PENDING_PLANS; do
    echo "  Approving install plan: $plan (ns: $ns)"
    oc patch installplan "$plan" -n "$ns" --type=merge -p '{"spec":{"approved":true}}' 2>/dev/null || true
  done
done

echo ""
echo "Checking operator status..."
for ns in keycloak openshift-serverless openshift-operators; do
  oc get csv -n "$ns" --no-headers 2>/dev/null | while read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    phase=$(echo "$line" | awk '{print $NF}')
    echo "  [$ns] $name -> $phase"
  done
done

echo ""
echo "============================================"
echo " Prerequisites complete."
echo " Verify all operators show 'Succeeded' above."
echo " If any are pending, wait and re-check with:"
echo "   oc get csv -n openshift-operators"
echo "   oc get csv -n keycloak"
echo "   oc get csv -n openshift-serverless"
echo "============================================"
