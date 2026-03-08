# The Alien Stack: Final Architecture for Agent-Native Software

**Version 1.0 - March 2026**

## Abstract

Alien Stack defines a single end-state architecture for software built primarily by coding agents. The core claim is simple: source, verification, and deployment should all operate on one machine-native representation, LLVM IR, with proofs attached to every exported behavior. Text is documentation, not authority. Build success means contracts are discharged, effects are declared, and artifacts are reproducible. This document specifies that final architecture directly, including trust boundaries, runtime model, and proof requirements.

## 1. Problem Statement

Current software stacks optimize for human authoring:
- Text files as canonical source.
- Implicit semantics distributed across compilers, tests, and conventions.
- Correctness inferred from sampled execution.
- Runtime behavior validated post hoc in production.

For agent-driven implementation, this creates recurring failure modes:
- Reconstructing structure from text on every turn.
- Weak guarantees at module boundaries.
- Drift between documentation, code, and verification artifacts.
- High verification cost paid late in the cycle.

Alien Stack removes these mismatches by making verification and structure first-class properties of the build graph.

### 1.1 Agent Interface Constraints (Today)

The architecture is designed for current LLM-based agents, not hypothetical future models. Today:
- Agents read and write text files through sequential token streams.
- Agents reason primarily over local spans and diffs, then stitch global behavior from repeated passes.
- Agents cannot reliably "mount" a full external knowledge graph as native working memory; they reconstruct task-specific graphs from code each session.
- Agents need explicit semantics (contracts, effects, invariants) attached to code to reduce ambiguity and search cost.

This is why Alien Stack does not introduce a new proprietary binary source format or AST-as-canonical-source model:
- A binary source format is opaque to current language models and weak for review, diff, and patch workflows.
- AST dumps still require parser/tooling mediation and often hide low-level execution semantics that matter for verification and codegen.
- Current models operate in language order; giving them semantically rich text/IR with machine-checkable metadata fits how they actually work.

So the final architecture uses LLVM IR as canonical behavior, while keeping a text representation (`.ll`) as the agent-facing interface.

## 2. Final Philosophy

Alien Stack is defined by six rules:

1. **One canonical representation.**
   LLVM IR is the only authoritative source representation for executable behavior.

2. **Proof-carrying linkage.**
   A function may be linked only when its contract and proof artifact pass machine verification.

3. **Declared effects, not inferred intent.**
   Every function declares external effects (syscalls, global writes, I/O classes, allocator use).

4. **Deterministic artifacts.**
   Build outputs, proof outputs, and benchmark reports are reproducible from commit + toolchain digest.

5. **Typed persistent state with invariants.**
   Persistent layouts are typed binary structures with invariants validated on mutation and recovery.

6. **Small explicit trust base.**
   The trusted computing base (TCB) is versioned and auditable.

No staged migration model is part of this specification. This is the target architecture.

## 3. Core Units

### 3.1 Proof-Carrying Function (PCF)

A PCF is the atomic software unit:
- LLVM IR function body.
- Precondition and postcondition formulas.
- Effect declaration.
- Symbol binding map from formulas to SSA values and memory regions.
- Proof witness.
- Verifier metadata (solver/checker identity and digest).

A minimal interface shape:

```llvm
; define i32 @f(i32 %x) !pcf.pre !1 !pcf.post !2 !pcf.effects !3 !pcf.bind !4 !pcf.proof !5
```

Required semantics:
- `pcf.pre`: entry assumptions.
- `pcf.post`: guarantees on normal and exceptional exits.
- `pcf.effects`: exhaustive side effects.
- `pcf.bind`: unambiguous mapping from contract symbols to SSA/memory entities.
- `pcf.proof`: checkable witness or certificate reference.

A PCF without complete metadata is non-linkable.

### 3.2 Invariant-Preserving Structure (IPS)

An IPS defines durable typed state:
- Binary layout schema.
- Invariant set over fields and relations.
- Certified accessors/mutators (PCFs).
- Recovery validation rules.

Mutation rule:
- Every mutator must prove invariant preservation.

Recovery rule:
- On restart, structure must validate checksum/version/invariants before exposure.

### 3.3 Effect Surface

Effects are part of the contract surface, not comments. At minimum:
- Syscalls used.
- Global memory writes.
- Network/filesystem capabilities.
- Nondeterministic inputs (clock, random, env).

