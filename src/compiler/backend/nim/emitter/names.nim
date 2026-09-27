## Creates collision-safe Nim identifiers from Eido semantic/source identities.

import ../../../semantic/symbols/ids

## Builds a collision-safe Nim function name from semantic identity.
proc functionName*(id: FunctionId, sourceName: string): string =
  "eido_fn_" & $id.value & "_" & sourceName

## Builds a collision-safe Nim method name from semantic identity and owner.
proc methodName*(
  id: MethodId,
  ownerName: string,
  sourceName: string
): string =
  "eido_method_" & $id.value & "_" & ownerName & "_" & sourceName

## Builds a collision-safe Nim local name from semantic identity.
proc localName*(id: LocalId, sourceName: string): string =
  "eido_local_" & $id.value & "_" & sourceName

## Builds the generated Nim name for one nominal Eido class.
proc className*(sourceName: string): string =
  "eido_class_" & sourceName

## Builds the generated Nim copier name for one nominal Eido class.
proc classCopyName*(sourceName: string): string =
  "eido_copy_" & sourceName

## Builds the generated internal recursive copier name.
proc classCopyInternalName*(sourceName: string): string =
  "eido_copy_" & sourceName & "_internal"

## Builds the generated memo field name for one copied class type.
proc classCopyTableName*(sourceName: string): string =
  "eido_copies_" & sourceName

## Builds the generated copy-context type name.
proc copyContextName*(): string =
  "eido_copy_context"

## Builds the generated Nim name for one Eido class field.
proc fieldName*(sourceName: string): string =
  "eido_field_" & sourceName
