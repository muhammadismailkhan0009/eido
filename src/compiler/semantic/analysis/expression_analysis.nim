## Resolves and type-checks expressions while lowering them to HIR.
## Example: source `takeByte(7)` contextually types literal `7` as Byte for that parameter.

import ../../diagnostics/errors
import ../../frontend/ast/expressions as astExpressions
import ../../hir/expressions as hirExpressions
import ../../types/model
import ../../types/function_result
import ../symbols/functions
import ../symbols/scope

## Resolves names and types in an AST expression and produces HIR.
## Example: source `a + 5` becomes a typed binary HIR node referencing `a` by `LocalId`.
proc analyzeExpr*(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols
): hirExpressions.HirExpr

## Analyzes an expression against an expected primitive type.
## Example: literal `7` becomes Byte when passed to a Byte parameter, but `128` is rejected.
proc analyzeExprExpected*(
  expr: astExpressions.Expr,
  expected: EidoType,
  locals: LocalScope,
  functions: FunctionSymbols
): hirExpressions.HirExpr

## Checks whether an integer literal fits the requested integral primitive.
## Example: 127 fits Byte; Int accepts the full parsed signed 64-bit range.
proc integerFits(value: int64, typ: EidoType): bool =
  case typ
  of etByte:
    value >= -128'i64 and value <= 127'i64
  of etShort:
    value >= -32768'i64 and value <= 32767'i64
  of etInt:
    true
  else:
    false

## Creates a typed HIR integer literal after range checking.
## Example: source `7` with expected Short becomes an `hekInteger` of type `etShort`.
proc analyzeIntegerAs(
  expr: astExpressions.Expr,
  typ: EidoType
): hirExpressions.HirExpr =
  if not integerFits(expr.intValue, typ):
    failAt(
      expr.span,
      "integer literal " & $expr.intValue & " does not fit " & typ.displayName
    )

  HirExpr(
    kind: hekInteger,
    span: expr.span,
    typ: typ,
    intValue: expr.intValue
  )

## Resolves one AST call and all of its arguments.
## Example: `mix(true, 2.5)` resolves the target FunctionId and checks Bool/Float argument types.
proc analyzeCall*(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols
): hirExpressions.HirCall =
  if expr.kind != astExpressions.ekCall:
    failAt(expr.span, "expected function call")

  if not functions.contains(expr.callee):
    failAt(expr.span, "unknown function '" & expr.callee & "'")

  let target = functions.get(expr.callee)
  if expr.arguments.len != target.parameterTypes.len:
    failAt(
      expr.span,
      "function '" & expr.callee & "' expects " &
        $target.parameterTypes.len & " arguments but got " &
        $expr.arguments.len
    )

  var arguments: seq[HirExpr]
  for index, argument in expr.arguments:
    arguments.add analyzeExprExpected(
      argument,
      target.parameterTypes[index],
      locals,
      functions
    )

  HirCall(
    span: expr.span,
    functionId: target.id,
    functionName: target.name,
    arguments: arguments,
    result: target.result
  )

## Analyzes an expression against an expected primitive type.
## Example: unsuffixed `1` may become Byte or Short in those parameter positions; otherwise it is Int.
proc analyzeExprExpected*(
  expr: astExpressions.Expr,
  expected: EidoType,
  locals: LocalScope,
  functions: FunctionSymbols
): hirExpressions.HirExpr =
  if expr.kind == astExpressions.ekInteger and expected.isIntegral:
    return analyzeIntegerAs(expr, expected)

  let analyzed = analyzeExpr(expr, locals, functions)
  if analyzed.typ != expected:
    failAt(
      expr.span,
      "type mismatch: expected " & expected.displayName &
        " but got " & analyzed.typ.displayName
    )
  analyzed

## Analyzes comparison operands while allowing an integer literal to adopt the other integral operand's type.
## Example: if `value` is Byte, both `value < 10` and `10 < value` analyze the literal as Byte.
proc analyzeComparisonOperands(
  leftExpr, rightExpr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols
): tuple[left, right: hirExpressions.HirExpr] =
  if leftExpr.kind == astExpressions.ekInteger and
      rightExpr.kind != astExpressions.ekInteger:
    let right = analyzeExpr(rightExpr, locals, functions)
    if right.typ.isIntegral:
      return (analyzeIntegerAs(leftExpr, right.typ), right)

  if rightExpr.kind == astExpressions.ekInteger and
      leftExpr.kind != astExpressions.ekInteger:
    let left = analyzeExpr(leftExpr, locals, functions)
    if left.typ.isIntegral:
      return (left, analyzeIntegerAs(rightExpr, left.typ))

  (
    analyzeExpr(leftExpr, locals, functions),
    analyzeExpr(rightExpr, locals, functions)
  )

