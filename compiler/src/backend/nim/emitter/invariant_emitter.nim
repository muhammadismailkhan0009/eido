## Renders class invariant checkers used by construction and instance-method boundaries.

import ../../../hir/declarations as hirDeclarations
import ../../../semantic/symbols/ids
import names
import type_emitter
import contract_emitter

## Renders one checker per class and returns the checked receiver for expression composition.
proc renderClassInvariantCheckers*(classes: seq[hirDeclarations.HirClass]): string =
  for classDecl in classes:
    if classDecl.invariants.len == 0:
      continue

    let receiverId =
      if classDecl.invariantReceiverLocalId.value >= 0:
        classDecl.invariantReceiverLocalId
      else:
        LocalId(0)
    let receiverName = localName(receiverId, "receiver")
    let depthField = invariantEvaluationDepthFieldName()
    result.add "proc " & classInvariantName(classDecl.sourceName) & "(" &
      receiverName & ": " & renderType(classDecl.typ) & "): " &
      renderType(classDecl.typ) & " =\n"
    result.add "  " & receiverName & "." & depthField & " += 1\n"
    result.add "  defer:\n"
    result.add "    " & receiverName & "." & depthField & " -= 1\n"

    for clause in classDecl.invariants:
      result.add renderContractCheck(
        clause,
        "invariant contract failed for class '" & classDecl.sourceName & "'",
        2
      )

    result.add "  return " & receiverName & "\n\n"
