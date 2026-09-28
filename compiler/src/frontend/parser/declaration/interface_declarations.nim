## Parses bodyless interface contracts.
## Interface methods are instance behavioral signatures and never contain bodies.

## Parses one semicolon-terminated interface method signature.
proc parseInterfaceMethod(parser: var Parser): FunctionDecl =
  let start = parser.consume(tkFunction, "expected 'function'")
  let name = parser.consume(tkIdentifier, "expected interface method name")
  discard parser.consume(tkLParen, "expected '(' after interface method name")
  let parameters = parser.parseParameters()
  discard parser.consume(tkRParen, "expected ')' after interface method parameters")
  let functionResult = parser.parseFunctionResult()
  let semicolon = parser.consume(
    tkSemicolon,
    "expected ';' after interface method declaration"
  )

  FunctionDecl(
    span: coverSpan(start.span, semicolon.span),
    name: name.lexeme,
    isNative: false,
    parameters: parameters,
    result: functionResult,
    body: @[]
  )

## Parses one non-generic interface with optional single-interface extension.
proc parseInterface*(parser: var Parser): InterfaceDecl =
  let start = parser.consume(tkInterface, "expected 'interface'")
  let name = parser.consume(tkIdentifier, "expected interface name")

  var parents: seq[string]
  if parser.check(tkExtends):
    discard parser.advance()
    let parent = parser.consume(
      tkIdentifier,
      "expected parent interface name after 'extends'"
    )
    parents.add parent.lexeme
    if parser.check(tkComma):
      failAt(
        parser.peek.span,
        "multiple interface extension is not part of v0; extend one interface"
      )

  discard parser.consume(tkLBrace, "expected '{' before interface body")

  var methods: seq[FunctionDecl]
  while not parser.check(tkRBrace):
    if parser.check(tkEof):
      failAt(parser.peek.span, "expected '}' after interface body")
    if not parser.check(tkFunction):
      failAt(
        parser.peek.span,
        "interface body may contain only function signatures"
      )
    methods.add parser.parseInterfaceMethod()

  let closeBrace = parser.consume(tkRBrace, "expected '}' after interface body")
  InterfaceDecl(
    span: coverSpan(start.span, closeBrace.span),
    name: name.lexeme,
    extends: parents,
    methods: methods
  )
