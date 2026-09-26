## Creates collision-safe Nim identifiers from semantic IDs. Example: Eido `salary` with local ID 0 becomes `eido_local_0_salary`.

import ../../../semantic/symbols/ids

## Builds a collision-safe Nim function name from semantic identity. Example: function ID 1 named `add` becomes `eido_fn_1_add`.
proc functionName*(id: FunctionId, sourceName: string): string =
  "eido_fn_" & $id.value & "_" & sourceName

## Builds a collision-safe Nim local name from semantic identity. Example: local ID 0 named `salary` becomes `eido_local_0_salary`.
proc localName*(id: LocalId, sourceName: string): string =
  "eido_local_" & $id.value & "_" & sourceName
