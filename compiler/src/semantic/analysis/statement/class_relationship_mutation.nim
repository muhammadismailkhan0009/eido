## Validates class-valued relationship replacement for set targets.
## Example: `set current = ref other;` preserves identity while `copy other` detaches it.

## Analyzes a value used to replace a persistent class relationship.
## Fresh/detached values flow directly; existing values require explicit copy/ref.
proc analyzeClassRelationshipMutationValue(
  source: astExpressions.Expr,
  expected: EidoType,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols
): HirExpr =
  if expected.kind != etkClass:
    raise newException(
      ValueError,
      "semantic invariant: class relationship mutation requires class target"
    )

  if source.kind == astExpressions.ekClassRelation:
    result = analyzeClassValueRelation(source, locals, functions, classes)
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
