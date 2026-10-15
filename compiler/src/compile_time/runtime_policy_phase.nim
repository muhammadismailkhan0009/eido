## Runs policy-specific Eido compile-time code that binds generic program events.
## The compiler exposes event points; memory-policy meaning remains in Eido.

import std/[os, strutils]
import ../pipeline/options
import host
import instrumentation_model

const
  GcPolicyManifestSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_policy_gc/module.yaml"
  )
  RuntimeBindingsSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_policy_gc/RuntimeBindings.eido"
  )
  GcPolicyRunnerSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/phases/memory_policy_gc/runner.eido"
  )
  CompileTimeNativeSupportSource = staticRead(
    currentSourcePath().parentDir / "../../compile_time/native/eido_native.nim"
  )

## Applies one Eido-selected generic event binding to the compiler plan.
proc setBinding(
  plan: var CompileTimeInstrumentationPlan,
  eventKind: int,
  methodName: string
) =
  case eventKind
  of 1: plan.bindingEnter = methodName
  of 2: plan.bindingWrite = methodName
  of 3: plan.bindingLeave = methodName
  of 4: plan.metadataType = methodName
  of 5: plan.metadataField = methodName
  of 6: plan.objectAcquire = methodName
  of 7: plan.temporaryEnter = methodName
  of 8: plan.temporaryLeave = methodName
  of 9: plan.statementBoundary = methodName
  of 10: plan.invariantEnter = methodName
  of 11: plan.invariantLeave = methodName
  of 12: plan.invariantClear = methodName
  of 13: plan.programExit = methodName
  else:
    raise newException(ValueError, "unknown compiler instrumentation event " & $eventKind)

## Parses one policy phase output into generic event-to-method bindings.
proc parseBindings(lines: seq[string]): CompileTimeInstrumentationPlan =
  for line in lines:
    if line.len == 0:
      continue
    if not line.startsWith("EIDO_BIND|"):
      raise newException(ValueError, "unexpected runtime-policy phase output: " & line)
    let parts = line.split('|')
    if parts.len != 3:
      raise newException(ValueError, "invalid runtime-policy binding record")
    result.setBinding(parseInt(parts[1]), parts[2])

## Runs the selected Eido runtime policy while keeping the compiler policy-neutral.
proc runRuntimePolicyPhase*(
  strategy: MemoryStrategy
): CompileTimeInstrumentationPlan =
  case strategy
  of msGc:
    let lines = runCompileTimeEidoPhase(
      "memory_policy_gc",
      GcPolicyManifestSource,
      CompileTimeNativeSupportSource,
      "{}",
      @[
        CompileTimePhaseSource(entry: "RuntimeBindings.eido", text: RuntimeBindingsSource),
        CompileTimePhaseSource(entry: "runner.eido", text: GcPolicyRunnerSource)
      ]
    )
    result = parseBindings(lines)
  of msManual:
    result = CompileTimeInstrumentationPlan()
