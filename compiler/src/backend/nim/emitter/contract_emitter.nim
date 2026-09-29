## Renders runtime enforcement for typed Eido contracts.
## Contract failure is a backend safety trap and does not define an Eido exception model.

import std/strutils
import ../../../hir/expressions as hirExpressions
import expression_emitter

## Renders one always-enabled runtime contract check at the requested indentation.
proc renderContractCheck*(
  clause: hirExpressions.HirExpr,
  message: string,
  indent: int
): string =
  let pad = repeat(' ', indent)
  result.add pad & "if not (" & renderExpr(clause) & "):\n"
  result.add pad & "  raise newException(AssertionDefect, \"" & message & "\")\n"
