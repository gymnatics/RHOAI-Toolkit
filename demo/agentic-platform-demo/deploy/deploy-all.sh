#!/bin/bash
set -euo pipefail

###############################################################################
# deploy-all.sh
# Single command to deploy the entire DBS Agentic AI Platform on a fresh ROSA cluster
#
# Prerequisites:
#   1. oc CLI installed and logged in as cluster-admin
#   2. Update env.sh with your cluster domain and API keys
#   3. Cluster has at least 1 GPU node (A10G) for HAP detector
#
# Usage:
#   ./deploy-all.sh              # Deploy everything
#   ./deploy-all.sh --from 05   # Resume from step 05
#   ./deploy-all.sh --only 06   # Run only step 06
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

FROM_STEP="${FROM_STEP:-00}"
ONLY_STEP="${ONLY_STEP:-}"

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --from) FROM_STEP="$2"; shift 2;;
    --only) ONLY_STEP="$2"; shift 2;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

should_run() {
  local step="$1"
  if [[ -n "$ONLY_STEP" ]]; then
    [[ "$step" == "$ONLY_STEP" ]]
  else
    [[ "$step" >= "$FROM_STEP" ]]
  fi
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  DBS Agentic AI Platform — Full Deployment                  ║"
echo "║  Cluster: ${CLUSTER_DOMAIN}                                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Verify cluster access
oc whoami &>/dev/null || { echo "ERROR: Not logged into cluster. Run 'oc login' first."; exit 1; }
echo "✓ Logged in as: $(oc whoami)"
echo "✓ Cluster: $(oc whoami --show-server)"
echo ""

# --- STEP 00: Operators ---
if should_run "00"; then
  echo "━━━ [00] Installing Operators ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "${SCRIPT_DIR}/00-prerequisites.sh"
  echo ""
  echo "⏳ Waiting 60s for operators to stabilize..."
  sleep 60
fi

# --- STEP 01: Namespaces ---
if should_run "01"; then
  echo "━━━ [01] Creating Namespaces & RBAC ━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "${SCRIPT_DIR}/01-namespaces.sh"
  echo ""
fi

# --- STEP 02: Keycloak ---
if should_run "02"; then
  echo "━━━ [02] Deploying Keycloak ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  oc apply -f "${SCRIPT_DIR}/02-keycloak.yaml"
  echo "⏳ Waiting for Keycloak to start..."
  oc wait --for=condition=ready pod -l app=keycloak -n keycloak --timeout=300s 2>/dev/null || \
    echo "  Keycloak may still be starting, continuing..."
  echo ""
fi

# --- STEP 03: MCP Gateway ---
if should_run "03"; then
  echo "━━━ [03] Deploying MCP Gateway ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  oc apply -f "${SCRIPT_DIR}/03-mcp-gateway.yaml"
  echo ""
fi

# --- STEP 04: KAgenti ---
if should_run "04"; then
  echo "━━━ [04] Deploying KAgenti Platform ━━━━━━━━━━━━━━━━━━━━━━━━━"
  oc apply -f "${SCRIPT_DIR}/04-kagenti.yaml"
  echo ""
fi

# --- STEP 05: Loki + Grafana ---
if should_run "05"; then
  echo "━━━ [05] Deploying Observability (Loki + Grafana) ━━━━━━━━━━━"
  oc apply -f "${SCRIPT_DIR}/05-loki-grafana.yaml"
  # Apply dashboard data (with cluster domain substituted)
  if [[ -f "${SCRIPT_DIR}/06b-grafana-dashboards.yaml" ]]; then
    sed "s|__CLUSTER_DOMAIN__|${CLUSTER_DOMAIN}|g" "${SCRIPT_DIR}/06b-grafana-dashboards.yaml" | oc apply -f -
  fi
  echo ""
fi

# --- STEP 06: Loan Agent ---
if should_run "06"; then
  echo "━━━ [06] Deploying Loan Agent + Tools ━━━━━━━━━━━━━━━━━━━━━━━"
  # Create LLM API key secret if not exists (reads from LLM_API_KEY env var or prompts)
  if ! oc get secret llm-api-key -n team1 &>/dev/null; then
    if [ -n "${LLM_API_KEY:-}" ]; then
      oc create secret generic llm-api-key -n team1 --from-literal=api-key="${LLM_API_KEY}"
    else
      echo "  WARNING: LLM_API_KEY not set. Create the secret manually:"
      echo "    oc create secret generic llm-api-key -n team1 --from-literal=api-key=YOUR_KEY"
    fi
  fi
  # Substitute cluster domain placeholder before applying
  sed "s|__CLUSTER_DOMAIN__|${CLUSTER_DOMAIN}|g" "${SCRIPT_DIR}/06-loan-agent.yaml" | oc apply -f -
  echo ""
fi

# --- STEP 06d: Policy Agent ---
if should_run "06"; then
  echo "━━━ [06d] Deploying Policy Governance Agent ━━━━━━━━━━━━━━━━━"
  oc apply -f "${SCRIPT_DIR}/06d-policy-agent.yaml"
  echo ""
fi

# --- STEP 07: Guardrails ---
if should_run "07"; then
  echo "━━━ [07] Deploying AI Guardrails ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  oc apply -f "${SCRIPT_DIR}/07-guardrails.yaml"
  echo ""
fi

# --- STEP 08: Dify ---
if should_run "08"; then
  echo "━━━ [08] Deploying Dify ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  oc apply -f "${SCRIPT_DIR}/08-dify.yaml"
  echo ""
fi

# --- STEP 09: Tekton Pipelines ---
if should_run "09"; then
  echo "━━━ [09] Deploying Tekton Pipelines ━━━━━━━━━━━━━━━━━━━━━━━━━"
  oc apply -f "${SCRIPT_DIR}/09-tekton-pipelines.yaml"
  echo ""
fi

# --- STEP 10: Rossoctl Services ---
if should_run "10"; then
  echo "━━━ [10] Deploying Rossoctl Platform Services ━━━━━━━━━━━━━━━"
  oc apply -f "${SCRIPT_DIR}/10-rossoctl-services.yaml"
  echo ""
fi

# --- STEP 11: Istio Mesh ---
if should_run "11"; then
  echo "━━━ [11] Deploying Service Mesh + Kiali ━━━━━━━━━━━━━━━━━━━━━"
  oc apply -f "${SCRIPT_DIR}/11-istio-mesh.yaml"
  echo ""
fi

# --- STEP 12: MLflow Evaluator ---
if should_run "12"; then
  echo "━━━ [12] Deploying MLflow Evaluator CronJob ━━━━━━━━━━━━━━━━━"
  oc apply -f "${SCRIPT_DIR}/12-mlflow-evaluator.yaml"
  echo ""
fi

# --- POST-DEPLOY: Wait and verify ---
echo ""
echo "━━━ Post-Deploy Verification ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Waiting 30s for pods to start..."
sleep 30

echo ""
echo "Pod Status:"
oc get pods -n team1 --no-headers | awk '{printf "  %-40s %s\n", $1, $3}'

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Deployment Complete!                                        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Service URLs (update CLUSTER_DOMAIN in env.sh):            ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  Loan Agent:  https://loan-agent-team1.%-20s ║\n" "${CLUSTER_DOMAIN}"
printf "║  Grafana:     https://grafana-team1.%-20s    ║\n" "${CLUSTER_DOMAIN}"
printf "║  Keycloak:    https://keycloak-keycloak.%-20s ║\n" "${CLUSTER_DOMAIN}"
printf "║  KAgenti UI:  https://kagenti-ui-kagenti-system.%-10s ║\n" "${CLUSTER_DOMAIN}"
printf "║  Kiali:       https://kiali-istio-system.%-20s ║\n" "${CLUSTER_DOMAIN}"
printf "║  Dify:        https://dify-dify.%-20s        ║\n" "${CLUSTER_DOMAIN}"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Demo Users (password: DemoPass123):                        ║"
echo "║    teller1 (group: teller)                                  ║"
echo "║    rm1 (group: rm)                                          ║"
echo "║    senior-rm1 (group: senior-rm)                            ║"
echo "║    alice (group: rm)                                        ║"
echo "║    bob (group: teller)                                      ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Next Steps:                                                ║"
echo "║  1. Verify llm-api-key secret in team1 namespace            ║"
echo "║  2. Wait for HAP detector GPU pod (may take 5-10 min)      ║"
echo "║  3. Verify: curl https://loan-agent-team1.\$CLUSTER_DOMAIN  ║"
echo "║  4. Run DEMO_SCRIPT.md for full walkthrough                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
