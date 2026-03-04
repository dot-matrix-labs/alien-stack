# LastStack Test Runner Specification

## Overview

Comprehensive test infrastructure for LastStack projects, supporting:
- **Unit tests** - Component-level testing
- **E2E tests** - Integration and browser testing
- **Formal verification** - PCF metadata and invariant validation

---

## Test Categories

### 1. Unit Tests

Test individual components in isolation.

**Scope:**
- Fractal algorithm correctness
- WASM module exports
- Server endpoint handlers
- Metadata annotation validity

**Execution:**
```bash
# Run all unit tests
./test/unit.sh

# Run specific unit test
./test/unit.sh fractal
./test/unit.sh server
```

**Expected output:**
```
[Unit Test] Running fractal algorithm tests...
  ✓ Mandelbrot boundary detection
  ✓ Escape time calculation
  ✓ Color mapping
  ✓ Buffer allocation
[Unit Test] 4/4 tests passed
```

### 2. End-to-End Tests

Test the complete system in a browser environment.

**Scope:**
- Server serves correct MIME types
- HTML loads without errors
- WASM instantiates successfully
- Fractal renders to canvas
- No console errors

**Execution:**
```bash
# Run E2E tests (requires browser/Playwright)
./test/e2e.sh

# Run with specific browser
./test/e2e.sh --browser chromium
```

**Expected output:**
```
[E2E Test] Starting server on port 9090...
[E2E Test] Testing GET / ...
  ✓ Status 200
  ✓ Content-Type: text/html
[E2E Test] Testing GET /fractal.wasm ...
  ✓ Status 200
  ✓ Content-Type: application/wasm
[E2E Test] Testing fractal rendering in browser...
  ✓ WASM loaded successfully
  ✓ Canvas has pixel data
  ✓ No console errors
[E2E Test] 6/6 tests passed
```

### 3. Formal Verification Tests

Validate PCF metadata and proofs.

**Scope:**
- Metadata present in IR
- Metadata survives optimization
- Invariants well-formed
- Proof annotations valid

**Execution:**
```bash
# Run formal verification
./test/verify.sh

# Check metadata survival
./test/verify.sh --check-optimization
```

**Expected output:**
```
[Verification] Loading server.ll...
[Verification] Checking PCF metadata...
  ✓ Found 12 !pcf metadata nodes
  ✓ Found 8 !ips metadata nodes
[Verification] Running optimization...
[Verification] Checking metadata survival...
  ✓ 12/12 metadata nodes survived optimization
[Verification] Checking invariants...
  ✓ @invariant annotations well-formed
  ✓ @pre/@post pairs balanced
[Verification] 4/4 checks passed
```

---

## Test Runner Interface

### Main Entry Point

**File:** `test/run.sh`

```bash
# Run all tests
./test/run.sh

# Run specific category
./test/run.sh unit
./test/run.sh e2e
./test/run.sh verify

# Run with verbose output
./test/run.sh --verbose

# Generate report
./test/run.sh --report
```

### Test Discovery

Tests are discovered from:
- `test/unit/*.sh` - Unit test scripts
- `test/e2e/*.sh` - E2E test scripts  
- `test/verify/*.sh` - Verification scripts

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | Some tests failed |
| 2 | Test infrastructure error |
| 3 | Missing dependencies |

---

## Test Configuration

### Environment Variables

```bash
# Server configuration
LASTSTACK_PORT=9090
LASTSTACK_HOST=localhost
LASTSTACK_ROOT=./demo/public

# Browser configuration (E2E)
BROWSER=chromium
HEADLESS=true

# Verification strictness
VERIFY_STRICT=true
VERIFY_WARNINGS_AS_ERRORS=false
```

### Test Fixtures

Located in `test/fixtures/`:
- `test/fixtures/index.html` - Expected HTML structure
- `test/fixtures/fractal.wasm` - Known-good WASM binary
- `test/fixtures/server.ll` - Reference IR with metadata

---

## Implementation

### Directory Structure

```
test/
├── run.sh              # Main entry point
├── unit.sh             # Unit test runner
├── e2e.sh              # E2E test runner
├── verify.sh           # Formal verification runner
├── common.sh           # Shared utilities
├── unit/
│   ├── fractal.sh      # Fractal algorithm tests
│   ├── wasm.sh         # WASM module tests
│   └── metadata.sh     # Metadata validation
├── e2e/
│   ├── server.sh       # Server endpoint tests
│   └── browser.sh      # Browser rendering tests
├── verify/
│   ├── metadata.sh     # PCF metadata checks
│   └── optimization.sh # Metadata survival
└── fixtures/            # Test data
```

### Unit Test Framework

Each unit test follows this template:

```bash
#!/bin/bash
# test/unit/fractal.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

test_mandelbrot_boundary() {
    # Test that points on boundary are detected
    local result=$(echo "$INPUT" | ./fractal_tool --check-boundary)
    assert_eq "$result" "true"
}

test_escape_time() {
    # Test escape time calculation
    local result=$(./fractal_tool --point 0,0 --max-iter 100)
    assert_eq "$result" "100"  # 0,0 never escapes
}

run_tests() {
    echo "[Unit Test] Running fractal tests..."
    test_mandelbrot_boundary
    test_escape_time
    # ...
    echo "[Unit Test] All tests passed"
}
```

### E2E Test Framework

Uses Playwright or similar for browser automation:

```bash
#!/bin/bash
# test/e2e/browser.sh

test_wasm_loads() {
    local html=$(curl -s http://localhost:9090/)
    local wasm=$(curl -s http://localhost:9090/fractal.wasm)
    
    # Check WASM magic number
    local magic=$(printf '%s' "$wasm" | head -c 4)
    assert_eq "$magic" "$(printf '\0asm')"
}

test_fractal_renders() {
    npx playwright test --grep "fractal renders"
}
```

### Verification Framework

Analyzes LLVM IR metadata:

```bash
#!/bin/bash
# test/verify/metadata.sh

verify_metadata_count() {
    local count=$(llvm-dis-14 server.bc -o - | grep -c '!{!"pcf\.' || true)
    assert_ge "$count" 10
}

verify_metadata_survival() {
    local before=$(llvm-dis-14 server.bc -o - | grep -c '!{!"pcf\.')
    local after=$(llvm-dis-14 server-opt.bc -o - | grep -c '!{!"pcf\.')
    assert_eq "$before" "$after"
}
```

---

## CI Integration

### GitHub Actions

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install dependencies
        run: |
          sudo apt-get install -y llvm-14 clang-14
          npm install playwright
      
      - name: Run unit tests
        run: ./test/unit.sh
      
      - name: Run verification
        run: ./test/verify.sh
      
      - name: Run E2E tests
        run: ./test/e2e.sh
```

---

## Dependencies

### Required
- `llvm-as-14` / `llvm-dis-14` - IR parsing
- `opt-14` - Optimization
- `llc-14` - Compilation

### Optional (E2E)
- `playwright` - Browser automation
- `chromium` / `firefox` - Browser binaries

### Optional (Verification)
- `llvm-lit` - LLVM test infrastructure (optional)
- `klee` - Symbolic execution (optional)

---

## Future Enhancements

- Property-based testing for fractal algorithm
- Fuzzing for server input handling
- Symbolic execution verification with KLEE
- Differential testing (WASM vs reference implementation)
- Performance benchmarking
