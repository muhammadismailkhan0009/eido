## Defines compiler-internal compile-time strategy results after private phase handles
## have been resolved back to stable semantic identities.

type
  CompileTimeFieldLayout* = object
    fieldName*: string
    offset*: int64
    traced*: bool

  CompileTimeTypeLayout* = object
    className*: string
    size*: int64
    alignment*: int64
    fields*: seq[CompileTimeFieldLayout]

  CompileTimeMemoryPlan* = object
    types*: seq[CompileTimeTypeLayout]
