#!/bin/bash
# ============================================================================
# Alien Stack Demo: Run Server
# ============================================================================
# Builds (if needed) and runs the Alien Stack webserver.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Always build first to avoid stale/incompatible binaries.
echo "[Alien Stack] Building..."
bash build.sh
echo ""

# Start server
echo "[Alien Stack] Starting server..."
echo "[Alien Stack] Press Ctrl+C to stop."
echo ""
exec ./alienstack-server
