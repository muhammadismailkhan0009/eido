## Parses named class construction expressions.
## Example: `Point { x: 10; y: 20; }` becomes one construction AST node.

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
      tkColon,
      "expected ':' after construction field name"
    )
    let value = parser.parseExpression()
    let semicolon = parser.consume(
      tkSemicolon,
      "expected ';' after construction field initializer"
    )

    fields.add ConstructionField(
      span: SourceSpan(
        startOffset: name.span.startOffset,
        endOffset: semicolon.span.endOffset,
        line: name.span.line,
        column: name.span.column
      ),
      name: name.lexeme,
      value: value
    )

  let closeBrace =
    parser.consume(tkRBrace, "expected '}' after construction")

  Expr(
    kind: ekConstruct,
    span: SourceSpan(
      startOffset: typeToken.span.startOffset,
      endOffset: closeBrace.span.endOffset,
      line: typeToken.span.line,
      column: typeToken.span.column
    ),
    typeName: typeToken.lexeme,
    fields: fields
  )
