## Finds the narrowest indexed semantic symbol at a source position.
proc symbolAt*(
  index: SymbolIndex,
  sourcePath: string,
  byteOffset: int
): SymbolMatch =
  var bestWidth = high(int)
  for symbol in index.symbols:
    if not symbol.span.containsOffset(sourcePath, byteOffset):
      continue
    let width = max(1, symbol.span.endOffset - symbol.span.startOffset)
    if width <= bestWidth:
      result = SymbolMatch(found: true, symbol: symbol)
      bestWidth = width

## Returns semantic symbols that belong to one source document.
proc semanticSymbolsIn*(
  index: SymbolIndex,
  sourcePath: string
): seq[ToolingSymbol] =
  for symbol in index.symbols:
    if sameSourcePath(symbol.span.sourcePath, sourcePath):
      result.add symbol
