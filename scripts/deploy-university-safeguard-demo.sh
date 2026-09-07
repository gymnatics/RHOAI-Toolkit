#!/bin/bash
################################################################################
# Deploy University Safeguard Demo (Standalone Entry Point)
################################################################################
# Thin wrapper around demo/university-safeguard-demo/deploy.sh
#
# Usage:
#   ./deploy-university-safeguard-demo.sh
#   ./deploy-university-safeguard-demo.sh -n my-namespace
#   ./deploy-university-safeguard-demo.sh --delete
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

exec "$ROOT_DIR/demo/university-safeguard-demo/deploy.sh" "$@"
