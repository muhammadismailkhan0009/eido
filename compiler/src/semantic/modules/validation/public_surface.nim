## Computes transitive module API surfaces from explicitly exported/adopted declarations.
## A reachable class exposes its complete current nominal surface: fields, method signatures, and implemented interfaces.

## Adds every nominal declaration referenced by one type reference to a closure.
proc addTypeRefClosure(
  source: TypeRef,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  seen: var HashSet[string]
)

## Adds one class/interface declaration and its complete public type graph.
proc addDeclarationClosure(
  name: string,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  seen: var HashSet[string]
) =
  if name in seen:
    return

  if name in classes:
    seen.incl name
    let sourceClass = classes[name]

    for implemented in sourceClass.implements:
      addDeclarationClosure(implemented, classes, interfaces, seen)

    for field in sourceClass.fields:
      addTypeRefClosure(field.typeRef, classes, interfaces, seen)

    for methodDecl in sourceClass.methods:
      for parameter in methodDecl.parameters:
        addTypeRefClosure(parameter.typeRef, classes, interfaces, seen)
      if methodDecl.result.kind == frrSingle:
        addTypeRefClosure(
          methodDecl.result.typeRef,
          classes,
          interfaces,
          seen
        )
    return

  if name in interfaces:
    seen.incl name
    let sourceInterface = interfaces[name]

    for parent in sourceInterface.extends:
      addDeclarationClosure(parent, classes, interfaces, seen)

    for methodDecl in sourceInterface.methods:
      for parameter in methodDecl.parameters:
        addTypeRefClosure(parameter.typeRef, classes, interfaces, seen)
      if methodDecl.result.kind == frrSingle:
        addTypeRefClosure(
          methodDecl.result.typeRef,
          classes,
          interfaces,
          seen
        )

## Adds nominal names and nested generic arguments from a source type.
proc addTypeRefClosure(
  source: TypeRef,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  seen: var HashSet[string]
) =
  if source.name in classes or source.name in interfaces:
    addDeclarationClosure(source.name, classes, interfaces, seen)

  for argument in source.arguments:
    addTypeRefClosure(argument, classes, interfaces, seen)

## Computes the outward public closure for every module's explicit exports.
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
      let target = resolveChildExport(
        modules,
        rootModule,
        moduleSpec,
        exportRef
      )
      addDeclarationClosure(
        target.symbolName,
        classes,
        interfaces,
        surface
      )
    result[moduleName] = surface

## Computes the family-visible closure explicitly adopted from child modules.
proc buildAdoptedSurfaces(
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  rootModule: string
): SurfaceRegistry =
  result = initTable[string, HashSet[string]]()

  for moduleName, moduleSpec in modules:
    var surface = initHashSet[string]()
    for adoption in moduleSpec.adopts:
      let target = resolveChildExport(
        modules,
        rootModule,
        moduleSpec,
        adoption
      )
      addDeclarationClosure(
        target.symbolName,
        classes,
        interfaces,
        surface
      )
    result[moduleName] = surface

## Creates the stable registry key for one parent→provider contract surface.
proc provisionSurfaceKey(parentModule, providerModule: string): string =
  parentModule & "->" & providerModule

## Computes the contract closure propagated only into each declared provider subtree.
proc buildProvidedSurfaces(
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry
): SurfaceRegistry =
  result = initTable[string, HashSet[string]]()

  for _, moduleSpec in modules:
    for provision in moduleSpec.provides:
      var surface = initHashSet[string]()
      addDeclarationClosure(
        provision.contract,
        classes,
        interfaces,
        surface
      )
      result[provisionSurfaceKey(
        moduleSpec.canonicalName,
        provision.providerModule
      )] = surface
