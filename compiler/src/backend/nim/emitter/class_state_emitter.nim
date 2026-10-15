## Emits class-owned mutable state separately from instance payloads.
## Class fields are process-wide slots and never enter constructors or instance layout.

import ../../../hir/declarations as hirDeclarations
import names
import type_emitter
import expression_emitter

## Declares every class-owned slot before generated helpers so static initializers may
## freely refer to other class-owned state regardless of source declaration order.
proc renderClassStateDeclarations*(
  classes: seq[hirDeclarations.HirClass],
  managedRuntime: bool
): string =
  for classDecl in classes:
    for field in classDecl.classFields:
      result.add "var " & classOwnedFieldName(
        classDecl.sourceName,
        field.sourceName
      ) & ": " & renderType(field.typ) & "\n"
      if managedRuntime and field.typ.isManagedNominalType:
        result.add "var " & classOwnedFieldRootName(
          classDecl.sourceName,
          field.sourceName
        ) & ": EidoGcRoot\n"
  if result.len > 0:
    result.add "\n"

## Registers managed class-owned slots as permanent precise roots before evaluating
## any initializer, then evaluates all initializers after generated helpers exist.
proc renderClassStateInitializers*(
  classes: seq[hirDeclarations.HirClass],
  managedRuntime: bool
): string =
  if managedRuntime:
    for classDecl in classes:
      for field in classDecl.classFields:
        if not field.typ.isManagedNominalType:
          continue
        let slot = classOwnedFieldName(classDecl.sourceName, field.sourceName)
        let root = classOwnedFieldRootName(classDecl.sourceName, field.sourceName)
        result.add "eidoGcPushRoot(addr " & root &
          ", cast[ptr EidoManagedRef](addr " & slot & "))\n"

  for classDecl in classes:
    for field in classDecl.classFields:
      result.add classOwnedFieldName(
        classDecl.sourceName,
        field.sourceName
      ) & " = " & renderExpr(field.initializer) & "\n"

  if result.len > 0:
    result.add "\n"
