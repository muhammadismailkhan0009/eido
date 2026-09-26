## Defines resolved HIR parameters and functions. Example: a no-result `notify` function stores `frNone`, while `returns Int` stores `frSingle(etInt)`.

import ../source/span
import ../types/model
import ../types/function_result
import ../semantic/symbols/ids
import statements

type
  HirField* = object
    span*: SourceSpan
    sourceName*: string
    typ*: EidoType

  HirClass* = object
    span*: SourceSpan
    sourceName*: string
    typ*: EidoType
    fields*: seq[HirField]

  HirParameter* = object
    span*: SourceSpan
    localId*: LocalId
    sourceName*: string
    typ*: EidoType

  HirFunction* = object
    span*: SourceSpan
    functionId*: FunctionId
    sourceName*: string
    parameters*: seq[HirParameter]
    result*: FunctionResult
    body*: seq[HirStmt]
