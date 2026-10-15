## Emits compiler-known generic object layout facts for the selected Eido memory runtime.
## These records describe structure only; the runtime decides how to use them.

import ../../../compile_time/model
import ../../../hir/declarations as hirDeclarations
import names
import runtime_bindings

## Finds one class declaration required by compiler-described object metadata.
proc findClass(
  classes: seq[hirDeclarations.HirClass],
  sourceName: string
): hirDeclarations.HirClass =
  for classDecl in classes:
    if classDecl.sourceName == sourceName:
      return classDecl
  raise newException(ValueError, "backend invariant: missing class '" & sourceName & "'")

## Finds one compiler-described byte offset for a class field.
proc findFieldMetadata(
  typeMetadata: CompileTimeTypeMetadata,
  fieldName: string
): CompileTimeFieldMetadata =
  for fieldMetadata in typeMetadata.fields:
    if fieldMetadata.fieldName == fieldName:
      return fieldMetadata
  raise newException(ValueError, "backend invariant: missing field metadata '" & fieldName & "'")

## Renders stable type IDs, payload sizes, and alignments from generic memory metadata.
proc renderMemoryMetadata*(
  metadata: CompileTimeMemoryMetadata,
  interfaces: seq[hirDeclarations.HirInterface]
): string =
  if metadata.types.len == 0:
    return ""
  result.add "const\n"
  for index, typeMetadata in metadata.types:
    let prefix = className(typeMetadata.className) & "_memory"
    result.add "  " & classMemoryTypeIdName(typeMetadata.className) &
      " = int64(" & $index & ")\n"
    result.add "  " & prefix & "_payload_size = int64(" & $typeMetadata.size & ")\n"
    result.add "  " & prefix & "_alignment = int64(" & $typeMetadata.alignment & ")\n"
  for index, interfaceDecl in interfaces:
    result.add "  " & interfaceMemoryTypeIdName(interfaceDecl.sourceName) &
      " = int64(" & $(metadata.types.len + index) & ")\n"
  result.add "\n"

## Renders runtime materialization of generic compiler-provided type/field metadata.
proc renderMemoryMetadataInitializers*(
  metadata: CompileTimeMemoryMetadata,
  classes: seq[hirDeclarations.HirClass],
  interfaces: seq[hirDeclarations.HirInterface],
  runtimeBindings: RuntimeBindings
): string =
  if metadata.types.len == 0 or
      runtimeBindings.metadataType.len == 0 or
      runtimeBindings.metadataField.len == 0:
    return ""

  for typeMetadata in metadata.types:
    let classDecl = findClass(classes, typeMetadata.className)
    let typeId = classMemoryTypeIdName(typeMetadata.className)
    result.add runtimeBindings.metadataType & "(" & typeId &
      ", int64(" & $typeMetadata.fields.len & "))\n"

    for fieldIndex, field in classDecl.fields:
      let fieldMetadata = typeMetadata.findFieldMetadata(field.sourceName)
      result.add runtimeBindings.metadataField & "(" & typeId &
        ", int64(" & $fieldIndex & "), int64(" & $fieldMetadata.offset & "), " &
        (if fieldMetadata.containsIdentity: "true" else: "false") & ")\n"

  # Interface boxes are backend-created objects whose first payload field stores
  # the receiver identity. This remains representation metadata, not collector policy.
  for interfaceDecl in interfaces:
    let typeId = interfaceMemoryTypeIdName(interfaceDecl.sourceName)
    result.add runtimeBindings.metadataType & "(" & typeId & ", int64(1))\n"
    result.add runtimeBindings.metadataField & "(" & typeId &
      ", int64(0), int64(0), true)\n"

  result.add "\n"
