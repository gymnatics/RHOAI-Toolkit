#!/bin/bash
set -euo pipefail

###############################################################################
# deploy-all.sh
# Single command to deploy the entire DBS Agentic AI Platform on a fresh cluster
#
# Prerequisites:
#   1. oc CLI installed and logged in as cluster-admin
#   2. helm CLI installed (for MCP Gateway)
#   3. Update env.sh with your cluster domain
#   4. Create the LLM API key secret:
#      oc create secret generic llm-api-key -n team1 --from-literal=api-key=YOUR_KEY
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

# Validate CLUSTER_DOMAIN is set
if [[ "${CLUSTER_DOMAIN}" == "__SET_YOUR_CLUSTER_DOMAIN__" || -z "${CLUSTER_DOMAIN}" ]]; then
  echo "ERROR: CLUSTER_DOMAIN is not configured."
  echo "  Edit env.sh and set CLUSTER_DOMAIN to your cluster's apps domain."
  echo "  Example: apps.cluster-xxxxx.xxxxx.sandbox1234.opentlc.com"
  exit 1
fi

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
  sed "s|__CLUSTER_DOMAIN__|${CLUSTER_DOMAIN}|g" "${SCRIPT_DIR}/02-keycloak.yaml" | oc apply -f -
  echo "⏳ Waiting for Keycloak to start..."
  oc wait --for=condition=ready pod -l app=keycloak -n keycloak --timeout=300s 2>/dev/null || \
    echo "  Keycloak may still be starting, continuing..."
  echo ""
fi

# --- STEP 03: MCP Gateway (Helm + supplemental resources) ---
if should_run "03"; then
  echo "━━━ [03] Deploying MCP Gateway (Helm v0.8.0) ━━━━━━━━━━━━━━━"
  # Create namespace first
  oc create namespace mcp-system 2>/dev/null || true

  # Install MCP Gateway via Helm
  if helm status mcp-gateway -n mcp-system &>/dev/null; then
    echo "  MCP Gateway Helm release already exists, upgrading..."
    helm upgrade mcp-gateway oci://ghcr.io/kuadrant/charts/mcp-gateway \
      --version 0.8.0 -n mcp-system --wait --timeout 120s 2>/dev/null || \
      echo "  Helm upgrade had warnings (may be ok)"
  else
    helm install mcp-gateway oci://ghcr.io/kuadrant/charts/mcp-gateway \
      --version 0.8.0 -n mcp-system --wait --timeout 120s 2>/dev/null || \
      echo "  Helm install had warnings (may be ok)"
  fi

  # Apply Gateway + MCPGatewayExtension with cluster domain
  sed "s|__CLUSTER_DOMAIN__|${CLUSTER_DOMAIN}|g" "${SCRIPT_DIR}/03-mcp-gateway.yaml" | oc apply -f -
  echo ""
fi

# --- STEP 04: KAgenti ---
if should_run "04"; then
  echo "━━━ [04] Deploying KAgenti/Rossoctl Platform ━━━━━━━━━━━━━━━━"
  sed "s|__CLUSTER_DOMAIN__|${CLUSTER_DOMAIN}|g" "${SCRIPT_DIR}/04-kagenti.yaml" | oc apply -f -

  # Create LLM API key in kagenti-system for policy agent
  if ! oc get secret llm-api-key -n kagenti-system &>/dev/null; then
    if [ -n "${LLM_API_KEY:-}" ]; then
      oc create secret generic llm-api-key -n kagenti-system --from-literal=api-key="${LLM_API_KEY}"
    fi
  fi
  echo ""
fi

# --- STEP 05: Loki + Grafana ---
if should_run "05"; then
  echo "━━━ [05] Deploying Observability (Loki + Grafana) ━━━━━━━━━━━"
  oc apply -f "${SCRIPT_DIR}/05-loki-grafana.yaml"
  if [[ -f "${SCRIPT_DIR}/06b-grafana-dashboards.yaml" ]]; then
    sed "s|__CLUSTER_DOMAIN__|${CLUSTER_DOMAIN}|g" "${SCRIPT_DIR}/06b-grafana-dashboards.yaml" | oc apply -f -
  fi
  echo ""
fi

# --- STEP 06: Loan Agent ---
if should_run "06"; then
  echo "━━━ [06] Deploying Loan Agent + Tools ━━━━━━━━━━━━━━━━━━━━━━━"

  # Create LLM API key secret if not exists
  if ! oc get secret llm-api-key -n team1 &>/dev/null; then
    if [ -n "${LLM_API_KEY:-}" ]; then
      oc create secret generic llm-api-key -n team1 --from-literal=api-key="${LLM_API_KEY}"
    else
      echo "  ⚠ WARNING: LLM_API_KEY not set. Create the secret manually:"
      echo "    oc create secret generic llm-api-key -n team1 --from-literal=api-key=YOUR_KEY"
    fi
  fi

  # Create OIDC secret for agent (client_credentials to MCP Gateway)
  if ! oc get secret loan-agent-oidc -n team1 &>/dev/null; then
    oc create secret generic loan-agent-oidc -n team1 \
      --from-literal=client-id=kagenti \
      --from-literal=client-secret=kagenti-secret
  fi

  # Substitute cluster domain placeholder before applying
  sed "s|__CLUSTER_DOMAIN__|${CLUSTER_DOMAIN}|g" "${SCRIPT_DIR}/06-loan-agent.yaml" | oc apply -f -
  echo ""
