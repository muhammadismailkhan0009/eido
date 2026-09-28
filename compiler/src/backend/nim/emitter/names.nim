## Creates collision-safe Nim identifiers from Eido semantic/source identities.

import std/strutils
import ../../../semantic/symbols/ids



## Encodes specialized generic nominal names into valid backend identifiers.
## Ordinary source identifiers remain unchanged for readable generated code.
proc nominalName(sourceName: string): string =
  if '<' notin sourceName:
    return sourceName

  result = "generic"
  for character in sourceName:
    result.add "_" & toHex(ord(character), 2)

## Builds a collision-safe Nim function name from semantic identity.
proc functionName*(id: FunctionId, sourceName: string): string =
  "eido_fn_" & $id.value & "_" & sourceName

## Builds the backend ABI symbol used by a top-level native Eido function.
## Example: platformWriteLine maps to eido_native_platformWriteLine in the native support module.
proc nativeFunctionName*(sourceName: string): string =
  "eido_native_" & sourceName

## Builds the backend ABI symbol used by a native Eido class method.
## Example: Console.writeLine maps to eido_native_method_Console_writeLine.
proc nativeMethodName*(ownerName, sourceName: string): string =
  "eido_native_method_" & nominalName(ownerName) & "_" & sourceName

## Builds a collision-safe Nim method name from semantic identity and owner.
proc methodName*(
  id: MethodId,
  ownerName: string,
  sourceName: string
): string =
  "eido_method_" & $id.value & "_" & nominalName(ownerName) & "_" & sourceName

## Builds a collision-safe Nim local name from semantic identity.
proc localName*(id: LocalId, sourceName: string): string =
  "eido_local_" & $id.value & "_" & sourceName

## Builds the generated Nim name for one nominal Eido class.
proc className*(sourceName: string): string =
  "eido_class_" & nominalName(sourceName)

## Builds the generated Nim name for one Eido interface wrapper type.
proc interfaceName*(sourceName: string): string =
  "eido_interface_" & nominalName(sourceName)

## Builds the generated closure field for one interface method.
proc interfaceMethodFieldName*(interfaceSourceName, methodSourceName: string): string =
  "eido_iface_" & nominalName(interfaceSourceName) & "_" & methodSourceName

## Builds the concrete-class adapter used to create one interface value.
proc interfaceAdapterName*(classSourceName, interfaceSourceName: string): string =
  "eido_adapt_" & nominalName(classSourceName) & "_to_" &
    nominalName(interfaceSourceName)

## Builds the adapter used for an interface-extension upcast.
proc interfaceUpcastName*(sourceInterface, targetInterface: string): string =
  "eido_upcast_" & nominalName(sourceInterface) & "_to_" &
    nominalName(targetInterface)

## Builds the generated Nim copier name for one nominal Eido class.
proc classCopyName*(sourceName: string): string =
  "eido_copy_" & nominalName(sourceName)

## Builds the generated internal recursive copier name.
proc classCopyInternalName*(sourceName: string): string =
  "eido_copy_" & nominalName(sourceName) & "_internal"

## Builds the generated memo field name for one copied class type.
proc classCopyTableName*(sourceName: string): string =
  "eido_copies_" & nominalName(sourceName)

## Builds the generated copy-context type name.
proc copyContextName*(): string =
  "eido_copy_context"

## Builds the generated Nim name for one Eido class field.
proc fieldName*(sourceName: string): string =
  "eido_field_" & sourceName
