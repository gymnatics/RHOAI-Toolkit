#!/bin/bash
################################################################################
# install-rhoai-33.sh — Thin wrapper for backward compatibility
# Delegates to the unified install-rhoai.sh with stable-3.3 channel.
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Forward all arguments, defaulting to stable-3.3 if no --channel specified
has_channel=false
for arg in "$@"; do
    [ "$arg" = "--channel" ] && has_channel=true
done

if [ "$has_channel" = true ]; then
    exec "$SCRIPT_DIR/install-rhoai.sh" "$@"
else
    exec "$SCRIPT_DIR/install-rhoai.sh" --channel stable-3.3 "$@"
fi
