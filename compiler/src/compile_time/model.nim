## Defines compiler-internal compile-time phase results.
## These structures never become part of the Eido runtime or public stdlib surface.

type
  CompileTimeFieldLayout* = object
    fieldHandle*: int64
    offset*: int64
    traced*: bool

  CompileTimeTypeLayout* = object
    typeHandle*: int64
    size*: int64
    alignment*: int64
    fields*: seq[CompileTimeFieldLayout]

  CompileTimeMemoryPlan* = object
    types*: seq[CompileTimeTypeLayout]
