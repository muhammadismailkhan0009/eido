## Parses braced statement blocks shared by structured control-flow statements.
## Example: conditional and while bodies both reuse this block parser.

## Parses statements between braces and returns the closing brace token.
## Example: owner "while body" produces diagnostics specific to that block.
proc parseBracedStatementBlock(
  parser: var Parser,
  owner: string
): tuple[body: seq[Stmt], closeBrace: Token] =
  discard parser.consume(tkLBrace, "expected '{' before " & owner)

  while not parser.check(tkRBrace):
    if parser.check(tkEof):
      failAt(parser.peek.span, "expected '}' after " & owner)

    result.body.add parser.parseStatement()

    # Preserve the language's rule that a direct return ends its current block.
    if result.body[^1].kind == skReturn and not parser.check(tkRBrace):
      failAt(parser.peek.span, "expected '}' after return")

  result.closeBrace = parser.consume(tkRBrace, "expected '}' after " & owner)
