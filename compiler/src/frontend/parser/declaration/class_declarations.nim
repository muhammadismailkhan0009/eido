## Parses class declarations containing fields and class-owned functions.
## Static versus instance behavior is inferred later from explicit self dependency.

## Parses one instance field or explicitly class-owned field declaration.
## Int value; is instance state while Int Counter.count = 0; is class state.
proc parseFieldDecl(parser: var Parser, className: string): FieldDecl =
  let typeRef = parser.parseFieldTypeRef()
  let firstName = parser.consume(tkIdentifier, "expected field name")

  if parser.check(tkDot):
    discard parser.advance()
    if firstName.lexeme != className:
      failAt(
        firstName.span,
        "class-owned field must be qualified by '" & className & "'"
      )
    let name = parser.consume(tkIdentifier, "expected class-owned field name")
    discard parser.consume(
      tkEqual,
      "expected '=' after class-owned field name"
    )
    let initializer = parser.parseExpression()
    let semicolon =
      parser.consume(tkSemicolon, "expected ';' after field declaration")
    return FieldDecl(
      span: coverSpan(typeRef.span, semicolon.span),
      name: name.lexeme,
      typeRef: typeRef,
      isClassOwned: true,
      ownerName: className,
      initializer: initializer
    )

  let semicolon =
    parser.consume(tkSemicolon, "expected ';' after field declaration")
  FieldDecl(
    span: coverSpan(typeRef.span, semicolon.span),
    name: firstName.lexeme,
    typeRef: typeRef,
    isClassOwned: false,
    ownerName: "",
    initializer: nil
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
  var invariants: seq[Expr]
  var invariantSeen = false
  var methods: seq[FunctionDecl]
  while not parser.check(tkRBrace):
    if parser.check(tkEof):
      failAt(parser.peek.span, "expected '}' after class body")

    if parser.check(tkInvariant):
      if invariantSeen:
        failAt(parser.peek.span, "class may declare only one invariant section")
      invariantSeen = true
      invariants = parser.parseContractClauses(tkInvariant, "invariant")
    elif parser.check(tkNative):
      methods.add parser.parseNativeFunction()
    elif parser.check(tkFunction):
      methods.add parser.parseFunction()
    else:
      fields.add parser.parseFieldDecl(name.lexeme)

  let closeBrace = parser.consume(tkRBrace, "expected '}' after class body")

  ClassDecl(
    span: coverSpan(start.span, closeBrace.span),
    name: name.lexeme,
    typeParameters: typeParameters,
    implements: implementedInterfaces,
    fields: fields,
    invariants: invariants,
    methods: methods
  )