Effect mismatch between declaration and body is a hard verification failure.

## 4. Architecture

### 4.1 Build and Verification Graph

The canonical pipeline is:

1. **Normalize IR**
   Parse modules, canonicalize symbols, freeze target triples and data layouts.

2. **Structural lint**
   Verify declared calls/reads/writes/effects against actual IR use-def and call graph.

3. **Contract extraction**
   Materialize SMT obligations from `pcf.pre/post`, control-flow, and memory model.

4. **Proof check / discharge**
   Validate proof witness or discharge obligations with configured solver profile.

5. **Link gate**
   Link only modules whose exported PCFs pass verification and effect compatibility checks.

6. **Artifact seal**
   Emit binaries plus manifest containing digests for IR, proofs, toolchain, and benchmark snapshot.

No step is advisory. Failure at any step blocks release artifacts.

### 4.2 Module Boundary Rules

At every boundary (native module, wasm module, RPC boundary):
- Caller must satisfy callee precondition.
- Callee guarantees postcondition and declared effects only.
- Boundary shims are generated from PCF metadata; they are not handwritten policy code.

### 4.3 Runtime Contract Mode

Runtime has two modes:
- **Verified mode**: proof-checked contracts trusted; only boundary assertions remain.
- **Audit mode**: selected contracts are rechecked at runtime for sampling and drift detection.

## 5. Persistence and Recovery Model

Alien Stack persistence uses typed binary objects with explicit durability protocol:
- Copy-on-write or journaled mutation records.
- Checksummed pages/segments.
- Monotonic version stamps.
- Crash recovery that replays or rolls back to last valid invariant-preserving state.

Durability guarantees are part of IPS metadata and must be machine-checked in recovery tests.

## 6. Trusted Computing Base (TCB)

The TCB is explicitly scoped to:
- LLVM frontend/parser and codegen components used in the build profile.
- PCF/IPS verifier implementation.
- Proof checker and/or SMT solver binaries.
- Linker and manifest sealer.
- Kernel/runtime primitives used by produced binaries.

Everything else is untrusted input. TCB versions and hashes are included in sealed manifests.

## 7. Operational Policy

### 7.1 Reproducibility

A release must be reproducible from:
- Commit SHA.
- Toolchain manifest.
- Verification profile.
- Benchmark workload definition.

### 7.2 Benchmark Policy (Operational)

Performance reporting rules:
- Benchmarks run in CI using committed workload definitions.
- Summary is committed in-repo (`docs/benchmark.md`).
- Raw metric artifacts are preserved (`k6-summary`).
- Claims in docs must match committed benchmark snapshots.

## 8. Demo Mapping (What Is Proven in This Repository)

This repository demonstrates practical viability of the architecture shape:
- A native HTTP server authored in LLVM IR (`demo/server.ll`).
- A WASM fractal module authored in LLVM IR (`demo/fractal.ll`).
- A minimal webpage where JS only instantiates WASM and blits its buffer (`demo/public/index.html`).
- Build, verification-report, and CI benchmark plumbing (`demo/build.sh`, `demo/verify.sh`, `.github/workflows/k6.yml`).

What the demo currently proves:
- LLVM IR can directly define both server and wasm workload.
- Proof metadata can survive optimization and be surfaced in verification reports.
- CI can continuously measure and persist benchmark snapshots.

What remains to fully meet this architecture spec:
- Solver-backed discharge of PCF obligations as a hard gate.
- Formal effect-surface lint with build failure on mismatch.
- First-class proof certificates with independent checker validation.
- IPS crash-recovery proofs and recovery harness.

## 9. Non-Goals

Alien Stack does not optimize for:
- Human-oriented syntax ergonomics as a primary concern.
- Framework-level abstraction layers with implicit side effects.
- Test-only correctness claims without contract/proof linkage.

## 10. Definition of Done for Alien Stack Systems

A system qualifies as Alien Stack-compliant when:
- Executable behavior is authored and versioned as LLVM IR modules.
- Exported behavior is expressed as complete PCFs.
- Verification is mandatory at link time.
- Effects are declared and mechanically validated.
- Persistent state uses IPS with validated recovery.
- Benchmark evidence is committed and reproducible.

This is the architecture: one representation, one verification contract, one release gate.
