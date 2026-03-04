# LastStack Demo

LastStack is a staged, agent-first software architecture described in `docs/white-paper.md`. The demo goal: a pure LLVM server and webpage (wasm) written by agents.

This repository now has three separate demos:
- `demo/webserver` - LLVM IR HTTP server + WASM fractal webpage.
- `demo/storage` - LLVM IR IPS durability and recovery runtime.
- `demo/plaintext` - LLVM IR HTTP plaintext server for the TechEmpower plaintext benchmark.

![Fractal output](docs/fractal-demo.png)

## Requirements

- LLVM toolchain (`llc`, `wasm-ld` preferred; `clang` fallback for wasm build)
- `clang` for native binaries
- POSIX shell tools

## Webserver Demo

Build and run:

```bash
cd demo/webserver
./build.sh
./run.sh
```

Open `http://localhost:9090`.

Spec:
- `demo/webserver/spec.md`

Key generated outputs:
- `demo/webserver/public/fractal.wasm`
- `demo/webserver/laststack-server`
- `demo/webserver/verification-report.json`
- `demo/webserver/link-gate-report.json`
- `demo/webserver/artifacts/manifest.json`

## Storage Demo

Build and run:

```bash
cd demo/storage
./build.sh
./run.sh
```

Spec:
- `demo/storage/spec.md`

Key generated outputs:
- `demo/storage/laststack-ips`
- `demo/storage/ips-report.json`

## Plaintext TFB Demo

Build and run:

```bash
cd demo/plaintext
./build.sh
./run.sh
```

Spec:
- `demo/plaintext/spec.md`

Key generated outputs:
- `demo/plaintext/laststack-plaintext`
- `demo/plaintext/verification-report.json`
- `demo/plaintext/link-gate-report.json`
- `demo/plaintext/artifacts/` (wrk logs and CSV)

The CI job `tfb-plaintext` (see `.github/workflows/tfb-plaintext.yml`) runs the TechEmpower plaintext profile (`wrk` at 256, 1k, 4k, 16k concurrency) first against the LLVM IR binary and then against the Rust Hyper `current-thread` implementation in `demo/plaintext/hyper`. Results are captured to `demo/plaintext/artifacts/<label>-wrk.csv` and recorded as workflow logs.

## Benchmarks

Latest recorded k6 benchmark snapshot (from `k6-summary`, run `22687025221`, 2026-03-04T20:07:18Z):

| scenario | intent | rps | p95_latency_s |
|---|---|---:|---:|
| single_vu | smoke / single-client path | 3233.9687563044486 | 0.16712449999999998 |
| steady_state | service latency at fixed load (3000 rps) | 2999.881623917175 | 0.278946 |
| 1000_vus | saturation / stress tail behavior | 8562.751178931177 | 19.700609 |

Interpretation:
- `steady_state` is the latency signal to track for normal service quality.
- `1000_vus` is intentionally a saturation profile; tail latency is expected to degrade there.

CI uploads raw summaries as the `k6-summary` artifact (`k6-single.json`, `k6-steady.json`, `k6-1000.json`).

## Files to Read First

- `docs/white-paper.md`
- `demo/webserver/spec.md`
- `demo/storage/spec.md`
- `demo/plaintext/spec.md`
- `docs/critique.md`
