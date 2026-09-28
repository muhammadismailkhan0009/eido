## Maps Eido semantic types to backend Nim type spellings.
## Class lowering remains representation-neutral semantically even though the backend has a stable generated name.

import ../../../types/model
import names

## Converts one definitely-present Eido semantic type to Nim source syntax.
## Example: Int becomes int64 and Account becomes its generated nominal class name.
proc renderRequiredType(typ: EidoType): string =
  case typ.kind
  of etkClass:
    className(typ.className)
  of etkInterface:
    interfaceName(typ.interfaceName)
  of etkString:
    "string"
  of etkPrimitive:
    case typ.primitive
    of ptBool: "bool"
    of ptByte: "int8"
    of ptShort: "int16"
    of ptInt: "int64"
    of ptFloat: "float64"
    of ptChar: "uint16"

## Converts one Eido semantic type to Nim source syntax.
## Example: Int? becomes Option[int64] without exposing Option in Eido source.
proc renderType*(typ: EidoType): string =
  if typ.isOptional:
    return "Option[" & renderRequiredType(requiredType(typ)) & "]"

  renderRequiredType(typ)
