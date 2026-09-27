## Parses bodyless top-level native function declarations supplied by backend support.
## Example: `native function platformArgument(Int index) returns String;`.

## Parses one native function signature terminated by a semicolon.
## Example: native functions reuse ordinary parameter/result grammar but never contain an Eido body.
proc parseNativeFunction*(parser: var Parser): FunctionDecl =
  let start = parser.consume(tkNative, "expected 'native'")
  discard parser.consume(tkFunction, "expected 'function' after 'native'")
  let name = parser.consume(tkIdentifier, "expected native function name")
  discard parser.consume(tkLParen, "expected '(' after native function name")
  let parameters = parser.parseParameters()
  discard parser.consume(tkRParen, "expected ')' after native function parameters")
  let functionResult = parser.parseFunctionResult()
  let semicolon =
    parser.consume(tkSemicolon, "expected ';' after native function declaration")

  FunctionDecl(
    span: coverSpan(start.span, semicolon.span),
    name: name.lexeme,
    isNative: true,
    parameters: parameters,
    result: functionResult,
    body: @[]
  )
