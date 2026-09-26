## Maps Eido semantic types to backend Nim type spellings.
## Class lowering remains representation-neutral semantically even though the backend has a stable generated name.

import ../../../types/model
import names

## Converts one Eido semantic type to Nim source syntax.
proc renderType*(typ: EidoType): string =
  case typ.kind
  of etkClass:
    className(typ.className)
  of etkPrimitive:
    case typ.primitive
    of ptBool: "bool"
    of ptByte: "int8"
    of ptShort: "int16"
    of ptInt: "int64"
    of ptFloat: "float64"
    of ptChar: "uint16"
