## Defines syntax-tree nodes for Eido expressions.
## Example: `-value` becomes a unary negation expression, while `a + 5` becomes a binary expression.

import ../../source/span

type
  UnaryOp* = enum
    uoNegate,
    uoNot

  ClassValueRelationKind* = enum
    cvrCopy,
    cvrRef

  BinaryOp* = enum
    boAdd,
    boSubtract,
    boMultiply,
    boDivide,
    boEqual,
    boNotEqual,
    boLess,
    boLessEqual,
    boGreater,
    boGreaterEqual,
    boAnd,
    boOr

  ExprKind* = enum
    ekInteger,
    ekFloat,
    ekBoolean,
    ekChar,
    ekString,
    ekIdentifier,
    ekCall,
    ekConstruct,
    ekClassRelation,
    ekFieldAccess,
    ekMethodCall,
    ekUnary,
    ekBinary

  ConstructionField* = object
    span*: SourceSpan
    name*: string
    value*: Expr

  Expr* = ref object
    span*: SourceSpan
    case kind*: ExprKind
    of ekInteger:
      intValue*: int64
    of ekFloat:
      floatValue*: float64
    of ekBoolean:
      boolValue*: bool
    of ekChar:
      charValue*: uint16
    of ekString:
      stringValue*: string
    of ekIdentifier:
      name*: string
    of ekCall:
      callee*: string
      arguments*: seq[Expr]
    of ekConstruct:
      typeName*: string
      fields*: seq[ConstructionField]
    of ekClassRelation:
      relationKind*: ClassValueRelationKind
      relatedValue*: Expr
    of ekFieldAccess:
      target*: Expr
      fieldName*: string
    of ekMethodCall:
      receiver*: Expr
      methodName*: string
      methodArguments*: seq[Expr]
    of ekUnary:
      unaryOp*: UnaryOp
      operand*: Expr
    of ekBinary:
      op*: BinaryOp
      left*: Expr
      right*: Expr
