## Defines resolved HIR declarations consumed by backends.

import ../source/span
import ../types/model
import ../types/function_result
import ../types/method_kind
import ../semantic/symbols/ids
import statements
import expressions

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

  HirInheritedContractClause* = object
    interfaceName*: string
    expr*: HirExpr

  HirMethod* = object
    span*: SourceSpan
    methodId*: MethodId
    sourceName*: string
    isNative*: bool
    ownerType*: EidoType
    parameters*: seq[HirParameter]
    result*: FunctionResult
    inheritedRequires*: seq[HirInheritedContractClause]
    requires*: seq[HirExpr]
    inheritedEnsures*: seq[HirInheritedContractClause]
    ensures*: seq[HirExpr]
    ensureResultLocalId*: LocalId
    body*: seq[HirStmt]
    case kind*: MethodKind
    of mkInstance:
      receiverLocalId*: LocalId
    of mkStatic:
      discard

  HirInterfaceMethod* = object
    span*: SourceSpan
    sourceName*: string
    declaringInterface*: string
    parameterTypes*: seq[EidoType]
    parameters*: seq[HirParameter]
    result*: FunctionResult
    requires*: seq[HirExpr]
    ensures*: seq[HirExpr]
    receiverLocalId*: LocalId
    ensureResultLocalId*: LocalId

  HirInterface* = object
    span*: SourceSpan
    sourceName*: string
    typ*: EidoType
    extends*: seq[string]
    methods*: seq[HirInterfaceMethod]

  HirClass* = object
    span*: SourceSpan
    sourceName*: string
    typ*: EidoType
    implements*: seq[string]
    fields*: seq[HirField]
    invariants*: seq[HirExpr]
    invariantReceiverLocalId*: LocalId
    methods*: seq[HirMethod]

  HirFunction* = object
    span*: SourceSpan
    functionId*: FunctionId
    sourceName*: string
    isNative*: bool
    parameters*: seq[HirParameter]
    result*: FunctionResult
    requires*: seq[HirExpr]
    ensures*: seq[HirExpr]
    ensureResultLocalId*: LocalId
    body*: seq[HirStmt]
