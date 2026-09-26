## Renders Boolean word negation from HIR to Nim.
## Example: Eido `not active` becomes Nim `(not active)`.
proc renderBooleanNot(expr: hirExpressions.HirExpr): string =
  "(not " & renderExpr(expr.operand) & ")"

## Renders short-circuit Boolean binary HIR to Nim.
## Example: Eido `left and right` becomes Nim `(left and right)`.
proc renderBooleanBinary(expr: hirExpressions.HirExpr): string =
  let operator =
    case expr.op
    of hirExpressions.hboAnd: "and"
    of hirExpressions.hboOr: "or"
    else:
      raise newException(
        ValueError,
        "backend invariant: non-Boolean operator reached Boolean emitter"
      )

  "(" & renderExpr(expr.left) & " " & operator & " " &
    renderExpr(expr.right) & ")"
