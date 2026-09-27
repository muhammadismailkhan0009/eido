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
  discard parser.consume(tkLBrace, "expected '{' before class body")

  var fields: seq[FieldDecl]
  var methods: seq[FunctionDecl]
  while not parser.check(tkRBrace):
    if parser.check(tkEof):
      failAt(parser.peek.span, "expected '}' after class body")

    if parser.check(tkFunction):
      methods.add parser.parseFunction()
    else:
      fields.add parser.parseFieldDecl()

  let closeBrace = parser.consume(tkRBrace, "expected '}' after class body")

  ClassDecl(
    span: coverSpan(start.span, closeBrace.span),
    name: name.lexeme,
    fields: fields,
    methods: methods
  )
