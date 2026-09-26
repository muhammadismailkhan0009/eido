## Analyzes primitive literals and contextual integral literal typing.
## Example: unsuffixed `7` is Int normally, but may become Byte in a Byte context.

## Checks whether an integer literal fits the requested integral primitive.
## Example: 127 fits Byte; Int accepts the full parsed signed 64-bit range.
proc integerFits(value: int64, typ: EidoType): bool =
  if typ.kind != etkPrimitive:
    return false

  case typ.primitive
  of ptByte:
    value >= -128'i64 and value <= 127'i64
  of ptShort:
    value >= -32768'i64 and value <= 32767'i64
  of ptInt:
    true
  else:
    false

## Creates a typed HIR integer literal after range checking.
## Example: source `7` with expected Short becomes an `hekInteger` of type `etShort`.
proc analyzeIntegerAs(
  expr: astExpressions.Expr,
  typ: EidoType
): hirExpressions.HirExpr =
  if not integerFits(expr.intValue, typ):
    failAt(
      expr.span,
      "integer literal " & $expr.intValue & " does not fit " & typ.displayName
    )

  HirExpr(
    kind: hekInteger,
    span: expr.span,
    typ: typ,
    intValue: expr.intValue
  )

## Analyzes one primitive literal expression using its default Eido type.
## Example: `2.5` becomes Float while `2147483648` remains Int.
proc analyzeLiteral(expr: astExpressions.Expr): hirExpressions.HirExpr =
  case expr.kind
  of astExpressions.ekInteger:
    analyzeIntegerAs(expr, etInt)
  of astExpressions.ekFloat:
    HirExpr(
      kind: hekFloating,
      span: expr.span,
      typ: etFloat,
      floatValue: expr.floatValue
    )
  of astExpressions.ekBoolean:
    HirExpr(
      kind: hekBoolean,
      span: expr.span,
      typ: etBool,
      boolValue: expr.boolValue
    )
  of astExpressions.ekChar:
    HirExpr(
      kind: hekChar,
      span: expr.span,
      typ: etChar,
      charValue: expr.charValue
    )
  else:
    raise newException(ValueError, "semantic invariant: expected literal expression")
