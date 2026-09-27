## Renders resolved HIR expressions and calls as Nim source.
## Example: Eido Int literal `2147483648` becomes `int64(2147483648)`.

import ../../../hir/expressions as hirExpressions
import ../../../types/model
import ../../../types/method_kind
import names
import type_emitter

## Renders one resolved HIR expression as Nim source.
## Example: local Int `x + 5` renders as `(eido_local_0_x + int64(5))`.
proc renderExpr*(expr: hirExpressions.HirExpr): string

include expression/string_values
include expression/boolean_operators
include expression/construction_expressions
include expression/field_access_expressions
include expression/method_call_expressions

## Renders a resolved function call without deciding whether its result is used.
## Example: resolved `add(1, 2)` becomes `eido_fn_1_add(int64(1), int64(2))`.
proc renderCall*(call: hirExpressions.HirCall): string =
  let renderedName =
    if call.isNative:
      nativeFunctionName(call.functionName)
    else:
      functionName(call.functionId, call.functionName)

  result = renderedName & "("
  for index, argument in call.arguments:
    if index > 0:
      result.add ", "
    result.add renderExpr(argument)
  result.add ")"

## Renders a typed integral literal with its Nim representation.
## Example: Eido Byte literal value 7 becomes `int8(7)`, while ordinary Int becomes `int64(...)`.
proc renderIntegerLiteral(expr: hirExpressions.HirExpr): string =
  if expr.typ.kind != etkPrimitive:
    raise newException(
      ValueError,
      "backend invariant: integer HIR has non-integral type"
    )

  case expr.typ.primitive
  of ptByte: "int8(" & $expr.intValue & ")"
  of ptShort: "int16(" & $expr.intValue & ")"
  of ptInt: "int64(" & $expr.intValue & ")"
  else:
    raise newException(
      ValueError,
      "backend invariant: integer HIR has non-integral type"
    )

## Renders an Eido Float literal as 64-bit Nim floating point.
## Example: Eido `1.5` becomes `float64(1.5)`.
proc renderFloatingLiteral(expr: hirExpressions.HirExpr): string =
  if expr.typ != etFloat:
    raise newException(ValueError, "backend invariant: floating HIR is not Float")
  "float64(" & $expr.floatValue & ")"

## Renders one resolved HIR expression as Nim source.
## Example: local Float `x / 2.0` renders with Nim floating-point division.
proc renderExpr*(expr: hirExpressions.HirExpr): string =
  case expr.kind
  of hirExpressions.hekInteger:
    result = renderIntegerLiteral(expr)
  of hirExpressions.hekFloating:
    result = renderFloatingLiteral(expr)
  of hirExpressions.hekBoolean:
    result = if expr.boolValue: "true" else: "false"
  of hirExpressions.hekChar:
    result = "uint16(" & $expr.charValue & ")"
  of hirExpressions.hekString:
    result = renderStringLiteral(expr)
  of hirExpressions.hekNone:
    result = "none(" & renderType(requiredType(expr.typ)) & ")"
  of hirExpressions.hekOptionalSome:
    result = "some(" & renderExpr(expr.optionalValue) & ")"
  of hirExpressions.hekOptionalGet:
    result = "get(" & renderExpr(expr.optionalValue) & ")"
  of hirExpressions.hekLocal:
    result = localName(expr.localId, expr.sourceName)
  of hirExpressions.hekCall:
    result = renderCall(expr.call)
  of hirExpressions.hekConstruct:
    result = renderConstruction(expr)
  of hirExpressions.hekClassRelation:
    case expr.classRelationKind
    of hirExpressions.hcvrRef:
      result = renderExpr(expr.relatedValue)
    of hirExpressions.hcvrCopy:
      result = classCopyName(expr.typ.className) & "(" &
        renderExpr(expr.relatedValue) & ")"
  of hirExpressions.hekFieldAccess:
    result = renderFieldAccess(expr)
  of hirExpressions.hekMethodCall:
    result = renderMethodCall(expr.methodCall)
  of hirExpressions.hekUnary:
    case expr.unaryOp
    of hirExpressions.huoNegate:
      result = "(-" & renderExpr(expr.operand) & ")"
    of hirExpressions.huoNot:
      result = renderBooleanNot(expr)
  of hirExpressions.hekBinary:
    if expr.op in {hirExpressions.hboAnd, hirExpressions.hboOr}:
      return renderBooleanBinary(expr)
    if expr.op == hirExpressions.hboAdd and expr.typ == etString:
      return renderStringConcatenation(expr)

    let operator =
      case expr.op
      of hirExpressions.hboAdd: "+"
      of hirExpressions.hboSubtract: "-"
      of hirExpressions.hboMultiply: "*"
      of hirExpressions.hboDivide:
        if expr.typ.isIntegral: "div" else: "/"
      of hirExpressions.hboEqual: "=="
      of hirExpressions.hboNotEqual: "!="
      of hirExpressions.hboLess: "<"
      of hirExpressions.hboLessEqual: "<="
      of hirExpressions.hboGreater: ">"
      of hirExpressions.hboGreaterEqual: ">="
      else:
        raise newException(
          ValueError,
          "backend invariant: Boolean operator reached scalar emitter"
        )
    result = "(" & renderExpr(expr.left) & " " & operator & " " &
      renderExpr(expr.right) & ")"
