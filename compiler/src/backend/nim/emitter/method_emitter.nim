## Renders class-owned Eido methods as Nim procedures.
## Instance methods receive a hidden receiver; inferred static methods do not.

import ../../../hir/declarations as hirDeclarations
import ../../../types/function_result
import ../../../types/method_kind
import names
import type_emitter
import statement_emitter

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
proc renderMethod*(methodDecl: hirDeclarations.HirMethod): string =
  result.add renderMethodSignature(methodDecl) & " =\n"

  if methodDecl.body.len == 0:
    result.add "  discard\n"
  else:
    for stmt in methodDecl.body:
      result.add renderStmt(stmt)
