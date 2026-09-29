## Parses built-in- or nominal-class-typed parameters and functions with zero or one result. Example: `function greet(String name) returns String { return name; }` uses the built-in String type.

import ../../source/span
import ../../diagnostics/errors
import ../lexer/token
import ../ast/declarations
import ../ast/expressions
import ../ast/type_references as astTypeRefs
import ../ast/statements
import core
import type_references as typeRefParser
import statement_parser
import expression_parser

include declaration/contracts

## Parses a field type using the shared declared-type grammar.
proc parseFieldTypeRef(parser: var Parser): astTypeRefs.TypeRef =
  typeRefParser.parseDeclaredTypeRef(parser)

## Parses comma-separated Java-style typed parameters with no fixed count. Example: `Int a, Bool b, Float c` becomes three parameter AST nodes.
proc parseParameters(parser: var Parser): seq[Parameter] =
  if parser.check(tkRParen):
    return

  while true:
    let typeRef = typeRefParser.parseDeclaredTypeRef(parser)
    let nameToken = parser.consume(tkIdentifier, "expected parameter name")
    result.add Parameter(
      span: coverSpan(typeRef.span, nameToken.span),
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
    typeRef: typeRefParser.parseDeclaredTypeRef(parser)
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

  var requires: seq[Expr]
  if parser.check(tkRequire):
    requires = parser.parseContractClauses(tkRequire, "require")

  var body: seq[Stmt]
  while not parser.check(tkRBrace) and not parser.check(tkEnsure):
    body.add parser.parseStatement()

    # A direct return may be followed only by the final ensure section or closing brace.
    if body[^1].kind == skReturn and
        not parser.check(tkRBrace) and
        not parser.check(tkEnsure):
      failAt(parser.peek.span, "expected 'ensure' or '}' after return")

  var ensures: seq[Expr]
  if parser.check(tkEnsure):
    ensures = parser.parseContractClauses(tkEnsure, "ensure")

  let closeBrace = parser.consume(tkRBrace, "expected '}' after function body")

  FunctionDecl(
    span: coverSpan(start.span, closeBrace.span),
    name: name.lexeme,
    isNative: false,
    parameters: parameters,
    result: functionResult,
    requires: requires,
    ensures: ensures,
    body: body
  )

include declaration/native_function_declarations
include declaration/interface_declarations
include declaration/class_declarations
