## Adds one semantic symbol unless the same fact was already indexed.
proc addSymbol(
  index: var SymbolIndex,
  seen: var HashSet[string],
  kind: ToolingSymbolKind,
  name: string,
  sourceSpan, declarationSpan: SourceSpan,
  isDeclaration: bool,
  isStatic: bool = false
) =
  let key =
    $sourceSpan.sourceId.value & ":" &
    $sourceSpan.startOffset & ":" &
    $sourceSpan.endOffset & ":" &
    $ord(kind) & ":" &
    $(if isDeclaration: 1 else: 0)

  if key in seen:
    return

  seen.incl key
  index.symbols.add ToolingSymbol(
    kind: kind,
    name: name,
    span: sourceSpan,
    declarationSpan: declarationSpan,
    isDeclaration: isDeclaration,
    isStatic: isStatic
  )

## Adds one nominal type-use symbol when its declaration is known.
proc addTypeUse(
  index: var SymbolIndex,
  seen: var HashSet[string],
  registry: TokenRegistry,
  definitions: TypeDefinitionRegistry,
  enclosing: SourceSpan,
  typ: EidoType,
  startAt: int = -1
) =
  let nominalName = typ.nominalTypeName
  if nominalName.len == 0 or nominalName notin definitions:
    return

  let sourceToken = registry.findNameToken(
    enclosing,
    nominalName,
    startAt
  )
  if not sourceToken.found:
    return

  index.addSymbol(
    seen,
    if typ.kind == etkClass: tskClass else: tskInterface,
    sourceBaseName(nominalName),
    sourceToken.token.span,
    definitions[nominalName],
    false
  )

## Finds the declaration span for an interface method, following inherited contracts.
proc resolveInterfaceMethodDefinition(
  directDefinitions: InterfaceMethodDefinitionRegistry,
  interfaces: InterfaceRegistry,
  ownerName, methodName: string,
  visiting: var HashSet[string]
): SourceSpan =
  let key = interfaceMethodKey(ownerName, methodName)
  if key in directDefinitions:
    return directDefinitions[key]
  if ownerName in visiting or ownerName notin interfaces:
    return

  visiting.incl ownerName
  for parent in interfaces[ownerName].extends:
    let inherited = resolveInterfaceMethodDefinition(
      directDefinitions,
      interfaces,
      parent,
      methodName,
      visiting
    )
    if inherited.endOffset > inherited.startOffset or
        inherited.sourcePath.len > 0:
      return inherited

## Adds one resolved local/parameter reference.
proc addLocalReference(
  index: var SymbolIndex,
  seen: var HashSet[string],
  localDefinitions: Table[int, ToolingSymbol],
  expr: HirExpr
) =
  let localKey = expr.localId.value
  if localKey notin localDefinitions:
    return

  let definition = localDefinitions[localKey]
  index.addSymbol(
    seen,
    definition.kind,
    if expr.sourceName == "receiver": "self" else: expr.sourceName,
    expr.span,
    definition.declarationSpan,
    false,
    definition.isStatic
  )
