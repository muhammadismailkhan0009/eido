## Defines policy-selected bindings from generic program events to ordinary Eido methods.
## Memory strategies choose bindings; the compiler only exposes semantic event points.

type
  CompileTimeInstrumentationPlan* = object
    bindingEnter*: string
    bindingWrite*: string
    bindingLeave*: string
    metadataType*: string
    metadataField*: string
    objectAcquire*: string
    temporaryEnter*: string
    temporaryLeave*: string
    statementBoundary*: string
    invariantEnter*: string
    invariantLeave*: string
    invariantClear*: string
    programExit*: string

## Reports whether a selected policy requires any target-side instrumentation.
proc isEmpty*(plan: CompileTimeInstrumentationPlan): bool =
  plan.bindingEnter.len == 0 and
    plan.bindingWrite.len == 0 and
    plan.bindingLeave.len == 0 and
    plan.objectAcquire.len == 0 and
    plan.programExit.len == 0
