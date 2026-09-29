## Analyzes declaration-level Design by Contract expressions.
## Every contract clause must resolve to Bool and is preserved as typed HIR.

import ../../diagnostics/errors
import ../../frontend/ast/expressions as astExpressions
import ../../hir/expressions as hirExpressions
import ../../types/model
import ../symbols/[functions, nominals, scope]
import expression_analysis


## Reports whether one contract expression references the contextual result name.
proc referencesResult(expr: astExpressions.Expr): bool =
  if expr.isNil:
    return false

  case expr.kind
  of ekIdentifier:
    expr.name == "result"
  of ekCall:
    for argument in expr.arguments:
      if referencesResult(argument):
        return true
    false
  of ekConstruct:
    for field in expr.fields:
      if referencesResult(field.value):
        return true
    false
  of ekClassRelation:
    referencesResult(expr.relatedValue)
  of ekFieldAccess:
    referencesResult(expr.target)
  of ekMethodCall:
    if referencesResult(expr.receiver):
      return true
    for argument in expr.methodArguments:
      if referencesResult(argument):
        return true
    false
  of ekUnary:
    referencesResult(expr.operand)
  of ekBinary:
    referencesResult(expr.left) or referencesResult(expr.right)
  of ekInteger, ekFloat, ekBoolean, ekChar, ekString, ekNone, ekTypeReference:
    false

## Resolves contract clauses in the supplied declaration scope and requires Bool results.
proc analyzeContractClauses*(
  clauses: seq[astExpressions.Expr],
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols,
  contractName: string,
  contextualResultAvailable: bool = false
): seq[hirExpressions.HirExpr] =
  for clause in clauses:
    if contractName == "ensure" and
        not contextualResultAvailable and
        referencesResult(clause):
      failAt(
        clause.span,
        "'result' is only available inside ensure of a value-returning callable"
      )
    let analyzed = analyzeExpr(clause, locals, functions, classes)
    if analyzed.typ != etBool:
      failAt(
        clause.span,
        "'" & contractName & "' contract clause must be Bool but got " &
          analyzed.typ.displayName
      )
    result.add analyzed
