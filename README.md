# LastStack Demo

A proof-of-concept stack showing how **proof-carrying LLVM IR** can back a tiny HTTP server and a WebAssembly workload. The repo contains:
- `demo/server.ll` — HTTP/1.1 server in LLVM IR with PCF metadata.
- `demo/fractal.ll` → `public/fractal.wasm` — Mandelbrot generator compiled to WASM.
- `demo/public/index.html` — minimal client that blits WASM pixels to a canvas (no extra JS shading).
- `demo/bench.ll` — sequential HTTP benchmark tool for localhost.

## Quickstart
- Build everything (server + wasm): `cd demo && ./build.sh`
- Run the server: `cd demo && ./run.sh` (serves on http://localhost:9090)
- Open the demo: visit `/` to see `fractal.wasm` rendered directly to the canvas.

## Benchmarks
- Local sequential benchmark: build `demo/bench.ll` (see header usage) to produce `./laststack-bench`, then run `./laststack-bench [port 9090] [n_requests 1000]` to measure loopback RPS/latency.
- CI k6 job publishes `benchmark.md` (artifact `k6-summary`) with single-VU and 1000-VU results for each run; use it for canonical numbers.

## Notes
- `demo/build.sh` now always emits `public/fractal.wasm` (llc/wasm-ld first, clang wasm32 fallback).
- The browser UI is intentionally minimal to keep focus on WASM output; JS only fetches, instantiates, and blits the buffer returned by `generate_fractal`.
