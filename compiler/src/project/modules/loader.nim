## Loads the mandatory module.yaml tree into an EidoProject.
## Parent manifests own child discovery; filesystem nesting alone never creates architecture.

import std/[os, sets, strutils, tables]
import ../../diagnostics/errors
import ../../source/source_unit
import ../model as projectModel
import ../../stdlib/builtin_sources
import manifest_parser
import model

## Documents the parentModuleName module helper behavior.
proc parentModuleName(name: string): string =
  let split = name.rfind('.')
  if split < 0: "" else: name[0 ..< split]

## Documents the isDescendant module helper behavior.
proc isDescendant(parentName, candidate: string): bool =
  candidate.startsWith(parentName & ".")

## Documents the moduleIndexByName module helper behavior.
proc moduleIndexByName(modules: seq[ModuleSpec], name: string): int =
  for index, moduleSpec in modules:
    if moduleSpec.canonicalName == name:
      return index
  -1

## Documents the resolveModuleReference module helper behavior.
proc resolveModuleReference(
  modules: seq[ModuleSpec],
  rootModule, currentModule, reference: string,
  manifestPath: string
): string =
  var candidates = initHashSet[string]()

  ## Documents the addIfPresent module helper behavior.
  proc addIfPresent(candidate: string) =
    if modules.moduleIndexByName(candidate) >= 0:
      candidates.incl candidate

  addIfPresent(reference)
  addIfPresent(rootModule & "." & reference)

  var scope = currentModule
  while scope.len > 0:
    addIfPresent(scope & "." & reference)
    scope = parentModuleName(scope)

  if candidates.len == 0:
    failAt(
      manifestPath, 1, 1,
      "unknown module reference '" & reference & "' from '" & currentModule & "'"
    )

  if candidates.len > 1:
    var names: seq[string]
    for candidate in candidates:
      names.add candidate
    failAt(
      manifestPath, 1, 1,
      "ambiguous module reference '" & reference & "' from '" &
        currentModule & "': " & names.join(", ")
    )

  for candidate in candidates:
    return candidate

## Documents the resolveChildSymbolReference module helper behavior.
proc resolveChildSymbolReference(
  modules: seq[ModuleSpec],
  rootModule: string,
  owner: ModuleSpec,
  reference: string
): tuple[moduleName, symbolName: string] =
  let separator = reference.rfind('.')
  if separator <= 0 or separator == reference.high:
    failAt(
      owner.manifestPath, 1, 1,
      "child contract reference must use '<child>.<name>': '" & reference & "'"
    )

  let moduleRef = reference[0 ..< separator]
  result.symbolName = reference[separator + 1 .. ^1]
  result.moduleName = resolveModuleReference(
    modules,
    rootModule,
    owner.canonicalName,
    moduleRef,
    owner.manifestPath
  )

  if not isDescendant(owner.canonicalName, result.moduleName):
    failAt(
      owner.manifestPath, 1, 1,
      "module '" & result.moduleName & "' is not a child of '" &
        owner.canonicalName & "'"
    )

## Documents the validateDependencyDag module helper behavior.
proc validateDependencyDag(modules: seq[ModuleSpec]) =
  var states = initTable[string, int]()
  var stack: seq[string]

  ## Documents the visit module helper behavior.
  proc visit(name: string) =
    let state = states.getOrDefault(name, 0)
    if state == 2:
      return
    if state == 1:
      stack.add name
      fail(
        "EIDO2003",
        "module dependency cycle: " & stack.join(" -> ")
      )

    states[name] = 1
    stack.add name
    let index = modules.moduleIndexByName(name)
    if index >= 0:
      for dependency in modules[index].dependencies:
        visit(dependency)
    discard stack.pop()
    states[name] = 2

  for moduleSpec in modules:
    if states.getOrDefault(moduleSpec.canonicalName, 0) == 0:
      visit(moduleSpec.canonicalName)

