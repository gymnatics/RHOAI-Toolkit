#!/bin/bash
################################################################################
# install-rhoai-34.sh — Thin wrapper for backward compatibility
# Delegates to the unified install-rhoai.sh with stable-3.4 channel.
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Forward all arguments, defaulting to stable-3.4 if no --channel specified
has_channel=false
for arg in "$@"; do
    [ "$arg" = "--channel" ] && has_channel=true
done

if [ "$has_channel" = true ]; then
    exec "$SCRIPT_DIR/install-rhoai.sh" "$@"
else
    exec "$SCRIPT_DIR/install-rhoai.sh" --channel stable-3.4 "$@"
fi
