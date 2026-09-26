## Checks statement rules and lowers statements to resolved HIR. Example: `notify(10);` becomes a resolved call statement, while `return;` is checked against a no-result function.

import ../../diagnostics/errors
import ../../frontend/ast/statements as astStatements
import ../../frontend/ast/expressions as astExpressions
import ../../hir/statements as hirStatements
import ../../hir/expressions
import ../../types/model
import ../../types/function_result
import ../symbols/model
import ../symbols/functions
import ../symbols/classes
import ../symbols/scope
import expression_analysis

## Checks one AST statement and lowers it to HIR.
## Example: conditional branches recursively reuse the same statement-analysis entry point.
proc analyzeStmt*(
  stmt: astStatements.Stmt,
  locals: var LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols,
  functionResult: FunctionResult,
  loopDepth: int = 0
): hirStatements.HirStmt

include statement/scoped_blocks
include statement/conditional_statements
include statement/while_statements
include statement/for_statements
include statement/loop_control_statements

## Checks one AST statement and lowers it to HIR. Example: `b = a;` verifies `b` exists, checks types, and stores both bindings by semantic ID.
proc analyzeStmt*(
  stmt: astStatements.Stmt,
  locals: var LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols,
  functionResult: FunctionResult,
  loopDepth: int = 0
): hirStatements.HirStmt =
  case stmt.kind
  of astStatements.skVar:
    if locals.contains(stmt.name):
      let existing = locals.get(stmt.name)
      case existing.kind
      of bkField:
        failAt(
          stmt.span,
          "local '" & stmt.name & "' conflicts with class field"
        )
      of bkParameter:
        failAt(
          stmt.span,
          "local '" & stmt.name & "' conflicts with parameter"
        )
      of bkVariable:
        failAt(stmt.span, "duplicate local '" & stmt.name & "'")

    let initializer = analyzeExpr(stmt.initializer, locals, functions, classes)

    if initializer.typ.kind == etkClass and
        stmt.initializer.kind != astExpressions.ekConstruct:
      failAt(
        stmt.initializer.span,
        "class-valued binding requires explicit copy or ref"
      )

    if stmt.initializer.kind == astExpressions.ekIdentifier:
      failAt(
        stmt.initializer.span,
        "bare identifier initializer requires explicit copy or ref"
      )

    let localId = locals.nextLocalId()
    let symbol = LocalSymbol(
      id: localId,
      name: stmt.name,
      typ: initializer.typ,
      kind: bkVariable,
      span: stmt.span
    )
    locals.add(stmt.name, symbol)

    HirStmt(
      kind: hskVar,
      span: stmt.span,
      localId: localId,
      sourceName: stmt.name,
      typ: initializer.typ,
      initializer: initializer
    )

  of astStatements.skAssign:
    if not locals.contains(stmt.target):
      failAt(stmt.span, "unknown assignment target '" & stmt.target & "'")

    let target = locals.get(stmt.target)
    case target.kind
    of bkParameter:
      failAt(stmt.span, "parameter reassignment is not supported")
    of bkField:
      failAt(
        stmt.span,
        "field mutation is not supported before set semantics"
      )
    of bkVariable:
      discard

    let value = analyzeExprExpected(
      stmt.assignedValue,
      target.typ,
      locals,
      functions,
      classes
    )

    if target.typ.kind == etkClass and
        stmt.assignedValue.kind != astExpressions.ekConstruct:
      failAt(
        stmt.assignedValue.span,
        "class-valued assignment requires explicit copy or ref"
      )

    HirStmt(
      kind: hskAssign,
      span: stmt.span,
      targetId: target.id,
      targetName: target.name,
      assignedValue: value
    )

  of astStatements.skCall:
    case stmt.call.kind
    of astExpressions.ekCall:
      HirStmt(
        kind: hskCall,
        span: stmt.span,
        call: analyzeCall(stmt.call, locals, functions, classes)
      )
    of astExpressions.ekMethodCall:
      HirStmt(
        kind: hskMethodCall,
        span: stmt.span,
        methodCall: analyzeMethodCall(
          stmt.call,
          locals,
          functions,
          classes
        )
      )
    else:
      raise newException(
        ValueError,
        "semantic invariant: call statement has non-call expression"
      )

  of astStatements.skReturn:
    case functionResult.kind
    of frNone:
      if not stmt.value.isNil:
        failAt(stmt.span, "function does not return a value; use 'return;'")
      HirStmt(
        kind: hskReturn,
        span: stmt.span,
        value: nil
      )

    of frSingle:
      if stmt.value.isNil:
        failAt(
          stmt.span,
          "function must return " & functionResult.typ.displayName
        )
      HirStmt(
        kind: hskReturn,
        span: stmt.span,
        value: analyzeExprExpected(
          stmt.value,
          functionResult.typ,
          locals,
          functions,
          classes
        )
      )

  of astStatements.skIf:
    analyzeConditional(
      stmt,
      locals,
      functions,
      classes,
      functionResult,
      loopDepth
    )

  of astStatements.skWhile:
    analyzeWhile(
      stmt,
      locals,
      functions,
      classes,
      functionResult,
      loopDepth
    )

  of astStatements.skFor:
    analyzeFor(
      stmt,
      locals,
      functions,
      classes,
      functionResult,
      loopDepth
    )

  of astStatements.skBreak, astStatements.skContinue:
    analyzeLoopControl(stmt, loopDepth)
