## Computes transitive module API surfaces from explicitly exported/adopted/provided roots.
## Surfaces store canonical declaration identities, never source-local names.

## Reports whether a canonical nominal declaration exists.
proc nominalExists(
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  key: string
): bool =
  key in classes or key in interfaces

## Resolves one source nominal reference while API surfaces are being constructed.
## Same-module declarations win; dependency/family candidates are considered only when needed.
proc resolveSurfaceReference(
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  publicSurfaces: SurfaceRegistry,
  rootModule, currentModule, reference: string,
  span: SourceSpan
): string =
  let separator = reference.rfind('.')
  if separator > 0:
    let moduleRef = reference[0 ..< separator]
    let localName = reference[separator + 1 .. ^1]
    let moduleName = resolveModuleReference(
      modules,
      rootModule,
      currentModule,
      moduleRef,
      span.sourcePath
    )
    let key = declarationKey(moduleName, localName)
    if nominalExists(classes, interfaces, key):
      return key
    failAt(span, "unknown qualified type '" & reference & "'")

  let localKey = declarationKey(currentModule, reference)
  if nominalExists(classes, interfaces, localKey):
    return localKey

  var candidates = initHashSet[string]()

  # Direct/ancestor-supplied dependencies contribute only their current public API.
  for dependency in effectiveDependencyNames(modules, currentModule):
    if dependency notin publicSurfaces:
      continue
    for key in publicSurfaces[dependency]:
      if declarationLocalName(key) == reference:
        candidates.incl key

  # Ancestor-owned declarations may be propagated downward. Architecture
  # validation later decides whether that propagation was actually authorized.
  var ancestor = parentModuleName(currentModule)
  while ancestor.len > 0:
    let key = declarationKey(ancestor, reference)
    if nominalExists(classes, interfaces, key):
      candidates.incl key

    if ancestor in publicSurfaces:
      for publicKey in publicSurfaces[ancestor]:
        if declarationLocalName(publicKey) == reference:
          candidates.incl publicKey
    ancestor = parentModuleName(ancestor)

  # Explicit parent adoption makes child roots potentially visible downward.
  for ancestorName in moduleAncestors(currentModule):
    if ancestorName notin modules:
      continue
    let ancestorSpec = modules[ancestorName]
    for adoption in ancestorSpec.adopts:
      let target = resolveChildExport(
        modules,
        rootModule,
        ancestorSpec,
        adoption
      )
      let targetKey = declarationKey(target.moduleName, target.symbolName)
      if declarationLocalName(targetKey) == reference:
        candidates.incl targetKey
      if target.moduleName in publicSurfaces:
        for publicKey in publicSurfaces[target.moduleName]:
          if declarationLocalName(publicKey) == reference:
            candidates.incl publicKey

  # A parent-owned provider contract is visible in its designated subtree.
  for ancestorName in moduleAncestors(currentModule):
    if ancestorName notin modules:
      continue
    for provision in modules[ancestorName].provides:
      if isSameOrDescendant(provision.providerModule, currentModule) and
          provision.contract == reference:
        let key = declarationKey(ancestorName, reference)
        if nominalExists(classes, interfaces, key):
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
      "ambiguous type '" & reference & "'; use a module-qualified name (" &
        names.join(", ") & ")"
    )

  ""

## Adds every nominal declaration referenced by one type reference.
proc addTypeRefClosure(
  source: TypeRef,
  ownerModule: string,
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  publicSurfaces: SurfaceRegistry,
  rootModule: string,
  seen: var HashSet[string]
)

## Adds one class/interface declaration and recursively follows its whole type surface.
proc addDeclarationClosure(
  key: string,
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  publicSurfaces: SurfaceRegistry,
  rootModule: string,
  seen: var HashSet[string]
) =
  if key.len == 0 or key in seen:
    return
  seen.incl key

  if key in classes:
    let sourceClass = classes[key]

    for implemented in sourceClass.implements:
      let resolved = resolveSurfaceReference(
        modules, classes, interfaces, publicSurfaces,
        rootModule, sourceClass.moduleName, implemented, sourceClass.span
      )
      addDeclarationClosure(
        resolved, modules, classes, interfaces, publicSurfaces, rootModule, seen
      )

    for field in sourceClass.fields:
      addTypeRefClosure(
        field.typeRef, sourceClass.moduleName,
        modules, classes, interfaces, publicSurfaces, rootModule, seen
      )

    for methodDecl in sourceClass.methods:
      for parameter in methodDecl.parameters:
        addTypeRefClosure(
          parameter.typeRef, sourceClass.moduleName,
          modules, classes, interfaces, publicSurfaces, rootModule, seen
        )
      if methodDecl.result.kind == frrSingle:
        addTypeRefClosure(
          methodDecl.result.typeRef, sourceClass.moduleName,
          modules, classes, interfaces, publicSurfaces, rootModule, seen
        )
    return

  if key in interfaces:
    let sourceInterface = interfaces[key]

    for parent in sourceInterface.extends:
      let resolved = resolveSurfaceReference(
        modules, classes, interfaces, publicSurfaces,
        rootModule, sourceInterface.moduleName, parent, sourceInterface.span
      )
      addDeclarationClosure(
        resolved, modules, classes, interfaces, publicSurfaces, rootModule, seen
      )

    for methodDecl in sourceInterface.methods:
      for parameter in methodDecl.parameters:
        addTypeRefClosure(
          parameter.typeRef, sourceInterface.moduleName,
          modules, classes, interfaces, publicSurfaces, rootModule, seen
        )
      if methodDecl.result.kind == frrSingle:
        addTypeRefClosure(
          methodDecl.result.typeRef, sourceInterface.moduleName,
          modules, classes, interfaces, publicSurfaces, rootModule, seen
        )

