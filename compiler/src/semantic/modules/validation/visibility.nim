## Returns the canonical parent module name, or empty for the root.
proc parentModuleName(name: string): string =
  let separator = name.rfind('.')
  if separator < 0: "" else: name[0 ..< separator]

## Reports strict canonical descendant containment.
proc isDescendant(parentName, candidate: string): bool =
  candidate.startsWith(parentName & ".")

## Reports same-module or descendant containment.
proc isSameOrDescendant(parentName, candidate: string): bool =
  candidate == parentName or isDescendant(parentName, candidate)

## Builds module-reference candidates visible from one canonical module.
proc moduleReferenceCandidates(
  modules: ModuleRegistry,
  rootModule, currentModule, reference: string
): seq[string] =
  var candidates: seq[string]

  template addIfPresent(candidate: string) =
    if candidate in modules and candidate notin candidates:
      candidates.add candidate

  addIfPresent(reference)
  addIfPresent(rootModule & "." & reference)

  var scope = currentModule
  while scope.len > 0:
    addIfPresent(scope & "." & reference)
    scope = parentModuleName(scope)

  candidates

## Resolves one manifest module reference without filesystem inference.
proc resolveModuleReference(
  modules: ModuleRegistry,
  rootModule, currentModule, reference, manifestPath: string
): string =
  let candidates = moduleReferenceCandidates(
    modules, rootModule, currentModule, reference
  )
  if candidates.len == 0:
    failAt(
      manifestPath, 1, 1,
      "unknown module reference '" & reference & "'"
    )
  if candidates.len > 1:
    failAt(
      manifestPath, 1, 1,
      "ambiguous module reference '" & reference & "': " &
        candidates.join(", ")
    )
  candidates[0]

## Resolves one manifest export to its owning canonical module and local symbol.
proc exportedSymbol(
  modules: ModuleRegistry,
  rootModule: string,
  owner: moduleModel.ModuleSpec,
  reference: string
): tuple[moduleName, symbolName: string] =
  let separator = reference.rfind('.')
  if separator < 0:
    return (owner.canonicalName, reference)

  let moduleRef = reference[0 ..< separator]
  let symbolName = reference[separator + 1 .. ^1]
  let targetModule = resolveModuleReference(
    modules,
    rootModule,
    owner.canonicalName,
    moduleRef,
    owner.manifestPath
  )
  if not isDescendant(owner.canonicalName, targetModule):
    failAt(
      owner.manifestPath, 1, 1,
      "exported child symbol must come from a descendant module"
    )
  (targetModule, symbolName)

## Returns a module and all of its canonical ancestors, nearest first.
proc moduleAncestors(moduleName: string): seq[string] =
  var current = moduleName
  while current.len > 0:
    result.add current
    current = parentModuleName(current)

## Resolves a parent reference to a declaration that its child really exports.
proc resolveChildExport(
  modules: ModuleRegistry,
  rootModule: string,
  parentModule: moduleModel.ModuleSpec,
  reference: string
): tuple[moduleName, symbolName: string] =
  let target = exportedSymbol(
    modules,
    rootModule,
    parentModule,
    reference
  )

  if target.moduleName == parentModule.canonicalName:
    return target

  let childSpec = modules[target.moduleName]
  var declared = false
  for childExport in childSpec.exports:
    let exported = exportedSymbol(
      modules,
      rootModule,
      childSpec,
      childExport
    )
    if exported.moduleName == target.moduleName and
        exported.symbolName == target.symbolName:
      declared = true
      break

  if not declared:
    failAt(
      parentModule.manifestPath, 1, 1,
      "child module '" & target.moduleName & "' does not export '" &
        target.symbolName & "'"
    )

  target


## Returns explicit dependencies inherited from the current module's ancestors.
proc effectiveDependencyNames(
  modules: ModuleRegistry,
  currentModule: string
): seq[string] =
  for ancestor in moduleAncestors(currentModule):
    if ancestor notin modules:
      continue
    for dependency in modules[ancestor].dependencies:
      if dependency notin result:
        result.add dependency

## Reports whether a symbol belongs to one precomputed architecture surface.
proc surfaceContains(
  surfaces: SurfaceRegistry,
  key, symbolName: string
): bool =
  key in surfaces and symbolName in surfaces[key]

## Reports whether a declaration is visible through family propagation or dependencies.
proc isSymbolVisible(
  modules: ModuleRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  currentModule, symbolName: string
): bool =
  for ancestor in moduleAncestors(currentModule):
    if ancestor notin modules:
      continue

    if publicSurfaces.surfaceContains(ancestor, symbolName):
      return true
    if adoptedSurfaces.surfaceContains(ancestor, symbolName):
      return true

    let spec = modules[ancestor]
    for provision in spec.provides:
      if not isSameOrDescendant(provision.providerModule, currentModule):
        continue
      let key = ancestor & "->" & provision.providerModule
      if providedSurfaces.surfaceContains(key, symbolName):
        return true

  for dependency in effectiveDependencyNames(modules, currentModule):
    if publicSurfaces.surfaceContains(dependency, symbolName):
      return true

  false

## Requires a cross-module class to belong to the effective API surface.
proc requireClassVisibility(
  modules: ModuleRegistry,
  classes: ClassRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  currentModule, className: string,
  spanPath: string,
  line, column: int
) =
  if className notin classes:
    return

  let target = classes[className]
  if target.moduleName == currentModule:
    return

  if not isSymbolVisible(
    modules,
    publicSurfaces,
    adoptedSurfaces,
    providedSurfaces,
    currentModule,
    className
  ):
    failAt(
      spanPath, line, column,
      "module '" & currentModule & "' cannot access class '" & className &
        "' from module '" & target.moduleName &
        "'; it is not reachable from an allowed module API surface"
    )

## Requires an interface to belong to the effective API/contract surface.
proc requireInterfaceVisibility(
  modules: ModuleRegistry,
  interfaces: InterfaceRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  currentModule, interfaceName: string,
  spanPath: string,
  line, column: int
) =
  if interfaceName notin interfaces:
    return

  let target = interfaces[interfaceName]
  if target.moduleName == currentModule:
    return

  if not isSymbolVisible(
    modules,
    publicSurfaces,
    adoptedSurfaces,
    providedSurfaces,
    currentModule,
    interfaceName
  ):
    failAt(
      spanPath, line, column,
      "module '" & currentModule & "' cannot use interface '" &
        interfaceName & "' from module '" & target.moduleName &
        "'; it is not reachable from an allowed module API surface"
    )
