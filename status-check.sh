#!/bin/bash
# Quick Status Check - Run this anytime to verify your setup
# Usage: ./status-check.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if preflight script exists
if [ -f "$SCRIPT_DIR/lib/preflight-check.sh" ]; then
    bash "$SCRIPT_DIR/lib/preflight-check.sh"
elif [ -f "/usr/local/bin/lib/preflight-check.sh" ]; then
    bash "/usr/local/bin/lib/preflight-check.sh"
else
    echo "Error: Pre-flight check script not found"
    exit 1
fi
