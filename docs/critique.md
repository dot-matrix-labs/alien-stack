# LastStack Critique (Re-evaluation against White Paper v1.1)

## Purpose

This document re-evaluates the current architecture spec (`docs/white-paper.md`, v1.1) against the live demo implementation (`demo/server.ll`, `demo/fractal.ll`, `demo/build.sh`, `demo/verify.sh`, `.github/workflows/k6.yml`).

## Executive Assessment

- The paper is now a strong normative architecture spec.
- The demo is still a prototype of IR-first delivery, not a proof-carrying system.
- The largest gap is enforcement: metadata is present in parts, but verification/link/release remain non-gating.

## White Paper Re-evaluation (v1.1)

### What Is Solid

- PCF model is now concrete: schema keys, proof envelope, and binding semantics are all specified.
- Effect model now has canonical atoms and matching rules.
- Verifier input/output contract and link-gate decision logic are defined.
- IPS durability/recovery protocol has minimum required fields and commit/replay flow.
- Agent-interface rationale (text-first, sequential LLM behavior) is explicit and coherent.

### Remaining Ambiguities (Lower Severity)

- Formula dialect profile is implied but not fully pinned: the allowed SMT logic fragments and quantifier policy should be fixed in a verifier profile appendix.
- Effect normalization depends on wrapper/platform maps, but the canonical source-of-truth location/versioning policy for those maps is not yet defined.
- Link-gate entailment checks are specified semantically, but complexity bounds/fallback policy (timeouts, unknown outcomes) are not explicitly defined.

These are operational clarifications, not core architecture gaps.

## Demo Conformance Matrix

| Spec area | Required by paper | Current demo status | Result |
|---|---|---|---|
| PCF coverage | Exported/critical functions carry full PCF metadata | `demo/fractal.ll` has no PCF metadata; `@read_file` and `@get_content_type` in `demo/server.ll` are not PCFs | Fail |
| `pcf.effects` | Declared and checked for every PCF | No `!pcf.effects` in demo code | Fail |
| `pcf.bind` | Symbols bound to SSA/memory regions | No `!pcf.bind` in demo code | Fail |
| Proof discharge | Solver/checker verdict gates build/link | `demo/verify.sh` is report-only and prints PASS text | Fail |
| Link gate | Enforce schema/pre/post/effect compatibility | No implemented link-gate stage | Fail |
| Artifact seal | Emit manifest with digests (IR/proof/toolchain/TCB) | No sealing/manifest step in build/CI | Fail |
| TCB scoping ops | Capture/version TCB in release artifacts | TCB exists only as paper text | Fail |
| IPS runtime | Typed persistent state with recovery validation | No IPS implementation in demo runtime | Fail |
| Benchmark accountability | CI benchmarks + committed snapshot | k6 CI writes `docs/benchmark.md` and uploads artifact | Pass |
| IR-first authored stack | Server and wasm authored in LLVM IR | Implemented (`demo/server.ll`, `demo/fractal.ll`) | Pass |

## Evidence Notes

- `demo/fractal.ll` contains no `!pcf.*` metadata.
- `demo/server.ll` defines `@read_file` and `@get_content_type` without PCF metadata.
- `demo/verify.sh` ends with a static PASS message and does not invoke solver/checker tooling.
- CI workflow uploads benchmark artifacts but has no verification/link-gate/artifact-seal stages.

## Verdict

The architecture is credible and now mostly specified. The implementation remains pre-compliance.

Accurate statement today:
- Implemented: LLVM-IR server + LLVM-IR wasm + wasm-first browser rendering + CI benchmark persistence.
- Not implemented: proof-carrying linkage, effect/binding enforcement, artifact sealing, TCB manifesting, IPS durability/recovery runtime.

## Recommended Next Milestones

1. Add `!pcf.effects` and `!pcf.bind` to all existing PCFs, then cover `@read_file`, `@get_content_type`, and exported fractal functions.
2. Replace `demo/verify.sh` with a fail-closed verifier stage that emits machine-readable verdicts.
3. Add a link-gate stage that consumes verifier outputs and rejects incompatible edges.
4. Add artifact sealing (`manifest.json`) including IR/proof/toolchain/TCB digests.
5. Implement a minimal IPS-backed object with crash-recovery validation to exercise section 5 claims.
