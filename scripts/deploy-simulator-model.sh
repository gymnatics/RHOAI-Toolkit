#!/bin/bash
################################################################################
# DEPRECATED: use scripts/deploy-maas-model.sh --model simulator instead.
################################################################################
# Kept as a thin wrapper for backward compatibility. This script's manifests
# were restructured into lib/manifests/maas/models/simulator/ (llm/ + maas/
# subdirs with kustomization.yaml) as part of the hybrid Kustomize migration.
# See .cursor/rules/manifests-source-of-truth.mdc for the rationale.
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "NOTE: scripts/deploy-simulator-model.sh is deprecated." >&2
echo "      Use: scripts/deploy-maas-model.sh --model simulator [-n namespace] [--delete]" >&2
echo "" >&2

ARGS=(--model simulator)
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) ARGS+=(-n "$2"); shift 2 ;;
        --delete) ARGS+=(--delete); shift ;;
        -h|--help)
            echo "Usage: $0 [-n namespace] [--delete]"
            echo "(Deprecated wrapper -- forwards to deploy-maas-model.sh --model simulator)"
            exit 0
            ;;
        *) shift ;;
    esac
done

exec "$SCRIPT_DIR/deploy-maas-model.sh" "${ARGS[@]}"
