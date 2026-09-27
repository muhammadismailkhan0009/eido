## Resolves unqualified identifiers to locals, parameters, or the explicit self receiver.

## Resolves one identifier expression from the effective method/function scope.
proc analyzeIdentifier(
  expr: astExpressions.Expr,
  locals: LocalScope
): hirExpressions.HirExpr =
  if not locals.contains(expr.name):
    if expr.name == "self":
      failAt(expr.span, "'self' is only available inside instance methods")
    failAt(expr.span, "unknown local '" & expr.name & "'")

  let symbol = locals.get(expr.name)
  case symbol.kind
  of bkReceiver:
    HirExpr(
      kind: hekLocal,
      span: expr.span,
      typ: symbol.typ,
      localId: symbol.id,
      sourceName: "receiver"
    )

  of bkField:
    failAt(
      expr.span,
      "own field '" & symbol.name & "' must be accessed through self." &
        symbol.name
    )

  of bkParameter, bkVariable:
    HirExpr(
      kind: hekLocal,
      span: expr.span,
      typ: symbol.typ,
      localId: symbol.id,
      sourceName: symbol.name
    )
