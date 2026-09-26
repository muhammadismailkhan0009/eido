## Maps Eido primitive semantic types to Nim representations.
## Example: Eido `Int` emits `int64` and Eido `Float` emits `float64`.

import ../../../types/model

## Converts an Eido primitive type to Nim source syntax.
## Example: `etFloat` renders as `float64`.
proc renderType*(typ: EidoType): string =
  case typ
  of etBool: "bool"
  of etByte: "int8"
  of etShort: "int16"
  of etInt: "int64"
  of etFloat: "float64"
  of etChar: "uint16"
