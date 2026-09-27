## Analyzes loop-control statements using the current loop nesting depth.
## Example: `break;` and `continue;` are valid only when at least one loop encloses them.

## Validates and lowers one break or continue statement.
## Example: a loop control nested inside an if within a while remains legal because loop depth is preserved.
proc analyzeLoopControl(
  stmt: astStatements.Stmt,
  loopDepth: int
): hirStatements.HirStmt =
  if loopDepth == 0:
    case stmt.kind
    of astStatements.skBreak:
      failAt(stmt.span, "'break' is only valid inside a loop")
    of astStatements.skContinue:
      failAt(stmt.span, "'continue' is only valid inside a loop")
    else:
      raise newException(
        ValueError,
        "semantic invariant: expected break or continue statement"
      )

  case stmt.kind
  of astStatements.skBreak:
    HirStmt(
      kind: hskBreak,
      span: stmt.span
    )
  of astStatements.skContinue:
    HirStmt(
      kind: hskContinue,
      span: stmt.span
    )
  else:
    raise newException(
      ValueError,
      "semantic invariant: expected break or continue statement"
    )
