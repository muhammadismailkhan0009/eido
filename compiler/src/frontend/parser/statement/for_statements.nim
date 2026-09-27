## Parses classic declaration-condition-update for loops.
## Example: `for (var i = 0; i < 10; set i = i + 1) { ... }`.

## Parses the explicit set update clause without a trailing semicolon.
## Example: `set i = i + 1` becomes an assignment AST statement.
proc parseForUpdate(parser: var Parser): Stmt =
  let start = parser.consume(
    tkSet,
    "expected 'set' in for update"
  )
  let target = parser.consume(
    tkIdentifier,
    "expected set target in for update"
  )
  discard parser.consume(
    tkEqual,
    "expected '=' after for update target"
  )
  let value = parser.parseExpression()

  Stmt(
    kind: skAssign,
    span: coverSpan(start.span, value.span),
    target: Expr(
      kind: ekIdentifier,
      span: target.span,
      name: target.lexeme
    ),
    assignedValue: value
  )

## Parses one classic for loop.
## Example: initializer runs once, condition gates each iteration, and update runs after each normal iteration.
proc parseForStmt*(parser: var Parser): Stmt =
  let start = parser.consume(tkFor, "expected 'for'")
  discard parser.consume(tkLParen, "expected '(' after 'for'")

  if not parser.check(tkVar):
    failAt(
      parser.peek.span,
      "expected variable declaration as for initializer"
    )
  let initializer = parser.parseVarStmt()

  let condition = parser.parseExpression()
  discard parser.consume(
    tkSemicolon,
    "expected ';' after for condition"
  )

  let update = parser.parseForUpdate()
  discard parser.consume(tkRParen, "expected ')' after for update")

  let loopBody = parser.parseBracedStatementBlock("for body")

  Stmt(
    kind: skFor,
    span: coverSpan(start.span, loopBody.closeBrace.span),
    forInitializer: initializer,
    forCondition: condition,
    forUpdate: update,
    forBody: loopBody.body
  )
