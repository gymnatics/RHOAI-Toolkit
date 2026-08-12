#!/bin/bash
set -euo pipefail

###############################################################################
# rebrand.sh
# Quickly rebrand the platform for a different customer demo
#
# Usage:
#   ./rebrand.sh DBS      # Default DBS branding
#   ./rebrand.sh OCBC     # Rebrand to OCBC
#   ./rebrand.sh POSB     # Rebrand to POSB
#   ./rebrand.sh "Bank X" # Rebrand to any name
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh" 2>/dev/null || true

NEW_BRAND="${1:-DBS}"
CURRENT_BRAND="${2:-DBS}"

if [[ "$NEW_BRAND" == "$CURRENT_BRAND" ]]; then
  echo "Brand is already set to '$NEW_BRAND'. Nothing to do."
  exit 0
fi

echo "============================================"
echo " Rebranding: $CURRENT_BRAND → $NEW_BRAND"
echo "============================================"

# --- Update local YAML files ---
echo "[1/3] Updating local files..."
FILES_TO_REBRAND=(
  "${SCRIPT_DIR}/06-loan-agent.yaml"
  "${SCRIPT_DIR}/06b-grafana-dashboards.yaml"
  "${SCRIPT_DIR}/06c-guardrails-dashboard.json"
  "${SCRIPT_DIR}/06d-policy-agent.yaml"
)

for file in "${FILES_TO_REBRAND[@]}"; do
  if [[ -f "$file" ]]; then
    sed -i.bak "s/${CURRENT_BRAND}/${NEW_BRAND}/g" "$file"
    rm -f "${file}.bak"
    count=$(grep -c "$NEW_BRAND" "$file" 2>/dev/null || echo "0")
    echo "  ✓ $(basename "$file") — $count references"
  fi
done

# --- Update live cluster ConfigMaps ---
echo ""
echo "[2/3] Updating cluster ConfigMaps..."

for cm in loan-agent-app loan-agent-ui loan-tools-server; do
  if oc get configmap "$cm" -n "${NS_AGENT}" &>/dev/null; then
    oc get configmap "$cm" -n "${NS_AGENT}" -o json | \
      python3 -c "
import sys, json
cm = json.load(sys.stdin)
for key in cm['data']:
    cm['data'][key] = cm['data'][key].replace('${CURRENT_BRAND}', '${NEW_BRAND}')
json.dump(cm, sys.stdout)
" | oc apply -f -
    echo "  ✓ ConfigMap: $cm"
  fi
done

# Grafana dashboards
if oc get configmap grafana-dashboards-data -n "${NS_AGENT}" &>/dev/null; then
  oc get configmap grafana-dashboards-data -n "${NS_AGENT}" -o json | \
    python3 -c "
import sys, json
cm = json.load(sys.stdin)
for key in cm['data']:
    cm['data'][key] = cm['data'][key].replace('${CURRENT_BRAND}', '${NEW_BRAND}')
json.dump(cm, sys.stdout)
" | oc apply -f -
  echo "  ✓ ConfigMap: grafana-dashboards-data"
fi

# --- Restart pods ---
echo ""
echo "[3/3] Restarting pods to pick up changes..."
oc rollout restart deployment/loan-agent -n "${NS_AGENT}" 2>/dev/null || true
oc rollout restart deployment/grafana -n "${NS_AGENT}" 2>/dev/null || true
echo "  ✓ loan-agent restarting"
echo "  ✓ grafana restarting"

echo ""
echo "============================================"
echo " Rebranding complete: $CURRENT_BRAND → $NEW_BRAND"
echo " Wait ~60s for pods to restart, then verify UI."
echo "============================================"
