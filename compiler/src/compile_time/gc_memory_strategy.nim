## Adapts the generic compile-time Eido host to the selected precise mark-and-sweep strategy.

import std/[os, strutils]
import ../hir/program as hirProgram
import ../types/storage
import host
import model
import snapshot

type
  RawFieldLayout = object
    fieldHandle: int64
    offset: int64
    traced: bool

  RawTypeLayout = object
    typeHandle: int64
    size: int64
    alignment: int64
    fields: seq[RawFieldLayout]

  RawCallableRoots = object
    callableHandle: int64
    valueHandles: seq[int64]

  RawMemoryPlan = object
    types: seq[RawTypeLayout]
    callables: seq[RawCallableRoots]

const
  GcMemoryStrategyManifestSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_gc/module.yaml"
  )
  CompilerPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_gc/Compiler.eido"
  )
  TypeInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_gc/TypeInfo.eido"
  )
  CallableInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_gc/CallableInfo.eido"
  )
  ValueInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_gc/ValueInfo.eido"
  )
  FieldInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_gc/FieldInfo.eido"
  )
  StorageInfoPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_gc/StorageInfo.eido"
  )
  MemoryPlanPhaseSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_gc/MemoryPlan.eido"
  )
  SelectedMemoryStrategySource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_gc/SelectedMemoryStrategy.eido"
  )
  RunnerSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_gc/runner.eido"
  )
  CompileTimeNativeSupportSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/native/eido_native.nim"
  )

## Returns the mutable raw plan slot for one private type handle.
proc ensureTypePlan(
  plan: var RawMemoryPlan,
  typeHandle: int64
): int =
  for index, typePlan in plan.types:
    if typePlan.typeHandle == typeHandle:
      return index

  result = plan.types.len
  plan.types.add RawTypeLayout(
    typeHandle: typeHandle,
    size: -1,
    alignment: -1,
    fields: @[]
  )

## Adds one private field-offset record emitted by the Eido strategy.
proc addFieldRecord(
  plan: var RawMemoryPlan,
  ownerType,
  fieldHandle,
  offset: int64
) =
  let typeIndex = plan.ensureTypePlan(ownerType)
  plan.types[typeIndex].fields.add RawFieldLayout(
    fieldHandle: fieldHandle,
    offset: offset,
    traced: false
  )

## Marks one previously described raw field as containing a managed reference.
proc addTraceRecord(
  plan: var RawMemoryPlan,
  ownerType,
  fieldHandle: int64
) =
  let typeIndex = plan.ensureTypePlan(ownerType)
  for fieldIndex in 0 ..< plan.types[typeIndex].fields.len:
    if plan.types[typeIndex].fields[fieldIndex].fieldHandle == fieldHandle:
      plan.types[typeIndex].fields[fieldIndex].traced = true
      return

  raise newException(
    ValueError,
    "GC memory strategy traced a field before describing its layout"
  )

## Stores the completed payload size and alignment emitted for one class handle.
proc addLayoutRecord(
  plan: var RawMemoryPlan,
  typeHandle,
  size,
  alignment: int64
) =
  let typeIndex = plan.ensureTypePlan(typeHandle)
  plan.types[typeIndex].size = size
  plan.types[typeIndex].alignment = alignment

## Returns the mutable raw root-plan slot for one private callable handle.
proc ensureCallablePlan(
  plan: var RawMemoryPlan,
  callableHandle: int64
): int =
  for index, callablePlan in plan.callables:
    if callablePlan.callableHandle == callableHandle:
      return index

  result = plan.callables.len
  plan.callables.add RawCallableRoots(
    callableHandle: callableHandle,
    valueHandles: @[]
  )

## Adds one selected parameter/local root emitted by the Eido strategy.
proc addRootRecord(
  plan: var RawMemoryPlan,
  callableHandle,
  valueHandle: int64
) =
  let callableIndex = plan.ensureCallablePlan(callableHandle)
  if valueHandle notin plan.callables[callableIndex].valueHandles:
    plan.callables[callableIndex].valueHandles.add valueHandle

## Parses the private line protocol while keeping invocation-local handles private.
proc parsePhaseOutput(lines: seq[string]): RawMemoryPlan =
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
      result.addTraceRecord(first, second)
    of 3:
      result.addLayoutRecord(first, second, third)
    of 4:
      result.addRootRecord(first, second)
    else:
      raise newException(
        ValueError,
        "unknown compiler-standard phase record kind " & $kind
      )

