## Resolves unqualified identifiers to locals, parameters, or own-class fields.

## Resolves one identifier expression from the effective method/function scope.
proc analyzeIdentifier(
  expr: astExpressions.Expr,
  locals: LocalScope
): hirExpressions.HirExpr =
  if not locals.contains(expr.name):
    failAt(expr.span, "unknown local or field '" & expr.name & "'")

  let symbol = locals.get(expr.name)
  case symbol.kind
  of bkField:
    let receiver = HirExpr(
      kind: hekLocal,
      span: expr.span,
      typ: symbol.ownerType,
      localId: symbol.receiverId,
      sourceName: "receiver"
    )
    HirExpr(
      kind: hekFieldAccess,
      span: expr.span,
      typ: symbol.typ,
      target: receiver,
      sourceFieldName: symbol.name
    )

  of bkParameter, bkVariable:
    HirExpr(
      kind: hekLocal,
      span: expr.span,
      typ: symbol.typ,
      localId: symbol.id,
      sourceName: symbol.name
    )
