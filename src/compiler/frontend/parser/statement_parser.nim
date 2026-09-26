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
    span: SourceSpan(
      startOffset: start.span.startOffset,
      endOffset: semicolon.span.endOffset,
      line: start.span.line,
      column: start.span.column
    ),
    name: name.lexeme,
    initializer: initializer
  )

## Parses reassignment to an existing primitive local. Example: `salary = 6000;` becomes `skAssign`.
proc parseAssignStmt*(parser: var Parser): Stmt =
  let target = parser.consume(tkIdentifier, "expected assignment target")
  discard parser.consume(tkEqual, "expected '=' after assignment target")
  let value = parser.parseExpression()
  let semicolon = parser.consume(
    tkSemicolon,
    "expected ';' after assignment"
  )

  Stmt(
    kind: skAssign,
    span: SourceSpan(
      startOffset: target.span.startOffset,
      endOffset: semicolon.span.endOffset,
      line: target.span.line,
      column: target.span.column
    ),
    target: target.lexeme,
    assignedValue: value
  )

## Parses a standalone function call statement. Example: `notify(10);` becomes `skCall` and may later discard a returned value.
proc parseCallStmt*(parser: var Parser): Stmt =
  let call = parser.parseExpression()
  if call.kind != ekCall:
    failAt(call.span, "only a function call may be used as an expression statement")

  let semicolon = parser.consume(
    tkSemicolon,
    "expected ';' after function call"
  )

  Stmt(
    kind: skCall,
    span: SourceSpan(
      startOffset: call.span.startOffset,
      endOffset: semicolon.span.endOffset,
      line: call.span.line,
      column: call.span.column
    ),
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
    span: SourceSpan(
      startOffset: start.span.startOffset,
      endOffset: semicolon.span.endOffset,
      line: start.span.line,
      column: start.span.column
    ),
    value: value
  )

include statement/conditional_statements

## Parses one statement by dispatching to its semantic statement family.
## Example: `if ready { return; }` delegates to conditional parsing.
proc parseStatement*(parser: var Parser): Stmt =
  if parser.check(tkVar):
    return parser.parseVarStmt()

  if parser.check(tkReturn):
    return parser.parseReturnStmt()

  if parser.check(tkIf):
    return parser.parseIfStmt()

  if parser.check(tkIdentifier) and parser.checkNext(tkEqual):
    return parser.parseAssignStmt()

  if parser.check(tkIdentifier) and parser.checkNext(tkLParen):
    return parser.parseCallStmt()

  failAt(
    parser.peek.span,
    "expected variable declaration, assignment, function call, return, if, or '}'"
  )