fi

# --- STEP 06d: Policy Agent ---
if should_run "06"; then
  echo "━━━ [06d] Deploying Policy Governance Agent ━━━━━━━━━━━━━━━━━"
  if [[ -f "${SCRIPT_DIR}/06d-policy-agent.yaml" ]]; then
    sed "s|__CLUSTER_DOMAIN__|${CLUSTER_DOMAIN}|g" "${SCRIPT_DIR}/06d-policy-agent.yaml" | oc apply -f -
  fi
  echo ""
fi

# --- STEP 07: Guardrails ---
if should_run "07"; then
  echo "━━━ [07] Deploying AI Guardrails ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Create TLS secrets for guardrails orchestrator (self-signed)
  if ! oc get secret loan-agent-guardrails-tls -n team1 &>/dev/null; then
    echo "  Generating TLS cert for guardrails orchestrator..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /tmp/guardrails-tls.key \
      -out /tmp/guardrails-tls.crt \
      -subj "/CN=loan-agent-guardrails.team1.svc" \
      -addext "subjectAltName=DNS:loan-agent-guardrails.team1.svc,DNS:loan-agent-guardrails-service.team1.svc" 2>/dev/null
    oc create secret tls loan-agent-guardrails-tls -n team1 \
      --cert=/tmp/guardrails-tls.crt --key=/tmp/guardrails-tls.key
    oc create secret generic loan-agent-guardrails-ca-bundle -n team1 \
      --from-file=ca-bundle.crt=/tmp/guardrails-tls.crt
    rm -f /tmp/guardrails-tls.key /tmp/guardrails-tls.crt
  fi

  # Create LLM API key in team1 if not already present (for LLM Judge)
  if ! oc get secret llm-api-key -n team1 &>/dev/null; then
    if [ -n "${LLM_API_KEY:-}" ]; then
      oc create secret generic llm-api-key -n team1 --from-literal=api-key="${LLM_API_KEY}"
    fi
  fi

  sed "s|__CLUSTER_DOMAIN__|${CLUSTER_DOMAIN}|g" "${SCRIPT_DIR}/07-guardrails.yaml" | oc apply -f -
  echo ""
fi

# --- STEP 08: Dify ---
if should_run "08"; then
  echo "━━━ [08] Deploying Dify ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  sed "s|__CLUSTER_DOMAIN__|${CLUSTER_DOMAIN}|g" "${SCRIPT_DIR}/08-dify.yaml" | oc apply -f -

  # Wait for API pod then run DB migration
  echo "  ⏳ Waiting for Dify API pod..."
  oc wait --for=condition=ready pod -l app=dify-api -n dify --timeout=180s 2>/dev/null || true
  DIFY_POD=$(oc get pods -n dify -l app=dify-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -n "$DIFY_POD" ]]; then
    echo "  Running Dify DB migration (flask db upgrade)..."
    oc exec -n dify "$DIFY_POD" -- flask db upgrade 2>/dev/null || \
      echo "  ⚠ DB migration failed or already up to date"
  fi
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
  sed "s|__CLUSTER_DOMAIN__|${CLUSTER_DOMAIN}|g" "${SCRIPT_DIR}/12-mlflow-evaluator.yaml" | oc apply -f -
  echo ""
fi

# --- POST-DEPLOY: Verify ---
echo ""
echo "━━━ Post-Deploy Verification ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Waiting 30s for pods to start..."
sleep 30

echo ""
echo "Pod Status (team1):"
oc get pods -n team1 --no-headers 2>/dev/null | awk '{printf "  %-40s %s\n", $1, $3}' || true

echo ""
echo "Pod Status (kagenti-system):"
oc get pods -n kagenti-system --no-headers 2>/dev/null | awk '{printf "  %-40s %s\n", $1, $3}' || true

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Deployment Complete!                                        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Service URLs:                                               ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  Loan Agent:  https://loan-agent-team1.%-20s ║\n" "${CLUSTER_DOMAIN}"
printf "║  Grafana:     https://grafana-team1.%-20s    ║\n" "${CLUSTER_DOMAIN}"
printf "║  Keycloak:    https://keycloak-keycloak.%-20s ║\n" "${CLUSTER_DOMAIN}"
printf "║  KAgenti UI:  https://kagenti-ui-kagenti-system.%-10s ║\n" "${CLUSTER_DOMAIN}"
printf "║  Dify:        https://dify-dify.%-20s        ║\n" "${CLUSTER_DOMAIN}"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Demo Users (password: DemoPass123):                        ║"
echo "║    teller1 (group: teller) — credit checks only             ║"
echo "║    rm1 (group: rm) — credit + KYC + calculator              ║"
echo "║    senior-rm1 (group: senior-rm) — full access              ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Next Steps:                                                ║"
echo "║  1. Verify llm-api-key secret in team1 namespace            ║"
echo "║  2. Wait for HAP detector pod (CPU, ~2 min startup)        ║"
echo "║  3. Verify: curl https://loan-agent-team1.\$CLUSTER_DOMAIN  ║"
echo "║  4. Run DEMO_SCRIPT.md for full walkthrough                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
