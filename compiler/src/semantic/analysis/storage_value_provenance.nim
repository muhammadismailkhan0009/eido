## Classifies Storage-valued expressions as owning roots or borrowed capabilities.
## This shared rule is used at bindings and persistent class-field boundaries.

import ../../frontend/ast/expressions as astExpressions
import ../../hir/expressions
import ../../types/model
import ../../types/storage
import ../symbols/[functions, model, nominals, scope]

## Returns the ownership provenance carried by one analyzed Storage expression.
proc classifyStorageValue*(
  source: astExpressions.Expr,
  analyzed: HirExpr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
): StorageValueProvenance =
  if analyzed.typ.kind != etkClass or
      not isConcreteStorageTypeName(analyzed.typ.className):
    return svpNotStorage

  case source.kind
  of astExpressions.ekMethodCall:
    if source.receiver.kind == astExpressions.ekIdentifier and
        isConcreteStorageTypeName(source.receiver.name):
      if source.methodName in ["allocate", "allocateRaw", "fromAddress"]:
        return svpOwned
      if source.methodName in ["view", "slice"]:
        return svpBorrowed
    if analyzed.kind == hekMethodCall and
        analyzed.methodCall.dispatchKind == hmdClass and
        analyzed.methodCall.ownerType.kind == etkClass and
        classes.containsClass(analyzed.methodCall.ownerType.className):
      return classes.getClass(
        analyzed.methodCall.ownerType.className
      ).getMethod(source.methodName).storageResultProvenance

    # Dynamic/interface Storage results cannot currently prove ownership transfer.
    svpBorrowed

  of astExpressions.ekCall:
    if functions.contains(source.callee):
      functions.get(source.callee).storageResultProvenance
    else:
      svpBorrowed

  of astExpressions.ekIdentifier:
    if locals.contains(source.name):
      locals.get(source.name).storageValueProvenance
    else:
      svpBorrowed

  else:
    svpBorrowed
