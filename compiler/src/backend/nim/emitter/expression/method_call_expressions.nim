## Renders resolved direct class calls and dynamic interface calls.

## Renders one class/interface method call.
proc renderMethodCall*(call: hirExpressions.HirMethodCall): string =
  if call.dispatchKind == hmdInterface:
    result = renderExpr(call.receiver) & "." &
      interfaceMethodFieldName(
        call.ownerType.interfaceName,
        call.methodName
      ) & "("

    for index, argument in call.arguments:
      if index > 0:
        result.add ", "
      result.add renderExpr(argument)
    result.add ")"
    return

  let renderedName =
    if call.isNative and
        isConcreteStorageTypeName(call.ownerType.className):
      storageMethodName(call.ownerType.className, call.methodName)
    elif call.isNative:
      nativeMethodName(call.ownerType.className, call.methodName)
    else:
      methodName(
        call.methodId,
        call.ownerType.className,
        call.methodName
      )

  result = renderedName & "("

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
