## Analyzes conditional control flow with isolated branch-local scopes.
## Example: both branches may read outer locals, but branch declarations do not leak outward.

## Analyzes one conditional branch in an isolated child scope.
## Example: locals declared inside a then-branch remain unavailable after the branch.
proc analyzeConditionalBranch(
  statements: seq[astStatements.Stmt],
  parentLocals: var LocalScope,
  functions: FunctionSymbols,
  functionResult: FunctionResult
): seq[hirStatements.HirStmt] =
  var branchLocals = parentLocals.fork()

  for statement in statements:
    result.add analyzeStmt(
      statement,
      branchLocals,
      functions,
      functionResult
    )

  parentLocals.synchronizeNextId(branchLocals)

## Analyzes an if/else statement and requires its condition to be Bool.
## Example: `if (count > 0) { ... }` lowers to HIR with isolated branch bodies.
proc analyzeConditional(
  stmt: astStatements.Stmt,
  locals: var LocalScope,
  functions: FunctionSymbols,
  functionResult: FunctionResult
): hirStatements.HirStmt =
  let condition = analyzeExprExpected(
    stmt.condition,
    etBool,
    locals,
    functions
  )

  let thenBranch = analyzeConditionalBranch(
    stmt.thenBranch,
    locals,
    functions,
    functionResult
  )

  let elseBranch = analyzeConditionalBranch(
    stmt.elseBranch,
    locals,
    functions,
    functionResult
  )

  HirStmt(
    kind: hskIf,
    span: stmt.span,
    condition: condition,
    thenBranch: thenBranch,
    elseBranch: elseBranch
  )

## Reports whether control cannot fall through the end of a statement block.
## Example: a block ending in a fully-returning if/else satisfies a result function.
proc blockAlwaysReturns*(statements: seq[hirStatements.HirStmt]): bool

## Reports whether one statement definitely returns on every path through it.
## Example: return always returns; if/else returns only when both branches definitely return.
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
## Example: a block ending in a fully-returning if/else satisfies a result function.
proc blockAlwaysReturns*(statements: seq[hirStatements.HirStmt]): bool =
  statements.len > 0 and stmtAlwaysReturns(statements[^1])
