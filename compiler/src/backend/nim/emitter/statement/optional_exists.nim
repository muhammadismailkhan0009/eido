## Renders lexical optional existence proof blocks.
## Source never exposes Option.get; HIR/body reads already contain explicit optional-get nodes.

## Renders one `if path exists { ... }` block as an Option presence check.
## Example: optional local user lowers to `if isSome(user):`.
proc renderExists(
  stmt: hirStatements.HirStmt,
  indent: int,
  exitContext: NormalExitContext
): string =
  let pad = indentation(indent)
  result.add pad & "if isSome(" & renderExpr(stmt.existsValue) & "):\n"

  if stmt.existsBody.len == 0:
    result.add indentation(indent + 2) & "discard\n"
  else:
    for bodyStmt in stmt.existsBody:
      result.add renderStmtAt(bodyStmt, indent + 2, exitContext)
