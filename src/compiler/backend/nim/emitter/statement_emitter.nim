## Renders HIR statements as Nim statements. Example: a no-result `notify(10);` call emits a direct proc call, while a value-returning call used as a statement emits `discard`.

import ../../../hir/statements as hirStatements
import ../../../types/function_result
import names
import type_emitter
import expression_emitter

## Renders one HIR statement as Nim source. Example: an HIR variable declaration becomes `var eido_local_0_x: int64 = int64(5)`.
proc renderStmt*(stmt: hirStatements.HirStmt): string =
  case stmt.kind
  of hirStatements.hskVar:
    "  var " & localName(stmt.localId, stmt.sourceName) &
      ": " & renderType(stmt.typ) & " = " &
      renderExpr(stmt.initializer) & "\n"

  of hirStatements.hskAssign:
    "  " & localName(stmt.targetId, stmt.targetName) &
      " = " & renderExpr(stmt.assignedValue) & "\n"

  of hirStatements.hskCall:
    if stmt.call.result.kind == frNone:
      "  " & renderCall(stmt.call) & "\n"
    else:
      "  discard " & renderCall(stmt.call) & "\n"

  of hirStatements.hskReturn:
    if stmt.value.isNil:
      "  return\n"
    else:
      "  return " & renderExpr(stmt.value) & "\n"
