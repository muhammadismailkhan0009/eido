## Emits class-owned mutable state separately from instance payloads.
## Every source-level class-owned value lives in a one-slot Storage capability.

import ../../../hir/declarations as hirDeclarations
import ../../../types/[model, storage]
import names
import type_emitter
import expression_emitter
import runtime_bindings

## Renders the backend Storage capability type holding one class-owned value.
proc classOwnedStorageType(fieldType: EidoType): string =
  "EidoStorage[" & renderType(fieldType) & "]"

## Renders class-owned mutable state as Storage-backed one-slot capabilities.
proc renderClassStateDeclarations*(
  classes: seq[hirDeclarations.HirClass],
  runtimeBackedObjects: bool
): string =
  for classDecl in classes:
    for field in classDecl.classFields:
      let slot = classOwnedFieldName(classDecl.sourceName, field.sourceName)
      result.add "var " & slot & ": " & classOwnedStorageType(field.typ) & "\n"
      if runtimeBackedObjects and field.typ.isIdentityNominalType:
        result.add "var " & classOwnedFieldMemoryValueName(
          classDecl.sourceName,
          field.sourceName
        ) & ": int64\n"

      if field.typ.kind == etkClass and
          isConcreteStorageTypeName(field.typ.className):
        result.add "proc " & classOwnedFieldReleaseName(
          classDecl.sourceName,
          field.sourceName
        ) & "() =\n"
        result.add "  var value = eidoStorageRead(" & slot & ", int64(0))\n"
        result.add "  " & storageMethodName(field.typ.className, "release") &
          "(value)\n"
        result.add "  eidoStorageWrite(" & slot & ", int64(0), value)\n"
  if result.len > 0:
    result.add "\n"

## Allocates and initializes every class-owned Storage slot in declaration order.
proc renderClassStateInitializers*(
  classes: seq[hirDeclarations.HirClass],
  runtimeBackedObjects: bool,
  runtimeBindings: RuntimeBindings = RuntimeBindings()
): string =
  if runtimeBackedObjects and runtimeBindings.bindingEnter.len > 0:
    for classDecl in classes:
      for field in classDecl.classFields:
        if not field.typ.isIdentityNominalType:
          continue
        let valueSlot = classOwnedFieldMemoryValueName(
          classDecl.sourceName,
          field.sourceName
        )
        result.add valueSlot & " = " & runtimeBindings.bindingEnter & "(int64(0))\n"

  for classDecl in classes:
    for field in classDecl.classFields:
      let slot = classOwnedFieldName(classDecl.sourceName, field.sourceName)
      result.add slot & " = eidoStorageAllocate[" & renderType(field.typ) &
        "](int64(1))\n"
      result.add "eidoStorageWrite(" & slot & ", int64(0), " &
        renderExpr(field.initializer) & ")\n"
      if runtimeBackedObjects and
          field.typ.isIdentityNominalType and
          runtimeBindings.bindingWrite.len > 0:
        let valueSlot = classOwnedFieldMemoryValueName(
          classDecl.sourceName,
          field.sourceName
        )
        result.add runtimeBindings.bindingWrite & "(" & valueSlot &
          ", eidoStorageRead(" & slot & ", int64(0)))\n"

  if result.len > 0:
    result.add "\n"
