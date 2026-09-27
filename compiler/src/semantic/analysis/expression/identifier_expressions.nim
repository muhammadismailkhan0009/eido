## Resolves unqualified identifiers to locals, parameters, or the explicit self receiver.
## Proven optional locals are lowered to explicit HIR unwrap nodes while source code stays wrapper-free.

## Resolves one identifier expression from the effective method/function scope.
## Example: inside `if user exists`, user is typed as User and lowered through optional-get HIR.
proc analyzeIdentifier(
  expr: astExpressions.Expr,
  locals: LocalScope
): hirExpressions.HirExpr =
  if not locals.contains(expr.name):
    if expr.name == "self":
      failAt(expr.span, "'self' is only available inside instance methods")
    failAt(expr.span, "unknown local '" & expr.name & "'")

  let symbol = locals.get(expr.name)
  var raw: HirExpr

  case symbol.kind
  of bkReceiver:
    raw = HirExpr(
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
    raw = HirExpr(
      kind: hekLocal,
      span: expr.span,
      typ: symbol.typ,
      localId: symbol.id,
      sourceName: symbol.name
    )

  if raw.typ.isOptional and
      locals.isOptionalProven(optionalPathKey(expr)):
    return HirExpr(
      kind: hekOptionalGet,
      span: expr.span,
      typ: requiredType(raw.typ),
      optionalValue: raw
    )

  raw
