## Translates compiler-owned semantic symbol facts into LSP semantic-token data.

import std/[algorithm, json, sets]
import ../../../../compiler/src/tooling/[comment_service, symbol_service]
import positions

const
  SemanticTokenTypes* = [
    "class",
    "interface",
    "function",
    "method",
    "property",
    "parameter",
    "variable",
    "comment"
  ]
  SemanticTokenModifiers* = [
    "declaration",
    "static"
  ]

## Returns the LSP legend index for one compiler semantic symbol kind.
proc tokenTypeIndex(kind: ToolingSymbolKind): int =
  case kind
  of tskClass: 0
  of tskInterface: 1
  of tskFunction: 2
  of tskMethod: 3
  of tskProperty: 4
  of tskParameter: 5
  of tskVariable: 6

## Returns the LSP semantic-token modifier bitset for one compiler symbol fact.
proc tokenModifierBits(symbol: ToolingSymbol): int =
  result = 0
  if symbol.isDeclaration:
    result = result or 1
  if symbol.isStatic:
    result = result or 2

type
  SemanticToken = object
    line: int
    character: int
    length: int
    tokenType: int
    modifiers: int

## Adds one single-line byte span as an LSP semantic token.
proc addSemanticToken(
  tokens: var seq[SemanticToken],
  sourceText: string,
  startOffset, endOffset, tokenType, modifiers: int
) =
  let startPos = lspPositionAt(sourceText, startOffset)
  let endPos = lspPositionAt(sourceText, endOffset)
  let line = startPos["line"].getInt
  let character = startPos["character"].getInt
  let endLine = endPos["line"].getInt
  let endCharacter = endPos["character"].getInt

  if endLine == line and endCharacter > character:
    tokens.add SemanticToken(
      line: line,
      character: character,
      length: endCharacter - character,
      tokenType: tokenType,
      modifiers: modifiers
    )

## Orders tokens exactly as required before LSP delta encoding.
proc compareSemanticTokens(left, right: SemanticToken): int =
  result = cmp(left.line, right.line)
  if result == 0:
    result = cmp(left.character, right.character)
  if result == 0:
    result = cmp(left.length, right.length)
  if result == 0:
    result = cmp(left.tokenType, right.tokenType)

## Encodes semantic symbols plus lexical comments using LSP delta-token encoding.
proc semanticTokensResult*(
  index: SymbolIndex,
  sourcePath: string,
  sourceText: string
): JsonNode =
  var tokens: seq[SemanticToken]
  var seen = initHashSet[string]()

  for symbol in index.semanticSymbolsIn(sourcePath):
    let key =
      $symbol.span.startOffset & ":" &
      $symbol.span.endOffset
    if key in seen:
      continue
    seen.incl key
    tokens.addSemanticToken(
      sourceText,
      symbol.span.startOffset,
      symbol.span.endOffset,
      tokenTypeIndex(symbol.kind),
      tokenModifierBits(symbol)
    )

  let commentType = SemanticTokenTypes.len - 1
  for comment in lineCommentRanges(sourceText):
    tokens.addSemanticToken(
      sourceText,
      comment.startOffset,
      comment.endOffset,
      commentType,
      0
    )

  tokens.sort(compareSemanticTokens)

  var data = newJArray()
  var previousLine = 0
  var previousCharacter = 0
  var first = true

  for token in tokens:
    let deltaLine =
      if first: token.line
      else: token.line - previousLine
    let deltaStart =
      if first or deltaLine != 0: token.character
      else: token.character - previousCharacter

    data.add %deltaLine
    data.add %deltaStart
    data.add %token.length
    data.add %token.tokenType
    data.add %token.modifiers

    previousLine = token.line
    previousCharacter = token.character
    first = false

  %*{"data": data}
