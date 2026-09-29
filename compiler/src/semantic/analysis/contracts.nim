## Analyzes declaration-level Design by Contract expressions.
## Every contract clause must resolve to Bool and is preserved as typed HIR.

import ../../diagnostics/errors
import ../../frontend/ast/expressions as astExpressions
import ../../hir/expressions as hirExpressions
import ../../types/model
import ../symbols/[functions, nominals, scope]
import expression_analysis

## Resolves contract clauses in the supplied declaration scope and requires Bool results.
proc analyzeContractClauses*(
  clauses: seq[astExpressions.Expr],
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols,
  contractName: string
): seq[hirExpressions.HirExpr] =
  for clause in clauses:
    let analyzed = analyzeExpr(clause, locals, functions, classes)
    if analyzed.typ != etBool:
      failAt(
        clause.span,
        "'" & contractName & "' contract clause must be Bool but got " &
          analyzed.typ.displayName
      )
    result.add analyzed
