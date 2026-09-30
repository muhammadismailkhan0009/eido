## Emits backend metadata derived from the selected GC compile-time strategy.
## These constants describe the future Eido-managed payload layout; the collector
## and root-frame runtime will consume them in later memory-management stages.

import ../../../compile_time/model
import names

## Renders deterministic per-class GC layout and tracing metadata.
proc renderGcMetadata*(plan: CompileTimeMemoryPlan): string =
  if plan.types.len == 0:
    return ""

  result.add "const\n"

  for typePlan in plan.types:
    let prefix = className(typePlan.className) & "_gc"
    result.add "  " & prefix & "_payload_size = int64(" & $typePlan.size & ")\n"
    result.add "  " & prefix & "_alignment = int64(" & $typePlan.alignment & ")\n"

    var tracedCount = 0
    for fieldPlan in typePlan.fields:
      if fieldPlan.traced:
        inc tracedCount

    result.add "  " & prefix & "_trace_count = " & $tracedCount & "\n"

    var traceIndex = 0
    for fieldPlan in typePlan.fields:
      if not fieldPlan.traced:
        continue
      result.add "  " & prefix & "_trace_" & $traceIndex &
        "_offset = int64(" & $fieldPlan.offset & ")\n"
      inc traceIndex

  result.add "\n"
