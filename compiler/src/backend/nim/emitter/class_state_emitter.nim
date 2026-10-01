## Emits class-owned mutable state separately from instance payloads.
## Class fields are one process-wide slot per class and never enter constructors.

import ../../../hir/declarations as hirDeclarations
import names
import type_emitter
import expression_emitter

## Renders one global backend slot for every class-owned Eido field.
proc renderClassState*(classes: seq[hirDeclarations.HirClass]): string =
  for classDecl in classes:
    for field in classDecl.classFields:
      result.add "var " & classOwnedFieldName(
        classDecl.sourceName,
        field.sourceName
      ) & ": " & renderType(field.typ) & " = " &
        renderExpr(field.initializer) & "\n"
  if result.len > 0:
    result.add "\n"
