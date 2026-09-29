## Rewrites module-project source references to canonical semantic identities.
## Ordinary semantic analysis therefore operates on collision-free names only.

## Resolves a source nominal reference against the final effective module surfaces.
proc resolveVisibleNominal(
  reference, currentModule: string,
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  rootModule: string,
  span: SourceSpan,
  strict: bool = true
): string =
  let separator = reference.rfind('.')
  if separator > 0:
    let moduleRef = reference[0 ..< separator]
    let localName = reference[separator + 1 .. ^1]
    let candidates = moduleReferenceCandidates(
      modules, rootModule, currentModule, moduleRef
    )
    if candidates.len == 0:
      if strict:
        failAt(span, "unknown module qualifier '" & moduleRef & "'")
      return ""
    if candidates.len > 1:
      if strict:
        failAt(span, "ambiguous module qualifier '" & moduleRef & "'")
      return ""

    let key = declarationKey(candidates[0], localName)
    if not nominalExists(classes, interfaces, key):
      if strict:
        failAt(span, "unknown qualified type '" & reference & "'")
      return ""

    if candidates[0] != currentModule and not isSymbolVisible(
      modules,
      publicSurfaces,
      adoptedSurfaces,
      providedSurfaces,
      currentModule,
      key
    ):
      if strict:
        failAt(
          span,
          "module '" & currentModule & "' cannot access '" & reference & "'"
        )
      return ""
    return key

  let localKey = declarationKey(currentModule, reference)
  if nominalExists(classes, interfaces, localKey):
    return localKey

  var candidates = initHashSet[string]()
  for key in classes.keys:
    if declarationLocalName(key) == reference and isSymbolVisible(
      modules,
      publicSurfaces,
      adoptedSurfaces,
      providedSurfaces,
      currentModule,
      key
    ):
      candidates.incl key

  for key in interfaces.keys:
    if declarationLocalName(key) == reference and isSymbolVisible(
      modules,
      publicSurfaces,
      adoptedSurfaces,
      providedSurfaces,
      currentModule,
      key
    ):
      candidates.incl key

  if candidates.len == 1:
    for key in candidates:
      return key

  if candidates.len > 1:
    var names: seq[string]
    for key in candidates:
      names.add key
    failAt(
      span,
      "ambiguous type '" & reference &
        "'; use a module-qualified name (" & names.join(", ") & ")"
    )

  if strict:
    failAt(span, "unknown type '" & reference & "'")
  ""

## Rewrites one declared type reference recursively.
proc qualifyTypeRef(
  source: var TypeRef,
  currentModule: string,
  typeParameters: HashSet[string],
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  rootModule: string
) =
  if source.name notin typeParameters and
      not isStorageTypeConstructor(source.name) and
      source.name notin ["Bool", "Byte", "Short", "Int", "Float", "Char", "String"]:
    source.name = resolveVisibleNominal(
      source.name,
      currentModule,
      modules,
      classes,
      interfaces,
      publicSurfaces,
      adoptedSurfaces,
      providedSurfaces,
      rootModule,
      source.span
    )

  for argument in mitems(source.arguments):
    qualifyTypeRef(
      argument, currentModule, typeParameters,
      modules, classes, interfaces,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      rootModule
    )

## Returns a dotted identifier/field-access path, or empty for a value expression.
proc nominalPath(source: Expr): string =
  if source.isNil:
    return ""
  case source.kind
  of ekIdentifier:
    source.name
  of ekFieldAccess:
    let prefix = nominalPath(source.target)
    if prefix.len == 0: "" else: prefix & "." & source.fieldName
  else:
    ""

## Returns the first identifier of a dotted path.
proc pathRoot(path: string): string =
  let separator = path.find('.')
  if separator < 0: path else: path[0 ..< separator]

