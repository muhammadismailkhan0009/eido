## Parses postfix member access and class-member call chains.
## Semantic analysis later distinguishes Type.method(...) from value.method(...).

## Extends one primary expression with zero or more `.field` or `.method(...)` operations.
proc parseFieldAccessChain(
  parser: var Parser,
  base: Expr
): Expr =
  result = base

  while parser.check(tkDot):
    discard parser.advance()
    let member = parser.consume(
      tkIdentifier,
      "expected member name after '.'"
    )

    if parser.check(tkLParen):
      let parsed = parser.parseCallArguments()
      result = Expr(
        kind: ekMethodCall,
        span: coverSpan(result.span, parsed.closeParen.span),
        receiver: result,
        methodName: member.lexeme,
        methodArguments: parsed.arguments
      )
    else:
      result = Expr(
        kind: ekFieldAccess,
        span: coverSpan(result.span, member.span),
        target: result,
        fieldName: member.lexeme
      )
