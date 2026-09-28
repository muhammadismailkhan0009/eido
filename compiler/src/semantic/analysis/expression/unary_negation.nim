## Type-checks numeric unary negation and lowers it to HIR.
## Example: `-count` accepts Int or Float but rejects Byte, Short, Bool, and Char.

## Analyzes recursive numeric unary negation.
## Example: `-2.5` produces Float HIR with `huoNegate`.
proc analyzeUnaryNegation(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
): hirExpressions.HirExpr =
  let operand = analyzeExpr(expr.operand, locals, functions, classes)
  if operand.typ != etInt and operand.typ != etFloat:
    failAt(
      expr.span,
      "unary '-' requires Int or Float but got " & operand.typ.displayName
    )

  HirExpr(
    kind: hekUnary,
    span: expr.span,
    typ: operand.typ,
    unaryOp: huoNegate,
    operand: operand
  )
