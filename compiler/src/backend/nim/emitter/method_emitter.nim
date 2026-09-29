## Renders class-owned Eido methods as Nim procedures.
## Instance methods receive a hidden receiver; inferred static methods do not.

import ../../../hir/declarations as hirDeclarations
import ../../../hir/expressions as hirExpressions
import ../../../types/function_result
import ../../../types/method_kind
import names
import type_emitter
import statement_emitter
import contract_emitter
import normal_exit

## Renders one generated method signature with a receiver only for instance methods.
## Example: Calculator.add(Int, Int) emits two Int parameters, while Account.value() emits its hidden Account receiver.
proc renderMethodSignature*(methodDecl: hirDeclarations.HirMethod): string =
  result = "proc " & methodName(
    methodDecl.methodId,
    methodDecl.ownerType.className,
    methodDecl.sourceName
  ) & "("

  var hasPreviousParameter = false
  if methodDecl.kind == mkInstance:
    result.add localName(methodDecl.receiverLocalId, "receiver") &
      ": " & renderType(methodDecl.ownerType)
    hasPreviousParameter = true

  for parameter in methodDecl.parameters:
    if hasPreviousParameter:
      result.add ", "
    result.add localName(
      parameter.localId,
      parameter.sourceName
    ) & ": " & renderType(parameter.typ)
    hasPreviousParameter = true

  result.add ")"
  if methodDecl.result.kind == frSingle:
    result.add ": " & renderType(methodDecl.result.typ)

## Renders one complete generated method body.
## Example: an empty inferred static method still emits discard.
proc renderMethod*(
  methodDecl: hirDeclarations.HirMethod,
  enforceInvariant: bool = false
): string =
  result.add renderMethodSignature(methodDecl) & " =\n"

  let hasInvariant = enforceInvariant and methodDecl.kind == mkInstance
  let receiverName =
    if methodDecl.kind == mkInstance:
      localName(methodDecl.receiverLocalId, "receiver")
    else:
      ""

  var effectiveEnsures: seq[hirExpressions.HirExpr]
  for inherited in methodDecl.inheritedEnsures:
    effectiveEnsures.add inherited.expr
  for clause in methodDecl.ensures:
    effectiveEnsures.add clause

  let exitContext = NormalExitContext(
    contractClauses: effectiveEnsures,
    contractMessage: "ensure contract failed in method '" &
      methodDecl.sourceName & "'",
    resultBindingName:
      if effectiveEnsures.len > 0 and methodDecl.result.kind == frSingle:
        localName(methodDecl.ensureResultLocalId, "result")
      else:
        "",
    invariantOwner:
      if hasInvariant: methodDecl.ownerType.className else: "",
    invariantReceiver: receiverName
  )

  if hasInvariant:
    result.add renderInvariantValidation(exitContext, 2)

  for inherited in methodDecl.inheritedRequires:
    result.add renderContractCheck(
      inherited.expr,
      "require contract inherited from interface '" &
        inherited.interfaceName & "' failed in method '" &
        methodDecl.sourceName & "'",
      2
    )

  for clause in methodDecl.requires:
    result.add renderContractCheck(
      clause,
      "require contract failed in method '" & methodDecl.sourceName & "'",
      2
    )

  if methodDecl.body.len == 0:
    if exitContext.hasNormalExitChecks:
      result.add renderNormalExitChecks(exitContext, 2)
    elif methodDecl.inheritedRequires.len == 0 and
        methodDecl.requires.len == 0 and
        not hasInvariant:
      result.add "  discard\n"
  else:
    for stmt in methodDecl.body:
      result.add renderStmtAt(stmt, 2, exitContext)
    if methodDecl.result.kind == frNone:
      result.add renderNormalExitChecks(exitContext, 2)
