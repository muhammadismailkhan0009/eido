## Exposes source-comment ranges as protocol-neutral tooling facts.
## Comments remain lexer trivia and never enter the parser, AST, or HIR.

import std/strutils
import ../frontend/lexer/scanner

type
  ToolingCommentRange* = object
    startOffset*: int
    endOffset*: int

## Finds // comments in lexer-trivia gaps between ordinary source tokens.
## String and Char contents are token spans, so embedded // text is not a comment.
proc lineCommentRanges*(sourceText: string): seq[ToolingCommentRange] =
  let lexicalTokens = lexAll(sourceText)
  var previousEnd = 0

  for lexicalToken in lexicalTokens:
    let gapEnd = lexicalToken.span.startOffset
    var index = previousEnd

    while index + 1 < gapEnd:
      if sourceText[index] == '/' and sourceText[index + 1] == '/':
        let startOffset = index
        index += 2
        while index < gapEnd and sourceText[index] notin {'\r', '\n'}:
          inc index
        result.add ToolingCommentRange(
          startOffset: startOffset,
          endOffset: index
        )
      else:
        inc index

    previousEnd = max(previousEnd, lexicalToken.span.endOffset)

## Returns the contiguous `///` documentation block immediately preceding a declaration.
## Ordinary `//` comments remain implementation comments and are never promoted into API docs.
proc documentationCommentBefore*(
  sourceText: string,
  declarationOffset: int
): string =
  if declarationOffset <= 0 or sourceText.len == 0:
    return ""

  let boundedOffset = min(declarationOffset, sourceText.len)
  let prefix = sourceText[0 ..< boundedOffset]
  var lines = prefix.splitLines()

  # A declaration can be indented, leaving only its indentation as the final
  # partial line in the prefix. That whitespace is not a documentation gap.
  if lines.len > 0 and lines[^1].strip().len == 0:
    discard lines.pop()

  var reversed: seq[string]
  while lines.len > 0:
    let line = lines.pop().strip()
    if not line.startsWith("///"):
      break

    var docLine = line[3 .. ^1]
    if docLine.startsWith(" "):
      docLine = docLine[1 .. ^1]
    reversed.add docLine

  for index in countdown(reversed.high, 0):
    result.add reversed[index]
    if index > 0:
      result.add "\n"
