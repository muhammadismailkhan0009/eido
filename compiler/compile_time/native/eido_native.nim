## Private native bridge for compiler-standard Eido compile-time phases.
## This module is materialized only beside cached phase executables and is never
## part of the ordinary Eido native-support path.

import std/[json, os, strformat]

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

proc eido_native_method_MemoryMetadata_layout*(
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

## Emits one generic program-event binding selected by an Eido compile-time policy.
proc eido_native_method_RuntimeBindings_bind*(
  eventKind: int64,
  methodName: string
) =
  echo "EIDO_BIND|" & $eventKind & "|" & methodName
