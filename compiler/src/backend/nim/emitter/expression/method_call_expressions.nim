## Renders resolved instance method calls as generated Nim procedure calls.

## Renders one method call with the receiver as the first generated argument.
proc renderMethodCall*(call: hirExpressions.HirMethodCall): string =
  result = methodName(
    call.methodId,
    call.ownerType.className,
    call.methodName
  ) & "("

  result.add renderExpr(call.receiver)
  for argument in call.arguments:
    result.add ", " & renderExpr(argument)

  result.add ")"
