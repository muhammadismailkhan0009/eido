## Analyzes structured statement bodies in isolated child scopes.
## Example: conditional branches and while bodies may read outer bindings without leaking new locals.

## Analyzes one statement block in a forked local scope and preserves function-wide LocalId uniqueness.
## Example: locals declared inside the block disappear afterward, while the parent allocator advances past their IDs.
proc analyzeScopedStatementBlock(
  statements: seq[astStatements.Stmt],
  parentLocals: var LocalScope,
  functions: FunctionSymbols,
  functionResult: FunctionResult,
  loopDepth: int
): seq[hirStatements.HirStmt] =
  var blockLocals = parentLocals.fork()

  for statement in statements:
    result.add analyzeStmt(
      statement,
      blockLocals,
      functions,
      functionResult,
      loopDepth
    )

  parentLocals.synchronizeNextId(blockLocals)
