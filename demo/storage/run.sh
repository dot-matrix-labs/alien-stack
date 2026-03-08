#!/bin/bash
# ============================================================================
# Alien Stack Storage Demo: Run
# ============================================================================
# Builds the storage demo and runs a quick recovery scenario.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[Storage] Building..."
bash build.sh
echo ""

STATE_FILE="/tmp/alienstack-ips-demo.bin"

echo "[Storage] Running scenario against $STATE_FILE"
./alienstack-ips "$STATE_FILE" init
./alienstack-ips "$STATE_FILE" add 1
./alienstack-ips "$STATE_FILE" recover
