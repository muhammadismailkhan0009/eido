## Resolves class field schemas after all nominal class names have been registered.

import std/sets
import ../../diagnostics/errors
import ../../frontend/ast/declarations as astDeclarations
import ../../hir/declarations as hirDeclarations
import ../symbols/nominals
import type_resolution

## Resolves one class declaration and rejects duplicate field names.
proc analyzeClass*(
  source: astDeclarations.ClassDecl,
  classes: NominalSymbols
): hirDeclarations.HirClass =
  var fieldNames = initHashSet[string]()
  var fields: seq[hirDeclarations.HirField]

  for field in source.fields:
    if field.name in fieldNames:
      failAt(field.span, "duplicate field '" & field.name & "'")
    fieldNames.incl field.name

    fields.add hirDeclarations.HirField(
      span: field.span,
      sourceName: field.name,
      typ: resolveDeclaredType(field.typeRef, classes)
    )

  hirDeclarations.HirClass(
    span: source.span,
    sourceName: source.name,
    typ: classes.getClass(source.name).typ,
    implements: source.implements,
    fields: fields,
    methods: @[]
  )
