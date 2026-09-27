## Parses conditional control-flow statements.
## Example: ordinary if uses a Bool condition, while exists proves one optional path.

## Parses a stable optional path used by `if <path> exists`.
## Example: `employee.address` becomes a field-access chain without allowing calls.
proc parseExistsTarget(parser: var Parser): Expr =
  var current: Expr
  if parser.check(tkIdentifier):
    let token = parser.advance()
    current = Expr(kind: ekIdentifier, span: token.span, name: token.lexeme)
  elif parser.check(tkSelf):
    let token = parser.advance()
    current = Expr(kind: ekIdentifier, span: token.span, name: token.lexeme)
  else:
    failAt(parser.peek.span, "expected optional local or field path after 'if'")

  while parser.check(tkDot):
    discard parser.advance()
    let field = parser.consume(
      tkIdentifier,
      "expected field name in exists path"
    )
    current = Expr(
      kind: ekFieldAccess,
      span: coverSpan(current.span, field.span),
      target: current,
      fieldName: field.lexeme
    )

  current

## Parses the dedicated lexical optional proof form.
## Example: `if user exists { ... }` proves user present only for that body.
proc parseExistsStmt(parser: var Parser, start: Token): Stmt =
  let target = parser.parseExistsTarget()
  discard parser.consume(tkExists, "expected 'exists' after optional path")
  let body = parser.parseBracedStatementBlock("exists proof block")

  Stmt(
    kind: skExists,
    span: coverSpan(start.span, body.closeBrace.span),
    existsTarget: target,
    existsBody: body.body
  )

## Parses an `if` statement with optional `else if` chaining and final `else`.
## Example: `if (a) { return 1; } else if (b) { return 2; } else { return 0; }`.
proc parseIfStmt*(parser: var Parser): Stmt =
  let start = parser.consume(tkIf, "expected 'if'")

  if not parser.check(tkLParen):
    return parser.parseExistsStmt(start)

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
