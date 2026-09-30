## Builds the private semantic snapshot consumed by compiler-standard Eido phases.
## Handles are dense integer ids valid only for one phase invocation.

import std/json
import ../hir/[declarations, program, statements]
import ../semantic/symbols/ids
import ../types/[function_result, method_kind, model, storage]
import target_storage_layout

type
  SnapshotType = object
    typ: EidoType
    declarationName: string
    fields: seq[int64]
    managed: bool

  SnapshotField = object
    ownerType: int64
    sourceName: string
    typ: int64

  SnapshotValue = object
    ownerCallable: int64
    localId: int64
    sourceName: string
    typ: int64

  SnapshotCallable = object
    kind: int64
    semanticId: int64
    ownerName: string
    sourceName: string
    parameters: seq[int64]
    locals: seq[int64]

  CompileTimeSnapshot* = object
    types: seq[SnapshotType]
    fields: seq[SnapshotField]
    declarations: seq[int64]
    values: seq[SnapshotValue]
    callables: seq[SnapshotCallable]

const
  SnapshotFunctionKind* = 1'i64
  SnapshotMethodKind* = 2'i64

## Finds an existing invocation-local handle for one semantic type or returns -1.
proc findType(types: seq[SnapshotType], typ: EidoType): int =
  for index, candidate in types:
    if candidate.typ == typ:
      return index
  -1

## Reports whether one semantic value is traced by the selected managed collector.
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
    declarationName: "",
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
  snapshot.types[int(typeHandle)].declarationName = classDecl.sourceName
  snapshot.declarations.add typeHandle

  for field in classDecl.fields:
    let fieldTypeHandle = snapshot.ensureType(field.typ)
    let fieldHandle = int64(snapshot.fields.len)
    snapshot.fields.add SnapshotField(
      ownerType: typeHandle,
      sourceName: field.sourceName,
      typ: fieldTypeHandle
    )
    snapshot.types[int(typeHandle)].fields.add fieldHandle

## Registers one interface reference type so fields/locals can resolve it by handle.
proc addInterface(
  snapshot: var CompileTimeSnapshot,
  interfaceDecl: HirInterface
) =
  discard snapshot.ensureType(interfaceDecl.typ)

## Adds one parameter/local value to a callable snapshot and returns its private handle.
proc addValue(
  snapshot: var CompileTimeSnapshot,
  callableHandle: int64,
  localId: LocalId,
  sourceName: string,
  typ: EidoType
): int64 =
  let handle = int64(snapshot.values.len)
  snapshot.values.add SnapshotValue(
    ownerCallable: callableHandle,
    localId: int64(localId.value),
    sourceName: sourceName,
    typ: snapshot.ensureType(typ)
  )
  handle

## Adds one local declaration only once for a callable.
proc addLocalValue(
  snapshot: var CompileTimeSnapshot,
  callableHandle: int64,
  localId: LocalId,
  sourceName: string,
  typ: EidoType
) =
  for existingHandle in snapshot.callables[int(callableHandle)].locals:
    let existing = snapshot.values[int(existingHandle)]
    if existing.localId == int64(localId.value):
      return

  let handle = snapshot.addValue(
    callableHandle,
    localId,
    sourceName,
    typ
  )
  snapshot.callables[int(callableHandle)].locals.add handle

## Recursively discovers local declarations in one structured HIR statement tree.
proc addStatementLocals(
  snapshot: var CompileTimeSnapshot,
  callableHandle: int64,
  statementsToScan: seq[HirStmt]
) =
  for stmt in statementsToScan:
    case stmt.kind
    of hskVar:
      snapshot.addLocalValue(
        callableHandle,
        stmt.localId,
        stmt.sourceName,
        stmt.typ
      )
    of hskIf:
      snapshot.addStatementLocals(callableHandle, stmt.thenBranch)
      snapshot.addStatementLocals(callableHandle, stmt.elseBranch)
    of hskExists:
      snapshot.addStatementLocals(callableHandle, stmt.existsBody)
    of hskWhile:
      snapshot.addStatementLocals(callableHandle, stmt.body)
    of hskFor:
      snapshot.addStatementLocals(callableHandle, @[stmt.forInitializer])
      snapshot.addStatementLocals(callableHandle, stmt.forBody)
      snapshot.addStatementLocals(callableHandle, @[stmt.forUpdate])
    else:
      discard

