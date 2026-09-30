## Renders class/interface method calls through representation-neutral helpers.

## Renders one class/interface method call.
proc renderMethodCall*(call: hirExpressions.HirMethodCall): string =
  var protect = false
  var rendered = ""

  if call.dispatchKind == hmdInterface:
    rendered = interfaceDispatchName(
      call.ownerType.interfaceName,
      call.methodName
    ) & "(" & renderExpr(call.receiver)
    if call.receiver.isManagedTemporary:
      protect = true

    for argument in call.arguments:
      rendered.add ", " & renderExpr(argument)
      if argument.isManagedTemporary:
        protect = true
    rendered.add ")"
    return protectManagedTemporary(rendered, protect)

  let renderedName =
    if call.isNative and
        isConcreteStorageTypeName(call.ownerType.className):
      storageMethodName(call.ownerType.className, call.methodName)
    elif call.isNative:
      nativeMethodName(call.ownerType.className, call.methodName)
    elif isManagedGcRuntimeClassName(call.ownerType.className):
      managedGcRuntimeMethodName(call.methodName)
    else:
      methodName(call.methodId, call.ownerType.className, call.methodName)

  rendered = renderedName & "("
  var wroteArgument = false
  if call.kind == mkInstance:
    rendered.add renderExpr(call.receiver)
    wroteArgument = true
    if call.receiver.isManagedTemporary:
      protect = true

  for argument in call.arguments:
    if wroteArgument:
      rendered.add ", "
    rendered.add renderExpr(argument)
    wroteArgument = true
    if argument.isManagedTemporary:
      protect = true

  rendered.add ")"
  protectManagedTemporary(rendered, protect)
