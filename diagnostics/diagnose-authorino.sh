#!/bin/bash

################################################################################
# Authorino Diagnostic Script
# Investigates why Authorino service is not being created
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ Authorino Diagnostic Report${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check 1: RHCL Operator
echo -e "${YELLOW}[1/8] Checking RHCL Operator...${NC}"
if oc get subscription rhcl-operator -n kuadrant-system &>/dev/null; then
    echo -e "${GREEN}✓ RHCL Operator subscription exists${NC}"
    oc get subscription rhcl-operator -n kuadrant-system -o jsonpath='{.status.installedCSV}{"\n"}'
else
    echo -e "${RED}✗ RHCL Operator subscription NOT found${NC}"
fi
echo ""

# Check 2: RHCL Operator Pod
echo -e "${YELLOW}[2/8] Checking RHCL Operator Pod...${NC}"
oc get pods -n kuadrant-system -l app.kubernetes.io/name=rhcl-operator
echo ""

# Check 3: Kuadrant CRD
echo -e "${YELLOW}[3/8] Checking Kuadrant CRD...${NC}"
if oc get crd kuadrants.kuadrant.io &>/dev/null; then
    echo -e "${GREEN}✓ Kuadrant CRD exists${NC}"
else
    echo -e "${RED}✗ Kuadrant CRD NOT found${NC}"
fi
echo ""

# Check 4: Kuadrant Instance
echo -e "${YELLOW}[4/8] Checking Kuadrant Instance...${NC}"
if oc get kuadrant kuadrant -n kuadrant-system &>/dev/null; then
    echo -e "${GREEN}✓ Kuadrant instance exists${NC}"
    echo ""
    echo "Kuadrant Status:"
    oc get kuadrant kuadrant -n kuadrant-system -o yaml | grep -A 20 "status:"
else
    echo -e "${RED}✗ Kuadrant instance NOT found${NC}"
fi
echo ""

# Check 5: Authorino CRD
echo -e "${YELLOW}[5/8] Checking Authorino CRD...${NC}"
if oc get crd authorinos.operator.authorino.kuadrant.io &>/dev/null; then
    echo -e "${GREEN}✓ Authorino CRD exists${NC}"
else
    echo -e "${RED}✗ Authorino CRD NOT found${NC}"
fi
echo ""

# Check 6: Authorino Instance
echo -e "${YELLOW}[6/8] Checking Authorino Instance...${NC}"
if oc get authorino -n kuadrant-system &>/dev/null; then
    echo -e "${GREEN}✓ Authorino instance exists${NC}"
    oc get authorino -n kuadrant-system
    echo ""
    echo "Authorino Status:"
    oc get authorino -n kuadrant-system -o yaml | grep -A 20 "status:"
else
    echo -e "${RED}✗ Authorino instance NOT found${NC}"
fi
echo ""

# Check 7: All Pods in kuadrant-system
echo -e "${YELLOW}[7/8] All Pods in kuadrant-system namespace:${NC}"
oc get pods -n kuadrant-system -o wide
echo ""

# Check 8: Services in kuadrant-system
echo -e "${YELLOW}[8/8] All Services in kuadrant-system namespace:${NC}"
oc get svc -n kuadrant-system
echo ""

# Check for Authorino service specifically
echo -e "${YELLOW}Checking for Authorino service specifically:${NC}"
if oc get svc/authorino-authorino-authorization -n kuadrant-system &>/dev/null; then
    echo -e "${GREEN}✓ Authorino service EXISTS!${NC}"
    oc get svc/authorino-authorino-authorization -n kuadrant-system -o yaml
else
    echo -e "${RED}✗ Authorino service NOT FOUND${NC}"
fi
echo ""

# Check operator logs
echo -e "${YELLOW}Recent RHCL Operator Logs (last 50 lines):${NC}"
OPERATOR_POD=$(oc get pods -n kuadrant-system -l app.kubernetes.io/name=rhcl-operator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$OPERATOR_POD" ]; then
    oc logs -n kuadrant-system "$OPERATOR_POD" --tail=50
else
    echo -e "${RED}No operator pod found${NC}"
fi
echo ""

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ Diagnostic Complete${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"

