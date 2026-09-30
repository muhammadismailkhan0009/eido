## Adapts the generic compile-time Eido host to the selected precise mark-and-sweep strategy.

import std/[os, strutils]
import ../hir/program as hirProgram
import ../types/storage
import host
import model
import snapshot

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

## Returns the mutable plan slot for one invocation-local type handle, creating it on first use.
proc ensureTypePlan(
  plan: var CompileTimeMemoryPlan,
  typeHandle: int64
): int =
  for index, typePlan in plan.types:
    if typePlan.typeHandle == typeHandle:
      return index

  result = plan.types.len
  plan.types.add CompileTimeTypeLayout(
    typeHandle: typeHandle,
    size: -1,
    alignment: -1,
    fields: @[]
  )

## Adds one field offset emitted by the Eido GC memory strategy.
proc addFieldRecord(
  plan: var CompileTimeMemoryPlan,
  ownerType,
  fieldHandle,
  offset: int64
) =
  let typeIndex = plan.ensureTypePlan(ownerType)
  plan.types[typeIndex].fields.add CompileTimeFieldLayout(
    fieldHandle: fieldHandle,
    offset: offset,
    traced: false
  )

## Marks one previously described field as containing a managed reference.
proc addTraceRecord(
  plan: var CompileTimeMemoryPlan,
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

## Stores the completed payload size and alignment emitted for one class type.
proc addLayoutRecord(
  plan: var CompileTimeMemoryPlan,
  typeHandle,
  size,
  alignment: int64
) =
  let typeIndex = plan.ensureTypePlan(typeHandle)
  plan.types[typeIndex].size = size
  plan.types[typeIndex].alignment = alignment

## Parses the private line protocol emitted by the Eido GC memory strategy.
proc parsePhaseOutput(lines: seq[string]): CompileTimeMemoryPlan =
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
    else:
      raise newException(
        ValueError,
        "unknown compiler-standard phase record kind " & $kind
      )

## Counts ordinary class declarations that require managed payload layout planning.
proc expectedClassLayouts(program: hirProgram.HirProgram): int =
  for classDecl in program.classes:
    if not isConcreteStorageTypeName(classDecl.sourceName):
      inc result

## Verifies that the Eido phase returned one complete layout for every ordinary class.
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
    if typePlan.size < 0 or typePlan.alignment <= 0:
      raise newException(
        ValueError,
        "GC memory strategy returned an incomplete type layout"
      )

## Executes the bundled Eido GC memory strategy against one analyzed program.
proc runGcMemoryStrategy*(
  program: hirProgram.HirProgram
): CompileTimeMemoryPlan =
  let lines = runCompileTimeEidoPhase(
    "memory_gc",
    GcMemoryStrategyManifestSource,
    CompileTimeNativeSupportSource,
    buildCompileTimeSnapshotJson(program),
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

  result = parsePhaseOutput(lines)
  validatePlan(program, result)