## Adds nominal names and nested generic arguments from a source type.
proc addTypeRefClosure(
  source: TypeRef,
  ownerModule: string,
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  publicSurfaces: SurfaceRegistry,
  rootModule: string,
  seen: var HashSet[string]
) =
  if isStorageTypeConstructor(source.name):
    for argument in source.arguments:
      addTypeRefClosure(
        argument, ownerModule,
        modules, classes, interfaces, publicSurfaces, rootModule, seen
      )
    return

  let resolved = resolveSurfaceReference(
    modules, classes, interfaces, publicSurfaces,
    rootModule, ownerModule, source.name, source.span
  )
  if resolved.len > 0:
    addDeclarationClosure(
      resolved, modules, classes, interfaces, publicSurfaces, rootModule, seen
    )

  for argument in source.arguments:
    addTypeRefClosure(
      argument, ownerModule,
      modules, classes, interfaces, publicSurfaces, rootModule, seen
    )

## Resolves one explicit manifest root to a canonical nominal identity.
proc manifestRootKey(
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  rootModule: string,
  owner: moduleModel.ModuleSpec,
  reference: string
): string =
  let target = resolveChildExport(modules, rootModule, owner, reference)
  let key = declarationKey(target.moduleName, target.symbolName)
  if not nominalExists(classes, interfaces, key):
    failAt(
      owner.manifestPath, 1, 1,
      "unknown exported declaration '" & reference & "'"
    )
  key

## Computes outward public closure to a fixed point because one dependency API
## may itself re-expose declarations from another dependency.
proc buildPublicSurfaces(
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  rootModule: string
): SurfaceRegistry =
  result = initTable[string, HashSet[string]]()

  for moduleName, moduleSpec in modules:
    var surface = initHashSet[string]()
    for exportRef in moduleSpec.exports:
      surface.incl manifestRootKey(
        modules, classes, interfaces, rootModule, moduleSpec, exportRef
      )
    result[moduleName] = surface

  var changed = true
  while changed:
    changed = false
    for moduleName, moduleSpec in modules:
      let roots = result[moduleName]
      var closure = initHashSet[string]()
      for key in roots:
        addDeclarationClosure(
          key, modules, classes, interfaces, result, rootModule, closure
        )

      var expanded = result[moduleName]
      for key in closure:
        expanded.incl key

      if expanded.len != result[moduleName].len:
        result[moduleName] = expanded
        changed = true

## Computes family-visible closure explicitly adopted from child modules.
proc buildAdoptedSurfaces(
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  publicSurfaces: SurfaceRegistry,
  rootModule: string
): SurfaceRegistry =
  result = initTable[string, HashSet[string]]()

  for moduleName, moduleSpec in modules:
    var surface = initHashSet[string]()
    for adoption in moduleSpec.adopts:
      let target = resolveChildExport(
        modules, rootModule, moduleSpec, adoption
      )
      let key = declarationKey(target.moduleName, target.symbolName)
      addDeclarationClosure(
        key, modules, classes, interfaces,
        publicSurfaces, rootModule, surface
      )
    result[moduleName] = surface

## Creates the stable registry key for one parent→provider contract surface.
proc provisionSurfaceKey(parentModule, providerModule: string): string =
  parentModule & "->" & providerModule

## Computes the contract closure propagated only into each declared provider subtree.
proc buildProvidedSurfaces(
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  publicSurfaces: SurfaceRegistry,
  rootModule: string
): SurfaceRegistry =
  result = initTable[string, HashSet[string]]()

  for _, moduleSpec in modules:
    for provision in moduleSpec.provides:
      let contractKey = declarationKey(
        moduleSpec.canonicalName,
        provision.contract
      )
      var surface = initHashSet[string]()
      addDeclarationClosure(
        contractKey, modules, classes, interfaces,
        publicSurfaces, rootModule, surface
      )
      result[provisionSurfaceKey(
        moduleSpec.canonicalName,
        provision.providerModule
      )] = surface
