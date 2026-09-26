## Renders class-owned Eido methods as Nim procedures with an explicit hidden receiver.

import ../../../hir/declarations as hirDeclarations
import ../../../types/function_result
import names
import type_emitter
import statement_emitter

## Renders one generated method signature with receiver parameter first.
proc renderMethodSignature*(methodDecl: hirDeclarations.HirMethod): string =
  result = "proc " & methodName(
    methodDecl.methodId,
    methodDecl.ownerType.className,
    methodDecl.sourceName
  ) & "("

  result.add localName(methodDecl.receiverLocalId, "receiver") &
    ": " & renderType(methodDecl.ownerType)

  for parameter in methodDecl.parameters:
    result.add ", " & localName(
      parameter.localId,
      parameter.sourceName
    ) & ": " & renderType(parameter.typ)

  result.add ")"
  if methodDecl.result.kind == frSingle:
    result.add ": " & renderType(methodDecl.result.typ)

## Renders one complete generated method body.
proc renderMethod*(methodDecl: hirDeclarations.HirMethod): string =
  result.add renderMethodSignature(methodDecl) & " =\n"

  if methodDecl.body.len == 0:
    result.add "  discard\n"
  else:
    for stmt in methodDecl.body:
      result.add renderStmt(stmt)
