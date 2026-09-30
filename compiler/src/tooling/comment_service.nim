## Exposes source-comment ranges as protocol-neutral tooling facts.
## Comments remain lexer trivia and never enter the parser, AST, or HIR.

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
