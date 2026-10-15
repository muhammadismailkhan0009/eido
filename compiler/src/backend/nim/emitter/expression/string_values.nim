## Renders immutable Eido String operations through the Storage-backed language runtime.

## Renders one UTF-8 source byte as the signed Byte representation used by Eido.
proc renderStringByte(value: char): string =
  let raw = ord(value)
  let signed = if raw <= 127: raw else: raw - 256
  "int8(" & $signed & ")"

## Renders one decoded String literal as fixed UTF-8 bytes copied into Eido storage.
proc renderStringLiteral(expr: hirExpressions.HirExpr): string =
  if expr.typ != etString or expr.kind != hirExpressions.hekString:
    raise newException(ValueError, "backend invariant: expected String literal HIR")

  if expr.stringValue.len == 0:
    return stringAllocateName() & "(int64(0))"

  result.add stringLiteralName() & "(["
  for index, value in expr.stringValue:
    if index > 0:
      result.add ", "
    result.add renderStringByte(value)
  result.add "])"

## Renders String concatenation through the built-in Eido String runtime.
proc renderStringConcatenation(expr: hirExpressions.HirExpr): string =
  if expr.typ != etString or expr.op != hirExpressions.hboAdd:
    raise newException(ValueError, "backend invariant: expected String concatenation")
  stringConcatName() & "(" & renderExpr(expr.left) & ", " &
    renderExpr(expr.right) & ")"

## Renders String equality/inequality by immutable UTF-8 byte content.
proc renderStringEquality(expr: hirExpressions.HirExpr): string =
  if expr.op notin {hirExpressions.hboEqual, hirExpressions.hboNotEqual} or
      expr.left.typ != etString or expr.right.typ != etString:
    raise newException(ValueError, "backend invariant: expected String equality")

  let comparison = stringEqualName() & "(" & renderExpr(expr.left) & ", " &
    renderExpr(expr.right) & ")"
  if expr.op == hirExpressions.hboNotEqual:
    "(not " & comparison & ")"
  else:
    comparison
