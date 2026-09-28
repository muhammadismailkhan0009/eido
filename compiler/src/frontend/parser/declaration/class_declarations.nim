## Parses class declarations containing fields and class-owned functions.
## Static versus instance behavior is inferred later from explicit self dependency.

## Parses one semicolon-terminated field declaration.
proc parseFieldDecl(parser: var Parser): FieldDecl =
  let typeRef = parser.parseFieldTypeRef()
  let name = parser.consume(tkIdentifier, "expected field name")
  let semicolon =
    parser.consume(tkSemicolon, "expected ';' after field declaration")

  FieldDecl(
    span: coverSpan(typeRef.span, semicolon.span),
    name: name.lexeme,
    typeRef: typeRef
  )

## Parses one class declaration. Fields and methods may appear in either order.
proc parseClass*(parser: var Parser): ClassDecl =
  let start = parser.consume(tkClass, "expected 'class'")
  let name = parser.consume(tkIdentifier, "expected class name")

  var typeParameters: seq[astTypeRefs.TypeParameterDecl]
  if parser.check(tkLess):
    discard parser.advance()
    if parser.check(tkGreater):
      failAt(parser.peek.span, "generic class type parameters cannot be empty")

    while true:
      let parameter = parser.consume(
        tkIdentifier,
        "expected generic type parameter name"
      )
      typeParameters.add astTypeRefs.TypeParameterDecl(
        span: parameter.span,
        name: parameter.lexeme
      )

      if parser.check(tkComma):
        discard parser.advance()
        continue

      discard parser.consume(
        tkGreater,
        "expected '>' after generic type parameters"
      )
      break

  var implementedInterfaces: seq[string]
  if parser.check(tkImplements):
    discard parser.advance()
    while true:
      let interfaceName = parser.consume(
        tkIdentifier,
        "expected interface name after 'implements'"
      )
      implementedInterfaces.add interfaceName.lexeme

      if not parser.check(tkComma):
        break
      discard parser.advance()

  discard parser.consume(tkLBrace, "expected '{' before class body")

  var fields: seq[FieldDecl]
  var methods: seq[FunctionDecl]
  while not parser.check(tkRBrace):
    if parser.check(tkEof):
      failAt(parser.peek.span, "expected '}' after class body")

    if parser.check(tkNative):
      methods.add parser.parseNativeFunction()
    elif parser.check(tkFunction):
      methods.add parser.parseFunction()
    else:
      fields.add parser.parseFieldDecl()

  let closeBrace = parser.consume(tkRBrace, "expected '}' after class body")

  ClassDecl(
    span: coverSpan(start.span, closeBrace.span),
    name: name.lexeme,
    typeParameters: typeParameters,
    implements: implementedInterfaces,
    fields: fields,
    methods: methods
  )
