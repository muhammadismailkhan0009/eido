## Type-checks binary arithmetic and lowers supported operators to HIR.
## Example: `a + b` requires matching Int or matching Float operands.

## Analyzes one binary arithmetic expression.
## Example: Int division remains typed Int while Float division remains typed Float.
proc analyzeArithmetic(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
): hirExpressions.HirExpr =
  let left = analyzeExpr(expr.left, locals, functions, classes)
  let right = analyzeExpr(expr.right, locals, functions, classes)

  if left.typ != right.typ:
    failAt(expr.span, "binary operands must have matching types")

  let isStringConcatenation =
    expr.op == astExpressions.boAdd and left.typ == etString
  if not left.typ.isNumericArithmetic and not isStringConcatenation:
    failAt(
      expr.span,
      "arithmetic requires matching Int/Float operands; String supports only +"
    )

  let op =
    case expr.op
    of astExpressions.boAdd: hboAdd
    of astExpressions.boSubtract: hboSubtract
    of astExpressions.boMultiply: hboMultiply
    of astExpressions.boDivide: hboDivide
    else:
      raise newException(
        ValueError,
        "semantic invariant: non-arithmetic operator reached arithmetic lowering"
      )

  HirExpr(
    kind: hekBinary,
    span: expr.span,
    typ: left.typ,
    op: op,
    left: left,
    right: right
  )
