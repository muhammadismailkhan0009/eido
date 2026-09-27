## Parses built-in literal primary expressions and decodes their token values.
## Example: `5`, `true`, `'A'`, and `"Eido"` become literal-shaped AST nodes.

## Converts one hexadecimal digit to its numeric value.
## Example: `F` becomes 15 while decoding a Unicode Char escape.
proc hexValue(c: char): uint16 =
  case c
  of '0'..'9': uint16(ord(c) - ord('0'))
  of 'a'..'f': uint16(ord(c) - ord('a') + 10)
  of 'A'..'F': uint16(ord(c) - ord('A') + 10)
  else: 0'u16

## Decodes a validated Char-token spelling into one 16-bit code unit.
## Example: `'A'` and `'\u0041'` both become 65.
proc parseCharValue(token: Token): uint16 =
  let text = token.lexeme
  if text.len == 3:
    return uint16(ord(text[1]))

  if text.len >= 4 and text[1] == '\\':
    case text[2]
    of 'n': return 10'u16
    of 'r': return 13'u16
    of 't': return 9'u16
    of 'b': return 8'u16
    of 'f': return 12'u16
    of '\\': return 92'u16
    of '\'': return 39'u16
    of 'u':
      var value = 0'u16
      for index in 3 .. 6:
        value = uint16(value * 16'u16 + hexValue(text[index]))
      return value
    else:
      discard

  failAt(token.span, "invalid Char literal")

## Decodes a validated String-token spelling into its immutable text value.
## Example: `"hello\\nworld"` becomes a String containing one newline.
proc parseStringValue(token: Token): string =
  var index = 1
  while index < token.lexeme.len - 1:
    let current = token.lexeme[index]
    if current != '\\':
      result.add current
      inc index
      continue

    inc index
    case token.lexeme[index]
    of 'n': result.add '\n'
    of 'r': result.add '\r'
    of 't': result.add '\t'
    of '\\': result.add '\\'
    of '"': result.add '"'
    else:
      failAt(token.span, "invalid String escape")
    inc index

## Parses a built-in literal when the current token is literal-shaped.
## Example: current token `2.5` returns a Float AST node; an identifier returns nil.
proc parseLiteral(parser: var Parser): Expr =
  if parser.check(tkInteger):
    let token = parser.advance()
    return Expr(
      kind: ekInteger,
      span: token.span,
      intValue: parseBiggestInt(token.lexeme).int64
    )

  if parser.check(tkFloat):
    let token = parser.advance()
    return Expr(
      kind: ekFloat,
      span: token.span,
      floatValue: parseFloat(token.lexeme)
    )

  if parser.check(tkBoolean):
    let token = parser.advance()
    return Expr(
      kind: ekBoolean,
      span: token.span,
      boolValue: token.lexeme == "true"
    )

  if parser.check(tkChar):
    let token = parser.advance()
    return Expr(
      kind: ekChar,
      span: token.span,
      charValue: parseCharValue(token)
    )

  if parser.check(tkStringLiteral):
    let token = parser.advance()
    return Expr(
      kind: ekString,
      span: token.span,
      stringValue: parseStringValue(token)
    )

  nil
