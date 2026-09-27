## Analyzes ordinary Boolean conditionals and lexical optional exists proofs.
## Exists proofs narrow exactly one stable source path for one lexical block.

## Analyzes an if/else statement and requires its condition to be Bool.
## Example: `if (count > 0) { ... }` lowers to HIR with isolated branch bodies.
proc analyzeConditional(
  stmt: astStatements.Stmt,
  locals: var LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols,
  functionResult: FunctionResult,
  loopDepth: int
): hirStatements.HirStmt =
  let condition = analyzeExprExpected(
    stmt.condition,
    etBool,
    locals,
    functions,
    classes
  )

  let thenBranch = analyzeScopedStatementBlock(
    stmt.thenBranch,
    locals,
    functions,
    classes,
    functionResult,
    loopDepth
  )

  let elseBranch = analyzeScopedStatementBlock(
    stmt.elseBranch,
    locals,
    functions,
    classes,
    functionResult,
    loopDepth
  )

  HirStmt(
    kind: hskIf,
    span: stmt.span,
    condition: condition,
    thenBranch: thenBranch,
    elseBranch: elseBranch
  )

## Analyzes `if path exists { ... }` and narrows that exact optional path only in its body.
## Mutation does not invalidate the proof in the initial model.
proc analyzeExists(
  stmt: astStatements.Stmt,
  locals: var LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols,
  functionResult: FunctionResult,
  loopDepth: int
): hirStatements.HirStmt =
  let path = optionalPathKey(stmt.existsTarget)
  if path.len == 0:
    failAt(stmt.existsTarget.span, "exists requires a stable local or field path")

  let value = analyzeExpr(
    stmt.existsTarget,
    locals,
    functions,
    classes
  )
  if not value.typ.isOptional:
    failAt(
      stmt.existsTarget.span,
      "exists requires an optional value but got " & value.typ.displayName
    )

  var proofLocals = locals.fork()
  proofLocals.proveOptional(path)

  var body: seq[hirStatements.HirStmt]
  for statement in stmt.existsBody:
    body.add analyzeStmt(
      statement,
      proofLocals,
      functions,
      classes,
      functionResult,
      loopDepth
    )

  locals.synchronizeNextId(proofLocals)

  HirStmt(
    kind: hskExists,
    span: stmt.span,
    existsValue: value,
    existsBody: body
  )

## Reports whether control cannot fall through the end of a statement block.
proc blockAlwaysReturns*(statements: seq[hirStatements.HirStmt]): bool

## Reports whether one statement definitely returns on every path through it.
## Exists never definitely returns because its body may not execute.
proc stmtAlwaysReturns*(stmt: hirStatements.HirStmt): bool =
  case stmt.kind
  of hskReturn:
    true
  of hskIf:
    stmt.elseBranch.len > 0 and
      blockAlwaysReturns(stmt.thenBranch) and
      blockAlwaysReturns(stmt.elseBranch)
  else:
    false

## Reports whether control cannot fall through the end of a statement block.
proc blockAlwaysReturns*(statements: seq[hirStatements.HirStmt]): bool =
  statements.len > 0 and stmtAlwaysReturns(statements[^1])
