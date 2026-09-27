## Parses function-call argument lists and top-level function calls.
## The shared argument helper is also used by postfix instance method calls.

## Parses one parenthesized comma-separated argument list.
proc parseCallArguments(
  parser: var Parser
): tuple[arguments: seq[Expr], closeParen: Token] =
  discard parser.consume(tkLParen, "expected '(' before arguments")

  if not parser.check(tkRParen):
    while true:
      result.arguments.add parser.parseExpression()
      if not parser.check(tkComma):
        break
      discard parser.advance()

  result.closeParen =
    parser.consume(tkRParen, "expected ')' after arguments")

## Parses a top-level function-call expression after its name.
proc parseCall(parser: var Parser, name: Token): Expr =
  let parsed = parser.parseCallArguments()

  Expr(
    kind: ekCall,
    span: coverSpan(name.span, parsed.closeParen.span),
    callee: name.lexeme,
    arguments: parsed.arguments
  )
