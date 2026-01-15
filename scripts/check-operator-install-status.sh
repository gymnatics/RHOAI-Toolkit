#!/usr/bin/env bash
################################################################################
# Check Operator Installation Status
# 
# Waits for an operator subscription to be fully installed by:
# 1. Waiting for InstallPlan to be created
# 2. Auto-approving Manual InstallPlans
# 3. Waiting for CSV to reach "Succeeded" phase
#
# Usage:
#   ./check-operator-install-status.sh <subscription-name> <namespace> [timeout]
#
# Examples:
#   ./check-operator-install-status.sh nfd openshift-nfd
#   ./check-operator-install-status.sh rhods-operator redhat-ods-operator 600
#
# Exit codes:
#   0 - Operator installed successfully
#   1 - Timeout or error
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Arguments
SUB_NAME="${1:-}"
NAMESPACE="${2:-}"
TIMEOUT="${3:-300}"
SLEEP=5

if [ -z "$SUB_NAME" ] || [ -z "$NAMESPACE" ]; then
    echo "Usage: $0 <subscription-name> <namespace> [timeout]"
    echo ""
    echo "Examples:"
    echo "  $0 nfd openshift-nfd"
    echo "  $0 rhods-operator redhat-ods-operator 600"
    exit 1
fi

start_time=$(date +%s)

echo -e "${CYAN}📦 Checking Operator: $SUB_NAME in namespace: $NAMESPACE${NC}"
echo ""

# ------------------------------------------------------------
# Check if subscription exists
# ------------------------------------------------------------
if ! oc get subscription "$SUB_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}⚠ Subscription '$SUB_NAME' not found in namespace '$NAMESPACE'${NC}"
    echo "  The operator may not be installed yet."
    exit 1
fi

# ------------------------------------------------------------
# STEP 1 — Wait for InstallPlan from subscription
# ------------------------------------------------------------
echo -e "${CYAN}⏳ Waiting for InstallPlan...${NC}"

while true; do
    IP_NAME=$(oc get subscription "$SUB_NAME" -n "$NAMESPACE" \
          -o jsonpath='{.status.installPlanRef.name}' 2>/dev/null || true)

    if [[ -n "$IP_NAME" ]]; then
        echo -e "${GREEN}📄 InstallPlan: $IP_NAME${NC}"
        break
    else
        echo "   • InstallPlan not yet populated (waiting...)"
    fi

    if (( $(date +%s) - start_time >= TIMEOUT )); then
        echo -e "${RED}❌ Timeout waiting for InstallPlan to appear${NC}"
        exit 1
    fi

    sleep "$SLEEP"
done

# ------------------------------------------------------------
# STEP 2 — Check and approve InstallPlan if needed
# ------------------------------------------------------------
APPROVAL_MODE=$(oc get installplan "$IP_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.approval}' 2>/dev/null || echo "Unknown")
APPROVED=$(oc get installplan "$IP_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.approved}' 2>/dev/null || echo "Unknown")

echo "   • Approval mode: $APPROVAL_MODE"
echo "   • Approved: $APPROVED"

if [[ "$APPROVAL_MODE" == "Manual" && "$APPROVED" == "false" ]]; then
    echo -e "${YELLOW}📝 InstallPlan requires manual approval → approving...${NC}"
    oc patch installplan "$IP_NAME" -n "$NAMESPACE" \
        --type merge -p '{"spec":{"approved":true}}'
    echo -e "${GREEN}✓ InstallPlan approved${NC}"
else
    echo -e "${GREEN}✓ InstallPlan already approved or auto-approved${NC}"
fi

# ------------------------------------------------------------
# STEP 3 — Get CSV from subscription and wait for Succeeded
# ------------------------------------------------------------
echo ""
echo -e "${CYAN}⏳ Waiting for CSV to be installed...${NC}"

while true; do
    CSV=$(oc get subscription "$SUB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.installedCSV}' 2>/dev/null || true)

    if [[ -n "$CSV" ]]; then
        echo -e "${GREEN}📦 CSV: $CSV${NC}"
        break
    else
        echo "   • installedCSV not yet populated (waiting...)"
    fi

    if (( $(date +%s) - start_time >= TIMEOUT )); then
        echo -e "${RED}❌ Timeout waiting for installedCSV to appear${NC}"
        exit 1
    fi

    sleep "$SLEEP"
done

echo ""
echo -e "${CYAN}⏳ Waiting for CSV to reach 'Succeeded' phase...${NC}"

while true; do
    PHASE=$(oc get csv "$CSV" -n "$NAMESPACE" \
            -o jsonpath='{.status.phase}' 2>/dev/null || echo "")

    if [[ "$PHASE" == "Succeeded" ]]; then
        echo ""
        echo -e "${GREEN}✅ Operator '$SUB_NAME' is fully installed${NC}"
        echo -e "${GREEN}   CSV: $CSV${NC}"
        echo -e "${GREEN}   Phase: Succeeded${NC}"
        exit 0
    fi

    if [[ -n "$PHASE" ]]; then
        echo "   • Phase: $PHASE (waiting...)"
    else
        echo "   • CSV not visible yet (waiting...)"
    fi

    if (( $(date +%s) - start_time >= TIMEOUT )); then
        echo -e "${RED}❌ Timeout waiting for CSV to reach Succeeded${NC}"
        echo "   Current phase: $PHASE"
        echo ""
        echo "Debug info:"
        oc get csv "$CSV" -n "$NAMESPACE" -o yaml | grep -A 10 "status:" || true
        exit 1
    fi

    sleep "$SLEEP"
done
