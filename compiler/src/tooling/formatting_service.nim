## Provides deterministic source formatting without depending on an editor protocol.
## The formatter operates on Eido tokens plus source comments so literals and comments
## keep their exact source spelling while layout is canonicalized.

import std/strutils
import ../frontend/lexer/[scanner, token]
import comment_service

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

## Reports whether a source gap crosses a physical line boundary.
proc containsLineBreak(source: string, startOffset, endOffset: int): bool =
  let start = max(0, min(startOffset, source.len))
  let finish = max(start, min(endOffset, source.len))
  for index in start ..< finish:
    if source[index] in {'\r', '\n'}:
      return true
  false

## Writes one standalone comment at the current structural indentation.
proc writeStandaloneComment(
  value: var string,
  source: string,
  comment: ToolingCommentRange,
  indent: int
) =
  if not value.lineStart:
    value.newline()
  value.writeIndent(indent)
  value.add source[comment.startOffset ..< comment.endOffset]
  value.newline()

## Writes a comment that originally followed a source token on the same line.
proc writeTrailingComment(
  value: var string,
  source: string,
  comment: ToolingCommentRange
) =
  value.ensureSpace()
  value.add source[comment.startOffset ..< comment.endOffset]
  value.newline()

## Formats one complete Eido source string into the canonical v0 layout.
proc formatSource*(source: string): string =
  let tokens = lexAll(source)
  let comments = lineCommentRanges(source)
  var commentIndex = 0
  var indent = 0
  var parenDepth = 0
  var previous = tkEof

  for index, token in tokens:
    # Comments that occur before this token and were not attached to the previous
    # token are standalone lines at the current structural indentation.
    while commentIndex < comments.len and
        comments[commentIndex].startOffset < token.span.startOffset:
      result.writeStandaloneComment(source, comments[commentIndex], indent)
      inc commentIndex

    if token.kind == tkEof:
      break

    let nextKind =
      if index + 1 < tokens.len: tokens[index + 1].kind
      else: tkEof
    let nextOffset =
      if index + 1 < tokens.len: tokens[index + 1].span.startOffset
      else: source.len

    var hasTrailingComment = false
    if commentIndex < comments.len:
      let comment = comments[commentIndex]
      hasTrailingComment =
        comment.startOffset >= token.span.endOffset and
        comment.startOffset < nextOffset and
        not source.containsLineBreak(
          token.span.endOffset,
          comment.startOffset
        )

    case token.kind
    of tkLBrace:
      result.ensureSpace()
      result.add "{"
      inc indent
      if not hasTrailingComment:
        result.newline()

    of tkRBrace:
      if not result.lineStart:
        result.newline()
      indent = max(0, indent - 1)
      result.writeIndent(indent)
      result.add "}"
      if not hasTrailingComment:
        if nextKind == tkElse:
          result.add " "
        elif nextKind != tkSemicolon:
          result.newline()

    of tkSemicolon:
      result.trimTrailingSpaces()
      result.add ";"
      if not hasTrailingComment:
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

    if hasTrailingComment:
      result.writeTrailingComment(
        source,
        comments[commentIndex]
      )
      inc commentIndex

    previous = token.kind

  result.trimTrailingSpaces()
  if result.len > 0 and result[^1] != '\n':
    result.add '\n'
