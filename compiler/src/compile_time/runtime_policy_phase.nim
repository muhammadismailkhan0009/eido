## Runs a selected Eido memory-policy module against generic compiler facts/events.
## The compiler supplies semantic inspection and event-binding APIs but no memory algorithm.

import std/[os, strutils]
import ../hir/program as hirProgram
import ../project/modules/model as moduleModel
import host
import instrumentation_model
import snapshot

const
  CompilerApiSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/api/memory_policy/Compiler.eido"
  )
  TypeInfoApiSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/api/memory_policy/TypeInfo.eido"
  )
  FieldInfoApiSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/api/memory_policy/FieldInfo.eido"
  )
  CallableInfoApiSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/api/memory_policy/CallableInfo.eido"
  )
  ValueInfoApiSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/api/memory_policy/ValueInfo.eido"
  )
  StorageInfoApiSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/api/memory_policy/StorageInfo.eido"
  )
  MemoryPolicyApiSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/api/memory_policy/MemoryPolicy.eido"
  )
  CompileTimeNativeSupportSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/native/eido_native.nim"
  )

  ReservedPolicyApiEntries = [
    "Compiler.eido",
    "TypeInfo.eido",
    "FieldInfo.eido",
    "CallableInfo.eido",
    "ValueInfo.eido",
    "StorageInfo.eido",
    "MemoryPolicy.eido"
  ]

## Assigns one policy-selected handler and rejects duplicate bindings.
proc assignBinding(slot: var string, eventName, handler: string) =
  if slot.len > 0:
    raise newException(
      ValueError,
      "memory policy binds compiler event '" & eventName & "' more than once"
    )
  if handler.len == 0:
    raise newException(ValueError, "memory policy handler reference cannot be empty")
  slot = handler

## Applies one named generic event binding to the compiler instrumentation plan.
proc setBinding(
  plan: var CompileTimeInstrumentationPlan,
  eventName,
  handler: string
) =
  case eventName
  of "bindingEnter": plan.bindingEnter.assignBinding(eventName, handler)
  of "bindingWrite": plan.bindingWrite.assignBinding(eventName, handler)
  of "bindingLeave": plan.bindingLeave.assignBinding(eventName, handler)
  of "typeMetadata": plan.metadataType.assignBinding(eventName, handler)
  of "fieldMetadata": plan.metadataField.assignBinding(eventName, handler)
  of "objectAcquire": plan.objectAcquire.assignBinding(eventName, handler)
  of "temporaryEnter": plan.temporaryEnter.assignBinding(eventName, handler)
  of "temporaryLeave": plan.temporaryLeave.assignBinding(eventName, handler)
  of "executionBoundary": plan.statementBoundary.assignBinding(eventName, handler)
  of "invariantEnter": plan.invariantEnter.assignBinding(eventName, handler)
  of "invariantLeave": plan.invariantLeave.assignBinding(eventName, handler)
  of "invariantClear": plan.invariantClear.assignBinding(eventName, handler)
  of "programExit": plan.programExit.assignBinding(eventName, handler)
  else:
    raise newException(
      ValueError,
      "unknown compiler memory-policy event '" & eventName & "'"
    )

## Parses one memory-policy phase output into generic event-to-handler bindings.
proc parseBindings(lines: seq[string]): CompileTimeInstrumentationPlan =
  for line in lines:
    if line.len == 0:
      continue
    if not line.startsWith("EIDO_BIND|"):
      raise newException(ValueError, "unexpected memory-policy phase output: " & line)
    let parts = line.split('|')
    if parts.len != 3:
      raise newException(ValueError, "invalid memory-policy binding record")
    result.setBinding(parts[1], parts[2])

## Builds the self-contained compile-time module used to execute one selected policy.
proc policyPhaseSources(
  policyModule: moduleModel.ModuleSpec
): tuple[manifest: string, sources: seq[CompileTimePhaseSource]] =
  result.sources = @[
    CompileTimePhaseSource(entry: "Compiler.eido", text: CompilerApiSource),
    CompileTimePhaseSource(entry: "TypeInfo.eido", text: TypeInfoApiSource),
    CompileTimePhaseSource(entry: "FieldInfo.eido", text: FieldInfoApiSource),
    CompileTimePhaseSource(entry: "CallableInfo.eido", text: CallableInfoApiSource),
    CompileTimePhaseSource(entry: "ValueInfo.eido", text: ValueInfoApiSource),
    CompileTimePhaseSource(entry: "StorageInfo.eido", text: StorageInfoApiSource),
    CompileTimePhaseSource(entry: "MemoryPolicy.eido", text: MemoryPolicyApiSource)
  ]

  result.manifest = "module: selected_memory_policy\nsources:\n"
  for apiEntry in ReservedPolicyApiEntries:
    result.manifest.add "  - " & apiEntry & "\n"

  for policySource in policyModule.policySources:
    if policySource.entry in ReservedPolicyApiEntries:
      raise newException(
        ValueError,
        "memory policy source collides with compiler policy API source: " &
          policySource.entry
      )
    result.manifest.add "  - " & policySource.entry & "\n"
    result.sources.add CompileTimePhaseSource(
      entry: policySource.entry,
      text: policySource.text
    )

  result.manifest.add "children: []\ndependencies: []\nexports: []\nprovides: {}\nadopts: []\n"

## Runs the selected Eido memory policy through the generic compile-time policy API.
proc runRuntimePolicyPhase*(
  program: hirProgram.HirProgram,
  policyModule: moduleModel.ModuleSpec
): CompileTimeInstrumentationPlan =
  if policyModule.policySources.len == 0:
    raise newException(
      ValueError,
      "selected memory policy module '" & policyModule.canonicalName &
        "' declares no policySources"
    )

  let phase = policyPhaseSources(policyModule)
  let phaseName = "memory_policy_" & policyModule.canonicalName.replace('.', '_')
  let lines = runCompileTimeEidoPhase(
    phaseName,
    phase.manifest,
    CompileTimeNativeSupportSource,
    buildCompileTimeSnapshotJson(program),
    phase.sources
  )
  result = parseBindings(lines)
