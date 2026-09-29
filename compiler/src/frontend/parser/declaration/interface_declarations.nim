## Parses bodyless interface contracts.
## Interface methods may declare require/ensure sections but never executable statements.

## Parses one interface method signature with optional behavioral contracts.
proc parseInterfaceMethod(parser: var Parser): FunctionDecl =
  let start = parser.consume(tkFunction, "expected 'function'")
  let name = parser.consume(tkIdentifier, "expected interface method name")
  discard parser.consume(tkLParen, "expected '(' after interface method name")
  let parameters = parser.parseParameters()
  discard parser.consume(tkRParen, "expected ')' after interface method parameters")
  let functionResult = parser.parseFunctionResult()

  if parser.check(tkSemicolon):
    let semicolon = parser.advance()
    return FunctionDecl(
      span: coverSpan(start.span, semicolon.span),
      name: name.lexeme,
      isNative: false,
      parameters: parameters,
      result: functionResult,
      body: @[]
    )

  discard parser.consume(
    tkLBrace,
    "expected ';' or contract block after interface method declaration"
  )

  var requires: seq[Expr]
  if parser.check(tkRequire):
    requires = parser.parseContractClauses(tkRequire, "require")

  var ensures: seq[Expr]
  if parser.check(tkEnsure):
    ensures = parser.parseContractClauses(tkEnsure, "ensure")

  if requires.len == 0 and ensures.len == 0:
    failAt(
      parser.peek.span,
      "interface method contract block must declare 'require' or 'ensure'"
    )

  if not parser.check(tkRBrace):
    failAt(
      parser.peek.span,
      "interface method contract block may contain only 'require' and 'ensure' sections"
    )

  let closeBrace = parser.consume(
    tkRBrace,
    "expected '}' after interface method contract"
  )

  FunctionDecl(
    span: coverSpan(start.span, closeBrace.span),
    name: name.lexeme,
    isNative: false,
    parameters: parameters,
    result: functionResult,
    requires: requires,
    ensures: ensures,
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
