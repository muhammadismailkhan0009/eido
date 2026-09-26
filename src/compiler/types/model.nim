## Defines Eido primitive semantic types independently of source spelling or Nim.
## Example: source `Int` resolves to one 64-bit integer semantic type; there is no separate Long type.

type
  EidoType* = enum
    etBool,
    etByte,
    etShort,
    etInt,
    etFloat,
    etChar

## Returns the human-readable Eido type name.
## Example: `etFloat` is displayed as `Float`.
proc displayName*(typ: EidoType): string =
  case typ
  of etBool: "Bool"
  of etByte: "Byte"
  of etShort: "Short"
  of etInt: "Int"
  of etFloat: "Float"
  of etChar: "Char"

## Reports whether a primitive is an integer-number type.
## Example: Byte, Short, and Int are integral, while Float is not.
proc isIntegral*(typ: EidoType): bool =
  typ in {etByte, etShort, etInt}

## Reports whether a primitive supports the currently implemented arithmetic operators.
## Example: Int and Float support arithmetic; Bool and Char do not.
proc isArithmetic*(typ: EidoType): bool =
  typ in {etInt, etFloat}

## Reports whether a primitive supports ordered numeric comparison.
## Example: Byte, Short, Int, and Float are numeric; Bool and Char are not.
proc isNumeric*(typ: EidoType): bool =
  typ in {etByte, etShort, etInt, etFloat}
