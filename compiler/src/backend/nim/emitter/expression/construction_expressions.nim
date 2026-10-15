## Renders validated named class construction.
## Example: Point { x: 10; } becomes a generated representation-neutral constructor call.

## Renders one construction expression using generated class/field identifiers.
proc renderConstruction(expr: hirExpressions.HirExpr): string =
  var rendered = ""
  if expr.checkInvariant:
    rendered = classInvariantName(expr.constructedTypeName) & "("
  rendered.add classConstructorName(expr.constructedTypeName) & "("

  for index, field in expr.fields:
    if index > 0:
      rendered.add ", "
    rendered.add "arg_" & fieldName(field.sourceName) & " = " &
      renderExpr(field.value)

  rendered.add ")"
  if expr.checkInvariant:
    rendered.add ")"

  protectIdentityTemporaries(rendered, true)
