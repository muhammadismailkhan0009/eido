## Parses named compile-time layout declarations. Layout execution/selection is
## deliberately deferred, so bodies are retained as ordinary Eido statement AST.

proc parseLayout*(parser: var Parser): LayoutDecl =
  let start = parser.consume(tkLayout, "expected 'layout'")
  let name = parser.consume(tkIdentifier, "expected layout name")

  var typeParameters: seq[astTypeRefs.TypeParameterDecl]
  if parser.check(tkLess):
    discard parser.advance()
    if parser.check(tkGreater):
      failAt(parser.peek.span, "generic layout parameters cannot be empty")

    while true:
      let parameter = parser.consume(
        tkIdentifier, "expected layout type parameter"
      )
      typeParameters.add astTypeRefs.TypeParameterDecl(
        span: parameter.span, name: parameter.lexeme
      )
      if not parser.check(tkComma):
        break
      discard parser.advance()
    discard parser.consume(tkGreater, "expected '>' after layout parameters")

  discard parser.consume(tkFor, "expected 'for' after layout name")
  let target = parser.parseDeclaredTypeRef()
  if target.isOptional:
    failAt(target.span, "layout target cannot be optional")
  discard parser.consume(tkLBrace, "expected '{' before layout body")

  let bodyStart = parser.position()
  var body: seq[Stmt]
  while not parser.check(tkRBrace):
    if parser.check(tkEof):
      failAt(parser.peek.span, "expected '}' after layout body")
    body.add parser.parseStatement()
    if body[^1].kind == skReturn and not parser.check(tkRBrace):
      failAt(parser.peek.span, "expected '}' after layout return")

  let ending = parser.consume(tkRBrace, "expected '}' after layout body")
  if body.len == 0 or body[^1].kind != skReturn or body[^1].value.isNil:
    failAt(ending.span, "layout body must end with 'return <shape>;'")

  LayoutDecl(
    span: coverSpan(start.span, ending.span),
    name: name.lexeme,
    typeParameters: typeParameters,
    targetType: target,
    body: body,
    bodySource: parser.tokenSource(bodyStart, parser.position() - 1)
  )
