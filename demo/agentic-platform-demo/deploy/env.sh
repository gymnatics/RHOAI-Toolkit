#!/bin/bash
###############################################################################
# env.sh — Central configuration for the Agentic AI Platform deployment
# Update these values for your specific cluster before running deploy scripts
#
# SECURITY: API keys are stored in Kubernetes Secrets, not in this file.
#           The LLM_API_KEY secret is created separately via oc create secret.
###############################################################################

# Cluster base domain — set this to your cluster's apps domain
# Example: apps.cluster-xxxxx.xxxxx.sandbox1234.opentlc.com
export CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-__SET_YOUR_CLUSTER_DOMAIN__}"

# Namespaces
export NS_AGENT="team1"
export NS_KEYCLOAK="keycloak"
export NS_MCP="mcp-system"
export NS_KAGENTI="kagenti-system"
export NS_DIFY="dify"
export NS_ISTIO="istio-system"
export NS_REGISTRY="cr-system"

# Keycloak
export KC_REALM="kagenti"
export KC_CLIENT_ID="kagenti"
export KC_ADMIN_USER="temp-admin"
export KC_ADMIN_PASS="$(openssl rand -hex 16)"
export KC_DEMO_PASSWORD="DemoPass123"

# LLM Inference (on-cluster via MaaS — API key stored in K8s Secret "llm-api-key")
# The LLM_API_KEY K8s secret must be created manually before deploy:
#   oc create secret generic llm-api-key -n team1 --from-literal=api-key=YOUR_KEY
export LLM_BASE_URL="https://maas.${CLUSTER_DOMAIN}/model-storage/${LLM_MODEL:-qwen35-35b-a3b}/v1"
export LLM_MODEL="${LLM_MODEL:-qwen35-35b-a3b}"
export LLM_SECRET_NAME="${LLM_SECRET_NAME:-llm-api-key}"

# GPU Node (for HAP detector)
export GPU_NODE_LABEL="nvidia.com/gpu.present=true"

# Container images
export PYTHON_IMAGE="registry.access.redhat.com/ubi9/python-311:latest"
export GRAFANA_IMAGE="docker.io/grafana/grafana:11.1.0"
export LOKI_IMAGE="docker.io/grafana/loki:2.9.4"
export REDIS_IMAGE="docker.io/redis:7-alpine"

# GitHub (for OPA policy sync)
export OPA_POLICY_REPO="https://github.com/avijra/kagenti-opa-policies"

# MLflow
export MLFLOW_TRACKING_URI="http://mlflow.redhat-ods-applications.svc:5000"
export MLFLOW_EXPERIMENT="loan-agent"
