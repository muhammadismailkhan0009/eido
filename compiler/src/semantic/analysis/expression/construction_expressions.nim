## Validates named class construction and lowers it to typed HIR.
## Every declared field must appear exactly once; source field order is semantically irrelevant.

## Analyzes one complete class construction expression.
proc analyzeConstruction(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols
): hirExpressions.HirExpr =
  if not classes.contains(expr.typeName):
    failAt(expr.span, "unknown class '" & expr.typeName & "'")

  let target = classes.get(expr.typeName)
  var suppliedNames: seq[string]
  var fields: seq[hirExpressions.HirConstructionField]

  for sourceField in expr.fields:
    if sourceField.name in suppliedNames:
      failAt(
        sourceField.span,
        "duplicate construction field '" & sourceField.name & "'"
      )

    var found = false
    var expectedType = etInt
    for declaredField in target.fields:
      if declaredField.name == sourceField.name:
        found = true
        expectedType = declaredField.typ
        break

    if not found:
      failAt(
        sourceField.span,
        "class '" & target.name & "' has no field '" &
          sourceField.name & "'"
      )

    suppliedNames.add sourceField.name

    let analyzedValue =
      if sourceField.value.kind == astExpressions.ekClassRelation:
        let relationValue = analyzeClassValueRelation(
          sourceField.value,
          locals,
          functions,
          classes
        )
        if relationValue.typ != expectedType:
          failAt(
            sourceField.value.span,
            "type mismatch: expected " & expectedType.displayName &
              " but got " & relationValue.typ.displayName
          )
        relationValue
      else:
        let value = analyzeExprExpected(
          sourceField.value,
          expectedType,
          locals,
          functions,
          classes
        )
        if expectedType.kind == etkClass and
            sourceField.value.kind notin {
              astExpressions.ekConstruct,
              astExpressions.ekCall,
              astExpressions.ekMethodCall
            }:
          failAt(
            sourceField.value.span,
            "existing class construction field requires explicit copy or ref"
          )
        value

    fields.add hirExpressions.HirConstructionField(
      span: sourceField.span,
      sourceName: sourceField.name,
      value: analyzedValue
    )

  for declaredField in target.fields:
    if declaredField.name notin suppliedNames:
      failAt(
        expr.span,
        "construction of '" & target.name &
          "' is missing field '" & declaredField.name & "'"
      )

  HirExpr(
    kind: hekConstruct,
    span: expr.span,
    typ: target.typ,
    constructedTypeName: target.name,
    fields: fields
  )
