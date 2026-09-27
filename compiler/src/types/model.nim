## Defines Eido semantic types independently of source spelling or backend representation.
## Primitive constants stay compact, String is a distinct built-in value, and nominal classes carry source-level identity.

type
  PrimitiveType* = enum
    ptBool,
    ptByte,
    ptShort,
    ptInt,
    ptFloat,
    ptChar

  EidoTypeKind* = enum
    etkPrimitive,
    etkString,
    etkClass

  EidoType* = object
    case kind*: EidoTypeKind
    of etkPrimitive:
      primitive*: PrimitiveType
    of etkString:
      discard
    of etkClass:
      className*: string

const
  etBool* = EidoType(kind: etkPrimitive, primitive: ptBool)
  etByte* = EidoType(kind: etkPrimitive, primitive: ptByte)
  etShort* = EidoType(kind: etkPrimitive, primitive: ptShort)
  etInt* = EidoType(kind: etkPrimitive, primitive: ptInt)
  etFloat* = EidoType(kind: etkPrimitive, primitive: ptFloat)
  etChar* = EidoType(kind: etkPrimitive, primitive: ptChar)
  etString* = EidoType(kind: etkString)

## Creates a nominal class type without choosing value/reference/heap semantics.
## Example: classType("Employee") identifies the declared Employee type.
proc classType*(name: string): EidoType =
  EidoType(kind: etkClass, className: name)

## Compares semantic types by built-in kind/value or nominal class identity.
proc `==`*(left, right: EidoType): bool =
  if left.kind != right.kind:
    return false

  case left.kind
  of etkPrimitive:
    left.primitive == right.primitive
  of etkString:
    true
  of etkClass:
    left.className == right.className

## Returns the human-readable Eido type name.
## Example: etFloat displays as Float while classType("Employee") displays as Employee.
proc displayName*(typ: EidoType): string =
  case typ.kind
  of etkClass:
    typ.className
  of etkString:
    "String"
  of etkPrimitive:
    case typ.primitive
    of ptBool: "Bool"
    of ptByte: "Byte"
    of ptShort: "Short"
    of ptInt: "Int"
    of ptFloat: "Float"
    of ptChar: "Char"

## Reports whether a semantic type is primitive.
proc isPrimitive*(typ: EidoType): bool =
  typ.kind == etkPrimitive

## Reports whether a type supports value equality without object identity.
## Example: String and Int are equality-comparable, while Account class identity is not.
proc isEqualityComparable*(typ: EidoType): bool =
  typ.kind in {etkPrimitive, etkString}

## Reports whether a type is an integer-number primitive.
proc isIntegral*(typ: EidoType): bool =
  typ.kind == etkPrimitive and
    typ.primitive in {ptByte, ptShort, ptInt}

## Reports whether a type supports the numeric arithmetic operator family.
## Example: Int and Float qualify, while String concatenation is handled separately.
proc isNumericArithmetic*(typ: EidoType): bool =
  typ.kind == etkPrimitive and
    typ.primitive in {ptInt, ptFloat}

## Reports whether a type supports ordered numeric comparison.
proc isNumeric*(typ: EidoType): bool =
  typ.kind == etkPrimitive and
    typ.primitive in {ptByte, ptShort, ptInt, ptFloat}
