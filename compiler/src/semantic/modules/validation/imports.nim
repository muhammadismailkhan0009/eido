## File-local import bindings. An import never adds a module dependency.
proc collectImports(
  source: Program,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  modules: ModuleRegistry
): ImportRegistry =
  result = initTable[string, Table[string, ImportBinding]]()
  for item in source.imports:
    if item.path notin classes and item.path notin interfaces:
      failAt(item.nameSpan, "unknown imported type '" & item.path & "'")
    let name = declarationLocalName(item.path)
    let localKey = declarationKey(item.moduleName, name)
    if localKey != item.path and (localKey in classes or localKey in interfaces):
      failAt(item.nameSpan, "import conflicts with module-local type '" & name & "'")
    if localKey == item.path:
      requireNominalDirectoryAccess(modules, classes, interfaces, item.moduleName, item.path, item.span)
    let path = item.span.sourcePath
    if path notin result:
      result[path] = initTable[string, ImportBinding]()
    if name in result[path]:
      failAt(item.nameSpan, "duplicate or conflicting import of '" & name & "'")
    result[path][name] = ImportBinding(target: item.path, authorized: localKey == item.path)

## Looks up the binding by short name or its exact qualified target.
proc importBinding(imports: ImportRegistry, span: SourceSpan, name: string): ImportBinding =
  if span.sourcePath notin imports:
    return
  let localName = declarationLocalName(name)
  let bindings = imports[span.sourcePath]
  if localName in bindings and (name == localName or bindings[localName].target == name):
    return bindings[localName]

## Admits only imports reachable from the architecture already established.
proc authorizeVisibleImports(
  source: Program,
  modules: ModuleRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  imports: var ImportRegistry
): bool =
  for item in source.imports:
    let path = item.span.sourcePath
    let name = declarationLocalName(item.path)
    if not imports[path][name].authorized and
        isSymbolVisible(modules, publicSurfaces, adoptedSurfaces,
          providedSurfaces, item.moduleName, item.path):
      imports[path][name].authorized = true
      result = true

## Rejects imports not authorized by the established module API surfaces.
proc validateImportVisibility(source: Program, imports: ImportRegistry) =
  for item in source.imports:
    if not importBinding(imports, item.span, item.path).authorized:
      failAt(item.nameSpan, "module '" & item.moduleName &
        "' cannot import '" & item.path & "': not visible through its module architecture")
