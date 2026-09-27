## Models Eido functions with either zero results or one typed result. Example: `function ping() {}` has `frNone`, while `returns Int` has `frSingle(etInt)`.

import model

type
  FunctionResultKind* = enum
    frNone,
    frSingle

  FunctionResult* = object
    case kind*: FunctionResultKind
    of frNone:
      discard
    of frSingle:
      typ*: EidoType

## Creates the semantic contract for a function that returns no value. Example: `function notify() {}` uses `noResult()`.
proc noResult*(): FunctionResult =
  FunctionResult(kind: frNone)

## Creates the semantic contract for a function returning one typed value. Example: `singleResult(etBool)` represents `returns Bool`, while a nominal class type represents a class-valued result.
proc singleResult*(typ: EidoType): FunctionResult =
  FunctionResult(kind: frSingle, typ: typ)
