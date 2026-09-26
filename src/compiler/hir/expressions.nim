## Defines typed, resolved HIR expressions and calls consumed by backends.
## Example: source `-value` becomes typed unary-negation HIR after `value` is resolved.

import ../source/span
import ../types/model
import ../types/function_result
import ../semantic/symbols/ids

type
  HirUnaryOp* = enum
    huoNegate

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
    hboGreaterEqual

  HirExprKind* = enum
    hekInteger,
    hekFloating,
    hekBoolean,
    hekChar,
    hekLocal,
    hekCall,
    hekUnary,
    hekBinary

  HirCall* = ref object
    span*: SourceSpan
    functionId*: FunctionId
    functionName*: string
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
    of hekLocal:
      localId*: LocalId
      sourceName*: string
    of hekCall:
      call*: HirCall
    of hekUnary:
      unaryOp*: HirUnaryOp
      operand*: HirExpr
    of hekBinary:
      op*: HirBinaryOp
      left*: HirExpr
      right*: HirExpr
