## Private native bridge for compiler-standard Eido compile-time phases.
## This module is materialized only beside cached phase executables and is never
## part of the ordinary Eido native-support path.

import std/[json, os, strformat, tables]

var
  snapshotLoaded = false
  snapshotRoot: JsonNode

proc snapshot(): JsonNode =
  if not snapshotLoaded:
    let arguments = commandLineParams()
    if arguments.len != 1:
      raise newException(
        ValueError,
        "compile-time phase requires exactly one semantic snapshot path"
      )
    snapshotRoot = parseFile(arguments[0])
    snapshotLoaded = true
  snapshotRoot

proc requireIndex(index, count: int64, label: string) =
  if index < 0 or index >= count:
    raise newException(
      IndexDefect,
      label & " handle/index is outside the compile-time snapshot"
    )

proc typeNode(typeHandle: int64): JsonNode =
  let types = snapshot()["types"]
  requireIndex(typeHandle, int64(types.len), "type")
  types[int(typeHandle)]

proc fieldNode(fieldHandle: int64): JsonNode =
  let fields = snapshot()["fields"]
  requireIndex(fieldHandle, int64(fields.len), "field")
  fields[int(fieldHandle)]


proc callableNode(callableHandle: int64): JsonNode =
  let callables = snapshot()["callables"]
  requireIndex(callableHandle, int64(callables.len), "callable")
  callables[int(callableHandle)]

proc valueNode(valueHandle: int64): JsonNode =
  let values = snapshot()["values"]
  requireIndex(valueHandle, int64(values.len), "value")
  values[int(valueHandle)]

proc eido_native_method_Compiler_typeCount*(): int64 =
  int64(snapshot()["declarations"].len)

proc eido_native_method_Compiler_typeAt*(index: int64): int64 =
  let declarations = snapshot()["declarations"]
  requireIndex(index, int64(declarations.len), "declaration")
  declarations[int(index)].getBiggestInt().int64


proc eido_native_method_Compiler_callableCount*(): int64 =
  int64(snapshot()["callables"].len)

proc eido_native_method_Compiler_callableAt*(index: int64): int64 =
  let callables = snapshot()["callables"]
  requireIndex(index, int64(callables.len), "callable")
  index

proc eido_native_method_TypeInfo_isIdentity*(typeHandle: int64): bool =
  typeNode(typeHandle)["identity"].getBool()

proc eido_native_method_TypeInfo_fieldCount*(typeHandle: int64): int64 =
  int64(typeNode(typeHandle)["fields"].len)

proc eido_native_method_TypeInfo_fieldAt*(
  typeHandle: int64,
  index: int64
): int64 =
  let fields = typeNode(typeHandle)["fields"]
  requireIndex(index, int64(fields.len), "type field")
  fields[int(index)].getBiggestInt().int64

proc eido_native_method_FieldInfo_typeOf*(fieldHandle: int64): int64 =
  fieldNode(fieldHandle)["type"].getBiggestInt().int64


proc eido_native_method_CallableInfo_parameterCount*(
  callableHandle: int64
): int64 =
  int64(callableNode(callableHandle)["parameters"].len)

proc eido_native_method_CallableInfo_parameterAt*(
  callableHandle,
  index: int64
): int64 =
  let parameters = callableNode(callableHandle)["parameters"]
  requireIndex(index, int64(parameters.len), "callable parameter")
  parameters[int(index)].getBiggestInt().int64

proc eido_native_method_CallableInfo_localCount*(
  callableHandle: int64
): int64 =
  int64(callableNode(callableHandle)["locals"].len)

proc eido_native_method_CallableInfo_localAt*(
  callableHandle,
  index: int64
): int64 =
  let locals = callableNode(callableHandle)["locals"]
  requireIndex(index, int64(locals.len), "callable local")
  locals[int(index)].getBiggestInt().int64

proc eido_native_method_ValueInfo_typeOf*(valueHandle: int64): int64 =
  valueNode(valueHandle)["type"].getBiggestInt().int64

proc eido_native_method_StorageInfo_sizeOf*(typeHandle: int64): int64 =
  typeNode(typeHandle)["size"].getBiggestInt().int64

proc eido_native_method_StorageInfo_alignmentOf*(typeHandle: int64): int64 =
  typeNode(typeHandle)["alignment"].getBiggestInt().int64

# Build-machine-only layout builder context. The placement algorithm lives in
# Layout.eido; this bridge provides semantic lookup and emits validated facts.
var activeLayout = -1'i64
var activeType = -1'i64
var recordedLayoutFields = initTable[(int64, int64), int64]()

proc eido_native_method_LayoutRuntime_begin*(layoutId: int64, ownerName: string) =
  activeLayout = layoutId
  activeType = -1
  let types = snapshot()["types"]
  for i in 0 ..< types.len:
    if types[i]["name"].getStr() == ownerName:
      activeType = int64(i)
      break
  if activeType < 0:
    raise newException(ValueError, "unknown layout target: " & ownerName)

