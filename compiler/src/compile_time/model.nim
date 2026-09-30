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

  CompileTimeCallableKind* = enum
    ctkFunction,
    ctkMethod

  CompileTimeRoot* = object
    localId*: int
    sourceName*: string

  CompileTimeCallableRoots* = object
    kind*: CompileTimeCallableKind
    semanticId*: int
    ownerName*: string
    sourceName*: string
    roots*: seq[CompileTimeRoot]

  CompileTimeMemoryPlan* = object
    types*: seq[CompileTimeTypeLayout]
    callables*: seq[CompileTimeCallableRoots]


## Reports whether one canonical class has a selected managed payload layout.
proc hasManagedLayout*(
  plan: CompileTimeMemoryPlan,
  className: string
): bool =
  for typePlan in plan.types:
    if typePlan.className == className:
      return true
  false
