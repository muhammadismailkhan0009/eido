## Renders validated named class construction.
## Example: Point { x: 10; } becomes a generated Nim ref-object initializer.

## Renders one construction expression using generated class/field identifiers.
proc renderConstruction(expr: hirExpressions.HirExpr): string =
  result = className(expr.constructedTypeName) & "("

  for index, field in expr.fields:
    if index > 0:
      result.add ", "
    result.add fieldName(field.sourceName) & ": " &
      renderExpr(field.value)

  result.add ")"
