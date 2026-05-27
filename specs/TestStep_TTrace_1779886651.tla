---- MODULE TestStep_TTrace_1779886651 ----
EXTENDS TestStep, Sequences, TLCExt, Toolbox, Naturals, TLC

_expression ==
    LET TestStep_TEExpression == INSTANCE TestStep_TEExpression
    IN TestStep_TEExpression!expression
----

_trace ==
    LET TestStep_TETrace == INSTANCE TestStep_TETrace
    IN TestStep_TETrace!trace
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
    \*         IN J!JsonSerialize("TestStep_TTrace_1779886651.json", _TETrace)

=============================================================================

 Note that you can extract this module `TestStep_TEExpression`
  to a dedicated file to reuse `expression` (the module in the 
  dedicated `TestStep_TEExpression.tla` file takes precedence 
  over the module `TestStep_TEExpression` below).

---- MODULE TestStep_TEExpression ----
EXTENDS TestStep, Sequences, TLCExt, Toolbox, Naturals, TLC

expression == 
    [
        \* To hide variables of the `TestStep` spec from the error trace,
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
\*---- MODULE TestStep_TETrace ----
\*EXTENDS TestStep, IOUtils, TLC
\*
\*trace == IODeserialize("TestStep_TTrace_1779886651.bin", TRUE)
\*
\*=============================================================================
\*

---- MODULE TestStep_TETrace ----
EXTENDS TestStep, TLC

trace == 
    <<
    ([result |-> "start",pc |-> "a"])
    >>
----


=============================================================================

---- CONFIG TestStep_TTrace_1779886651 ----

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
\* Generated on Wed May 27 20:57:31 CST 2026