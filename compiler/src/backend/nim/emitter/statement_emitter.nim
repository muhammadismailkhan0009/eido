## Renders typed HIR statements as Nim while preserving structured indentation.
## Example: function-level statements start at two spaces and nested conditional bodies indent further.

import std/strutils
import ../../../hir/statements as hirStatements
import ../../../types/function_result
import names
import type_emitter
import expression_emitter
import normal_exit

## Returns spaces for one emitted statement indentation level.
## Example: indentation(4) prefixes a statement nested inside a function-level conditional.
proc indentation(level: int): string =
  repeat(' ', level)

## Renders one HIR statement at an explicit indentation level.
## Example: conditional emission recursively calls this for branch statements.
proc renderStmtAt*(
  stmt: hirStatements.HirStmt,
  indent: int,
  exitContext: NormalExitContext
): string

include statement/conditional_statements
include statement/optional_exists
include statement/while_statements
include statement/for_statements
include statement/loop_control_statements

## Renders one HIR statement at an explicit indentation level.
## Example: an HIR variable declaration nested at four spaces keeps that indentation.
proc renderStmtAt*(
  stmt: hirStatements.HirStmt,
  indent: int,
  exitContext: NormalExitContext
): string =
  let pad = indentation(indent)

  case stmt.kind
  of hirStatements.hskVar:
    result.add pad & "var " & localName(stmt.localId, stmt.sourceName) &
      ": " & renderType(stmt.typ) & " = " &
      renderExpr(stmt.initializer) & "\n"

  of hirStatements.hskAssign:
    result.add pad & localName(stmt.targetId, stmt.targetName) &
      " = " & renderExpr(stmt.assignedValue) & "\n"

  of hirStatements.hskFieldSet:
    result.add pad & localName(stmt.receiverId, "receiver") & "." &
      fieldName(stmt.fieldName) & " = " &
      renderExpr(stmt.fieldValue) & "\n"
    result.add renderInvariantValidation(exitContext, indent)

  of hirStatements.hskCall:
    if stmt.call.result.kind == frNone:
      result.add pad & renderCall(stmt.call) & "\n"
    else:
      result.add pad & "discard " & renderCall(stmt.call) & "\n"

  of hirStatements.hskMethodCall:
    if stmt.methodCall.result.kind == frNone:
      result.add pad & renderMethodCall(stmt.methodCall) & "\n"
    else:
      result.add pad & "discard " & renderMethodCall(stmt.methodCall) & "\n"

  of hirStatements.hskReturn:
    if stmt.value.isNil:
      result.add renderNormalExitChecks(exitContext, indent)
      result.add pad & "return\n"
    elif exitContext.hasNormalExitChecks:
      let returnLocal =
        if exitContext.resultBindingName.len > 0:
          exitContext.resultBindingName
        else:
          "eido_runtime_return_" & $stmt.span.startOffset
      result.add pad & "let " & returnLocal & " = " & renderExpr(stmt.value) & "\n"
      result.add renderNormalExitChecks(exitContext, indent)
      result.add pad & "return " & returnLocal & "\n"
    else:
      result.add pad & "return " & renderExpr(stmt.value) & "\n"

  of hirStatements.hskIf:
    result.add renderConditional(stmt, indent, exitContext)

  of hirStatements.hskExists:
    result.add renderExists(stmt, indent, exitContext)

  of hirStatements.hskWhile:
    result.add renderWhile(stmt, indent, exitContext)

  of hirStatements.hskFor:
    result.add renderFor(stmt, indent, exitContext)

  of hirStatements.hskBreak, hirStatements.hskContinue:
    result.add renderLoopControl(stmt, indent)

## Renders one function-level HIR statement.
## Example: top-level function statements begin with two spaces in generated Nim.
proc renderStmtAt*(stmt: hirStatements.HirStmt, indent: int): string =
  renderStmtAt(stmt, indent, NormalExitContext())

## Renders one function-level HIR statement without callable exit hooks.
proc renderStmt*(stmt: hirStatements.HirStmt): string =
  renderStmtAt(stmt, 2, NormalExitContext())