## Resolves ephemeral phase handles back to canonical backend-facing identities.
proc resolvePlan(
  semanticSnapshot: CompileTimeSnapshot,
  rawPlan: RawMemoryPlan
): CompileTimeMemoryPlan =
  for rawType in rawPlan.types:
    var typePlan = CompileTimeTypeLayout(
      className: semanticSnapshot.declarationName(rawType.typeHandle),
      size: rawType.size,
      alignment: rawType.alignment,
      fields: @[]
    )

    for rawField in rawType.fields:
      typePlan.fields.add CompileTimeFieldLayout(
        fieldName: semanticSnapshot.fieldName(rawField.fieldHandle),
        offset: rawField.offset,
        traced: rawField.traced
      )

    result.types.add typePlan

  for rawCallable in rawPlan.callables:
    let rawKind = semanticSnapshot.callableKind(rawCallable.callableHandle)
    var callablePlan = CompileTimeCallableRoots(
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
        semanticSnapshot.callableSemanticId(
          rawCallable.callableHandle
        )
      ),
      ownerName: semanticSnapshot.callableOwnerName(
        rawCallable.callableHandle
      ),
      sourceName: semanticSnapshot.callableSourceName(
        rawCallable.callableHandle
      ),
      roots: @[]
    )

    for valueHandle in rawCallable.valueHandles:
      callablePlan.roots.add CompileTimeRoot(
        localId: int(semanticSnapshot.valueLocalId(valueHandle)),
        sourceName: semanticSnapshot.valueSourceName(valueHandle)
      )

    result.callables.add callablePlan

## Counts ordinary class declarations that receive compile-time layout records.
proc expectedClassLayouts(program: hirProgram.HirProgram): int =
  for classDecl in program.classes:
    if not isConcreteStorageTypeName(classDecl.sourceName):
      inc result

## Verifies one complete stable layout for every ordinary class declaration.
proc validatePlan(
  program: hirProgram.HirProgram,
  plan: CompileTimeMemoryPlan
) =
  if plan.types.len != expectedClassLayouts(program):
    raise newException(
      ValueError,
      "GC memory strategy did not return one layout per ordinary class"
    )

  for typePlan in plan.types:
    if typePlan.className.len == 0 or
        typePlan.size < 0 or
        typePlan.alignment <= 0:
      raise newException(
        ValueError,
        "GC memory strategy returned an incomplete type layout"
      )

## Executes the bundled Eido GC memory strategy against one analyzed program.
proc runGcMemoryStrategy*(
  program: hirProgram.HirProgram
): CompileTimeMemoryPlan =
  let semanticSnapshot = buildCompileTimeSnapshot(program)
  let lines = runCompileTimeEidoPhase(
    "memory_gc",
    GcMemoryStrategyManifestSource,
    CompileTimeNativeSupportSource,
    semanticSnapshot.compileTimeSnapshotJson(),
    @[
      CompileTimePhaseSource(
        entry: "Compiler.eido",
        text: CompilerPhaseSource
      ),
      CompileTimePhaseSource(
        entry: "TypeInfo.eido",
        text: TypeInfoPhaseSource
      ),
      CompileTimePhaseSource(
        entry: "CallableInfo.eido",
        text: CallableInfoPhaseSource
      ),
      CompileTimePhaseSource(
        entry: "ValueInfo.eido",
        text: ValueInfoPhaseSource
      ),
      CompileTimePhaseSource(
        entry: "FieldInfo.eido",
        text: FieldInfoPhaseSource
      ),
      CompileTimePhaseSource(
        entry: "StorageInfo.eido",
        text: StorageInfoPhaseSource
      ),
      CompileTimePhaseSource(
        entry: "MemoryPlan.eido",
        text: MemoryPlanPhaseSource
      ),
      CompileTimePhaseSource(
        entry: "SelectedMemoryStrategy.eido",
        text: SelectedMemoryStrategySource
      ),
      CompileTimePhaseSource(
        entry: "runner.eido",
        text: RunnerSource
      )
    ]
  )

  let rawPlan = parsePhaseOutput(lines)
  result = resolvePlan(semanticSnapshot, rawPlan)
  validatePlan(program, result)
