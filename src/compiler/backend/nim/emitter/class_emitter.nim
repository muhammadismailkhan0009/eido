## Renders nominal Eido class layouts for the Nim backend.
## The ref-object representation is an internal backend choice, not an Eido reference-semantics contract.

import ../../../hir/declarations as hirDeclarations
import names
import type_emitter

## Renders all class layouts in one Nim type section so class fields may reference other declared classes.
proc renderClasses*(classes: seq[hirDeclarations.HirClass]): string =
  if classes.len == 0:
    return ""

  result.add "type\n"
  for classDecl in classes:
    result.add "  " & className(classDecl.sourceName) & " = ref object\n"

    if classDecl.fields.len == 0:
      result.add "    discard\n"
    else:
      for field in classDecl.fields:
        result.add "    " & fieldName(field.sourceName) &
          ": " & renderType(field.typ) & "\n"

  result.add "\n"
