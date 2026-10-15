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
  analyzePersistentClassValue(source, expected, locals, functions, classes)
