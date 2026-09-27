## Parses conditional control-flow statements.
## Example: `if (ready) { return 1; } else { return 0; }` becomes one conditional AST node.

## Parses an `if` statement with optional `else if` chaining and final `else`.
## Example: `if (a) { return 1; } else if (b) { return 2; } else { return 0; }`.
proc parseIfStmt*(parser: var Parser): Stmt =
  let start = parser.consume(tkIf, "expected 'if'")
  discard parser.consume(tkLParen, "expected '(' after 'if'")
  let condition = parser.parseExpression()
  discard parser.consume(tkRParen, "expected ')' after if condition")
  let thenPart =
    parser.parseBracedStatementBlock("conditional branch")

  var elseBody: seq[Stmt]
  var endSpan = thenPart.closeBrace.span

  if parser.check(tkElse):
    discard parser.advance()

    if parser.check(tkIf):
      let elseIf = parser.parseIfStmt()
      elseBody = @[elseIf]
      endSpan = elseIf.span
    else:
      let elsePart =
        parser.parseBracedStatementBlock("conditional branch")
      elseBody = elsePart.body
      endSpan = elsePart.closeBrace.span

  Stmt(
    kind: skIf,
    span: coverSpan(start.span, endSpan),
    condition: condition,
    thenBranch: thenPart.body,
    elseBranch: elseBody
  )
