## Resolves local identifier expressions to typed semantic identities.
## Example: source `count` becomes an HIR local carrying its LocalId and Int type.

## Resolves one local identifier expression.
## Example: `value` is rejected when no local or parameter with that name exists.
proc analyzeIdentifier(
  expr: astExpressions.Expr,
  locals: LocalScope
): hirExpressions.HirExpr =
  if not locals.contains(expr.name):
    failAt(expr.span, "unknown local '" & expr.name & "'")

  let symbol = locals.get(expr.name)
  HirExpr(
    kind: hekLocal,
    span: expr.span,
    typ: symbol.typ,
    localId: symbol.id,
    sourceName: symbol.name
  )
