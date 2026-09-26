## Parses while-loop statements.
## Example: `while (count < 10) { count = count + 1; }`.

## Parses a parenthesized while condition and braced loop body.
## Example: the body may contain declarations, assignments, calls, returns, conditionals, or nested loops.
proc parseWhileStmt*(parser: var Parser): Stmt =
  let start = parser.consume(tkWhile, "expected 'while'")
  discard parser.consume(tkLParen, "expected '(' after 'while'")
  let condition = parser.parseExpression()
  discard parser.consume(tkRParen, "expected ')' after while condition")
  let loopBody = parser.parseBracedStatementBlock("while body")

  Stmt(
    kind: skWhile,
    span: SourceSpan(
      startOffset: start.span.startOffset,
      endOffset: loopBody.closeBrace.span.endOffset,
      line: start.span.line,
      column: start.span.column
    ),
    whileCondition: condition,
    body: loopBody.body
  )
