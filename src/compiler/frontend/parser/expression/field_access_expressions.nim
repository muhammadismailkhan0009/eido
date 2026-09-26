## Parses postfix field-access chains.
## Example: `employee.address.zip` becomes nested left-associated field-access nodes.

## Extends one primary expression with zero or more `.field` accesses.
proc parseFieldAccessChain(
  parser: var Parser,
  base: Expr
): Expr =
  result = base

  while parser.check(tkDot):
    discard parser.advance()
    let field = parser.consume(
      tkIdentifier,
      "expected field name after '.'"
    )

    result = Expr(
      kind: ekFieldAccess,
      span: SourceSpan(
        startOffset: result.span.startOffset,
        endOffset: field.span.endOffset,
        line: result.span.line,
        column: result.span.column
      ),
      target: result,
      fieldName: field.lexeme
    )
