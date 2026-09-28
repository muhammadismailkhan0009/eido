## Returns the source-facing base identifier from a canonical or generic nominal name.
proc sourceBaseName(name: string): string =
  let genericStart = name.find('<')
  let prefix =
    if genericStart >= 0: name[0 ..< genericStart]
    else: name
  let separator = prefix.rfind('.')
  if separator >= 0: prefix[separator + 1 .. ^1] else: prefix

## Returns a stable registry key for one class field.
proc fieldKey(ownerName, fieldName: string): string =
  ownerName & "\x1f" & fieldName

## Returns a stable registry key for one interface method.
proc interfaceMethodKey(ownerName, methodName: string): string =
  ownerName & "\x1f" & methodName

## Returns the canonical nominal identity carried by a semantic type.
proc nominalTypeName(typ: EidoType): string =
  case typ.kind
  of etkClass: typ.className
  of etkInterface: typ.interfaceName
  else: ""

## Reports whether two source paths identify the same document.
proc sameSourcePath(left, right: string): bool =
  if left == right:
    return true
  if left.len == 0 or right.len == 0:
    return false
  absolutePath(left) == absolutePath(right)

## Reports whether an offset is inside one source span.
proc containsOffset(sourceSpan: SourceSpan, sourcePath: string, offset: int): bool =
  sameSourcePath(sourceSpan.sourcePath, sourcePath) and
    offset >= sourceSpan.startOffset and
    offset < max(sourceSpan.endOffset, sourceSpan.startOffset + 1)

## Builds compiler-token streams for every source in the checked project.
proc buildTokenRegistry(project: EidoProject): TokenRegistry =
  result = initTable[int, seq[Token]]()
  for source in project.sources:
    result[source.id.value] = lexAll(source)

## Finds one identifier token inside an enclosing compiler span.
proc findNameToken(
  registry: TokenRegistry,
  enclosing: SourceSpan,
  name: string,
  startAt: int = -1,
  chooseLast: bool = false,
  requireDotBefore: bool = false
): TokenMatch =
  let sourceId = enclosing.sourceId.value
  if sourceId notin registry:
    return

  let expected = sourceBaseName(name)
  let lowerBound =
    if startAt >= 0: startAt
    else: enclosing.startOffset

  var previousKind = tkEof
  for candidate in registry[sourceId]:
    if candidate.kind == tkEof:
      break
    if candidate.span.endOffset <= enclosing.startOffset:
      previousKind = candidate.kind
      continue
    if candidate.span.startOffset >= enclosing.endOffset:
      break

    let matches =
      candidate.kind == tkIdentifier and
      candidate.lexeme == expected and
      candidate.span.startOffset >= lowerBound and
      (not requireDotBefore or previousKind == tkDot)

    if matches:
      result = TokenMatch(found: true, token: candidate)
      if not chooseLast:
        return

    previousKind = candidate.kind

## Finds a declaration name token that immediately follows its declaration keyword.
proc findDeclarationNameToken(
  registry: TokenRegistry,
  enclosing: SourceSpan,
  declarationKind: TokenKind,
  name: string
): TokenMatch =
  let sourceId = enclosing.sourceId.value
  if sourceId notin registry:
    return

  let expected = sourceBaseName(name)
  var previousKind = tkEof
  for candidate in registry[sourceId]:
    if candidate.kind == tkEof:
      break
    if candidate.span.endOffset <= enclosing.startOffset:
      previousKind = candidate.kind
      continue
    if candidate.span.startOffset >= enclosing.endOffset:
      break

    if previousKind == declarationKind and
        candidate.kind == tkIdentifier and
        candidate.lexeme == expected:
      return TokenMatch(found: true, token: candidate)

    previousKind = candidate.kind

## Finds a nominal result type token after the returns keyword in a callable span.
proc findResultTypeToken(
  registry: TokenRegistry,
  enclosing: SourceSpan,
  typ: EidoType
): TokenMatch =
  if typ.kind notin {etkClass, etkInterface}:
    return

  let sourceId = enclosing.sourceId.value
  if sourceId notin registry:
    return

  var returnsEnd = -1
  for candidate in registry[sourceId]:
    if candidate.span.startOffset < enclosing.startOffset:
      continue
    if candidate.span.startOffset >= enclosing.endOffset:
      break
    if candidate.kind == tkReturns:
      returnsEnd = candidate.span.endOffset
      break

  if returnsEnd >= 0:
    result = registry.findNameToken(
      enclosing,
      typ.nominalTypeName,
      returnsEnd
    )
