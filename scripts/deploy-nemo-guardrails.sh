#!/bin/bash
################################################################################
# Deploy NeMo Guardrails (Standalone Entry Point)
################################################################################
# Thin wrapper around demo/nemo-guardrails-demo/deploy.sh
#
# Usage:
#   ./deploy-nemo-guardrails.sh [namespace]
#   ./deploy-nemo-guardrails.sh --selfcheck
#   ./deploy-nemo-guardrails.sh --delete
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

exec "$ROOT_DIR/demo/nemo-guardrails-demo/deploy.sh" "$@"