include expression/boolean_operators

## Resolves names and types in an AST expression and produces HIR.
## Example: `2147483648` is still Int and `2.5` is Float.
proc analyzeExpr*(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols
): hirExpressions.HirExpr =
  case expr.kind
  of astExpressions.ekInteger:
    analyzeIntegerAs(expr, etInt)

  of astExpressions.ekFloat:
    HirExpr(
      kind: hekFloating,
      span: expr.span,
      typ: etFloat,
      floatValue: expr.floatValue
    )

  of astExpressions.ekBoolean:
    HirExpr(
      kind: hekBoolean,
      span: expr.span,
      typ: etBool,
      boolValue: expr.boolValue
    )

  of astExpressions.ekChar:
    HirExpr(
      kind: hekChar,
      span: expr.span,
      typ: etChar,
      charValue: expr.charValue
    )

  of astExpressions.ekIdentifier:
    if not locals.contains(expr.name):
      failAt(expr.span, "unknown local '" & expr.name & "'")
    let symbol = locals.get(expr.name)
    HirExpr(
      kind: hekLocal,
      span: expr.span,
      typ: symbol.typ,
      localId: symbol.id,
      sourceName: symbol.name
    )

  of astExpressions.ekCall:
    let call = analyzeCall(expr, locals, functions)
    if call.result.kind == frNone:
      failAt(
        expr.span,
        "function '" & call.functionName & "' does not return a value"
      )
    HirExpr(
      kind: hekCall,
      span: expr.span,
      typ: call.result.typ,
      call: call
    )

  of astExpressions.ekUnary:
    let operand = analyzeExpr(expr.operand, locals, functions)

    case expr.unaryOp
    of astExpressions.uoNegate:
      if operand.typ notin {etInt, etFloat}:
        failAt(
          expr.span,
          "unary '-' requires Int or Float but got " & operand.typ.displayName
        )

      HirExpr(
        kind: hekUnary,
        span: expr.span,
        typ: operand.typ,
        unaryOp: huoNegate,
        operand: operand
      )

    of astExpressions.uoNot:
      analyzeBooleanNot(expr, locals, functions)

  of astExpressions.ekBinary:
    if expr.op in {astExpressions.boAnd, astExpressions.boOr}:
      return analyzeBooleanBinary(expr, locals, functions)

    if expr.op in {
      astExpressions.boEqual,
      astExpressions.boNotEqual,
      astExpressions.boLess,
      astExpressions.boLessEqual,
      astExpressions.boGreater,
      astExpressions.boGreaterEqual
    }:
      let operands = analyzeComparisonOperands(
        expr.left, expr.right, locals, functions
      )
      let left = operands.left
      let right = operands.right

      if left.typ != right.typ:
        failAt(
          expr.span,
          "comparison operands must have the same primitive type"
        )

      if expr.op in {
        astExpressions.boLess,
        astExpressions.boLessEqual,
        astExpressions.boGreater,
        astExpressions.boGreaterEqual
      } and not left.typ.isNumeric:
        failAt(
          expr.span,
          "ordered comparison requires Byte, Short, Int, or Float operands"
        )

      let op =
        case expr.op
        of astExpressions.boEqual: hboEqual
        of astExpressions.boNotEqual: hboNotEqual
        of astExpressions.boLess: hboLess
        of astExpressions.boLessEqual: hboLessEqual
        of astExpressions.boGreater: hboGreater
        of astExpressions.boGreaterEqual: hboGreaterEqual
        else: hboEqual

      return HirExpr(
        kind: hekBinary,
        span: expr.span,
        typ: etBool,
        op: op,
        left: left,
        right: right
      )

    let left = analyzeExpr(expr.left, locals, functions)
    let right = analyzeExpr(expr.right, locals, functions)

    if left.typ != right.typ or not left.typ.isArithmetic:
      failAt(
        expr.span,
        "arithmetic operands must have the same Int or Float type"
      )

    let op =
      case expr.op
      of astExpressions.boAdd: hboAdd
      of astExpressions.boSubtract: hboSubtract
      of astExpressions.boMultiply: hboMultiply
      of astExpressions.boDivide: hboDivide
      else:
        raise newException(
          ValueError,
          "semantic invariant: comparison operator reached arithmetic lowering"
        )

    HirExpr(
      kind: hekBinary,
      span: expr.span,
      typ: left.typ,
      op: op,
      left: left,
      right: right
    )
