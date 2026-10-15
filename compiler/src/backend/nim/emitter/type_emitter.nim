## Maps Eido semantic types to backend Nim type spellings.
## Class lowering remains representation-neutral semantically even though the backend has a stable generated name.

import ../../../types/model
import ../../../types/storage
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
    "int64"
  of etkPrimitive:
    case typ.primitive
    of ptBool: "bool"
    of ptByte: "int8"
    of ptShort: "int16"
    of ptInt: "int64"
    of ptFloat: "float64"
    of ptChar: "uint16"



## Reports whether one nominal type carries Eido object/interface identity.
proc isIdentityNominalType*(typ: EidoType): bool =
  case typ.kind
  of etkClass:
    not isConcreteStorageTypeName(typ.className)
  of etkInterface:
    true
  else:
    false

## Converts one Eido semantic type to Nim source syntax.
## Example: Int? becomes Option[int64] without exposing Option in Eido source.
proc renderType*(typ: EidoType): string =
  if typ.isOptional:
    if typ.isIdentityNominalType:
      return renderRequiredType(requiredType(typ))
    return "Option[" & renderRequiredType(requiredType(typ)) & "]"

  renderRequiredType(typ)
