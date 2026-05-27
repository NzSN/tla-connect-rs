# Approach 1: Batch Trace Generation + Replay

This is the closest analog to the Quint/quint-connect workflow. It has two phases:

1. **Generate** ITF traces from a TLA+ spec using the Apalache CLI
2. **Replay** those traces against a Rust `Driver`, comparing state after every step

## Phase 1: Trace Generation (`src/trace_gen.rs`)

### Configuration (`ApalacheConfig`)

| Field | Default | Description |
|---|---|---|
| `spec` (required) | — | Path to the TLA+ spec file |
| `inv` | `"TraceComplete"` | Invariant to violate for trace generation |
| `max_traces` | `100` | Maximum number of traces |
| `max_length` | `50` | Maximum trace length (steps) |
| `view` | `None` | View operator for trace diversity |
| `cinit` | `None` | Constant initialization predicate name |
| `mode` | `Simulate` | `Simulate` (random) or `Check` (BMC) |
| `apalache_bin` | `"apalache-mc"` | Path to Apalache binary |
| `out_dir` | `None` | Output directory (temp dir if None) |
| `keep_outputs` | `false` | Keep temp dir after drop |
| `timeout` | `None` | Subprocess timeout |

Two modes select different Apalache subcommands:

```
Simulate:  apalache-mc simulate --inv=<inv> --max-run=<max_traces> --length=<max_length>
Check:     apalache-mc check    --inv=<inv> --max-error=<max_traces> --length=<max_length>
```

### Flow

```
generate_traces(&config)
  │
  ├─ 1. Resolve output directory (temp or user-specified)
  ├─ 2. Canonicalize spec path
  ├─ 3. Build & spawn Apalache CLI command
  ├─ 4. Wait with optional timeout (run_with_timeout in src/util.rs)
  ├─ 5. Accept exit codes 0 or 12 (12 = invariant violated = counterexample found)
  └─ 6. Collect all .itf.json files from output dir via recursive walk
       └─ Returns GeneratedTraces { traces, out_dir, _temp }
```

Exit code 12 is the expected success case — Apalache uses it to signal "invariant violated," which means a counterexample trace was found. Exit code 0 means no counterexample found (no traces produced), which is an error in this context.

`GeneratedTraces` owns the temp directory; it is cleaned up on `Drop` unless `keep_outputs` was set. Call `.persist()` to keep it explicitly.

## Phase 2: Trace Replay (`src/replay.rs`)

### Per-Trace, Per-State Loop

```
for each trace:
    fresh Driver from factory()
    for each state in trace.states:
        ┌─────────────────────────────────────┐
        │ 1. extract_mbt_vars()               │
        │    - action_taken (3-tier lookup)    │
        │    - nondet_picks                    │
        ├─────────────────────────────────────┤
        │ 2. Build Step { action_taken,       │
        │       nondet_picks, state }          │
        ├─────────────────────────────────────┤
        │ 3. driver.step(&step)               │
        ├─────────────────────────────────────┤
        │ 4. State::from_spec(state_value)    │
        │    (deserialize ITF → user's State)  │
        ├─────────────────────────────────────┤
        │ 5. ExtractState::from_driver(&driver)│
        ├─────────────────────────────────────┤
        │ 6. spec_state == driver_state?      │
        │    ✓ continue                       │
        │    ✗ return StateMismatch with diff │
        └─────────────────────────────────────┘
```

### Action Resolution (`extract_mbt_vars`)

Three-tier priority for determining which TLA+ action was taken:

1. **ITF state metadata** (`#meta`): checks keys `"action"`, `"label"`, `"transition"` in order
2. **Explicit `action_taken` field** in the state record
3. **Fallback**: `"init"` at state index 0, `"unknown"` otherwise

### State Comparison & Diff

When states diverge, `format_state_mismatch()` produces:

- A **summary** via `State::diff()` (default: line-by-line comparison of `Debug` output)
- A **full unified diff** via `unified_diff()` (using the `similar` crate)

### Public API

| Function | Description |
|---|---|
| `replay_traces(factory, traces)` | Sequential replay, no progress |
| `replay_traces_with_progress(factory, traces, callback)` | Sequential with `ReplayProgressFn` |
| `replay_traces_parallel(factory, traces)` | Rayon-based parallel (feature `parallel`) |
| `replay_trace_str(factory, json_str)` | Single trace from JSON string (testing) |
| `load_traces_from_dir(path)` | Parse all `.itf.json` files from a directory |

### Progress Callback

```rust
pub struct ReplayProgress {
    pub trace_index: usize,
    pub total_traces: usize,
    pub state_index: usize,
    pub total_states: usize,
    pub action: String,
}
```

### ReplayStats

```rust
pub struct ReplayStats {
    pub traces_replayed: usize,
    pub total_states: usize,
    pub duration: Duration,
}
```

## What It Catches

> **"If the TLA+ spec allows a behavior, does my Rust implementation also handle it?"**

The TLA+ spec defines the full state space; Apalache generates concrete paths through it (counterexamples to `TraceComplete`). Replay checks that the Rust implementation faithfully follows each path — every action must be executable, and every resulting state must match the spec's expectation.

## End-to-End Data Flow

```
┌──────────────┐
│  TLA+ spec   │  MySpec.tla (with invariant TraceComplete)
└──────┬───────┘
       │
       ▼  apalache-mc {simulate,check} --inv=TraceComplete
┌──────────────┐
│  ITF traces  │  *.itf.json files
└──────┬───────┘
       │
       ▼  replay_traces(factory, traces)
┌──────────────────────────────────────┐
│  ┌────────────────────────────────┐  │
│  │  Trace 0    Trace 1    ...     │  │
│  │  ┌──────┐  ┌──────┐           │  │
│  │  │init  │  │init  │           │  │
│  │  │step1 │  │step1 │           │  │
│  │  │step2 │  │step2 │           │  │
│  │  │...   │  │...   │           │  │
│  │  └──────┘  └──────┘           │  │
│  └────────────────────────────────┘  │
│  Driver created fresh per trace      │
│  State compared after every step     │
└──────────────────────────────────────┘
```