proc eido_native_method_LayoutRuntime_currentType*(): int64 =
  if activeType < 0:
    raise newException(ValueError, "Layout.create outside a layout declaration")
  activeType

proc eido_native_method_LayoutRuntime_currentLayout*(): int64 =
  if activeLayout < 0:
    raise newException(ValueError, "Layout.create outside a layout declaration")
  activeLayout

proc eido_native_method_LayoutRuntime_findField*(ownerType: int64, name: string): int64 =
  let fields = typeNode(ownerType)["fields"]
  for handle in fields:
    let index = handle.getBiggestInt().int64
    if fieldNode(index)["name"].getStr() == name:
      return index
  raise newException(ValueError, "layout field '" & name & "' does not belong to target class")

proc eido_native_method_LayoutRuntime_checkAlignment*(alignment: int64) =
  if alignment <= 0 or (alignment and (alignment - 1)) != 0:
    raise newException(ValueError, "layout alignment must be a positive power of two")

proc eido_native_method_LayoutRuntime_recordField*(layoutId, field, offset: int64) =
  if layoutId != activeLayout or fieldNode(field)["owner"].getBiggestInt() != activeType:
    raise newException(ValueError, "layout field belongs to a different declaration")
  let key = (layoutId, field)
  if key in recordedLayoutFields:
    raise newException(ValueError, "layout field placed twice: " & fieldNode(field)["name"].getStr())
  recordedLayoutFields[key] = offset
  echo &"EIDO_CT|5|{layoutId}|{field}|{offset}"

proc eido_native_method_LayoutRuntime_offsetOf*(layoutId, field: int64): int64 =
  let key = (layoutId, field)
  if key notin recordedLayoutFields:
    raise newException(ValueError, "layout field has not been placed")
  recordedLayoutFields[key]

proc eido_native_method_LayoutRuntime_complete*(layoutId, size, alignment: int64) =
  if layoutId != activeLayout:
    raise newException(ValueError, "layout context mismatch")
  echo &"EIDO_CT|6|{layoutId}|{size}|{alignment}"
  activeLayout = -1
  activeType = -1

proc emitRecord(kind, first, second, third: int64) =
  echo &"EIDO_CT|{kind}|{first}|{second}|{third}"

proc eido_native_method_MemoryMetadata_field*(
  ownerType,
  fieldHandle,
  offset: int64
) =
  emitRecord(1, ownerType, fieldHandle, offset)

proc eido_native_method_MemoryMetadata_identityField*(
  ownerType,
  fieldHandle: int64
) =
  emitRecord(2, ownerType, fieldHandle, 0)

proc eido_native_method_MemoryMetadata_recordLayout*(
  typeHandle,
  size,
  alignment: int64
) =
  emitRecord(3, typeHandle, size, alignment)


proc eido_native_method_MemoryMetadata_identityValue*(
  callableHandle,
  valueHandle: int64
) =
  emitRecord(4, callableHandle, valueHandle, 0)

## Emits one named generic program-event binding selected by an Eido memory policy.
proc emitPolicyBinding(eventName, handler: string) =
  echo "EIDO_BIND|" & eventName & "|" & handler

proc eido_native_method_MemoryPolicy_bindingEnter*(handler: string) =
  emitPolicyBinding("bindingEnter", handler)

proc eido_native_method_MemoryPolicy_bindingWrite*(handler: string) =
  emitPolicyBinding("bindingWrite", handler)

proc eido_native_method_MemoryPolicy_bindingLeave*(handler: string) =
  emitPolicyBinding("bindingLeave", handler)

proc eido_native_method_MemoryPolicy_typeMetadata*(handler: string) =
  emitPolicyBinding("typeMetadata", handler)

proc eido_native_method_MemoryPolicy_fieldMetadata*(handler: string) =
  emitPolicyBinding("fieldMetadata", handler)

proc eido_native_method_MemoryPolicy_objectAcquire*(handler: string) =
  emitPolicyBinding("objectAcquire", handler)

proc eido_native_method_MemoryPolicy_temporaryEnter*(handler: string) =
  emitPolicyBinding("temporaryEnter", handler)

proc eido_native_method_MemoryPolicy_temporaryLeave*(handler: string) =
  emitPolicyBinding("temporaryLeave", handler)

proc eido_native_method_MemoryPolicy_executionBoundary*(handler: string) =
  emitPolicyBinding("executionBoundary", handler)

proc eido_native_method_MemoryPolicy_invariantEnter*(handler: string) =
  emitPolicyBinding("invariantEnter", handler)

proc eido_native_method_MemoryPolicy_invariantLeave*(handler: string) =
  emitPolicyBinding("invariantLeave", handler)

proc eido_native_method_MemoryPolicy_invariantClear*(handler: string) =
  emitPolicyBinding("invariantClear", handler)

proc eido_native_method_MemoryPolicy_programExit*(handler: string) =
  emitPolicyBinding("programExit", handler)
