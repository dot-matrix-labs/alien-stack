# Plaintext Demo Specification

## Goal
Deliver a handwritten LLVM IR HTTP server that satisfies the TechEmpower FrameworkBenchmarks `plaintext` test. The server must respond to `GET /plaintext` (and any path) with `200 OK`, a `Content-Type: text/plain` header, and the constant body `Hello, World!` without heap allocations or standard library abstractions.

## Requirements
- Listen on port `18081` without needing env vars.
- Single-threaded accept loop; no connection pooling or `tokio`.
- Response is a single prebuilt buffer owned by the binary.
- PCF metadata attached to every gate-controlled function (`respond_plaintext`, `handle_client`, `main`).
- Verification (`verify.sh`) and link gate (`link-gate.sh`) must enforce metadata coverage.

## Build pipeline
- `clang` compiles `plaintext.ll` to `alienstack-plaintext` with `-O2`.
- `build.sh` runs the verification and link gates to fail closed if metadata is missing.
- `run.sh` builds and executes the server on the configured port.

## Benchmarks
CI runs the TFB plaintext profile (256, 1k, 4k, 16k concurrency wheels of `wrk`) against:
1. The LLVM IR plaintext server (this code).
2. Rust Hyper `current-thread` implementation (`demo/plaintext/hyper`).

The CI job captures `wrk` logs for each concurrency level to prove parity with the identical Hyper baseline.
