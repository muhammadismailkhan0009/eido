## Creates collision-safe Nim identifiers from Eido semantic/source identities.

import ../../../semantic/symbols/ids

## Builds a collision-safe Nim function name from semantic identity.
proc functionName*(id: FunctionId, sourceName: string): string =
  "eido_fn_" & $id.value & "_" & sourceName

## Builds a collision-safe Nim local name from semantic identity.
proc localName*(id: LocalId, sourceName: string): string =
  "eido_local_" & $id.value & "_" & sourceName

## Builds the generated Nim name for one nominal Eido class.
proc className*(sourceName: string): string =
  "eido_class_" & sourceName

## Builds the generated Nim name for one Eido class field.
proc fieldName*(sourceName: string): string =
  "eido_field_" & sourceName