## Documents the loadModuleProject module helper behavior.
proc loadModuleProject*(
  manifestPath: string,
  target: projectModel.ProjectTarget
): projectModel.EidoProject =
  let rootManifest = absolutePath(manifestPath)
  if rootManifest.extractFilename != "module.yaml":
    failAt(rootManifest, 1, 1, "Eido module projects must start from module.yaml")
  if not fileExists(rootManifest):
    failAt(rootManifest, 1, 1, "module manifest does not exist")

  var modules: seq[ModuleSpec]
  var sources: seq[SourceUnit]
  var loadedManifestPaths = initHashSet[string]()
  var ownedSourcePaths = initHashSet[string]()

  ## Documents the loadOne module helper behavior.
  proc loadOne(
    currentManifestPath,
    parentCanonical,
    expectedLocalName: string
  ): string =
    let normalizedManifest = absolutePath(currentManifestPath)
    if normalizedManifest in loadedManifestPaths:
      failAt(
        normalizedManifest, 1, 1,
        "module.yaml cannot belong to more than one parent"
      )
    loadedManifestPaths.incl normalizedManifest

    if not fileExists(normalizedManifest):
      failAt(normalizedManifest, 1, 1, "child module.yaml does not exist")

    let manifest = parseModuleManifest(
      readFile(normalizedManifest),
      normalizedManifest
    )

    if expectedLocalName.len > 0 and manifest.name != expectedLocalName:
      failAt(
        normalizedManifest, 1, 1,
        "child manifest declares module '" & manifest.name &
          "' but parent declared child '" & expectedLocalName & "'"
      )

    let canonical =
      if parentCanonical.len == 0:
        manifest.name
      else:
        parentCanonical & "." & manifest.name

    if modules.moduleIndexByName(canonical) >= 0:
      failAt(
        normalizedManifest, 1, 1,
        "duplicate module identity '" & canonical & "'"
      )

    let directory = parentDir(normalizedManifest)
    var spec = ModuleSpec(
      name: manifest.name,
      canonicalName: canonical,
      parentName: parentCanonical,
      manifestPath: normalizedManifest,
      directory: directory,
      dependencies: manifest.dependencies,
      exports: manifest.exports,
      adopts: manifest.adopts
    )

    let ownIndex = modules.len
    modules.add spec

    for sourceEntry in manifest.sources:
      let sourcePath = absolutePath(directory / sourceEntry)
      if sourcePath in ownedSourcePaths:
        failAt(
          normalizedManifest, 1, 1,
          "source file belongs to more than one module: " & sourcePath
        )
      if sourcePath.splitFile.ext != ".eido":
        failAt(
          normalizedManifest, 1, 1,
          "module source must be an .eido file: " & sourceEntry
        )
      if not fileExists(sourcePath):
        failAt(
          normalizedManifest, 1, 1,
          "module source does not exist: " & sourceEntry
        )

      ownedSourcePaths.incl sourcePath
      modules[ownIndex].sourcePaths.add sourcePath
      sources.add initSourceUnit(
        sources.len,
        sourcePath,
        readFile(sourcePath),
        canonical
      )

    for child in manifest.children:
      let childManifest = absolutePath(directory / child.path / "module.yaml")
      let childCanonical = loadOne(
        childManifest,
        canonical,
        child.name
      )
      modules[ownIndex].children.add childCanonical

    for provision in manifest.provides:
      modules[ownIndex].provides.add ModuleProvision(
        contract: provision.contract,
        providerModule: provision.by
      )

    canonical

  let rootModule = loadOne(rootManifest, "", "")
  addBuiltinStdlib(sources, modules, rootModule)

  # Resolve explicit dependency references only after the complete child tree is known.
  for index in 0 ..< modules.len:
    var resolvedDependencies: seq[string]
    for dependency in modules[index].dependencies:
      let resolved = resolveModuleReference(
        modules,
        rootModule,
        modules[index].canonicalName,
        dependency,
        modules[index].manifestPath
      )
      if resolved == modules[index].canonicalName:
        failAt(
          modules[index].manifestPath, 1, 1,
          "module cannot depend on itself"
        )
      if resolved notin resolvedDependencies:
        resolvedDependencies.add resolved
    modules[index].dependencies = resolvedDependencies

    for provisionIndex in 0 ..< modules[index].provides.len:
      let provider = resolveModuleReference(
        modules,
        rootModule,
        modules[index].canonicalName,
        modules[index].provides[provisionIndex].providerModule,
        modules[index].manifestPath
      )
      if not isDescendant(modules[index].canonicalName, provider):
        failAt(
          modules[index].manifestPath, 1, 1,
          "provided contract implementation must come from a child module"
        )
      modules[index].provides[provisionIndex].providerModule = provider

    for adoption in modules[index].adopts:
      discard resolveChildSymbolReference(
        modules,
        rootModule,
        modules[index],
        adoption
      )

  validateDependencyDag(modules)

  projectModel.initModuleProject(
    target,
    sources,
    modules,
    rootModule
  )
