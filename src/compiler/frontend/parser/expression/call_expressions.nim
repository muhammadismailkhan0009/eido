## Parses function-call primary expressions.
## Example: `add(10, 20)` becomes a call expression with two arguments.

## Parses a function-call expression after its name.
## Example: `add(10, 20)` becomes a call with callee `add` and two arguments.
proc parseCall(parser: var Parser, name: Token): Expr =
  discard parser.consume(tkLParen, "expected '(' after function name")
  var arguments: seq[Expr]

  if not parser.check(tkRParen):
    while true:
      arguments.add parser.parseExpression()
      if not parser.check(tkComma):
        break
      discard parser.advance()

  let closeParen = parser.consume(tkRParen, "expected ')' after arguments")
  Expr(
    kind: ekCall,
    span: SourceSpan(
      startOffset: name.span.startOffset,
      endOffset: closeParen.span.endOffset,
      line: name.span.line,
      column: name.span.column
    ),
    callee: name.lexeme,
    arguments: arguments
  )
