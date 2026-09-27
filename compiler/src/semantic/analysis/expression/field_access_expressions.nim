## Resolves class field access against nominal class schemas.
## Optional receivers require an enclosing exists proof before member access.

## Analyzes one field-access expression and returns the declared or proven field type.
## Example: employee.address is Address? normally and Address inside its exists block.
proc analyzeFieldAccess(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols
): hirExpressions.HirExpr =
  let target = analyzeExpr(expr.target, locals, functions, classes)

  if target.typ.isOptional:
    failAt(
      expr.target.span,
      "optional value '" & optionalPathKey(expr.target) &
        "' requires an exists block before member access"
    )

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
      let raw = HirExpr(
        kind: hekFieldAccess,
        span: expr.span,
        typ: field.typ,
        target: target,
        sourceFieldName: field.name
      )

      if field.typ.isOptional and
          locals.isOptionalProven(optionalPathKey(expr)):
        return HirExpr(
          kind: hekOptionalGet,
          span: expr.span,
          typ: requiredType(field.typ),
          optionalValue: raw
        )

      return raw

  failAt(
    expr.span,
    "class '" & classSymbol.name & "' has no field '" &
      expr.fieldName & "'"
  )
