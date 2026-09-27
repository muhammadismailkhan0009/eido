## Resolves class-qualified inferred-static calls and value-qualified instance calls.

## Analyzes arguments against one resolved class method signature.
## Example: Calculator.add(1, 2) checks both values against the add parameter types.
proc analyzeMethodArguments(
  expr: astExpressions.Expr,
  target: MethodSymbol,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols
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

## Resolves a class-qualified call to an inferred static method.
## Example: Calculator.add(1, 2) resolves without creating or passing a Calculator receiver.
proc analyzeStaticMethodCall(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols
): hirExpressions.HirMethodCall =
  let owner = classes.get(expr.receiver.name)
  if not owner.containsMethod(expr.methodName):
    failAt(
      expr.span,
      "class '" & owner.name & "' has no method '" &
        expr.methodName & "'"
    )

  let target = owner.getMethod(expr.methodName)
  if target.kind != mkStatic:
    failAt(
      expr.span,
      "instance method '" & owner.name & "." & target.name &
        "' requires an instance receiver of type " & owner.name
    )

  HirMethodCall(
    span: expr.span,
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

## Resolves one class member call and enforces inferred static/instance call form.
## Example: Calculator.add(...) is static while account.balance() requires an account receiver.
proc analyzeMethodCall*(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols
): hirExpressions.HirMethodCall =
  if expr.kind != astExpressions.ekMethodCall:
    failAt(expr.span, "expected class method call")

  if expr.receiver.kind == astExpressions.ekIdentifier and
      not locals.contains(expr.receiver.name) and
      classes.contains(expr.receiver.name):
    return analyzeStaticMethodCall(
      expr,
      locals,
      functions,
      classes
    )

  let receiver = analyzeExpr(expr.receiver, locals, functions, classes)
  if receiver.typ.kind != etkClass:
    failAt(
      expr.span,
      "method call requires a class receiver but got " &
        receiver.typ.displayName
    )

  if not classes.contains(receiver.typ.className):
    failAt(expr.span, "unknown class type '" & receiver.typ.className & "'")

  let owner = classes.get(receiver.typ.className)
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
## Example: Calculator.add(...) may initialize Int while Logger.flush() cannot initialize a value.
proc analyzeValueMethodCall(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols
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
