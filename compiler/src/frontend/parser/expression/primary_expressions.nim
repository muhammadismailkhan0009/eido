## Dispatches primary atoms and then applies postfix field access.
## Example: `employee.address.zip` starts from identifier `employee` and grows through postfix access.

## Parses a complete primary expression including postfix access.
proc parsePrimary(parser: var Parser): Expr

## Parses one primary atom before postfix operators are applied.
proc parsePrimaryAtom(parser: var Parser): Expr =
  let literal = parser.parseLiteral()
  if not literal.isNil:
    return literal

  if parser.check(tkCopy) or parser.check(tkRef):
    let relation = parser.advance()
    let value = parser.parsePrimary()
    return Expr(
      kind: ekClassRelation,
      span: coverSpan(relation.span, value.span),
      relationKind: if relation.kind == tkCopy: cvrCopy else: cvrRef,
      relatedValue: value
    )

  if parser.check(tkSelf):
    let token = parser.advance()
    return Expr(
      kind: ekIdentifier,
      span: token.span,
      name: token.lexeme
    )

  if parser.check(tkIdentifier):
    let token = parser.advance()
    if parser.check(tkLParen):
      return parser.parseCall(token)
    if parser.check(tkLBrace):
      return parser.parseConstruction(token)
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
    "expected literal, identifier, call, construction, or grouped expression"
  )

## Parses a complete primary expression including chained field access.
proc parsePrimary(parser: var Parser): Expr =
  parser.parseFieldAccessChain(parser.parsePrimaryAtom())
