#!/bin/bash

################################################################################
# Fix RHCL Operator Installation
# Changes OperatorGroup to support AllNamespaces install mode
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ Fixing RHCL Operator Installation${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Issue: RHCL operator requires AllNamespaces install mode${NC}"
echo -e "${YELLOW}Current: OperatorGroup configured for OwnNamespace mode${NC}"
echo ""

# Step 1: Delete existing resources
echo -e "${BLUE}[1/5] Cleaning up existing resources...${NC}"

echo "Deleting Authorino instance..."
oc delete authorino --all -n kuadrant-system --ignore-not-found=true

echo "Deleting Kuadrant instance..."
oc delete kuadrant kuadrant -n kuadrant-system --ignore-not-found=true

echo "Deleting subscription..."
oc delete subscription rhcl-operator -n kuadrant-system --ignore-not-found=true

echo "Deleting CSV..."
oc delete csv rhcl-operator.v1.2.0 -n kuadrant-system --ignore-not-found=true

echo "Deleting OperatorGroup..."
oc delete operatorgroup kuadrant-system -n kuadrant-system --ignore-not-found=true

echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# Step 2: Wait for cleanup
echo -e "${BLUE}[2/5] Waiting for cleanup to complete...${NC}"
sleep 10
echo -e "${GREEN}✓ Wait complete${NC}"
echo ""

# Step 3: Create new OperatorGroup with AllNamespaces support
echo -e "${BLUE}[3/5] Creating cluster-wide OperatorGroup...${NC}"

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: kuadrant-system
  namespace: kuadrant-system
spec: {}
EOF

echo -e "${GREEN}✓ OperatorGroup created (cluster-wide mode)${NC}"
echo ""

# Step 4: Recreate subscription
echo -e "${BLUE}[4/5] Recreating RHCL Operator subscription...${NC}"

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhcl-operator
  namespace: kuadrant-system
spec:
  channel: stable
  installPlanApproval: Automatic
  name: rhcl-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

echo -e "${GREEN}✓ Subscription created${NC}"
echo ""

# Step 5: Wait for operator to be ready
echo -e "${BLUE}[5/5] Waiting for RHCL operator to be ready...${NC}"
echo "This may take 2-3 minutes..."
echo ""

sleep 30

# Wait for CSV to be ready
timeout=180
elapsed=0
until oc get csv -n kuadrant-system | grep rhcl-operator | grep -q Succeeded; do
    if [ $elapsed -ge $timeout ]; then
        echo -e "${RED}✗ Timeout waiting for operator${NC}"
        echo ""
        echo "Current CSV status:"
        oc get csv -n kuadrant-system | grep rhcl
        exit 1
    fi
    echo "Waiting for operator CSV... (${elapsed}s elapsed)"
    sleep 10
    elapsed=$((elapsed + 10))
done

echo -e "${GREEN}✓ RHCL Operator is ready!${NC}"
echo ""

# Check for operator pod
echo "Checking for operator pod..."
oc get pods -n kuadrant-system
echo ""

# Recreate Kuadrant instance
echo -e "${BLUE}Creating Kuadrant instance...${NC}"

cat <<EOF | oc apply -f -
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
EOF

echo -e "${GREEN}✓ Kuadrant instance created${NC}"
echo ""

# Wait for Kuadrant to deploy Authorino
echo -e "${BLUE}Waiting for Authorino service to be created...${NC}"
echo "This may take 1-2 minutes..."
echo ""

sleep 30

auth_timeout=120
auth_elapsed=0
until oc get svc/authorino-authorino-authorization -n kuadrant-system &>/dev/null; do
    if [ $auth_elapsed -ge $auth_timeout ]; then
        echo -e "${YELLOW}⚠ Authorino service not ready yet${NC}"
        echo ""
        echo "Current pods:"
        oc get pods -n kuadrant-system
        echo ""
        echo "Current services:"
        oc get svc -n kuadrant-system
        echo ""
        echo "You may need to wait a bit longer. Check with:"
        echo "  oc get svc -n kuadrant-system"
        exit 0
    fi
    echo "Waiting for Authorino service... (${auth_elapsed}s elapsed)"
    sleep 10
    auth_elapsed=$((auth_elapsed + 10))
done

echo -e "${GREEN}✓ Authorino service is ready!${NC}"
echo ""

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ RHCL Operator Fixed Successfully!${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "You can now run: ./setup-maas.sh"
echo ""

