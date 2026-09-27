## Resolves instance method calls from the nominal receiver class.

## Resolves one instance method call and checks its arguments.
proc analyzeMethodCall*(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: ClassSymbols
): hirExpressions.HirMethodCall =
  if expr.kind != astExpressions.ekMethodCall:
    failAt(expr.span, "expected instance method call")

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
  if expr.methodArguments.len != target.parameterTypes.len:
    failAt(
      expr.span,
      "method '" & expr.methodName & "' expects " &
        $target.parameterTypes.len & " arguments but got " &
        $expr.methodArguments.len
    )

  var arguments: seq[HirExpr]
  for index, argument in expr.methodArguments:
    arguments.add analyzeExprExpected(
      argument,
      target.parameterTypes[index],
      locals,
      functions,
      classes
    )

  HirMethodCall(
    span: expr.span,
    methodId: target.id,
    methodName: target.name,
    ownerType: owner.typ,
    receiver: receiver,
    arguments: arguments,
    result: target.result
  )

## Resolves a method call used as a value and rejects zero-result methods.
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
