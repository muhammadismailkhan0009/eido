## Renders loop-control HIR statements.
## Example: validated Eido `break;` and `continue;` become Nim loop-control statements.

## Renders one break or continue statement at the requested indentation level.
## Example: a loop-body control statement normally renders with four leading spaces.
proc renderLoopControl(
  stmt: hirStatements.HirStmt,
  indent: int
): string =
  let pad = indentation(indent)

  case stmt.kind
  of hskBreak:
    pad & "break\n"
  of hskContinue:
    pad & "continue\n"
  else:
    raise newException(
      ValueError,
      "emitter invariant: expected break or continue statement"
    )
