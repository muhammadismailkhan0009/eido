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
import ../symbols/scope
import expression_analysis

## Checks one AST statement and lowers it to HIR. Example: `b = a;` verifies `b` exists, checks types, and stores both bindings by semantic ID.
proc analyzeStmt*(
  stmt: astStatements.Stmt,
  locals: var LocalScope,
  functions: FunctionSymbols,
  functionResult: FunctionResult
): hirStatements.HirStmt =
  case stmt.kind
  of astStatements.skVar:
    if locals.contains(stmt.name):
      failAt(stmt.span, "duplicate local '" & stmt.name & "'")

    let initializer = analyzeExpr(stmt.initializer, locals, functions)

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
    if target.kind != bkVariable:
      failAt(stmt.span, "parameter reassignment is not supported")

    let value = analyzeExprExpected(
      stmt.assignedValue,
      target.typ,
      locals,
      functions
    )

    HirStmt(
      kind: hskAssign,
      span: stmt.span,
      targetId: target.id,
      targetName: target.name,
      assignedValue: value
    )

  of astStatements.skCall:
    HirStmt(
      kind: hskCall,
      span: stmt.span,
      call: analyzeCall(stmt.call, locals, functions)
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
          functions
        )
      )
