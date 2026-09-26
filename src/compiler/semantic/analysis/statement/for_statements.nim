## Analyzes classic for-loop semantics with an isolated loop scope.
## Example: the initializer binding is visible to condition, update, and body but not after the loop.

## Analyzes one for loop and preserves nearest-loop control semantics through loop depth.
## Example: `for (var i = 0; i < 10; i = i + 1) { ... }` requires a Bool condition.
proc analyzeFor(
  stmt: astStatements.Stmt,
  locals: var LocalScope,
  functions: FunctionSymbols,
  functionResult: FunctionResult,
  loopDepth: int
): hirStatements.HirStmt =
  var forLocals = locals.fork()

  let initializer = analyzeStmt(
    stmt.forInitializer,
    forLocals,
    functions,
    functionResult,
    loopDepth
  )

  let condition = analyzeExprExpected(
    stmt.forCondition,
    etBool,
    forLocals,
    functions
  )

  let update = analyzeStmt(
    stmt.forUpdate,
    forLocals,
    functions,
    functionResult,
    loopDepth + 1
  )

  let body = analyzeScopedStatementBlock(
    stmt.forBody,
    forLocals,
    functions,
    functionResult,
    loopDepth + 1
  )

  locals.synchronizeNextId(forLocals)

  HirStmt(
    kind: hskFor,
    span: stmt.span,
    forInitializer: initializer,
    forCondition: condition,
    forUpdate: update,
    forBody: body
  )
