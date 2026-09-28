## Analyzes Boolean word negation and lowers it to typed HIR.
## Example: `not active` requires Bool and produces Bool HIR.
proc analyzeBooleanNot(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
): hirExpressions.HirExpr =
  let operand = analyzeExpr(expr.operand, locals, functions, classes)
  if operand.typ != etBool:
    failAt(
      expr.span,
      "'not' requires Bool but got " & operand.typ.displayName
    )

  HirExpr(
    kind: hekUnary,
    span: expr.span,
    typ: etBool,
    unaryOp: huoNot,
    operand: operand
  )

## Analyzes short-circuit Boolean binary operators and lowers them to typed HIR.
## Example: `ready and valid` requires two Bool operands and produces Bool HIR.
proc analyzeBooleanBinary(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
): hirExpressions.HirExpr =
  let left = analyzeExpr(expr.left, locals, functions, classes)
  let right = analyzeExpr(expr.right, locals, functions, classes)

  if left.typ != etBool or right.typ != etBool:
    failAt(
      expr.span,
      "'and' and 'or' require Bool operands"
    )

  let op =
    if expr.op == astExpressions.boAnd: hboAnd else: hboOr

  HirExpr(
    kind: hekBinary,
    span: expr.span,
    typ: etBool,
    op: op,
    left: left,
    right: right
  )
