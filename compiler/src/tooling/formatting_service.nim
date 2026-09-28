## Provides deterministic source formatting without depending on an editor protocol.
## The formatter operates on Eido tokens so strings/literals keep their exact source spelling.

import std/strutils
import ../frontend/lexer/[scanner, token]

## Removes horizontal whitespace from the end of the current output buffer.
proc trimTrailingSpaces(value: var string) =
  while value.len > 0 and value[^1] in {' ', '\t'}:
    value.setLen(value.len - 1)

## Reports whether the formatter is currently positioned at the start of a line.
proc lineStart(value: string): bool =
  value.len == 0 or value[^1] == '\n'

## Writes canonical four-space indentation when the output is at a line start.
proc writeIndent(value: var string, indent: int) =
  if value.lineStart:
    value.add repeat("    ", indent)

## Ends the current formatted line exactly once after trimming trailing spaces.
proc newline(value: var string) =
  value.trimTrailingSpaces()
  if value.len == 0 or value[^1] != '\n':
    value.add '\n'

## Inserts one separating space unless whitespace is already present.
proc ensureSpace(value: var string) =
  if value.len > 0 and value[^1] notin {' ', '\n'}:
    value.add ' '

## Reports whether a token uses canonical surrounding operator spacing.
proc isOperator(kind: TokenKind): bool =
  kind in {
    tkEqual, tkEqualEqual, tkBangEqual,
    tkLess, tkLessEqual, tkGreater, tkGreaterEqual,
    tkPlus, tkMinus, tkStar, tkSlash
  }

## Reports whether a control keyword requires a space before its opening parenthesis.
proc isControlWithParen(kind: TokenKind): bool =
  kind in {tkIf, tkWhile, tkFor}

## Reports whether a word-like token needs separation from the previous token.
proc needsWordSpace(previous: TokenKind): bool =
  previous notin {
    tkEof, tkLParen, tkLBracket, tkDot,
    tkQuestion, tkLess
  } and not previous.isOperator

## Formats one complete Eido source string into the canonical v0 layout.
proc formatSource*(source: string): string =
  let tokens = lexAll(source)
  var indent = 0
  var parenDepth = 0
  var previous = tkEof

  for index, token in tokens:
    if token.kind == tkEof:
      break

    let nextKind =
      if index + 1 < tokens.len: tokens[index + 1].kind
      else: tkEof

    case token.kind
    of tkLBrace:
      result.ensureSpace()
      result.add "{"
      result.newline()
      inc indent

    of tkRBrace:
      if not result.lineStart:
        result.newline()
      indent = max(0, indent - 1)
      result.writeIndent(indent)
      result.add "}"
      if nextKind == tkElse:
        result.add " "
      elif nextKind != tkSemicolon:
        result.newline()

    of tkSemicolon:
      result.trimTrailingSpaces()
      result.add ";"
      if parenDepth > 0:
        result.add " "
      else:
        result.newline()

    of tkComma:
      result.trimTrailingSpaces()
      result.add ", "

    of tkLParen:
      if previous.isControlWithParen:
        result.ensureSpace()
      result.add "("
      inc parenDepth

    of tkRParen:
      result.trimTrailingSpaces()
      result.add ")"
      parenDepth = max(0, parenDepth - 1)

    of tkLBracket:
      result.add "["

    of tkRBracket:
      result.trimTrailingSpaces()
      result.add "]"

    of tkDot:
      result.trimTrailingSpaces()
      result.add "."

    of tkQuestion:
      result.trimTrailingSpaces()
      result.add "?"

    of tkColon:
      result.trimTrailingSpaces()
      result.add ": "

    else:
      result.writeIndent(indent)
      if token.kind.isOperator:
        result.ensureSpace()
        result.add token.lexeme
        result.add " "
      else:
        if previous.needsWordSpace:
          result.ensureSpace()
        result.add token.lexeme

    previous = token.kind

  result.trimTrailingSpaces()
  if result.len > 0 and result[^1] != '\n':
    result.add '\n'
