## Dispatches primary expressions after literal, call, and grouping helpers are available.
## Example: `salary`, `add(1, 2)`, and `[a + b]` are selected here.

## Parses identifiers, calls, literals, and all three mathematical grouping forms.
## Example: `5`, `salary`, `add(1, 2)`, and `{a + b}` start here.
proc parsePrimary(parser: var Parser): Expr =
  let literal = parser.parseLiteral()
  if not literal.isNil:
    return literal

  if parser.check(tkIdentifier):
    let token = parser.advance()
    if parser.check(tkLParen):
      return parser.parseCall(token)
    return Expr(
      kind: ekIdentifier,
      span: token.span,
      name: token.lexeme
    )

  if parser.check(tkLParen):
    discard parser.advance()
    return parser.parseGrouped(tkRParen, ")")

  if parser.check(tkLBracket):
    discard parser.advance()
    return parser.parseGrouped(tkRBracket, "]")

  if parser.check(tkLBrace):
    discard parser.advance()
    return parser.parseGrouped(tkRBrace, "}")

  failAt(
    parser.peek.span,
    "expected primitive literal, identifier, call, or grouped expression"
  )
