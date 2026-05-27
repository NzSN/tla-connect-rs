---- MODULE TestIF_TTrace_1779886600 ----
EXTENDS Sequences, TLCExt, TestIF, Toolbox, Naturals, TLC

_expression ==
    LET TestIF_TEExpression == INSTANCE TestIF_TEExpression
    IN TestIF_TEExpression!expression
----

_trace ==
    LET TestIF_TETrace == INSTANCE TestIF_TETrace
    IN TestIF_TETrace!trace
----

_prop ==
    ~<>[](
        result = ("start")
        /\
        pc = ("a")
    )
----

_init ==
    /\ result = _TETrace[1].result
    /\ pc = _TETrace[1].pc
----

_next ==
    /\ \E i,j \in DOMAIN _TETrace:
        /\ \/ /\ j = i + 1
              /\ i = TLCGet("level")
        /\ result  = _TETrace[i].result
        /\ result' = _TETrace[j].result
        /\ pc  = _TETrace[i].pc
        /\ pc' = _TETrace[j].pc

\* Uncomment the ASSUME below to write the states of the error trace
\* to the given file in Json format. Note that you can pass any tuple
\* to `JsonSerialize`. For example, a sub-sequence of _TETrace.
    \* ASSUME
    \*     LET J == INSTANCE Json
    \*         IN J!JsonSerialize("TestIF_TTrace_1779886600.json", _TETrace)

=============================================================================

 Note that you can extract this module `TestIF_TEExpression`
  to a dedicated file to reuse `expression` (the module in the 
  dedicated `TestIF_TEExpression.tla` file takes precedence 
  over the module `TestIF_TEExpression` below).

---- MODULE TestIF_TEExpression ----
EXTENDS Sequences, TLCExt, TestIF, Toolbox, Naturals, TLC

expression == 
    [
        \* To hide variables of the `TestIF` spec from the error trace,
        \* remove the variables below.  The trace will be written in the order
        \* of the fields of this record.
        result |-> result
        ,pc |-> pc
        
        \* Put additional constant-, state-, and action-level expressions here:
        \* ,_stateNumber |-> _TEPosition
        \* ,_resultUnchanged |-> result = result'
        
        \* Format the `result` variable as Json value.
        \* ,_resultJson |->
        \*     LET J == INSTANCE Json
        \*     IN J!ToJson(result)
        
        \* Lastly, you may build expressions over arbitrary sets of states by
        \* leveraging the _TETrace operator.  For example, this is how to
        \* count the number of times a spec variable changed up to the current
        \* state in the trace.
        \* ,_resultModCount |->
        \*     LET F[s \in DOMAIN _TETrace] ==
        \*         IF s = 1 THEN 0
        \*         ELSE IF _TETrace[s].result # _TETrace[s-1].result
        \*             THEN 1 + F[s-1] ELSE F[s-1]
        \*     IN F[_TEPosition - 1]
    ]

=============================================================================



Parsing and semantic processing can take forever if the trace below is long.
 In this case, it is advised to uncomment the module below to deserialize the
 trace from a generated binary file.

\*
\*---- MODULE TestIF_TETrace ----
\*EXTENDS IOUtils, TestIF, TLC
\*
\*trace == IODeserialize("TestIF_TTrace_1779886600.bin", TRUE)
\*
\*=============================================================================
\*

---- MODULE TestIF_TETrace ----
EXTENDS TestIF, TLC

trace == 
    <<
    ([result |-> "start",pc |-> "a"])
    >>
----


=============================================================================

---- CONFIG TestIF_TTrace_1779886600 ----
CONSTANTS
    Flag = FALSE

PROPERTY
    _prop

CHECK_DEADLOCK
    \* CHECK_DEADLOCK off because of PROPERTY or INVARIANT above.
    FALSE

INIT
    _init

NEXT
    _next

CONSTANT
    _TETrace <- _trace

ALIAS
    _expression
=============================================================================
\* Generated on Wed May 27 20:56:41 CST 2026