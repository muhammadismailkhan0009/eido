## Renders typed HIR statements as Nim while preserving structured indentation.
## Example: function-level statements start at two spaces and nested conditional bodies indent further.

import std/strutils
import ../../../hir/statements as hirStatements
import ../../../types/function_result
import names
import type_emitter
import expression_emitter

## Returns spaces for one emitted statement indentation level.
## Example: indentation(4) prefixes a statement nested inside a function-level conditional.
proc indentation(level: int): string =
  repeat(' ', level)

## Renders one HIR statement at an explicit indentation level.
## Example: conditional emission recursively calls this for branch statements.
proc renderStmtAt*(
  stmt: hirStatements.HirStmt,
  indent: int
): string

include statement/conditional_statements
include statement/while_statements
include statement/loop_control_statements

## Renders one HIR statement at an explicit indentation level.
## Example: an HIR variable declaration nested at four spaces keeps that indentation.
proc renderStmtAt*(
  stmt: hirStatements.HirStmt,
  indent: int
): string =
  let pad = indentation(indent)

  case stmt.kind
  of hirStatements.hskVar:
    pad & "var " & localName(stmt.localId, stmt.sourceName) &
      ": " & renderType(stmt.typ) & " = " &
      renderExpr(stmt.initializer) & "\n"

  of hirStatements.hskAssign:
    pad & localName(stmt.targetId, stmt.targetName) &
      " = " & renderExpr(stmt.assignedValue) & "\n"

  of hirStatements.hskCall:
    if stmt.call.result.kind == frNone:
      pad & renderCall(stmt.call) & "\n"
    else:
      pad & "discard " & renderCall(stmt.call) & "\n"

  of hirStatements.hskReturn:
    if stmt.value.isNil:
      pad & "return\n"
    else:
      pad & "return " & renderExpr(stmt.value) & "\n"

  of hirStatements.hskIf:
    renderConditional(stmt, indent)

  of hirStatements.hskWhile:
    renderWhile(stmt, indent)

  of hirStatements.hskBreak, hirStatements.hskContinue:
    renderLoopControl(stmt, indent)

## Renders one function-level HIR statement.
## Example: top-level function statements begin with two spaces in generated Nim.
proc renderStmt*(stmt: hirStatements.HirStmt): string =
  renderStmtAt(stmt, 2)
