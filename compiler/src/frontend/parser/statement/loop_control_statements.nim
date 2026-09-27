## Parses loop-control statements.
## Example: `break;` exits the nearest loop and `continue;` starts its next iteration.

## Parses one semicolon-terminated break statement.
## Example: `break;` becomes `skBreak`; loop-context legality is checked semantically.
proc parseBreakStmt*(parser: var Parser): Stmt =
  let start = parser.consume(tkBreak, "expected 'break'")
  let semicolon = parser.consume(tkSemicolon, "expected ';' after break")

  Stmt(
    kind: skBreak,
    span: coverSpan(start.span, semicolon.span)
  )

## Parses one semicolon-terminated continue statement.
## Example: `continue;` becomes `skContinue`; loop-context legality is checked semantically.
proc parseContinueStmt*(parser: var Parser): Stmt =
  let start = parser.consume(tkContinue, "expected 'continue'")
  let semicolon =
    parser.consume(tkSemicolon, "expected ';' after continue")

  Stmt(
    kind: skContinue,
    span: coverSpan(start.span, semicolon.span)
  )
