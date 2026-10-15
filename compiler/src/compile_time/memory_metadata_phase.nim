## Adapts the generic compile-time Eido host to compiler memory-metadata discovery.
## The phase describes program structure only; memory-management policy stays in Eido runtime code.

import std/[os, strutils]
import ../hir/program as hirProgram
import ../types/storage
import ../source/span
import host
import model
import snapshot

type
  RawFieldMetadata = object
    fieldHandle: int64
    offset: int64
    containsIdentity: bool

  RawTypeMetadata = object
    typeHandle: int64
    size: int64
    alignment: int64
    fields: seq[RawFieldMetadata]

  RawCallableMetadata = object
    callableHandle: int64
    valueHandles: seq[int64]

  RawMemoryMetadata = object
    types: seq[RawTypeMetadata]
    callables: seq[RawCallableMetadata]

const
  MemoryMetadataManifestSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/module.yaml"
  )
  CompilerPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/Compiler.eido"
  )
  TypeInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/TypeInfo.eido"
  )
  CallableInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/CallableInfo.eido"
  )
  ValueInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/ValueInfo.eido"
  )
  FieldInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/FieldInfo.eido"
  )
  StorageInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/StorageInfo.eido"
  )
  MemoryMetadataPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/MemoryMetadata.eido"
  )
  MemoryMetadataBuilderSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/MemoryMetadataBuilder.eido"
  )
  RunnerSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/runner.eido"
  )
  CompileTimeNativeSupportSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/native/eido_native.nim"
  )

## Returns the mutable raw metadata slot for one private type handle.
proc ensureTypeMetadata(
  metadata: var RawMemoryMetadata,
  typeHandle: int64
): int =
  for index, typeMetadata in metadata.types:
    if typeMetadata.typeHandle == typeHandle:
      return index

  result = metadata.types.len
  metadata.types.add RawTypeMetadata(
    typeHandle: typeHandle,
    size: -1,
    alignment: -1,
    fields: @[]
  )

## Adds one private field-offset fact emitted by the Eido metadata phase.
proc addFieldRecord(
  metadata: var RawMemoryMetadata,
  ownerType,
  fieldHandle,
  offset: int64
) =
  let typeIndex = metadata.ensureTypeMetadata(ownerType)
  metadata.types[typeIndex].fields.add RawFieldMetadata(
    fieldHandle: fieldHandle,
    offset: offset,
    containsIdentity: false
  )

## Marks one described field as containing Eido object/interface identity.
proc addIdentityFieldRecord(
  metadata: var RawMemoryMetadata,
  ownerType,
  fieldHandle: int64
) =
  let typeIndex = metadata.ensureTypeMetadata(ownerType)
  for fieldIndex in 0 ..< metadata.types[typeIndex].fields.len:
    if metadata.types[typeIndex].fields[fieldIndex].fieldHandle == fieldHandle:
      metadata.types[typeIndex].fields[fieldIndex].containsIdentity = true
      return

  raise newException(
    ValueError,
    "memory metadata described identity before the field layout"
  )

## Stores completed payload size and alignment for one class handle.
proc addLayoutRecord(
  metadata: var RawMemoryMetadata,
  typeHandle,
  size,
  alignment: int64
) =
  let typeIndex = metadata.ensureTypeMetadata(typeHandle)
  metadata.types[typeIndex].size = size
  metadata.types[typeIndex].alignment = alignment

## Returns the mutable raw callable metadata slot for one private callable handle.
proc ensureCallableMetadata(
  metadata: var RawMemoryMetadata,
  callableHandle: int64
): int =
  for index, callableMetadata in metadata.callables:
    if callableMetadata.callableHandle == callableHandle:
      return index

  result = metadata.callables.len
  metadata.callables.add RawCallableMetadata(
    callableHandle: callableHandle,
    valueHandles: @[]
  )

## Adds one identity-valued parameter/local fact emitted by the Eido phase.
proc addIdentityValueRecord(
  metadata: var RawMemoryMetadata,
  callableHandle,
  valueHandle: int64
) =
  let callableIndex = metadata.ensureCallableMetadata(callableHandle)
  if valueHandle notin metadata.callables[callableIndex].valueHandles:
    metadata.callables[callableIndex].valueHandles.add valueHandle

## Parses the private line protocol while keeping invocation-local handles private.
proc parsePhaseOutput(lines: seq[string]): RawMemoryMetadata =
  for line in lines:
    if line.len == 0:
      continue
    if not line.startsWith("EIDO_CT|"):
      raise newException(
        ValueError,
        "unexpected compiler-standard phase output: " & line
      )

    let parts = line.split('|')
    if parts.len != 5:
      raise newException(ValueError, "invalid compiler-standard phase record")

    let kind = parseInt(parts[1])
    let first = int64(parseInt(parts[2]))
    let second = int64(parseInt(parts[3]))
    let third = int64(parseInt(parts[4]))

    case kind
    of 1:
      result.addFieldRecord(first, second, third)
    of 2:
      result.addIdentityFieldRecord(first, second)
    of 3:
      result.addLayoutRecord(first, second, third)
    of 4:
      result.addIdentityValueRecord(first, second)
    else:
      raise newException(
        ValueError,
        "unknown compiler-standard phase record kind " & $kind
      )

