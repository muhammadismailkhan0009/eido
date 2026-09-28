## Applies expected-type checking, contextual integral typing, optional injection,
## and explicit nominal conversion into interface values.

## Wraps a definitely-present value in the optional representation expected by its context.
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

## Converts one proven class/interface subtype to its expected interface wrapper.
proc convertInterfaceValue(
  value: hirExpressions.HirExpr,
  expected: EidoType,
  classes: NominalSymbols
): hirExpressions.HirExpr =
  if value.typ == expected:
    return value

  if not classes.isAssignable(value.typ, expected):
    failAt(
      value.span,
      "type mismatch: expected " & expected.displayName &
        " but got " & value.typ.displayName
    )

  HirExpr(
    kind: hekInterfaceConvert,
    span: value.span,
    typ: expected,
    interfaceValue: value
  )

## Analyzes an expression against an expected semantic type.
proc analyzeExprExpected*(
  expr: astExpressions.Expr,
  expected: EidoType,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
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

    if required.kind == etkInterface and
        not analyzed.typ.isOptional and
        classes.isAssignable(analyzed.typ, required):
      return liftOptionalValue(
        convertInterfaceValue(analyzed, required, classes),
        expected
      )

    failAt(
      expr.span,
      "type mismatch: expected " & expected.displayName &
        " but got " & analyzed.typ.displayName
    )

  if expr.kind == astExpressions.ekInteger and expected.isIntegral:
    return analyzeIntegerAs(expr, expected)

  let analyzed = analyzeExpr(expr, locals, functions, classes)
  if analyzed.typ == expected:
    return analyzed

  if expected.kind == etkInterface and
      classes.isAssignable(analyzed.typ, expected):
    return convertInterfaceValue(analyzed, expected, classes)

  failAt(
    expr.span,
    "type mismatch: expected " & expected.displayName &
      " but got " & analyzed.typ.displayName
  )
