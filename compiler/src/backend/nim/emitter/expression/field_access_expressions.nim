## Renders resolved field access using generated backend field names.
## Example: employee.address.zip becomes chained generated Nim field access.

## Renders one field-access expression recursively from its receiver.
proc renderFieldAccess(expr: hirExpressions.HirExpr): string =
  classFieldGetName(
    expr.target.typ.className,
    expr.sourceFieldName
  ) & "(" & renderExpr(expr.target) & ")"
