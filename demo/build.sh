#!/bin/bash
# ============================================================================
# LastStack Demo: Build Pipeline
# ============================================================================
# Compiles LLVM IR → optimized IR → native binary
#
# Pipeline:
#   1. Verify IR is well-formed (llvm-as)
#   2. Optimize IR (opt -O2)
#   3. Compile to native object (llc)
#   4. Link to executable (clang)
#
# In a full LastStack system, steps 1-2 would include proof-checking passes
# and invariant metadata validation. The metadata survives optimization
# as LLVM preserves named metadata through standard passes.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[LastStack Build] Starting build pipeline..."

# Step 0: Compile fractal.ll to WASM
echo "[LastStack Build] Step 0: Compiling fractal.ll to WASM..."
llc-14 --march=wasm32 --filetype=obj -O2 fractal.ll -o public/fractal.o 2>&1
wasm-ld-14 --no-entry --export-all public/fractal.o -o public/fractal.wasm 2>&1
echo "[LastStack Build]   ✓ fractal.wasm built"

# Step 1: Parse and verify IR → bitcode
echo "[LastStack Build] Step 1: Verifying IR well-formedness..."
llvm-as-14 server.ll -o server.bc 2>&1
echo "[LastStack Build]   ✓ IR parsed and verified"

# Step 2: Optimize (preserving metadata)
echo "[LastStack Build] Step 2: Optimizing IR (O2)..."
opt-14 -O2 server.bc -o server-opt.bc 2>&1
echo "[LastStack Build]   ✓ IR optimized"

# Step 3: Compile to native object
echo "[LastStack Build] Step 3: Compiling to native object..."
llc-14 -O2 -relocation-model=pic -filetype=obj server-opt.bc -o server.o 2>&1
echo "[LastStack Build]   ✓ Native object generated"

# Step 4: Link
echo "[LastStack Build] Step 4: Linking executable..."
clang server.o -o laststack-server 2>&1
echo "[LastStack Build]   ✓ Executable linked"

# Report
echo ""
echo "[LastStack Build] Build complete!"
echo "[LastStack Build] Binary: $SCRIPT_DIR/laststack-server"
echo "[LastStack Build] Size: $(stat -c%s laststack-server) bytes"
echo ""

# Step 5: Verify metadata survived optimization
echo "[LastStack Build] Step 5: Checking PCF metadata survival..."
METADATA_COUNT=$(llvm-dis-14 server-opt.bc -o - 2>/dev/null | grep -c '!{!"pcf\.\|!{!"ips\.' || true)
echo "[LastStack Build]   Found $METADATA_COUNT PCF/IPS metadata nodes in optimized IR"
if [ "$METADATA_COUNT" -gt 0 ]; then
    echo "[LastStack Build]   ✓ Proof-carrying metadata survived optimization"
else
    echo "[LastStack Build]   ⚠ Metadata was stripped (expected with standard passes)"
    echo "[LastStack Build]     In production, custom metadata-preserving passes would retain these"
fi

echo ""
echo "[LastStack Build] To run: ./laststack-server"
echo "[LastStack Build] Then visit: http://localhost:9090"
