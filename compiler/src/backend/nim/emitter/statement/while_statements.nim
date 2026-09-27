## Renders while-loop HIR with recursively indented body statements.
## Example: an Eido while becomes a Nim while using the already-typed condition expression.

## Renders one while statement at the requested indentation level.
## Example: a function-level loop starts at two spaces and its body at four.
proc renderWhile(
  stmt: hirStatements.HirStmt,
  indent: int
): string =
  let pad = indentation(indent)
  result.add pad & "while " & renderExpr(stmt.whileCondition) & ":\n"

  if stmt.body.len == 0:
    result.add indentation(indent + 2) & "discard\n"
  else:
    for bodyStmt in stmt.body:
      result.add renderStmtAt(bodyStmt, indent + 2)
