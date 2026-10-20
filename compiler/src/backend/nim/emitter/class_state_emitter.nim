## Emits class-owned mutable state separately from instance payloads.
## The slot itself is process-lifetime backend representation; dynamic backing
## referenced by its value remains owned by Eido Storage/memory policy.

import ../../../hir/declarations as hirDeclarations
import ../../../types/[model, storage]
import names
import type_emitter
import expression_emitter
import runtime_bindings

## Reports whether one concrete Storage specialization still uses a native release bridge.
proc hasNativeStorageRelease(
  classes: seq[hirDeclarations.HirClass],
  storageName: string
): bool =
  for classDecl in classes:
    if classDecl.sourceName != storageName:
      continue
    for methodDecl in classDecl.methods:
      if methodDecl.sourceName == "release":
        return methodDecl.isNative
  false

## Renders class-owned mutable slots as inline process-lifetime backend values.
proc renderClassStateDeclarations*(
  classes: seq[hirDeclarations.HirClass],
  runtimeBackedObjects: bool
): string =
  for classDecl in classes:
    for field in classDecl.classFields:
      let slot = classOwnedFieldName(classDecl.sourceName, field.sourceName)
      result.add "var " & slot & ": " & renderType(field.typ) & "\n"
      if runtimeBackedObjects and field.typ.isIdentityNominalType:
        result.add "var " & classOwnedFieldMemoryValueName(
          classDecl.sourceName,
          field.sourceName
        ) & ": int64\n"

      if field.typ.kind == etkClass and
          isConcreteStorageTypeName(field.typ.className) and
          hasNativeStorageRelease(classes, field.typ.className):
        result.add "proc " & classOwnedFieldReleaseName(
          classDecl.sourceName,
          field.sourceName
        ) & "() =\n"
        result.add "  var value = " & slot & "\n"
        result.add "  " & storageMethodName(field.typ.className, "release") &
          "(value)\n"
        result.add "  " & slot & " = value\n"
  if result.len > 0:
    result.add "\n"

## Initializes every class-owned slot in declaration order and reports identity roots.
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
      result.add slot & " = " & renderExpr(field.initializer) & "\n"
      if runtimeBackedObjects and
          field.typ.isIdentityNominalType and
          runtimeBindings.bindingWrite.len > 0:
        let valueSlot = classOwnedFieldMemoryValueName(
          classDecl.sourceName,
          field.sourceName
        )
        result.add runtimeBindings.bindingWrite & "(" & valueSlot &
          ", " & slot & ")\n"

  if result.len > 0:
    result.add "\n"
