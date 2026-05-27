---- MODULE GenerateTraces ----
\* TLA+ specification of the `generate_traces` function from src/trace_gen.rs.
\*
\* This spec models the control flow and error handling of invoking Apalache
\* to generate ITF traces from a TLA+ specification.
\*
\* The algorithm:
\*   1. Resolve the output directory (user-supplied or temp).
\*   2. Canonicailze the spec path (fail if not found).
\*   3. Build and run the Apalache command (simulate or check).
\*   4. If the command succeeds (exit 0 or 12), collect .itf.json traces from
\*      the output directory.
\*   5. Return GeneratedTraces or an error.

EXTENDS Naturals, FiniteSets, TLC

\* ---------------------------------------------------------------------------
\* Model-value constants for Apalache exit outcomes
\* ---------------------------------------------------------------------------
CONSTANTS
  A_OK, A_CEX, A_FAIL, A_NOTFOUND      \* Apalache result values

ASSUME /\ A_OK \notin {A_CEX, A_FAIL, A_NOTFOUND}
       /\ A_CEX \notin {A_FAIL, A_NOTFOUND}
       /\ A_FAIL /= A_NOTFOUND

ApalacheResultValues == {A_OK, A_CEX, A_FAIL, A_NOTFOUND}

\* ---------------------------------------------------------------------------
\* Scenario constants (boolean flags)
\* ---------------------------------------------------------------------------
CONSTANT SpecExists       \* boolean
CONSTANT HasItfFiles       \* boolean
CONSTANT UserOutDir        \* boolean
CONSTANT KeepOutputs       \* boolean
CONSTANT TempDirFailed     \* boolean
CONSTANT TraceParseFailed  \* boolean
CONSTANT ApalacheTimeout   \* boolean

\* Which Apalache outcome occurs (must be one of the model values above)
CONSTANT ApalacheResult

ASSUME ApalacheResult \in ApalacheResultValues

\* ---------------------------------------------------------------------------
\* State machine for generate_traces
\* ---------------------------------------------------------------------------

VARIABLE pc      \* program counter
VARIABLE result  \* outcome label

Outcomes == {
    "Init",
    "TempDirCreated", "TempDirPersisted",
    "UserOutDirResolved",
    "SpecCanonicalized",
    "ApalacheOK", "ApalacheCEX", "ApalacheFailed",
    "ApalacheTimedOut", "ApalacheNotFound",
    "TracesCollected", "NoTracesFound", "TraceParseFailed",
    "SpecNotFound", "TempDirFailed"
}

Errors == {
    "SpecNotFound",
    "TempDirFailed",
    "ApalacheFailed",
    "ApalacheTimedOut",
    "ApalacheNotFound",
    "NoTracesFound",
    "TraceParseFailed"
}

Init ==
    /\ pc = "start"
    /\ result = "Init"

\* ---------------------------------------------------------------------------
\* Step 1: Resolve the output directory
\* ---------------------------------------------------------------------------

ResolveOutDir ==
    /\ pc = "start"
    /\ \/ UserOutDir /\ pc' = "spec-canonicalize" /\ result' = "UserOutDirResolved"
       \/ ~UserOutDir
          /\ \/ KeepOutputs /\ pc' = "spec-canonicalize" /\ result' = "TempDirPersisted"
             \/ ~KeepOutputs
                /\ \/ TempDirFailed /\ pc' = "done" /\ result' = "TempDirFailed"
                   \/ ~TempDirFailed /\ pc' = "spec-canonicalize" /\ result' = "TempDirCreated"

\* ---------------------------------------------------------------------------
\* Step 2: Canonicalize the spec path
\* ---------------------------------------------------------------------------

CanonicalizeSpec ==
    /\ pc = "spec-canonicalize"
    /\ \/ SpecExists /\ pc' = "run-apalache" /\ result' = "SpecCanonicalized"
       \/ ~SpecExists /\ pc' = "done" /\ result' = "SpecNotFound"

\* ---------------------------------------------------------------------------
\* Step 3: Run Apalache
\* ---------------------------------------------------------------------------

