## Renders classic for-loop HIR by lowering it to labeled Nim blocks plus while.
## Example: continue exits the per-iteration block so the update still runs.

## Renders one statement inside a for body with loop-control labels for the owning for loop.
## Example: Eido continue becomes a break to the update-path block; break exits the whole for loop.
proc renderForBodyStmt(
  stmt: hirStatements.HirStmt,
  indent: int,
  breakLabel: string,
  continueLabel: string
): string =
  let pad = indentation(indent)

  case stmt.kind
  of hskBreak:
    result.add pad & "break " & breakLabel & "\n"

  of hskContinue:
    result.add pad & "break " & continueLabel & "\n"

  of hskIf:
    result.add pad & "if " & renderExpr(stmt.condition) & ":\n"

    if stmt.thenBranch.len == 0:
      result.add indentation(indent + 2) & "discard\n"
    else:
      for branchStmt in stmt.thenBranch:
        result.add renderForBodyStmt(
          branchStmt,
          indent + 2,
          breakLabel,
          continueLabel
        )

    if stmt.elseBranch.len > 0:
      result.add pad & "else:\n"
      for branchStmt in stmt.elseBranch:
        result.add renderForBodyStmt(
          branchStmt,
          indent + 2,
          breakLabel,
          continueLabel
        )

  of hskWhile, hskFor:
    # Nested loops own their break/continue semantics.
    result.add renderStmtAt(stmt, indent)

  else:
    result.add renderStmtAt(stmt, indent)

## Renders one classic for loop at the requested indentation level.
## Example: initializer runs once, body runs inside an update-path block, and update follows every non-breaking iteration.
proc renderFor(
  stmt: hirStatements.HirStmt,
  indent: int
): string =
  let pad = indentation(indent)
  let loopId = $int(stmt.forInitializer.localId)
  let breakLabel = "eido_for_break_" & loopId
  let continueLabel = "eido_for_continue_" & loopId

  result.add pad & "block " & breakLabel & ":\n"
  result.add renderStmtAt(stmt.forInitializer, indent + 2)
  result.add indentation(indent + 2) &
    "while " & renderExpr(stmt.forCondition) & ":\n"
  result.add indentation(indent + 4) &
    "block " & continueLabel & ":\n"

  if stmt.forBody.len == 0:
    result.add indentation(indent + 6) & "discard\n"
  else:
    for bodyStmt in stmt.forBody:
      result.add renderForBodyStmt(
        bodyStmt,
        indent + 6,
        breakLabel,
        continueLabel
      )

  result.add renderStmtAt(stmt.forUpdate, indent + 4)
