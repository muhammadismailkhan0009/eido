## Defines Eido semantic types independently of source spelling or backend representation.
## Primitive/String/class identity is orthogonal to explicit optional state.

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
    isOptional*: bool
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

## Creates a nominal non-optional class type.
## Example: classType("Employee") identifies the declared Employee type.
proc classType*(name: string): EidoType =
  EidoType(kind: etkClass, className: name)

## Marks a type as optional without changing its underlying value identity.
## Example: optionalType(etInt) represents source Int?.
proc optionalType*(typ: EidoType): EidoType =
  result = typ
  result.isOptional = true

## Removes optional state after a lexical exists proof.
## Example: requiredType(optionalType(classType("User"))) becomes User.
proc requiredType*(typ: EidoType): EidoType =
  result = typ
  result.isOptional = false

## Compares semantic types including explicit optional state.
## Example: Int and Int? are distinct while two Int? values have the same type.
proc `==`*(left, right: EidoType): bool =
  if left.isOptional != right.isOptional or left.kind != right.kind:
    return false

  case left.kind
  of etkPrimitive:
    left.primitive == right.primitive
  of etkString:
    true
  of etkClass:
    left.className == right.className

## Returns the human-readable Eido type name including optional suffix.
## Example: classType("Employee") displays Employee while optional Employee displays Employee?.
proc displayName*(typ: EidoType): string =
  let base =
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

  base & (if typ.isOptional: "?" else: "")

## Reports whether a semantic type is a definitely-present primitive.
proc isPrimitive*(typ: EidoType): bool =
  not typ.isOptional and typ.kind == etkPrimitive

## Reports whether a definitely-present type supports value equality.
## Optional presence is handled structurally through exists rather than equality.
proc isEqualityComparable*(typ: EidoType): bool =
  not typ.isOptional and typ.kind in {etkPrimitive, etkString}

## Reports whether a definitely-present type is an integer-number primitive.
proc isIntegral*(typ: EidoType): bool =
  not typ.isOptional and typ.kind == etkPrimitive and
    typ.primitive in {ptByte, ptShort, ptInt}

## Reports whether a definitely-present type supports numeric arithmetic.
proc isNumericArithmetic*(typ: EidoType): bool =
  not typ.isOptional and typ.kind == etkPrimitive and
    typ.primitive in {ptInt, ptFloat}

## Reports whether a definitely-present type supports ordered numeric comparison.
proc isNumeric*(typ: EidoType): bool =
  not typ.isOptional and typ.kind == etkPrimitive and
    typ.primitive in {ptByte, ptShort, ptInt, ptFloat}
