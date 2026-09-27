## Parses postfix member access and instance method-call chains.
## Example: `employee.address.zip` and `account.remaining(20)` are left-associated postfix expressions.

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
        span: SourceSpan(
          startOffset: result.span.startOffset,
          endOffset: parsed.closeParen.span.endOffset,
          line: result.span.line,
          column: result.span.column
        ),
        receiver: result,
        methodName: member.lexeme,
        methodArguments: parsed.arguments
      )
    else:
      result = Expr(
        kind: ekFieldAccess,
        span: SourceSpan(
          startOffset: result.span.startOffset,
          endOffset: member.span.endOffset,
          line: result.span.line,
          column: result.span.column
        ),
        target: result,
        fieldName: member.lexeme
      )
