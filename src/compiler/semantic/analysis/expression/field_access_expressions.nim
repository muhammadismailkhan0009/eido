## Resolves class field access against nominal class schemas.
## Example: `employee.address.zip` resolves one field at a time using each receiver type.

## Analyzes one field-access expression and returns the declared field type.
proc analyzeFieldAccess(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols
): hirExpressions.HirExpr =
  let target = analyzeExpr(expr.target, locals, functions, classes)

  if target.typ.kind != etkClass:
    failAt(
      expr.span,
      "field access requires a class value but got " &
        target.typ.displayName
    )

  if not classes.contains(target.typ.className):
    failAt(
      expr.span,
      "unknown class type '" & target.typ.className & "'"
    )

  let classSymbol = classes.get(target.typ.className)
  for field in classSymbol.fields:
    if field.name == expr.fieldName:
      return HirExpr(
        kind: hekFieldAccess,
        span: expr.span,
        typ: field.typ,
        target: target,
        sourceFieldName: field.name
      )

  failAt(
    expr.span,
    "class '" & classSymbol.name & "' has no field '" &
      expr.fieldName & "'"
  )
