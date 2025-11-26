#!/bin/bash

################################################################################
# Check for Pending InstallPlans
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Checking for Pending InstallPlans                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if oc is available
if ! command -v oc &> /dev/null; then
    echo -e "${RED}✗ oc command not found${NC}"
    exit 1
fi

# Check if logged in
if ! oc whoami &>/dev/null; then
    echo -e "${RED}✗ Not logged in to OpenShift cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Connected to cluster${NC}"
echo ""

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠ jq not found, using basic check${NC}"
    echo ""
    
    # Basic check without jq
    echo -e "${BLUE}All InstallPlans:${NC}"
    oc get installplan -A
    echo ""
    
    echo -e "${YELLOW}To check approval status manually:${NC}"
    echo "  oc get installplan -A -o yaml | grep -A2 'approved:'"
    echo ""
    exit 0
fi

# Check for pending InstallPlans using jq
echo -e "${BLUE}Checking all namespaces for pending InstallPlans...${NC}"
echo ""

PENDING=$(oc get installplan -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.approved==false) | "\(.metadata.namespace)|\(.metadata.name)|\(.spec.clusterServiceVersionNames[0])"' 2>/dev/null)

if [ -z "$PENDING" ]; then
    echo -e "${GREEN}✓ No pending InstallPlans found!${NC}"
    echo ""
    echo -e "${BLUE}All InstallPlans are either approved or auto-approved.${NC}"
    echo ""
    
    # Show recent InstallPlans for reference
    echo -e "${BLUE}Recent InstallPlans (last 10):${NC}"
    oc get installplan -A --sort-by='.metadata.creationTimestamp' | tail -11
    echo ""
else
    echo -e "${RED}✗ Found pending InstallPlans requiring manual approval:${NC}"
    echo ""
    echo -e "${YELLOW}NAMESPACE                NAME                          CSV${NC}"
    echo "$PENDING" | while IFS='|' read -r namespace name csv; do
        printf "%-24s %-29s %s\n" "$namespace" "$name" "$csv"
    done
    echo ""
    
    echo -e "${YELLOW}To approve all pending InstallPlans:${NC}"
    echo ""
    echo "$PENDING" | while IFS='|' read -r namespace name csv; do
        echo "  oc patch installplan $name -n $namespace --type merge -p '{\"spec\":{\"approved\":true}}'"
    done
    echo ""
    
    echo -e "${YELLOW}Or approve all at once:${NC}"
    cat << 'EOF'
  oc get installplan -A -o json | jq -r '.items[] | select(.spec.approved==false) | "\(.metadata.namespace) \(.metadata.name)"' | while read ns name; do oc patch installplan "$name" -n "$ns" --type merge -p '{"spec":{"approved":true}}'; done
EOF
    echo ""
    
    # Ask if user wants to approve now
    read -p "$(echo -e ${BLUE}Do you want to approve all pending InstallPlans now?${NC} [y/N]: )" approve
    
    if [[ "$approve" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${BLUE}Approving pending InstallPlans...${NC}"
        echo ""
        
        echo "$PENDING" | while IFS='|' read -r namespace name csv; do
            echo -e "${BLUE}Approving: $name in $namespace${NC}"
            oc patch installplan "$name" -n "$namespace" --type merge -p '{"spec":{"approved":true}}'
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Approved: $name${NC}"
            else
                echo -e "${RED}✗ Failed to approve: $name${NC}"
            fi
            echo ""
        done
        
        echo -e "${GREEN}✓ All pending InstallPlans have been approved!${NC}"
        echo ""
    else
        echo ""
        echo -e "${YELLOW}InstallPlans not approved. You can approve them manually later.${NC}"
        echo ""
    fi
fi

# Show Service Mesh status if relevant
echo -e "${BLUE}Checking Service Mesh status...${NC}"
if oc get namespace istio-system &>/dev/null; then
    echo -e "${GREEN}✓ istio-system namespace exists${NC}"
    
    if oc get smcp -n istio-system &>/dev/null 2>&1; then
        echo -e "${GREEN}✓ Service Mesh Control Plane found:${NC}"
        oc get smcp -n istio-system
    else
        echo -e "${YELLOW}⚠ No Service Mesh Control Plane found yet${NC}"
    fi
else
    echo -e "${YELLOW}⚠ istio-system namespace not found (Service Mesh not installed yet)${NC}"
fi

echo ""

