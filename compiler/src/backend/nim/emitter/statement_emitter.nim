## Renders typed HIR statements as Nim while preserving structured indentation.
## Example: function-level statements start at two spaces and nested conditional bodies indent further.

import std/strutils
import ../../../hir/statements as hirStatements
import ../../../types/function_result
import ../../../semantic/symbols/ids
import names
import type_emitter
import expression_emitter
import normal_exit
import instrumentation_emitter

## Returns spaces for one emitted statement indentation level.
proc indentation(level: int): string =
  repeat(' ', level)

## Renders one HIR statement at an explicit indentation level.
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

## Renders one stable expression-free execution boundary for the selected Eido memory runtime.
proc renderMemoryBoundary(context: NormalExitContext, pad: string): string =
  if context.instrumentationEnabled and context.runtimeBindings.statementBoundary.len > 0:
    result.add pad & context.runtimeBindings.statementBoundary & "()\n"

## Renders one HIR statement at an explicit indentation level.
proc renderStmtAt*(
  stmt: hirStatements.HirStmt,
  indent: int,
  exitContext: NormalExitContext
): string =
  let pad = indentation(indent)

  case stmt.kind
  of hirStatements.hskVar:
    result.add pad & "var " & localName(stmt.localId, stmt.sourceName) &
      ": " & renderType(stmt.typ) & " = " & renderExpr(stmt.initializer) & "\n"
    if exitContext.isIdentityValue(stmt.localId):
      result.add renderLocalValueRegistration(
        stmt.localId,
        stmt.sourceName,
        indent,
        exitContext.runtimeBindings
      )
    result.add renderMemoryBoundary(exitContext, pad)

  of hirStatements.hskAssign:
    result.add pad & localName(stmt.targetId, stmt.targetName) &
      " = " & renderExpr(stmt.assignedValue) & "\n"
    if exitContext.isIdentityValue(stmt.targetId) and
        exitContext.runtimeBindings.bindingWrite.len > 0:
      result.add pad & exitContext.runtimeBindings.bindingWrite & "(" &
        memoryValueSlotName(stmt.targetId) & ", " &
        localName(stmt.targetId, stmt.targetName) & ")\n"
    result.add renderMemoryBoundary(exitContext, pad)

  of hirStatements.hskFieldSet:
    result.add pad & classFieldSetName(
      exitContext.ownerClassName,
      stmt.fieldName
    ) & "(" & localName(stmt.receiverId, "receiver") & ", " &
      renderExpr(stmt.fieldValue) & ")\n"
    result.add renderInvariantValidation(exitContext, indent)
    result.add renderMemoryBoundary(exitContext, pad)

  of hirStatements.hskClassFieldSet:
    let classSlot = classOwnedFieldName(
      stmt.classFieldOwner.className,
      stmt.classFieldName
    )
    result.add pad & classSlot & " = " &
      renderExpr(stmt.classFieldValue) & "\n"
    if exitContext.instrumentationEnabled and
        stmt.classFieldValue.typ.isIdentityNominalType and
        exitContext.runtimeBindings.bindingWrite.len > 0:
      result.add pad & exitContext.runtimeBindings.bindingWrite & "(" &
        classOwnedFieldMemoryValueName(
          stmt.classFieldOwner.className,
          stmt.classFieldName
        ) & ", " & classSlot & ")\n"
    result.add renderMemoryBoundary(exitContext, pad)

  of hirStatements.hskCall:
    if stmt.call.result.kind == frNone:
      result.add pad & renderCall(stmt.call) & "\n"
    else:
      result.add pad & "discard " & renderCall(stmt.call) & "\n"
    result.add renderMemoryBoundary(exitContext, pad)

  of hirStatements.hskMethodCall:
    if stmt.methodCall.result.kind == frNone:
      result.add pad & renderMethodCall(stmt.methodCall) & "\n"
    else:
      result.add pad & "discard " & renderMethodCall(stmt.methodCall) & "\n"
    result.add renderMemoryBoundary(exitContext, pad)

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
      if exitContext.resultIdentityValueId >= 0:
        result.add pad & returnLocal & " = " & renderExpr(stmt.value) & "\n"
        if exitContext.runtimeBindings.bindingWrite.len > 0:
          result.add pad & exitContext.runtimeBindings.bindingWrite & "(" &
            memoryValueSlotName(LocalId(exitContext.resultIdentityValueId)) & ", " &
            returnLocal & ")\n"
      else:
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
proc renderStmtAt*(stmt: hirStatements.HirStmt, indent: int): string =
  renderStmtAt(stmt, indent, NormalExitContext())

## Renders one function-level HIR statement without callable exit hooks.
proc renderStmt*(stmt: hirStatements.HirStmt): string =
  renderStmtAt(stmt, 2, NormalExitContext())
