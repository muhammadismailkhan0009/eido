## Translates compiler-owned semantic symbol facts into LSP semantic-token data.

import std/[json, sets]
import ../../../../compiler/src/tooling/symbol_service
import positions

const
  SemanticTokenTypes* = [
    "class",
    "interface",
    "function",
    "method",
    "property",
    "parameter",
    "variable"
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

## Encodes one document's compiler semantic symbols using LSP delta-token encoding.
proc semanticTokensResult*(
  index: SymbolIndex,
  sourcePath: string,
  sourceText: string
): JsonNode =
  var data = newJArray()
  var previousLine = 0
  var previousCharacter = 0
  var first = true
  var seen = initHashSet[string]()

  for symbol in index.semanticSymbolsIn(sourcePath):
    let startPos = lspPositionAt(sourceText, symbol.span.startOffset)
    let endPos = lspPositionAt(sourceText, symbol.span.endOffset)
    let line = startPos["line"].getInt
    let character = startPos["character"].getInt
    let endLine = endPos["line"].getInt
    let endCharacter = endPos["character"].getInt

    if endLine != line or endCharacter <= character:
      continue

    let key = $line & ":" & $character & ":" & $endCharacter
    if key in seen:
      continue
    seen.incl key

    let deltaLine =
      if first: line
      else: line - previousLine
    let deltaStart =
      if first or deltaLine != 0: character
      else: character - previousCharacter

    data.add %deltaLine
    data.add %deltaStart
    data.add %(endCharacter - character)
    data.add %tokenTypeIndex(symbol.kind)
    data.add %tokenModifierBits(symbol)

    previousLine = line
    previousCharacter = character
    first = false

  %*{"data": data}
