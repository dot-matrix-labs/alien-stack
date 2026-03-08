#!/bin/bash
# =============================================================================
# Run the Alien Stack plaintext demo server
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

bash build.sh

echo "[Plaintext Run] Starting plaintext server..."
exec ./alienstack-plaintext
