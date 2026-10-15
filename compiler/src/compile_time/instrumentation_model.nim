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
    plan.metadataType.len == 0 and
    plan.metadataField.len == 0 and
    plan.objectAcquire.len == 0 and
    plan.temporaryEnter.len == 0 and
    plan.temporaryLeave.len == 0 and
    plan.statementBoundary.len == 0 and
    plan.invariantEnter.len == 0 and
    plan.invariantLeave.len == 0 and
    plan.invariantClear.len == 0 and
    plan.programExit.len == 0
