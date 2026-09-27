## Parses named class construction expressions.
## Example: `Point { x = 10; y = 20; }` becomes one construction AST node.

## Parses a construction expression after the type-name identifier was consumed.
proc parseConstruction(
  parser: var Parser,
  typeToken: Token
): Expr =
  discard parser.consume(tkLBrace, "expected '{' after class name")

  var fields: seq[ConstructionField]
  while not parser.check(tkRBrace):
    if parser.check(tkEof):
      failAt(parser.peek.span, "expected '}' after construction")

    let name = parser.consume(
      tkIdentifier,
      "expected field name in construction"
    )
    discard parser.consume(
      tkEqual,
      "expected '=' after construction field name"
    )
    let value = parser.parseExpression()
    let semicolon = parser.consume(
      tkSemicolon,
      "expected ';' after construction field initializer"
    )

    fields.add ConstructionField(
      span: coverSpan(name.span, semicolon.span),
      name: name.lexeme,
      value: value
    )

  let closeBrace =
    parser.consume(tkRBrace, "expected '}' after construction")

  Expr(
    kind: ekConstruct,
    span: coverSpan(typeToken.span, closeBrace.span),
    typeName: typeToken.lexeme,
    fields: fields
  )
