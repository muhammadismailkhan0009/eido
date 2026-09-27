## Defines resolved HIR declarations consumed by backends.

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

  HirParameter* = object
    span*: SourceSpan
    localId*: LocalId
    sourceName*: string
    typ*: EidoType

  HirMethod* = object
    span*: SourceSpan
    methodId*: MethodId
    sourceName*: string
    ownerType*: EidoType
    receiverLocalId*: LocalId
    parameters*: seq[HirParameter]
    result*: FunctionResult
    body*: seq[HirStmt]

  HirClass* = object
    span*: SourceSpan
    sourceName*: string
    typ*: EidoType
    fields*: seq[HirField]
    methods*: seq[HirMethod]

  HirFunction* = object
    span*: SourceSpan
    functionId*: FunctionId
    sourceName*: string
    parameters*: seq[HirParameter]
    result*: FunctionResult
    body*: seq[HirStmt]
