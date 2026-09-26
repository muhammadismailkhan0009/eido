## Scans raw Eido source into tokens while tracking line and column positions. Example: `return 1.5;` becomes return/Float-literal/semicolon tokens.

import ../../source/span
import ../../diagnostics/errors
import token
import keywords

type
  Lexer* = object
    source: string
    current: int
    line: int
    column: int

## Creates a lexer positioned at the first source character. Example: `initLexer("var x = 5;")` starts at line 1, column 1.
proc initLexer*(source: string): Lexer =
  Lexer(source: source, current: 0, line: 1, column: 1)

## Reports whether the lexer consumed all source characters. Example: after scanning the last `;`, the next check eventually becomes true.
proc atEnd(lexer: Lexer): bool =
  lexer.current >= lexer.source.len

## Reads a source character ahead without consuming it. Example: distance 0 reads the current character and distance 1 reads the following character.
proc peekAt(lexer: Lexer, distance: int): char =
  let index = lexer.current + distance
  if index >= lexer.source.len: '\0' else: lexer.source[index]

## Reads the current source character without consuming it. Example: while scanning `var`, it can inspect the next `a` before advancing.
proc peek(lexer: Lexer): char =
  lexer.peekAt(0)

## Checks whether a character may begin an Eido identifier. Example: `a` and `_` are valid starts, while `5` is not.
proc isIdentStart(c: char): bool =
  c in {'a'..'z', 'A'..'Z', '_'}

## Checks whether a character may continue an identifier. Example: `5` is allowed inside `value5` even though it cannot start the name.
proc isIdentPart(c: char): bool =
  isIdentStart(c) or c in {'0'..'9'}

## Checks whether a character is a hexadecimal digit. Example: `F` is valid inside the Char literal `'\u004F'`.
proc isHexDigit(c: char): bool =
  c in {'0'..'9', 'a'..'f', 'A'..'F'}

## Consumes one source character and updates offset/line/column state. Example: consuming `\n` moves the lexer to the next line.
proc advance(lexer: var Lexer): char =
  result = lexer.source[lexer.current]
  inc lexer.current
  if result == '\n':
    inc lexer.line
    lexer.column = 1
  else:
    inc lexer.column

## Conditionally consumes one expected source character.
## Example: after scanning `=`, matching another `=` distinguishes equality from assignment.
proc matchNext(lexer: var Lexer, expected: char): bool =
  if lexer.atEnd or lexer.peek != expected:
    return false
  discard lexer.advance()
  true

## Builds one token with its source span. Example: scanned text `123` becomes a `tkInteger` token pointing back to its exact location.
proc makeToken(
  kind: TokenKind,
  lexeme: string,
  startOffset, endOffset, line, column: int
): Token =
  Token(
    kind: kind,
    lexeme: lexeme,
    span: SourceSpan(
      startOffset: startOffset,
      endOffset: endOffset,
      line: line,
      column: column
    )
  )

## Consumes spaces, tabs, carriage returns, and newlines before the next token. Example: indentation before `return` is ignored lexically.
proc skipWhitespace(lexer: var Lexer) =
  while not lexer.atEnd and lexer.peek in {' ', '\t', '\r', '\n'}:
    discard lexer.advance()

## Scans an Int or Float literal after its first digit was consumed.
## Example: `2147483648` is still Int and `2.5` is Float; width suffixes are rejected.
proc scanNumber(
  lexer: var Lexer,
  startOffset, startLine, startColumn: int
): Token =
  while not lexer.atEnd and lexer.peek in {'0'..'9'}:
    discard lexer.advance()

  var kind = tkInteger
  if lexer.peek == '.' and lexer.peekAt(1) in {'0'..'9'}:
    kind = tkFloat
    discard lexer.advance()
    while not lexer.atEnd and lexer.peek in {'0'..'9'}:
      discard lexer.advance()

  if lexer.peek in {'L', 'l', 'F', 'f', 'D', 'd'}:
    failAt(
      startLine,
      startColumn,
      "numeric type suffixes are not supported; use Int or Float directly"
    )

  let text = lexer.source[startOffset ..< lexer.current]
  makeToken(
    kind, text, startOffset, lexer.current, startLine, startColumn
  )

