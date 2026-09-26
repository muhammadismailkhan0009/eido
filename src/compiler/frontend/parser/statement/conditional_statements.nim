## Parses conditional control-flow statements.
## Example: `if (ready) { return 1; } else { return 0; }` becomes one conditional AST node.

## Parses one braced conditional branch using the normal statement dispatcher.
## Example: the body after `if (condition) {` is parsed until its matching `}`.
proc parseConditionalBranch(parser: var Parser): tuple[body: seq[Stmt], closeBrace: Token] =
  discard parser.consume(tkLBrace, "expected '{' before conditional branch")

  while not parser.check(tkRBrace):
    if parser.check(tkEof):
      failAt(parser.peek.span, "expected '}' after conditional branch")

    result.body.add parser.parseStatement()

    # Preserve the language's existing rule that a direct return ends its block.
    if result.body[^1].kind == skReturn and not parser.check(tkRBrace):
      failAt(parser.peek.span, "expected '}' after return")

  result.closeBrace =
    parser.consume(tkRBrace, "expected '}' after conditional branch")

## Parses an `if` statement with optional `else if` chaining and final `else`.
## Example: `if (a) { return 1; } else if (b) { return 2; } else { return 0; }`.
proc parseIfStmt*(parser: var Parser): Stmt =
  let start = parser.consume(tkIf, "expected 'if'")
  discard parser.consume(tkLParen, "expected '(' after 'if'")
  let condition = parser.parseExpression()
  discard parser.consume(tkRParen, "expected ')' after if condition")
  let thenPart = parser.parseConditionalBranch()

  var elseBody: seq[Stmt]
  var endSpan = thenPart.closeBrace.span

  if parser.check(tkElse):
    discard parser.advance()

    if parser.check(tkIf):
      let elseIf = parser.parseIfStmt()
      elseBody = @[elseIf]
      endSpan = elseIf.span
    else:
      let elsePart = parser.parseConditionalBranch()
      elseBody = elsePart.body
      endSpan = elsePart.closeBrace.span

  Stmt(
    kind: skIf,
    span: SourceSpan(
      startOffset: start.span.startOffset,
      endOffset: endSpan.endOffset,
      line: start.span.line,
      column: start.span.column
    ),
    condition: condition,
    thenBranch: thenPart.body,
    elseBranch: elseBody
  )