## Adds one top-level function and its parameter/local value universe.
proc addFunction(
  snapshot: var CompileTimeSnapshot,
  fn: HirFunction
) =
  let callableHandle = int64(snapshot.callables.len)
  snapshot.callables.add SnapshotCallable(
    kind: SnapshotFunctionKind,
    semanticId: int64(fn.functionId.value),
    ownerName: "",
    sourceName: fn.sourceName,
    parameters: @[],
    locals: @[]
  )

  for parameter in fn.parameters:
    let handle = snapshot.addValue(
      callableHandle,
      parameter.localId,
      parameter.sourceName,
      parameter.typ
    )
    snapshot.callables[int(callableHandle)].parameters.add handle

  snapshot.addStatementLocals(callableHandle, fn.body)

  if fn.ensures.len > 0 and fn.result.kind == frSingle and
      isManagedReference(fn.result.typ):
    snapshot.addLocalValue(
      callableHandle,
      fn.ensureResultLocalId,
      "result",
      fn.result.typ
    )

## Adds one class method and its receiver/parameter/local value universe.
proc addMethod(
  snapshot: var CompileTimeSnapshot,
  methodDecl: HirMethod
) =
  if methodDecl.isNative:
    return

  let callableHandle = int64(snapshot.callables.len)
  snapshot.callables.add SnapshotCallable(
    kind: SnapshotMethodKind,
    semanticId: int64(methodDecl.methodId.value),
    ownerName: methodDecl.ownerType.className,
    sourceName: methodDecl.sourceName,
    parameters: @[],
    locals: @[]
  )

  if methodDecl.kind == mkInstance:
    let receiverHandle = snapshot.addValue(
      callableHandle,
      methodDecl.receiverLocalId,
      "receiver",
      methodDecl.ownerType
    )
    snapshot.callables[int(callableHandle)].parameters.add receiverHandle

  for parameter in methodDecl.parameters:
    let handle = snapshot.addValue(
      callableHandle,
      parameter.localId,
      parameter.sourceName,
      parameter.typ
    )
    snapshot.callables[int(callableHandle)].parameters.add handle

  snapshot.addStatementLocals(callableHandle, methodDecl.body)

  if methodDecl.ensures.len > 0 and methodDecl.result.kind == frSingle and
      isManagedReference(methodDecl.result.typ):
    snapshot.addLocalValue(
      callableHandle,
      methodDecl.ensureResultLocalId,
      "result",
      methodDecl.result.typ
    )

## Builds the read-only invocation snapshot consumed by compiler-standard Eido phases.
proc buildCompileTimeSnapshot*(program: HirProgram): CompileTimeSnapshot =
  for typ in [etBool, etByte, etShort, etInt, etFloat, etChar, etString]:
    discard result.ensureType(typ)

  for interfaceDecl in program.interfaces:
    result.addInterface(interfaceDecl)

  for classDecl in program.classes:
    result.addClass(classDecl)

  for fn in program.functions:
    if not fn.isNative:
      result.addFunction(fn)

  for classDecl in program.classes:
    if isConcreteStorageTypeName(classDecl.sourceName):
      continue
    for methodDecl in classDecl.methods:
      result.addMethod(methodDecl)

## Resolves one private type handle back to the canonical class identity it represents.
proc declarationName*(snapshot: CompileTimeSnapshot, typeHandle: int64): string =
  if typeHandle < 0 or typeHandle >= int64(snapshot.types.len):
    raise newException(ValueError, "invalid compile-time type handle")

  result = snapshot.types[int(typeHandle)].declarationName
  if result.len == 0:
    raise newException(
      ValueError,
      "compile-time type handle does not identify a class declaration"
    )

