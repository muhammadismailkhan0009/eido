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
    if call.receiver.isIdentityTemporary:
      protect = true

    for argument in call.arguments:
      rendered.add ", " & renderExpr(argument)
      if argument.isIdentityTemporary:
        protect = true
    rendered.add ")"
    return protectIdentityTemporaries(rendered, protect)

  if call.isNative and
      isConcreteStorageTypeName(call.ownerType.className) and
      call.methodName == "release" and
      call.arguments.len == 1 and
      call.arguments[0].kind == hirExpressions.hekClassFieldAccess:
    let argument = call.arguments[0]
    return classOwnedFieldReleaseName(
      argument.classFieldOwner.className,
      argument.classFieldName
    ) & "()"

  # Fresh constructions and explicit copies initialize a Storage-owned
  # payload directly, rather than first allocating a managed root object.
  if call.kind == mkStatic and
      isConcreteStorageTypeName(call.ownerType.className) and
      call.methodName == "write" and call.arguments.len == 3:
    let value = call.arguments[2]
    let storageOwner = call.ownerType.className
    if value.kind == hirExpressions.hekConstruct and
        storageElementName(storageOwner) == value.constructedTypeName:
      var construction = storageMethodName(storageOwner, "writeConstruct") &
        "(" & renderExpr(call.arguments[0]) & ", " &
        renderExpr(call.arguments[1])
      for field in value.fields:
        construction.add ", arg_" & fieldName(field.sourceName) &
          " = " & renderExpr(field.value)
      construction.add ")"
      return protectIdentityTemporaries(construction, true)
    if value.kind == hirExpressions.hekClassRelation and
        value.classRelationKind == hirExpressions.hcvrCopy:
      let copying = storageMethodName(storageOwner, "writeCopy") & "(" &
        renderExpr(call.arguments[0]) & ", " &
        renderExpr(call.arguments[1]) & ", " &
        renderExpr(value.relatedValue) & ")"
      return protectIdentityTemporaries(copying, true)

  let renderedName =
    if call.isNative and
        isConcreteStorageTypeName(call.ownerType.className):
      storageMethodName(call.ownerType.className, call.methodName)
    elif call.isNative:
      nativeMethodName(call.ownerType.className, call.methodName)
    else:
      methodName(call.methodId, call.ownerType.className, call.methodName)

  rendered = renderedName & "("
  var wroteArgument = false
  if call.kind == mkInstance:
    rendered.add renderExpr(call.receiver)
    wroteArgument = true
    if call.receiver.isIdentityTemporary:
      protect = true

  for argument in call.arguments:
    if wroteArgument:
      rendered.add ", "
    if call.isNative and not isConcreteStorageTypeName(call.ownerType.className):
      rendered.add renderNativeArgument(argument)
    else:
      rendered.add renderExpr(argument)
    wroteArgument = true
    if argument.isIdentityTemporary:
      protect = true

  rendered.add ")"
  rendered = protectIdentityTemporaries(rendered, protect)
  if call.isNative and not isConcreteStorageTypeName(call.ownerType.className):
    wrapNativeResult(rendered, call.result)
  else:
    rendered
