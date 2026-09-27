## Renders resolved inferred-static and instance method calls as Nim procedure calls.

## Renders one class method call with a receiver only for instance methods.
## Example: Calculator.add(1,2) omits a receiver while account.value() passes account first.
proc renderMethodCall*(call: hirExpressions.HirMethodCall): string =
  result = methodName(
    call.methodId,
    call.ownerType.className,
    call.methodName
  ) & "("

  var hasPreviousArgument = false
  if call.kind == mkInstance:
    result.add renderExpr(call.receiver)
    hasPreviousArgument = true

  for argument in call.arguments:
    if hasPreviousArgument:
      result.add ", "
    result.add renderExpr(argument)
    hasPreviousArgument = true

  result.add ")"
