## Parses field-only class declarations.
## Example: `class Point { Int x; Int y; }`.

## Parses one semicolon-terminated field declaration.
proc parseFieldDecl(parser: var Parser): FieldDecl =
  let typeRef = parser.parseFieldTypeRef()
  let name = parser.consume(tkIdentifier, "expected field name")
  let semicolon =
    parser.consume(tkSemicolon, "expected ';' after field declaration")

  FieldDecl(
    span: SourceSpan(
      startOffset: typeRef.span.startOffset,
      endOffset: semicolon.span.endOffset,
      line: typeRef.span.line,
      column: typeRef.span.column
    ),
    name: name.lexeme,
    typeRef: typeRef
  )

## Parses one field-only class declaration. The closing brace ends the declaration.
proc parseClass*(parser: var Parser): ClassDecl =
  let start = parser.consume(tkClass, "expected 'class'")
  let name = parser.consume(tkIdentifier, "expected class name")
  discard parser.consume(tkLBrace, "expected '{' before class body")

  var fields: seq[FieldDecl]
  while not parser.check(tkRBrace):
    if parser.check(tkEof):
      failAt(parser.peek.span, "expected '}' after class body")
    fields.add parser.parseFieldDecl()

  let closeBrace = parser.consume(tkRBrace, "expected '}' after class body")

  ClassDecl(
    span: SourceSpan(
      startOffset: start.span.startOffset,
      endOffset: closeBrace.span.endOffset,
      line: start.span.line,
      column: start.span.column
    ),
    name: name.lexeme,
    fields: fields
  )