RunApalache ==
    /\ pc = "run-apalache"
    /\ \/ ApalacheTimeout /\ pc' = "done" /\ result' = "ApalacheTimedOut"
       \/ ~ApalacheTimeout
          /\ \/ ApalacheResult = A_FAIL /\ pc' = "done" /\ result' = "ApalacheFailed"
             \/ ApalacheResult = A_NOTFOUND /\ pc' = "done" /\ result' = "ApalacheNotFound"
             \/ ApalacheResult = A_OK /\ pc' = "collect-traces" /\ result' = "ApalacheOK"
             \/ ApalacheResult = A_CEX /\ pc' = "collect-traces" /\ result' = "ApalacheCEX"

\* ---------------------------------------------------------------------------
\* Step 4: Collect ITF traces from output directory
\* ---------------------------------------------------------------------------

CollectTraces ==
    /\ pc = "collect-traces"
    /\ \/ ~HasItfFiles /\ pc' = "done" /\ result' = "NoTracesFound"
       \/ HasItfFiles
          /\ \/ TraceParseFailed /\ pc' = "done" /\ result' = "TraceParseFailed"
             \/ ~TraceParseFailed /\ pc' = "done" /\ result' = "TracesCollected"

\* ---------------------------------------------------------------------------
\* Final state: Stutter once done
\* ---------------------------------------------------------------------------

Done == pc = "done" /\ UNCHANGED <<pc, result>>

\* ---------------------------------------------------------------------------
\* The overall next-state relation
\* ---------------------------------------------------------------------------

SuccessStates == {"ApalacheOK", "ApalacheCEX"}

Next ==
    \/ ResolveOutDir
    \/ CanonicalizeSpec
    \/ RunApalache
    \/ CollectTraces
    \/ Done

\* ---------------------------------------------------------------------------
\* Specification (with weak fairness to prevent infinite stuttering)
\* ---------------------------------------------------------------------------

Spec == Init /\ [][Next]_<<pc, result>> /\ WF_<<pc, result>>(Next)

\* ---------------------------------------------------------------------------
\* INVARIANTS (state predicates — checked at every state)
\* ---------------------------------------------------------------------------

TypeInvariant ==
    /\ pc \in {"start", "spec-canonicalize", "run-apalache", "collect-traces", "done"}
    /\ result \in Outcomes

\* When we reach TracesCollected, all subsystems must have succeeded.
TracesCollectedCorrect ==
    (result = "TracesCollected")
        => /\ SpecExists
           /\ ApalacheResult \in {A_OK, A_CEX}
           /\ ~ApalacheTimeout
           /\ HasItfFiles
           /\ ~TraceParseFailed

\* When SpecNotFound, the spec file didn't exist.
SpecNotFoundCorrect ==
    (result = "SpecNotFound") => ~SpecExists

\* When TempDirFailed, we were taking the temp-dir path.
TempDirFailedCorrect ==
    (result = "TempDirFailed") => /\ ~UserOutDir /\ ~KeepOutputs

\* When ApalacheTimedOut, a timeout was configured.
ApalacheTimedOutCorrect ==
    (result = "ApalacheTimedOut") => ApalacheTimeout

\* When NoTracesFound, Apalache ran but the output dir was empty.
NoTracesFoundCorrect ==
    (result = "NoTracesFound") => /\ ~HasItfFiles
                                  /\ ApalacheResult \in {A_OK, A_CEX}

\* When TraceParseFailed, files existed but couldn't be parsed.
TraceParseFailedCorrect ==
    (result = "TraceParseFailed") => /\ HasItfFiles
                                      /\ TraceParseFailed
                                      /\ ApalacheResult \in {A_OK, A_CEX}

\* ---------------------------------------------------------------------------
\* TEMPORAL PROPERTIES (checked across entire behaviour)
\* ---------------------------------------------------------------------------

\* The algorithm always terminates (pc becomes "done").
Termination == <>(pc = "done")

\* Once an error label is assigned, we never recover to TracesCollected.
NoRecovery ==
    \A e \in Errors : []((result = e) => [](result # "TracesCollected"))

=============================================================================
