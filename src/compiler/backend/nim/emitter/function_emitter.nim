## Renders HIR function signatures and bodies. Example: no-result Eido `notify(Int id)` becomes a Nim `proc` with no result type.

import ../../../hir/declarations as hirDeclarations
import ../../../types/function_result
import names
import type_emitter
import statement_emitter

## Renders a Nim procedure signature from an HIR function. Example: `add(Int a, Int b) returns Int` becomes a proc with two `int64` parameters and an `int64` result.
proc renderSignature*(fn: hirDeclarations.HirFunction): string =
  result = "proc " & functionName(fn.functionId, fn.sourceName) & "("
  for index, parameter in fn.parameters:
    if index > 0:
      result.add ", "
    result.add localName(parameter.localId, parameter.sourceName) &
      ": " & renderType(parameter.typ)
  result.add ")"

  if fn.result.kind == frSingle:
    result.add ": " & renderType(fn.result.typ)

## Renders a complete Nim procedure body from an HIR function. Example: an empty no-result Eido function emits `discard` so the Nim body remains valid.
proc renderFunction*(fn: hirDeclarations.HirFunction): string =
  result.add renderSignature(fn) & " =\n"
  if fn.body.len == 0:
    result.add "  discard\n"
  else:
    for stmt in fn.body:
      result.add renderStmt(stmt)
