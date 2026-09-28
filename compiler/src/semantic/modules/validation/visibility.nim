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

## Reports whether one class is legal as a module-level static API.
proc isStaticOnly(source: ClassDecl): bool =
  if source.fields.len != 0:
    return false
  for methodDecl in source.methods:
    if not methodDecl.isNative and inferMethodKind(methodDecl) != mkStatic:
      return false
  true

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

## Returns public export owners for a symbol from one module boundary.
proc publicExportOwners(
  modules: ModuleRegistry,
  rootModule, moduleName, symbolName: string
): seq[string] =
  if moduleName notin modules:
    return

  let moduleSpec = modules[moduleName]
  for exportRef in moduleSpec.exports:
    let target = exportedSymbol(
      modules,
      rootModule,
      moduleSpec,
      exportRef
    )
    if target.symbolName == symbolName and target.moduleName notin result:
      result.add target.moduleName

## Returns declaration owners made visible downward by ancestor architecture.
proc familyVisibleOwners(
  modules: ModuleRegistry,
  rootModule, currentModule, symbolName: string
): seq[string] =
  for ancestor in moduleAncestors(currentModule):
    if ancestor notin modules:
      continue
    let spec = modules[ancestor]

    # Public ancestor API propagates downward.
    for owner in publicExportOwners(
      modules, rootModule, ancestor, symbolName
    ):
      if owner notin result:
        result.add owner

    # Explicit child adoption becomes family-visible from the adopting parent.
    for adoption in spec.adopts:
      let target = exportedSymbol(
        modules,
        rootModule,
        spec,
        adoption
      )
      if target.symbolName == symbolName and target.moduleName notin result:
        result.add target.moduleName

    # A parent-owned provided contract propagates into its designated provider subtree.
    for provision in spec.provides:
      if provision.contract == symbolName and
          isSameOrDescendant(provision.providerModule, currentModule):
        if spec.canonicalName notin result:
          result.add spec.canonicalName

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

## Returns owners visible either through family propagation or explicit dependencies.
proc visibleOwners(
  modules: ModuleRegistry,
  rootModule, currentModule, symbolName: string
): seq[string] =
  for owner in familyVisibleOwners(
    modules, rootModule, currentModule, symbolName
  ):
    if owner notin result:
      result.add owner

  for dependency in effectiveDependencyNames(modules, currentModule):
    for owner in publicExportOwners(
      modules, rootModule, dependency, symbolName
    ):
      if owner notin result:
        result.add owner

## Requires a cross-module static class reference to be publicly/family visible.
proc requireStaticVisibility(
  modules: ModuleRegistry,
  classes: ClassRegistry,
  rootModule, currentModule, className: string,
  spanPath: string,
  line, column: int
) =
  if className notin classes:
    return

  let target = classes[className]
  if target.moduleName == currentModule:
    return

  let owners = visibleOwners(
    modules, rootModule, currentModule, className
  )
  if target.moduleName notin owners:
    failAt(
      spanPath, line, column,
      "module '" & currentModule & "' cannot access '" & className &
        "' from module '" & target.moduleName &
        "'; expose it through an allowed module boundary"
    )

## Requires an interface type to be visible through the current architecture.
proc requireInterfaceVisibility(
  modules: ModuleRegistry,
  interfaces: InterfaceRegistry,
  rootModule, currentModule, interfaceName: string,
  spanPath: string,
  line, column: int
) =
  if interfaceName notin interfaces:
    return

  let target = interfaces[interfaceName]
  if target.moduleName == currentModule:
    return

  let owners = visibleOwners(
    modules, rootModule, currentModule, interfaceName
  )
  if target.moduleName notin owners:
    failAt(
      spanPath, line, column,
      "module '" & currentModule & "' cannot use interface '" &
        interfaceName & "' from module '" & target.moduleName &
        "'; expose or propagate that contract explicitly"
    )

