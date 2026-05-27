# Architecture Overview

`tla-connect` is a Rust library for **model-based testing** that bridges TLA+ formal specifications with Rust implementations via the [Apalache](https://apalache.informal.systems/) model checker. It offers three complementary approaches.

## Core Abstractions (`src/driver.rs`)

| Trait/Type | Role |
|---|---|
| **`Driver`** | User's Rust type under test; maps TLA+ actions to Rust methods via `step(&Step)` |
| **`State`** | Deserializes from ITF (spec) state; implements `PartialEq` for comparison |
| **`ExtractState<D>`** | Extracts comparable state from the Driver |
| **`Step`** | Holds `action_taken`, `nondet_picks`, and the full ITF state record |
| **`switch!` macro** | Dispatches on `action_taken` to the right Rust code block |

## Module Map

| Module | Feature | Purpose |
|---|---|---|
| `src/driver.rs` | always | Core traits (`Driver`, `State`, `ExtractState`), `Step`, `switch!` macro, diff utilities |
| `src/error.rs` | always | Typed error hierarchy |
| `src/builder.rs` | always | `impl_builder!` macro for typed builders |
| `src/util.rs` | trace-gen, trace-validation | `run_with_timeout()` for Apalache subprocess |
| `src/replay.rs` | `replay` | ITF trace replay runner |
| `src/trace_gen.rs` | `trace-gen` | Apalache CLI trace generation |
| `src/trace_validation/` | `trace-validation` | NDJSON trace emission + validation |
| `src/rpc/` | `rpc` | JSON-RPC client + types for interactive testing |

## Feature Flags

| Feature | Enables | Default |
|---|---|---|
| `replay` | ITF trace replay against a Driver | yes |
| `trace-gen` | Apalache CLI trace generation | yes |
| `trace-validation` | Post-hoc NDJSON trace validation | yes |
| `rpc` | Interactive symbolic testing via Apalache JSON-RPC | no |
| `parallel` | Parallel trace replay using rayon | no |
| `full` | All features | no |

## The Three Approaches

```
Approach 1:  Apalache CLI ──► ITF traces ──► replay_traces() ──► Driver
Approach 2:  Apalache RPC server ◄──► interactive_test() ◄──► Driver
Approach 3:  Rust code ──► StateEmitter (NDJSON) ──► Apalache CLI ──► validate
```

| Approach | Direction | Catches |
|---|---|---|
| 1. Batch Replay | Spec → Implementation | Implementation doesn't handle a case the spec allows |
| 2. Interactive RPC | Spec ↔ Implementation | Implementation doesn't handle a case the spec allows |
| 3. Post-hoc Validation | Implementation → Spec | Implementation does something the spec doesn't allow |

## Error Types (`src/error.rs`)

- **`Error`** — top-level enum wrapping all sub-errors via `#[from]`
- **`DriverError`** — unknown action, action failure, state extraction failure
- **`StepError`** — shared between replay & RPC: step execution, spec deserialize, driver state extraction, state mismatch (with unified diff)
- **`ReplayError`** — MBT var extraction, parse, directory read
- **`TraceGenError`** — spec not found, Apalache CLI failure, no traces found
- **`ValidationError`** — trace spec/line errors, schema inconsistency, TLA+ conversion
- **`RpcError`** — HTTP/JSON-RPC errors, init disabled, constants unsatisfiable
- **`ApalacheError`** — shared: execution failure, not found, timeout
- **`BuilderError`** — missing required field
