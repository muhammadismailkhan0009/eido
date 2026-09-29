## Parses statement forms such as declarations, assignments, calls, and returns. Example: `notify(10);` becomes an `skCall` statement.

import ../../source/span
import ../../diagnostics/errors
import ../lexer/token
import ../ast/statements
import ../ast/expressions
import core
import expression_parser

## Parses one statement using the owning statement-family parser.
## Example: declarations, assignments, calls, returns, and conditionals dispatch here.
proc parseStatement*(parser: var Parser): Stmt

## Parses a `var` declaration statement. Example: `var salary = 5000;` becomes `skVar` with initializer `5000`.
proc parseVarStmt*(parser: var Parser): Stmt =
  let start = parser.consume(tkVar, "expected 'var'")
  let name = parser.consume(tkIdentifier, "expected variable name")
  discard parser.consume(tkEqual, "expected '=' after variable name")
  let initializer = parser.parseExpression()
  let semicolon = parser.consume(
    tkSemicolon,
    "expected ';' after variable declaration"
  )

  Stmt(
    kind: skVar,
    span: coverSpan(start.span, semicolon.span),
    name: name.lexeme,
    initializer: initializer
  )

## Parses the restricted mutation target forms supported by `set`.
## Example: `value` is a local target while `self.balance` is an own-field target.
proc parseSetTarget(parser: var Parser): Expr =
  if parser.check(tkIdentifier):
    let target = parser.advance()
    return Expr(
      kind: ekIdentifier,
      span: target.span,
      name: target.lexeme
    )

  if parser.check(tkSelf):
    let receiver = parser.advance()
    discard parser.consume(tkDot, "expected '.' after 'self' in set target")
    let field = parser.consume(tkIdentifier, "expected field name after 'self.'")
    let selfExpr = Expr(
      kind: ekIdentifier,
      span: receiver.span,
      name: receiver.lexeme
    )
    return Expr(
      kind: ekFieldAccess,
      span: coverSpan(receiver.span, field.span),
      target: selfExpr,
      fieldName: field.lexeme
    )

  failAt(parser.peek.span, "expected local name or 'self.<field>' after 'set'")

## Parses explicit mutation of an existing binding or own-class field.
## Example: `set salary = 6000;` and `set self.balance = 0;`.
proc parseSetStmt*(parser: var Parser): Stmt =
  let start = parser.consume(tkSet, "expected 'set'")
  let target = parser.parseSetTarget()
  discard parser.consume(tkEqual, "expected '=' after set target")
  let value = parser.parseExpression()
  let semicolon = parser.consume(
    tkSemicolon,
    "expected ';' after set statement"
  )

  Stmt(
    kind: skAssign,
    span: coverSpan(start.span, semicolon.span),
    target: target,
    assignedValue: value
  )

## Parses a standalone function call statement. Example: `notify(10);` becomes `skCall` and may later discard a returned value.
proc parseCallStmt*(parser: var Parser): Stmt =
  let call = parser.parseExpression()
  if call.kind notin {ekCall, ekMethodCall}:
    failAt(call.span, "only a function or method call may be used as an expression statement")

  let semicolon = parser.consume(
    tkSemicolon,
    "expected ';' after function call"
  )

  Stmt(
    kind: skCall,
    span: coverSpan(call.span, semicolon.span),
    call: call
  )

## Parses a return statement with zero or one value. Example: `return;` has no value while `return total;` stores `total`.
proc parseReturnStmt*(parser: var Parser): Stmt =
  let start = parser.consume(tkReturn, "expected 'return'")
  var value: Expr = nil
  if not parser.check(tkSemicolon):
    value = parser.parseExpression()

  let semicolon = parser.consume(
    tkSemicolon,
    "expected ';' after return"
  )

  Stmt(
    kind: skReturn,
    span: coverSpan(start.span, semicolon.span),
    value: value
  )

include statement/braced_blocks
include statement/conditional_statements
include statement/while_statements
include statement/for_statements
include statement/loop_control_statements

## Parses one statement by dispatching to its semantic statement family.
## Example: `if (ready) { return; }` and `while (ready) { ... }` delegate to focused parsers.
proc parseStatement*(parser: var Parser): Stmt =
  if parser.check(tkVar):
    return parser.parseVarStmt()

  if parser.check(tkReturn):
    return parser.parseReturnStmt()

  if parser.check(tkIf):
    return parser.parseIfStmt()

  if parser.check(tkWhile):
    return parser.parseWhileStmt()

  if parser.check(tkFor):
    return parser.parseForStmt()

  if parser.check(tkBreak):
    return parser.parseBreakStmt()

  if parser.check(tkContinue):
    return parser.parseContinueStmt()

  if parser.check(tkSet):
    return parser.parseSetStmt()

  if parser.check(tkSelf) and parser.checkNext(tkDot):
    return parser.parseCallStmt()

  if parser.check(tkIdentifier) and
      (
        parser.checkNext(tkLParen) or
        parser.checkNext(tkDot) or
        parser.checkNext(tkLess)
      ):
    return parser.parseCallStmt()

  failAt(
    parser.peek.span,
    "expected variable declaration, set statement, function call, return, if, while, for, break, continue, or '}'"
  )
