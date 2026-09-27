## Renders conditional HIR with recursively indented branch statements.
## Example: an Eido if/else becomes a Nim if/else whose bodies remain structured.

## Renders one conditional statement at the requested indentation level.
## Example: a function-level if starts at two spaces and its branch body at four.
proc renderConditional(
  stmt: hirStatements.HirStmt,
  indent: int
): string =
  let pad = indentation(indent)
  result.add pad & "if " & renderExpr(stmt.condition) & ":\n"

  if stmt.thenBranch.len == 0:
    result.add indentation(indent + 2) & "discard\n"
  else:
    for branchStmt in stmt.thenBranch:
      result.add renderStmtAt(branchStmt, indent + 2)

  if stmt.elseBranch.len > 0:
    result.add pad & "else:\n"
    for branchStmt in stmt.elseBranch:
      result.add renderStmtAt(branchStmt, indent + 2)
