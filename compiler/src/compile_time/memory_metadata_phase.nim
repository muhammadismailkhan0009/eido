## Adapts the generic compile-time Eido host to compiler memory-metadata discovery.
## The phase describes program structure only; memory-management policy stays in Eido runtime code.

import std/[os, strutils]
import ../hir/program as hirProgram
import ../types/[model, storage]
import host
import model
import snapshot
import layout_runner
import layout_validation
import layout_selection

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

  RawNamedLayoutMetadata = object
    layoutId: int64
    size: int64
    alignment: int64
    fields: seq[RawFieldMetadata]

  RawMemoryMetadata = object
    types: seq[RawTypeMetadata]
    namedLayouts: seq[RawNamedLayoutMetadata]
    callables: seq[RawCallableMetadata]

const
  MemoryMetadataManifestSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/module.yaml"
  )
  CompilerPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/api/memory_policy/Compiler.eido"
  )
  TypeInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/api/memory_policy/TypeInfo.eido"
  )
  CallableInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/api/memory_policy/CallableInfo.eido"
  )
  ValueInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/api/memory_policy/ValueInfo.eido"
  )
  FieldInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/api/memory_policy/FieldInfo.eido"
  )
  StorageInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/api/memory_policy/StorageInfo.eido"
  )
  LayoutRuntimePhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/LayoutRuntime.eido"
  )
  LayoutPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/Layout.eido"
  )
  MemoryMetadataPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/MemoryMetadata.eido"
  )
  MemoryMetadataBuilderSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_metadata/MemoryMetadataBuilder.eido"
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

## Adds an explicit named-layout field to an invocation-local layout definition.
proc ensureNamedLayout(
  metadata: var RawMemoryMetadata, layoutId: int64
): int =
  for i, layout in metadata.namedLayouts:
    if layout.layoutId == layoutId:
      return i
  result = metadata.namedLayouts.len
  metadata.namedLayouts.add RawNamedLayoutMetadata(
    layoutId: layoutId, size: -1, alignment: -1, fields: @[]
  )

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
    of 5:
      let i = result.ensureNamedLayout(first)
      result.namedLayouts[i].fields.add RawFieldMetadata(
        fieldHandle: second, offset: third
      )
    of 6:
      let i = result.ensureNamedLayout(first)
      result.namedLayouts[i].size = second
      result.namedLayouts[i].alignment = third
    else:
      raise newException(
        ValueError,
        "unknown compiler-standard phase record kind " & $kind
      )

## Resolves ephemeral phase handles back to canonical backend-facing metadata.
proc resolveMetadata(
  semanticSnapshot: CompileTimeSnapshot,
  rawMetadata: RawMemoryMetadata,
  program: hirProgram.HirProgram
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

  for rawLayout in rawMetadata.namedLayouts:
    if rawLayout.layoutId < 0 or rawLayout.layoutId >= int64(program.layouts.len):
      raise newException(ValueError, "invalid compile-time named-layout handle")
    let declaration = program.layouts[int(rawLayout.layoutId)]
    var resolved = CompileTimeTypeMetadata(
      className: declaration.targetClass,
      size: rawLayout.size,
      alignment: rawLayout.alignment,
      fields: @[]
    )
    for rawField in rawLayout.fields:
      resolved.fields.add CompileTimeFieldMetadata(
        fieldName: semanticSnapshot.fieldName(rawField.fieldHandle),
        offset: rawField.offset,
        containsIdentity: block:
          var identity = false
          for classDecl in program.classes:
            if classDecl.sourceName != declaration.targetClass:
              continue
            for field in classDecl.fields:
              if field.sourceName == semanticSnapshot.fieldName(rawField.fieldHandle):
                identity = field.typ.kind in {etkClass, etkInterface} and
                  (field.typ.kind != etkClass or
                    not isConcreteStorageTypeName(field.typ.className))
          identity
      )
    result.namedLayouts.add CompileTimeNamedLayoutMetadata(
      name: declaration.sourceName, layout: resolved
    )

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

## Executes the bundled generic Eido memory-metadata phase against one analyzed program.
proc runMemoryMetadataPhase*(
  program: hirProgram.HirProgram
): CompileTimeMemoryMetadata =
  let semanticSnapshot = buildCompileTimeSnapshot(program)
  let userLayouts = layoutRunnerSource(program)
  var lines: seq[string]
  try:
    lines = runCompileTimeEidoPhase(
      "memory_metadata",
      MemoryMetadataManifestSource,
      CompileTimeNativeSupportSource,
      semanticSnapshot.compileTimeSnapshotJson(),
      @[
        CompileTimePhaseSource(entry: "../../api/memory_policy/Compiler.eido", text: CompilerPhaseSource),
        CompileTimePhaseSource(entry: "../../api/memory_policy/TypeInfo.eido", text: TypeInfoPhaseSource),
        CompileTimePhaseSource(entry: "../../api/memory_policy/CallableInfo.eido", text: CallableInfoPhaseSource),
        CompileTimePhaseSource(entry: "../../api/memory_policy/ValueInfo.eido", text: ValueInfoPhaseSource),
        CompileTimePhaseSource(entry: "../../api/memory_policy/FieldInfo.eido", text: FieldInfoPhaseSource),
        CompileTimePhaseSource(entry: "../../api/memory_policy/StorageInfo.eido", text: StorageInfoPhaseSource),
        CompileTimePhaseSource(entry: "MemoryMetadata.eido", text: MemoryMetadataPhaseSource),
        CompileTimePhaseSource(
          entry: "LayoutRuntime.eido", text: LayoutRuntimePhaseSource
        ),
        CompileTimePhaseSource(entry: "Layout.eido", text: LayoutPhaseSource),
        CompileTimePhaseSource(
          entry: "UserLayoutRunners.eido", text: userLayouts.layoutSource
        ),
        CompileTimePhaseSource(
          entry: "MemoryMetadataBuilder.eido",
          text: MemoryMetadataBuilderSource
        ),
        CompileTimePhaseSource(
          entry: "runner.eido", text: userLayouts.runnerSource
        )
      ]
    )
  except OSError as error:
    raise newException(ValueError,
      "Eido compile-time memory layout evaluation failed: " & error.msg)

  let rawMetadata = parsePhaseOutput(lines)
  result = resolveMetadata(semanticSnapshot, rawMetadata, program)
  validateMetadata(program, result)
  applyLayoutSelections(program, result)
