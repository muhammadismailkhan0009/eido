## Analyzes while-loop semantics with an isolated loop-body scope.
## Example: loop bodies may read and assign outer locals, while loop-local declarations do not leak.

## Analyzes a while condition and body.
## Example: `while (count < 10) { count = count + 1; }` requires a Bool condition.
proc analyzeWhile(
  stmt: astStatements.Stmt,
  locals: var LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols,
  functionResult: FunctionResult,
  loopDepth: int
): hirStatements.HirStmt =
  let condition = analyzeExprExpected(
    stmt.whileCondition,
    etBool,
    locals,
    functions,
    classes
  )

  let body = analyzeScopedStatementBlock(
    stmt.body,
    locals,
    functions,
    classes,
    functionResult,
    loopDepth + 1
  )

  HirStmt(
    kind: hskWhile,
    span: stmt.span,
    whileCondition: condition,
    body: body
  )
