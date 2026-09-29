## Resolves class-qualified static calls and value-qualified class/interface calls.

## Analyzes arguments against one resolved class method signature.
proc analyzeMethodArguments(
  expr: astExpressions.Expr,
  target: MethodSymbol,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
): seq[HirExpr] =
  if expr.methodArguments.len != target.parameterTypes.len:
    failAt(
      expr.span,
      "method '" & expr.methodName & "' expects " &
        $target.parameterTypes.len & " arguments but got " &
        $expr.methodArguments.len
    )

  for index, argument in expr.methodArguments:
    result.add analyzeExprExpected(
      argument,
      target.parameterTypes[index],
      locals,
      functions,
      classes
    )

## Analyzes arguments against one interface method contract.
proc analyzeInterfaceMethodArguments(
  expr: astExpressions.Expr,
  target: InterfaceMethodSymbol,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
): seq[HirExpr] =
  if expr.methodArguments.len != target.parameterTypes.len:
    failAt(
      expr.span,
      "interface method '" & expr.methodName & "' expects " &
        $target.parameterTypes.len & " arguments but got " &
        $expr.methodArguments.len
    )

  for index, argument in expr.methodArguments:
    result.add analyzeExprExpected(
      argument,
      target.parameterTypes[index],
      locals,
      functions,
      classes
    )

## Validates that Storage.release receives an owning mutable storage location.
proc validateStorageReleaseOwner(
  expr: astExpressions.Expr,
  locals: LocalScope
) =
  if expr.methodArguments.len != 1:
    return

  let argument = expr.methodArguments[0]
  case argument.kind
  of astExpressions.ekIdentifier:
    if not locals.contains(argument.name) or
        locals.get(argument.name).kind != bkVariable or
        locals.get(argument.name).storageValueProvenance != svpOwned:
      failAt(
        argument.span,
        "Storage.release requires an owning Storage allocation; borrowed views and parameters cannot release backing memory"
      )

  of astExpressions.ekFieldAccess:
    if argument.target.kind != astExpressions.ekIdentifier or
        argument.target.name != "self":
      failAt(
        argument.span,
        "Storage.release requires an owning local or self field"
      )

  else:
    failAt(
      argument.span,
      "Storage.release requires an owning local or self field"
    )

## Resolves a class-qualified call to an inferred static method.
proc analyzeStaticMethodCall(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
): hirExpressions.HirMethodCall =
  let owner = classes.getClass(expr.receiver.name)
  if not owner.containsMethod(expr.methodName):
    failAt(
      expr.span,
      "class '" & owner.name & "' has no method '" &
        expr.methodName & "'"
    )

  let target = owner.getMethod(expr.methodName)
  if isConcreteStorageTypeName(owner.name):
    if target.name == "release":
      validateStorageReleaseOwner(expr, locals)
    if target.name == "view" and storageElementName(owner.name) == "String":
      failAt(
        expr.span,
        "Storage<String>.view is unavailable until raw-view initialization tracking is defined"
      )

  if target.kind != mkStatic:
    failAt(
      expr.span,
      "instance method '" & owner.name & "." & target.name &
        "' requires an instance receiver of type " & owner.name
    )

  HirMethodCall(
    span: expr.span,
    dispatchKind: hmdClass,
    methodId: target.id,
    methodName: target.name,
    isNative: target.isNative,
    kind: mkStatic,
    ownerType: owner.typ,
    arguments: analyzeMethodArguments(
      expr,
      target,
      locals,
      functions,
      classes
    ),
    result: target.result
  )

## Resolves an interface-qualified dynamic call through its contract wrapper.
proc analyzeInterfaceMethodCall(
  expr: astExpressions.Expr,
  receiver: HirExpr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
): hirExpressions.HirMethodCall =
  let interfaceName = receiver.typ.interfaceName
  if not classes.containsInterfaceMethod(interfaceName, expr.methodName):
    failAt(
      expr.span,
      "interface '" & interfaceName & "' has no method '" &
        expr.methodName & "'"
    )

  let target = classes.getInterfaceMethod(interfaceName, expr.methodName)
  HirMethodCall(
    span: expr.span,
    dispatchKind: hmdInterface,
    methodId: MethodId(-1),
    methodName: target.name,
    isNative: false,
    kind: mkInstance,
    ownerType: receiver.typ,
    receiver: receiver,
    arguments: analyzeInterfaceMethodArguments(
      expr,
      target,
      locals,
      functions,
      classes
    ),
    result: target.result
  )

## Resolves one class/interface member call and enforces its call form.
proc analyzeMethodCall*(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
): hirExpressions.HirMethodCall =
  if expr.kind != astExpressions.ekMethodCall:
    failAt(expr.span, "expected method call")

  if expr.receiver.kind == astExpressions.ekIdentifier and
      not locals.contains(expr.receiver.name) and
      classes.containsClass(expr.receiver.name):
    return analyzeStaticMethodCall(
      expr,
      locals,
      functions,
      classes
    )

  let receiver = analyzeExpr(expr.receiver, locals, functions, classes)
  if receiver.typ.isOptional:
    failAt(
      expr.receiver.span,
      "optional value '" & optionalPathKey(expr.receiver) &
        "' requires an exists block before method access"
    )

  if receiver.typ.kind == etkInterface:
    return analyzeInterfaceMethodCall(
      expr,
      receiver,
      locals,
      functions,
      classes
    )

  if receiver.typ.kind != etkClass:
    failAt(
      expr.span,
      "method call requires a class or interface receiver but got " &
        receiver.typ.displayName
    )

  if not classes.containsClass(receiver.typ.className):
    failAt(expr.span, "unknown class type '" & receiver.typ.className & "'")

  let owner = classes.getClass(receiver.typ.className)
  if not owner.containsMethod(expr.methodName):
    failAt(
      expr.span,
      "class '" & owner.name & "' has no method '" &
        expr.methodName & "'"
    )

  let target = owner.getMethod(expr.methodName)
  if target.kind != mkInstance:
    failAt(
      expr.span,
      "static method '" & owner.name & "." & target.name &
        "' must be called through " & owner.name & "." &
        target.name & "(...)"
    )

  HirMethodCall(
    span: expr.span,
    dispatchKind: hmdClass,
    methodId: target.id,
    methodName: target.name,
    isNative: target.isNative,
    kind: mkInstance,
    ownerType: owner.typ,
    receiver: receiver,
    arguments: analyzeMethodArguments(
      expr,
      target,
      locals,
      functions,
      classes
    ),
    result: target.result
  )

## Resolves a method call used as a value and rejects zero-result methods.
proc analyzeValueMethodCall(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
): hirExpressions.HirExpr =
  let call = analyzeMethodCall(expr, locals, functions, classes)
  if call.result.kind == frNone:
    failAt(
      expr.span,
      "method '" & call.methodName & "' does not return a value"
    )

  HirExpr(
    kind: hekMethodCall,
    span: expr.span,
    typ: call.result.typ,
    methodCall: call
  )
