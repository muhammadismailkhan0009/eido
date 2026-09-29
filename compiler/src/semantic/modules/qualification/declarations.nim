## Rewrites one callable signature/body under its owning module.
proc qualifyCallable(
  source: var FunctionDecl,
  currentModule: string,
  typeParameters: HashSet[string],
  includeSelf: bool,
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  functions: FunctionOwnerRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  rootModule: string
) =
  var locals = initHashSet[string]()
  if includeSelf:
    locals.incl "self"

  for parameter in mitems(source.parameters):
    qualifyTypeRef(
      parameter.typeRef, currentModule, typeParameters,
      modules, classes, interfaces,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      rootModule
    )
    locals.incl parameter.name

  if source.result.kind == frrSingle:
    qualifyTypeRef(
      source.result.typeRef, currentModule, typeParameters,
      modules, classes, interfaces,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      rootModule
    )

  for clause in source.requires:
    qualifyExpr(
      clause, currentModule, locals, typeParameters,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      rootModule
    )
  for clause in source.ensures:
    qualifyExpr(
      clause, currentModule, locals, typeParameters,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      rootModule
    )

  qualifyStatements(
    source.body, currentModule, locals, typeParameters,
    modules, classes, interfaces, functions,
    publicSurfaces, adoptedSurfaces, providedSurfaces,
    rootModule
  )

## Rewrites all module-project declarations/references to canonical semantic names.
proc qualifyModuleProgram(
  source: var Program,
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  functions: FunctionOwnerRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  rootModule: string
) =
  var noTypeParameters = initHashSet[string]()

  for sourceInterface in mitems(source.interfaces):
    for index in 0 ..< sourceInterface.extends.len:
      sourceInterface.extends[index] = resolveVisibleNominal(
        sourceInterface.extends[index],
        sourceInterface.moduleName,
        modules, classes, interfaces,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        rootModule,
        sourceInterface.span
      )
    for methodDecl in mitems(sourceInterface.methods):
      qualifyCallable(
        methodDecl, sourceInterface.moduleName, noTypeParameters, false,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        rootModule
      )
    sourceInterface.name = declarationKey(
      sourceInterface.moduleName,
      sourceInterface.name
    )

  for sourceClass in mitems(source.classes):
    var typeParameters = initHashSet[string]()
    for parameter in sourceClass.typeParameters:
      typeParameters.incl parameter.name

    for index in 0 ..< sourceClass.implements.len:
      sourceClass.implements[index] = resolveVisibleNominal(
        sourceClass.implements[index],
        sourceClass.moduleName,
        modules, classes, interfaces,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        rootModule,
        sourceClass.span
      )

    for field in mitems(sourceClass.fields):
      qualifyTypeRef(
        field.typeRef, sourceClass.moduleName, typeParameters,
        modules, classes, interfaces,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        rootModule
      )

    var invariantLocals = initHashSet[string]()
    invariantLocals.incl "self"
    for clause in sourceClass.invariants:
      qualifyExpr(
        clause, sourceClass.moduleName, invariantLocals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        rootModule
      )

    for methodDecl in mitems(sourceClass.methods):
      qualifyCallable(
        methodDecl, sourceClass.moduleName, typeParameters, true,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        rootModule
      )

    sourceClass.name = declarationKey(
      sourceClass.moduleName,
      sourceClass.name
    )

  for sourceFunction in mitems(source.functions):
    let localName = sourceFunction.name
    qualifyCallable(
      sourceFunction, sourceFunction.moduleName, noTypeParameters, false,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      rootModule
    )
    sourceFunction.name = declarationKey(
      sourceFunction.moduleName,
      localName
    )