## Resolves ephemeral phase handles back to canonical backend-facing metadata.
proc resolveMetadata(
  semanticSnapshot: CompileTimeSnapshot,
  rawMetadata: RawMemoryMetadata
): CompileTimeMemoryMetadata =
  for rawType in rawMetadata.types:
    var typeMetadata = CompileTimeTypeMetadata(
      className: semanticSnapshot.declarationName(rawType.typeHandle),
      size: rawType.size,
      alignment: rawType.alignment,
      fields: @[]
    )

    for rawField in rawType.fields:
      typeMetadata.fields.add CompileTimeFieldMetadata(
        fieldName: semanticSnapshot.fieldName(rawField.fieldHandle),
        offset: rawField.offset,
        containsIdentity: rawField.containsIdentity
      )

    result.types.add typeMetadata

  for rawCallable in rawMetadata.callables:
    let rawKind = semanticSnapshot.callableKind(rawCallable.callableHandle)
    var callableMetadata = CompileTimeCallableMetadata(
      kind:
        if rawKind == SnapshotFunctionKind:
          ctkFunction
        elif rawKind == SnapshotMethodKind:
          ctkMethod
        else:
          raise newException(
            ValueError,
            "unknown compile-time callable kind"
          ),
      semanticId: int(
        semanticSnapshot.callableSemanticId(rawCallable.callableHandle)
      ),
      ownerName: semanticSnapshot.callableOwnerName(rawCallable.callableHandle),
      sourceName: semanticSnapshot.callableSourceName(rawCallable.callableHandle),
      identityValues: @[]
    )

    for valueHandle in rawCallable.valueHandles:
      callableMetadata.identityValues.add CompileTimeIdentityValue(
        localId: int(semanticSnapshot.valueLocalId(valueHandle)),
        sourceName: semanticSnapshot.valueSourceName(valueHandle)
      )

    result.callables.add callableMetadata

## Counts ordinary class declarations that receive generic object-layout metadata.
proc expectedClassLayouts(program: hirProgram.HirProgram): int =
  for classDecl in program.classes:
    if not isConcreteStorageTypeName(classDecl.sourceName) and
        not classDecl.span.isHiddenRuntime:
      inc result

## Verifies one complete stable layout for every ordinary class declaration.
proc validateMetadata(
  program: hirProgram.HirProgram,
  metadata: CompileTimeMemoryMetadata
) =
  if metadata.types.len != expectedClassLayouts(program):
    raise newException(
      ValueError,
      "memory metadata did not return one layout per ordinary class"
    )

  for typeMetadata in metadata.types:
    if typeMetadata.className.len == 0 or
        typeMetadata.size < 0 or
        typeMetadata.alignment <= 0:
      raise newException(
        ValueError,
        "memory metadata returned an incomplete type layout"
      )

## Executes the bundled generic Eido memory-metadata phase against one analyzed program.
proc runMemoryMetadataPhase*(
  program: hirProgram.HirProgram
): CompileTimeMemoryMetadata =
  let semanticSnapshot = buildCompileTimeSnapshot(program)
  let lines = runCompileTimeEidoPhase(
    "memory_metadata",
    MemoryMetadataManifestSource,
    CompileTimeNativeSupportSource,
    semanticSnapshot.compileTimeSnapshotJson(),
    @[
      CompileTimePhaseSource(entry: "Compiler.eido", text: CompilerPhaseSource),
      CompileTimePhaseSource(entry: "TypeInfo.eido", text: TypeInfoPhaseSource),
      CompileTimePhaseSource(entry: "CallableInfo.eido", text: CallableInfoPhaseSource),
      CompileTimePhaseSource(entry: "ValueInfo.eido", text: ValueInfoPhaseSource),
      CompileTimePhaseSource(entry: "FieldInfo.eido", text: FieldInfoPhaseSource),
      CompileTimePhaseSource(entry: "StorageInfo.eido", text: StorageInfoPhaseSource),
      CompileTimePhaseSource(entry: "MemoryMetadata.eido", text: MemoryMetadataPhaseSource),
      CompileTimePhaseSource(
        entry: "MemoryMetadataBuilder.eido",
        text: MemoryMetadataBuilderSource
      ),
      CompileTimePhaseSource(entry: "runner.eido", text: RunnerSource)
    ]
  )

  let rawMetadata = parsePhaseOutput(lines)
  result = resolveMetadata(semanticSnapshot, rawMetadata)
  validateMetadata(program, result)