## Scans one 16-bit Eido Char literal. Example: `'A'`, `'\n'`, and `'\u0041'` each become one `tkChar` token.
proc scanChar(
  lexer: var Lexer,
  startOffset, startLine, startColumn: int
): Token =
  if lexer.atEnd or lexer.peek == '\n' or lexer.peek == '\r':
    failAt(startLine, startColumn, "unterminated Char literal")

  if lexer.peek == '\'':
    failAt(startLine, startColumn, "Char literal cannot be empty")

  if lexer.peek == '\\':
    discard lexer.advance()
    if lexer.atEnd:
      failAt(startLine, startColumn, "unterminated Char escape")

    let escape = lexer.advance()
    case escape
    of 'u':
      for _ in 0 ..< 4:
        if lexer.atEnd or not isHexDigit(lexer.peek):
          failAt(startLine, startColumn, "Char Unicode escape requires four hexadecimal digits")
        discard lexer.advance()
    of 'n', 'r', 't', 'b', 'f', '\\', '\'':
      discard
    else:
      failAt(startLine, startColumn, "unsupported Char escape '\\" & $escape & "'")
  else:
    let value = lexer.advance()
    if ord(value) > 127:
      failAt(
        startLine,
        startColumn,
        "non-ASCII Char literal must use a \\uXXXX escape"
      )

  if lexer.atEnd or lexer.peek != '\'':
    failAt(startLine, startColumn, "Char literal must contain exactly one character")
  discard lexer.advance()

  let text = lexer.source[startOffset ..< lexer.current]
  makeToken(
    tkChar, text, startOffset, lexer.current, startLine, startColumn
  )

## Scans and returns the next token from source text. Example: at `+ 5`, the first call returns `tkPlus`.
proc nextToken*(lexer: var Lexer): Token =
  lexer.skipWhitespace()

  if lexer.atEnd:
    return makeToken(
      tkEof, "", lexer.current, lexer.current, lexer.line, lexer.column
    )

  let startOffset = lexer.current
  let startLine = lexer.line
  let startColumn = lexer.column
  let c = lexer.advance()

  if isIdentStart(c):
    while not lexer.atEnd and isIdentPart(lexer.peek):
      discard lexer.advance()
    let text = lexer.source[startOffset ..< lexer.current]
    return makeToken(
      keywordKind(text), text, startOffset, lexer.current, startLine, startColumn
    )

  if c in {'0'..'9'}:
    return lexer.scanNumber(startOffset, startLine, startColumn)

  if c == '\'':
    return lexer.scanChar(startOffset, startLine, startColumn)

  let kind =
    case c
    of '(': tkLParen
    of ')': tkRParen
    of '[': tkLBracket
    of ']': tkRBracket
    of '{': tkLBrace
    of '}': tkRBrace
    of ';': tkSemicolon
    of ',': tkComma
    of '=':
      if lexer.matchNext('='): tkEqualEqual else: tkEqual
    of '!':
      if lexer.matchNext('='):
        tkBangEqual
      else:
        failAt(startLine, startColumn, "unexpected character '!'; use '!=' for inequality")
    of '<':
      if lexer.matchNext('='): tkLessEqual else: tkLess
    of '>':
      if lexer.matchNext('='): tkGreaterEqual else: tkGreater
    of '+': tkPlus
    of '-': tkMinus
    of '*': tkStar
    of '/': tkSlash
    else:
      failAt(startLine, startColumn, "unexpected character '" & $c & "'")

  makeToken(
    kind,
    lexer.source[startOffset ..< lexer.current],
    startOffset,
    lexer.current,
    startLine,
    startColumn
  )

## Scans the entire source into a token sequence ending in EOF. Example: `return true;` yields return, Bool literal, semicolon, and EOF tokens.
proc lexAll*(source: string): seq[Token] =
  var lexer = initLexer(source)
  while true:
    let token = lexer.nextToken()
    result.add token
    if token.kind == tkEof:
      break
