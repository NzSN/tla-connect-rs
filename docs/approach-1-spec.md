# TLA+ Spec for Approach 1

The examples reference `specs/Counter.tla` — a file you provide. Here is the spec that matches the example Driver's three actions (`init`, `increment`, `decrement`) and single variable (`counter`).

## Counter.tla

```tla
---- MODULE Counter ----
EXTENDS Integers

VARIABLE counter

Init == counter = 0

Increment == counter' = counter + 1

Decrement == counter' = counter - 1

Next == Increment \/ Decrement

\* Invariant: when violated, a generated trace is "complete"
\* (i.e., the spec reached a state where no more transitions were expected).
\* Apalache searches for counterexamples to this invariant.
TraceComplete == FALSE
====
```

## How It Maps to the Rust Driver

| TLA+ action | Rust switch arm | Effect |
|---|---|---|
| `Init` | `"init"` | `self.value = 0` |
| `Increment` | `"increment"` | `self.value += 1` |
| `Decrement` | `"decrement"` | `self.value -= 1` |

The ITF trace records `counter` as a state variable and `action_taken` as metadata identifying which action fired.

## Key Contract

- **`TraceComplete == FALSE`** — Apalache treats this as an invariant to violate. Every counterexample it finds is a sequence of states that reaches the negation of `TraceComplete` (i.e., `TRUE`), which always happens immediately. This makes every generated trace a valid behavior of the spec.
- The Rust `State` struct mirrors the TLA+ variables (here just `counter`) with matching types.
- The `Driver::step()` implementation must handle every action that Apalache can produce, or return `DriverError::UnknownAction`.

## The `TraceComplete` Pattern

This is the standard MBT (model-based testing) pattern used by `tla-connect`:

```
apalache-mc simulate --inv=TraceComplete --max-run=100 --length=50 Counter.tla
```

Apalache generates up to 100 random traces of up to 50 steps each, searching for a state where `TraceComplete` is `FALSE` — which is always true since `TraceComplete` is constantly `FALSE`. Every trace is therefore a valid random walk through the spec's state space.

If you want more structured traces, replace `TraceComplete` with a meaningful invariant (e.g., `[](counter < 100)`) — Apalache will then find counterexample traces that violate it.
