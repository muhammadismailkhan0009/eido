## Parses structured Design by Contract sections attached to declarations.
## Contract clauses are unnamed Boolean expressions separated by semicolons.

## Parses one non-empty `{ expression; ... }` contract section after its keyword.
proc parseContractClauses(
  parser: var Parser,
  keyword: TokenKind,
  keywordText: string
): seq[Expr] =
  discard parser.consume(keyword, "expected '" & keywordText & "'")
  discard parser.consume(tkLBrace, "expected '{' after '" & keywordText & "'")

  if parser.check(tkRBrace):
    failAt(parser.peek.span, "'" & keywordText & "' contract cannot be empty")

  while not parser.check(tkRBrace):
    result.add parser.parseExpression()
    discard parser.consume(
      tkSemicolon,
      "expected ';' after '" & keywordText & "' contract clause"
    )

  discard parser.consume(tkRBrace, "expected '}' after '" & keywordText & "' contract")
