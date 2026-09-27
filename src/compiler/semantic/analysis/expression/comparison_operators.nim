## Type-checks equality and ordered comparisons, including contextual integral literals.
## Example: when `value` is Byte, both `value < 10` and `10 < value` type 10 as Byte.

## Analyzes comparison operands while allowing an integer literal to adopt the other integral operand's type.
## Example: a Byte local compared with literal 10 keeps both operands Byte.
proc analyzeComparisonOperands(
  leftExpr, rightExpr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols
): tuple[left, right: hirExpressions.HirExpr] =
  if leftExpr.kind == astExpressions.ekInteger and
      rightExpr.kind != astExpressions.ekInteger:
    let right = analyzeExpr(rightExpr, locals, functions, classes)
    if right.typ.isIntegral:
      return (analyzeIntegerAs(leftExpr, right.typ), right)

  if rightExpr.kind == astExpressions.ekInteger and
      leftExpr.kind != astExpressions.ekInteger:
    let left = analyzeExpr(leftExpr, locals, functions, classes)
    if left.typ.isIntegral:
      return (left, analyzeIntegerAs(rightExpr, left.typ))

  (
    analyzeExpr(leftExpr, locals, functions, classes),
    analyzeExpr(rightExpr, locals, functions, classes)
  )

## Analyzes one equality or ordered-comparison expression.
## Example: ordered comparisons require matching Byte, Short, Int, or Float operands.
proc analyzeComparison(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols
): hirExpressions.HirExpr =
  let operands = analyzeComparisonOperands(
    expr.left, expr.right, locals, functions, classes
  )
  let left = operands.left
  let right = operands.right

  if left.typ != right.typ or
      not left.typ.isEqualityComparable or
      not right.typ.isEqualityComparable:
    failAt(
      expr.span,
      "equality operands must have the same primitive or String type"
    )

  if expr.op in {
    astExpressions.boLess,
    astExpressions.boLessEqual,
    astExpressions.boGreater,
    astExpressions.boGreaterEqual
  } and not left.typ.isNumeric:
    failAt(
      expr.span,
      "ordered comparison requires Byte, Short, Int, or Float operands"
    )

  let op =
    case expr.op
    of astExpressions.boEqual: hboEqual
    of astExpressions.boNotEqual: hboNotEqual
    of astExpressions.boLess: hboLess
    of astExpressions.boLessEqual: hboLessEqual
    of astExpressions.boGreater: hboGreater
    of astExpressions.boGreaterEqual: hboGreaterEqual
    else:
      raise newException(
        ValueError,
        "semantic invariant: non-comparison operator reached comparison lowering"
      )

  HirExpr(
    kind: hekBinary,
    span: expr.span,
    typ: etBool,
    op: op,
    left: left,
    right: right
  )
