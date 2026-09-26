## Resolves function-call expressions and their argument/result contracts.
## Example: `mix(true, 2.5)` resolves a FunctionId and checks both arguments.

## Resolves one AST call and all of its arguments.
## Example: arguments are analyzed against the target function's parameter types.
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

## Resolves a call used as a value and rejects zero-result functions.
## Example: `value()` becomes an HIR expression, while `ping()` cannot initialize a value.
proc analyzeValueCall(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols
): hirExpressions.HirExpr =
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
