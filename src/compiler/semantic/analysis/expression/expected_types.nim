## Applies expected-type checking and contextual integral literal typing.
## Example: literal `7` becomes Byte for a Byte parameter, while `128` is rejected.

## Analyzes an expression against an expected primitive type.
## Example: unsuffixed `1` may become Byte or Short in parameter positions.
proc analyzeExprExpected*(
  expr: astExpressions.Expr,
  expected: EidoType,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols
): hirExpressions.HirExpr =
  if expr.kind == astExpressions.ekInteger and expected.isIntegral:
    return analyzeIntegerAs(expr, expected)

  let analyzed = analyzeExpr(expr, locals, functions, classes)
  if analyzed.typ != expected:
    failAt(
      expr.span,
      "type mismatch: expected " & expected.displayName &
        " but got " & analyzed.typ.displayName
    )
  analyzed
