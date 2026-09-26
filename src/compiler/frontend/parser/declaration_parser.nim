## Parses primitive-typed parameters and functions with zero or one result. Example: `function notify(Int id) {}` has one input and no result.

import ../../source/span
import ../../diagnostics/errors
import ../lexer/token
import ../ast/declarations
import ../ast/statements
import core
import statement_parser

## Parses source-level primitive type syntax. Example: parameter type `Float` becomes a `TypeRef` whose name is `Float`.
proc parseTypeRef(parser: var Parser): TypeRef =
  let typeToken = parser.consume(tkPrimitiveType, "expected primitive type")
  TypeRef(span: typeToken.span, name: typeToken.lexeme)

## Parses comma-separated Java-style typed parameters with no fixed count. Example: `Int a, Bool b, Float c` becomes three parameter AST nodes.
proc parseParameters(parser: var Parser): seq[Parameter] =
  if parser.check(tkRParen):
    return

  while true:
    let typeRef = parser.parseTypeRef()
    let nameToken = parser.consume(tkIdentifier, "expected parameter name")
    result.add Parameter(
      span: SourceSpan(
        startOffset: typeRef.span.startOffset,
        endOffset: nameToken.span.endOffset,
        line: typeRef.span.line,
        column: typeRef.span.column
      ),
      name: nameToken.lexeme,
      typeRef: typeRef
    )

    if not parser.check(tkComma):
      break
    discard parser.advance()

## Parses an optional single function result. Example: omitted `returns` means no result; `returns Bool` stores one Bool result type.
proc parseFunctionResult(parser: var Parser): FunctionResultRef =
  if not parser.check(tkReturns):
    return FunctionResultRef(kind: frrNone)

  discard parser.advance()
  FunctionResultRef(
    kind: frrSingle,
    typeRef: parser.parseTypeRef()
  )

## Parses one complete function declaration. Example: `function add(Int a, Int b) returns Int { return a + b; }` becomes a `FunctionDecl`.
proc parseFunction*(parser: var Parser): FunctionDecl =
  let start = parser.consume(tkFunction, "expected 'function'")
  let name = parser.consume(tkIdentifier, "expected function name")
  discard parser.consume(tkLParen, "expected '(' after function name")
  let parameters = parser.parseParameters()
  discard parser.consume(tkRParen, "expected ')' after function parameters")
  let functionResult = parser.parseFunctionResult()
  discard parser.consume(tkLBrace, "expected '{' before function body")

  var body: seq[Stmt]
  while not parser.check(tkRBrace) and not parser.check(tkReturn):
    if parser.check(tkVar):
      body.add parser.parseVarStmt()
    elif parser.check(tkIdentifier) and parser.checkNext(tkEqual):
      body.add parser.parseAssignStmt()
    elif parser.check(tkIdentifier) and parser.checkNext(tkLParen):
      body.add parser.parseCallStmt()
    else:
      failAt(
        parser.peek.span,
        "expected variable declaration, assignment, function call, return, or '}'"
      )

  if parser.check(tkReturn):
    body.add parser.parseReturnStmt()

  let closeBrace = parser.consume(tkRBrace, "expected '}' after function body")

  FunctionDecl(
    span: SourceSpan(
      startOffset: start.span.startOffset,
      endOffset: closeBrace.span.endOffset,
      line: start.span.line,
      column: start.span.column
    ),
    name: name.lexeme,
    parameters: parameters,
    result: functionResult,
    body: body
  )
