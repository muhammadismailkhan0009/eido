## Defines typed, resolved HIR expressions and calls consumed by backends.
## Example: source `-value` becomes typed unary-negation HIR after `value` is resolved.

import ../source/span
import ../types/model
import ../types/function_result
import ../semantic/symbols/ids

type
  HirUnaryOp* = enum
    huoNegate,
    huoNot

  HirClassValueRelationKind* = enum
    hcvrCopy,
    hcvrRef

  HirBinaryOp* = enum
    hboAdd,
    hboSubtract,
    hboMultiply,
    hboDivide,
    hboEqual,
    hboNotEqual,
    hboLess,
    hboLessEqual,
    hboGreater,
    hboGreaterEqual,
    hboAnd,
    hboOr

  HirExprKind* = enum
    hekInteger,
    hekFloating,
    hekBoolean,
    hekChar,
    hekString,
    hekLocal,
    hekCall,
    hekConstruct,
    hekClassRelation,
    hekFieldAccess,
    hekMethodCall,
    hekUnary,
    hekBinary

  HirConstructionField* = object
    span*: SourceSpan
    sourceName*: string
    value*: HirExpr

  HirCall* = ref object
    span*: SourceSpan
    functionId*: FunctionId
    functionName*: string
    arguments*: seq[HirExpr]
    result*: FunctionResult

  HirMethodCall* = ref object
    span*: SourceSpan
    methodId*: MethodId
    methodName*: string
    ownerType*: EidoType
    receiver*: HirExpr
    arguments*: seq[HirExpr]
    result*: FunctionResult

  HirExpr* = ref object
    span*: SourceSpan
    typ*: EidoType
    case kind*: HirExprKind
    of hekInteger:
      intValue*: int64
    of hekFloating:
      floatValue*: float64
    of hekBoolean:
      boolValue*: bool
    of hekChar:
      charValue*: uint16
    of hekString:
      stringValue*: string
    of hekLocal:
      localId*: LocalId
      sourceName*: string
    of hekCall:
      call*: HirCall
    of hekConstruct:
      constructedTypeName*: string
      fields*: seq[HirConstructionField]
    of hekClassRelation:
      classRelationKind*: HirClassValueRelationKind
      relatedValue*: HirExpr
    of hekFieldAccess:
      target*: HirExpr
      sourceFieldName*: string
    of hekMethodCall:
      methodCall*: HirMethodCall
    of hekUnary:
      unaryOp*: HirUnaryOp
      operand*: HirExpr
    of hekBinary:
      op*: HirBinaryOp
      left*: HirExpr
      right*: HirExpr