## Resolves one private field handle back to its stable source-level field identity.
proc fieldName*(snapshot: CompileTimeSnapshot, fieldHandle: int64): string =
  if fieldHandle < 0 or fieldHandle >= int64(snapshot.fields.len):
    raise newException(ValueError, "invalid compile-time field handle")
  snapshot.fields[int(fieldHandle)].sourceName

## Returns the stable callable kind encoded by one private callable handle.
proc callableKind*(snapshot: CompileTimeSnapshot, callableHandle: int64): int64 =
  if callableHandle < 0 or callableHandle >= int64(snapshot.callables.len):
    raise newException(ValueError, "invalid compile-time callable handle")
  snapshot.callables[int(callableHandle)].kind

## Returns the stable semantic function/method id behind one private callable handle.
proc callableSemanticId*(
  snapshot: CompileTimeSnapshot,
  callableHandle: int64
): int64 =
  if callableHandle < 0 or callableHandle >= int64(snapshot.callables.len):
    raise newException(ValueError, "invalid compile-time callable handle")
  snapshot.callables[int(callableHandle)].semanticId

## Returns the owner class name for one method handle or empty for a function.
proc callableOwnerName*(
  snapshot: CompileTimeSnapshot,
  callableHandle: int64
): string =
  if callableHandle < 0 or callableHandle >= int64(snapshot.callables.len):
    raise newException(ValueError, "invalid compile-time callable handle")
  snapshot.callables[int(callableHandle)].ownerName

## Returns the source name behind one private callable handle.
proc callableSourceName*(
  snapshot: CompileTimeSnapshot,
  callableHandle: int64
): string =
  if callableHandle < 0 or callableHandle >= int64(snapshot.callables.len):
    raise newException(ValueError, "invalid compile-time callable handle")
  snapshot.callables[int(callableHandle)].sourceName

## Returns the stable LocalId encoded by one private parameter/local handle.
proc valueLocalId*(snapshot: CompileTimeSnapshot, valueHandle: int64): int64 =
  if valueHandle < 0 or valueHandle >= int64(snapshot.values.len):
    raise newException(ValueError, "invalid compile-time value handle")
  snapshot.values[int(valueHandle)].localId

## Returns the stable source name encoded by one private parameter/local handle.
proc valueSourceName*(snapshot: CompileTimeSnapshot, valueHandle: int64): string =
  if valueHandle < 0 or valueHandle >= int64(snapshot.values.len):
    raise newException(ValueError, "invalid compile-time value handle")
  snapshot.values[int(valueHandle)].sourceName

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

  var values = newJArray()
  for entry in snapshot.values:
    values.add %*{
      "owner": entry.ownerCallable,
      "type": entry.typ
    }

  var callables = newJArray()
  for entry in snapshot.callables:
    var parameters = newJArray()
    for handle in entry.parameters:
      parameters.add %handle
    var locals = newJArray()
    for handle in entry.locals:
      locals.add %handle

    callables.add %*{
      "kind": entry.kind,
      "semanticId": entry.semanticId,
      "ownerName": entry.ownerName,
      "sourceName": entry.sourceName,
      "parameters": parameters,
      "locals": locals
    }

  result["types"] = types
  result["fields"] = fields
  result["declarations"] = declarations
  result["values"] = values
  result["callables"] = callables

## Serializes one already-built snapshot into the private phase transport protocol.
proc compileTimeSnapshotJson*(snapshot: CompileTimeSnapshot): string =
  $toJson(snapshot)

## Serializes one analyzed program into the private compile-time phase protocol.
proc buildCompileTimeSnapshotJson*(program: HirProgram): string =
  buildCompileTimeSnapshot(program).compileTimeSnapshotJson()
