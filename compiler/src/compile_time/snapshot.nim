## Builds the private semantic snapshot consumed by compiler-standard Eido phases.
## Handles are dense integer ids valid only for one phase invocation.

import std/json
import ../hir/[declarations, program]
import ../types/[model, storage]
import target_storage_layout

type
  SnapshotType = object
    typ: EidoType
    fields: seq[int64]
    managed: bool

  SnapshotField = object
    ownerType: int64
    typ: int64

  CompileTimeSnapshot = object
    types: seq[SnapshotType]
    fields: seq[SnapshotField]
    declarations: seq[int64]

## Finds an existing invocation-local handle for one semantic type or returns -1.
proc findType(types: seq[SnapshotType], typ: EidoType): int =
  for index, candidate in types:
    if candidate.typ == typ:
      return index
  -1

## Reports whether one semantic value is traced by the first managed-object collector.
proc isManagedReference(typ: EidoType): bool =
  case typ.kind
  of etkClass:
    not isConcreteStorageTypeName(typ.className)
  of etkInterface:
    true
  of etkPrimitive, etkString:
    false

## Returns a dense invocation-local type handle, adding the semantic type when necessary.
proc ensureType(snapshot: var CompileTimeSnapshot, typ: EidoType): int64 =
  let existing = findType(snapshot.types, typ)
  if existing >= 0:
    return int64(existing)

  let handle = int64(snapshot.types.len)
  snapshot.types.add SnapshotType(
    typ: typ,
    fields: @[],
    managed: isManagedReference(typ)
  )
  handle

## Adds one ordinary class declaration and its fields to the compile-time snapshot.
proc addClass(
  snapshot: var CompileTimeSnapshot,
  classDecl: HirClass
) =
  if isConcreteStorageTypeName(classDecl.sourceName):
    return

  let typeHandle = snapshot.ensureType(classDecl.typ)
  snapshot.declarations.add typeHandle

  for field in classDecl.fields:
    let fieldTypeHandle = snapshot.ensureType(field.typ)
    let fieldHandle = int64(snapshot.fields.len)
    snapshot.fields.add SnapshotField(
      ownerType: typeHandle,
      typ: fieldTypeHandle
    )
    snapshot.types[int(typeHandle)].fields.add fieldHandle

## Registers one interface reference type so fields can resolve it by handle.
proc addInterface(
  snapshot: var CompileTimeSnapshot,
  interfaceDecl: HirInterface
) =
  # Interfaces are reference-shaped semantic types but have no object fields for
  # the managed-class layout phase.
  discard snapshot.ensureType(interfaceDecl.typ)

## Builds the read-only invocation snapshot consumed by compiler-standard Eido phases.
proc buildSnapshot(program: HirProgram): CompileTimeSnapshot =
  # Seed primitive/String handles so dynamically discovered field types always
  # have stable storage-layout facts even when no declaration mentions them first.
  for typ in [etBool, etByte, etShort, etInt, etFloat, etChar, etString]:
    discard result.ensureType(typ)

  for interfaceDecl in program.interfaces:
    result.addInterface(interfaceDecl)

  for classDecl in program.classes:
    result.addClass(classDecl)

## Encodes one compile-time semantic snapshot into the private JSON transport model.
proc toJson(snapshot: CompileTimeSnapshot): JsonNode =
  result = newJObject()

  var types = newJArray()
  for entry in snapshot.types:
    let layout = storageLayoutOf(entry.typ)
    var fields = newJArray()
    for fieldHandle in entry.fields:
      fields.add %fieldHandle

    types.add %*{
      "managed": entry.managed,
      "size": layout.size,
      "alignment": layout.alignment,
      "fields": fields
    }

  var fields = newJArray()
  for entry in snapshot.fields:
    fields.add %*{
      "owner": entry.ownerType,
      "type": entry.typ
    }

  var declarations = newJArray()
  for typeHandle in snapshot.declarations:
    declarations.add %typeHandle

  result["types"] = types
  result["fields"] = fields
  result["declarations"] = declarations

## Serializes one analyzed program into the private compile-time phase protocol.
proc buildCompileTimeSnapshotJson*(program: HirProgram): string =
  $toJson(buildSnapshot(program))
