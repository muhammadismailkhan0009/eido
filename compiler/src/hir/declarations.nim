## Defines resolved HIR declarations consumed by backends.

import ../source/span
import ../types/model
import ../types/function_result
import ../types/method_kind
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
    parameters*: seq[HirParameter]
    result*: FunctionResult
    body*: seq[HirStmt]
    case kind*: MethodKind
    of mkInstance:
      receiverLocalId*: LocalId
    of mkStatic:
      discard

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
    isNative*: bool
    parameters*: seq[HirParameter]
    result*: FunctionResult
    body*: seq[HirStmt]
