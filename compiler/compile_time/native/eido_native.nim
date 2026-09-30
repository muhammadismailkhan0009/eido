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

proc eido_native_method_Compiler_typeCount*(): int64 =
  int64(snapshot()["declarations"].len)

proc eido_native_method_Compiler_typeAt*(index: int64): int64 =
  let declarations = snapshot()["declarations"]
  requireIndex(index, int64(declarations.len), "declaration")
  declarations[int(index)].getBiggestInt().int64

proc eido_native_method_TypeInfo_isManaged*(typeHandle: int64): bool =
  typeNode(typeHandle)["managed"].getBool()

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

proc eido_native_method_StorageInfo_sizeOf*(typeHandle: int64): int64 =
  typeNode(typeHandle)["size"].getBiggestInt().int64

proc eido_native_method_StorageInfo_alignmentOf*(typeHandle: int64): int64 =
  typeNode(typeHandle)["alignment"].getBiggestInt().int64

proc emitRecord(kind, first, second, third: int64) =
  echo &"EIDO_CT|{kind}|{first}|{second}|{third}"

proc eido_native_method_MemoryPlan_field*(
  ownerType,
  fieldHandle,
  offset: int64
) =
  emitRecord(1, ownerType, fieldHandle, offset)

proc eido_native_method_MemoryPlan_trace*(
  ownerType,
  fieldHandle: int64
) =
  emitRecord(2, ownerType, fieldHandle, 0)

proc eido_native_method_MemoryPlan_layout*(
  typeHandle,
  size,
  alignment: int64
) =
  emitRecord(3, typeHandle, size, alignment)
