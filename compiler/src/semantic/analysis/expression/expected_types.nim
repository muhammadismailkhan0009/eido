## Applies expected-type checking, contextual integral typing, and optional injection.
## Example: Int can flow into Int?, while none is valid only when an optional type is expected.

## Wraps a definitely-present value in the optional representation expected by its context.
## Example: Int value 7 becomes an Int? HIR some node when returning Int?.
proc liftOptionalValue(
  value: hirExpressions.HirExpr,
  expected: EidoType
): hirExpressions.HirExpr =
  HirExpr(
    kind: hekOptionalSome,
    span: value.span,
    typ: expected,
    optionalValue: value
  )

## Analyzes an expression against an expected semantic type.
## Example: none becomes the expected T?, while a proven T may be injected into T?.
proc analyzeExprExpected*(
  expr: astExpressions.Expr,
  expected: EidoType,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols
): hirExpressions.HirExpr =
  if expr.kind == astExpressions.ekNone:
    if not expected.isOptional:
      failAt(expr.span, "none requires an optional expected type")
    return HirExpr(
      kind: hekNone,
      span: expr.span,
      typ: expected
    )

  if expected.isOptional:
    let required = requiredType(expected)

    if expr.kind == astExpressions.ekInteger and required.isIntegral:
      return liftOptionalValue(analyzeIntegerAs(expr, required), expected)

    let analyzed = analyzeExpr(expr, locals, functions, classes)
    if analyzed.typ == expected:
      return analyzed
    if analyzed.typ == required:
      return liftOptionalValue(analyzed, expected)

    failAt(
      expr.span,
      "type mismatch: expected " & expected.displayName &
        " but got " & analyzed.typ.displayName
    )

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
