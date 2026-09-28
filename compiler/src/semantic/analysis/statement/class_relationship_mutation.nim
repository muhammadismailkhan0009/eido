## Validates class-valued relationship replacement for set targets.
## Optional absence is not an identity choice; present class values retain copy/ref rules.

## Analyzes a value used to replace a persistent class relationship.
## Fresh/detached values and none flow directly; existing values require explicit copy/ref.
proc analyzeClassRelationshipMutationValue(
  source: astExpressions.Expr,
  expected: EidoType,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
): HirExpr =
  if expected.kind != etkClass:
    raise newException(
      ValueError,
      "semantic invariant: class relationship mutation requires class target"
    )

  if source.kind == astExpressions.ekNone:
    return analyzeExprExpected(
      source,
      expected,
      locals,
      functions,
      classes
    )

  if source.kind == astExpressions.ekClassRelation:
    result = analyzeClassValueRelation(source, locals, functions, classes)

    if expected.isOptional and result.typ == requiredType(expected):
      return HirExpr(
        kind: hekOptionalSome,
        span: result.span,
        typ: expected,
        optionalValue: result
      )

    if result.typ != expected:
      failAt(
        source.span,
        "type mismatch: expected " & expected.displayName &
          " but got " & result.typ.displayName
      )
    return

  result = analyzeExprExpected(
    source,
    expected,
    locals,
    functions,
    classes
  )

  if source.kind notin {
    astExpressions.ekConstruct,
    astExpressions.ekCall,
    astExpressions.ekMethodCall
  }:
    failAt(
      source.span,
      "existing class relationship replacement requires explicit copy or ref"
    )
