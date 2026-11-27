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
  imports: ImportRegistry,
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
      imports,
      rootModule
    )
    locals.incl parameter.name

  if source.result.kind == frrSingle:
    qualifyTypeRef(
      source.result.typeRef, currentModule, typeParameters,
      modules, classes, interfaces,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      imports,
      rootModule
    )

  for clause in source.requires:
    qualifyExpr(
      clause, currentModule, locals, typeParameters,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      imports,
      rootModule
    )
  var ensureLocals = locals
  if source.result.kind == frrSingle:
    ensureLocals.incl "result"
  for clause in source.ensures:
    qualifyExpr(
      clause, currentModule, ensureLocals, typeParameters,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      imports,
      rootModule
    )

  qualifyStatements(
    source.body, currentModule, locals, typeParameters,
    modules, classes, interfaces, functions,
    publicSurfaces, adoptedSurfaces, providedSurfaces,
    imports,
    rootModule
  )

## Validates local configuration class references; intrinsic selection strings
## are checked against resolved layouts in the HIR pass.
proc checkLayoutConfigDirectory(call: Expr, currentModule: string,
    modules: ModuleRegistry, classes: ClassRegistry, interfaces: InterfaceRegistry) =
  if call.isNil or call.kind != ekMethodCall: return
  let path = nominalPath(call.receiver)
  if path.len == 0: return
  let localKey = declarationKey(currentModule, path)
  # Configuration calls also accept unique suffix-qualified class names.
  if path in classes:
    requireNominalDirectoryAccess(modules, classes, interfaces, currentModule, path, call.span)
  elif localKey in classes:
    requireNominalDirectoryAccess(modules, classes, interfaces, currentModule, localKey, call.span)
  else:
    var matches: seq[string]
    for key in classes.keys:
      if key.endsWith("." & path): matches.add key
    if matches.len == 1:
      requireNominalDirectoryAccess(modules, classes, interfaces, currentModule, matches[0], call.span)

## Rewrites all module-project declarations/references to canonical semantic names.
proc qualifyModuleProgram(
  source: var Program,
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  functions: FunctionOwnerRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  imports: ImportRegistry,
  rootModule: string
) =
  var noTypeParameters = initHashSet[string]()

  for sourceInterface in mitems(source.interfaces):
    var typeParameters = initHashSet[string]()
    for parameter in sourceInterface.typeParameters:
      typeParameters.incl parameter.name

    for index in 0 ..< sourceInterface.extends.len:
      sourceInterface.extends[index] = resolveVisibleNominal(
        sourceInterface.extends[index],
        sourceInterface.moduleName,
        modules, classes, interfaces,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule,
        sourceInterface.span
      )
    for methodDecl in mitems(sourceInterface.methods):
      qualifyCallable(
        methodDecl, sourceInterface.moduleName, typeParameters, true,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
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

    for implemented in mitems(sourceClass.implements):
      qualifyTypeRef(
        implemented, sourceClass.moduleName, typeParameters,
        modules, classes, interfaces,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

    var classFieldLocals = initHashSet[string]()
    for field in mitems(sourceClass.fields):
      qualifyTypeRef(
        field.typeRef, sourceClass.moduleName, typeParameters,
        modules, classes, interfaces,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )
      if field.isClassOwned and not field.initializer.isNil:
        qualifyExpr(
          field.initializer, sourceClass.moduleName, classFieldLocals, typeParameters,
          modules, classes, interfaces, functions,
          publicSurfaces, adoptedSurfaces, providedSurfaces,
          imports,
          rootModule
        )

    var invariantLocals = initHashSet[string]()
    invariantLocals.incl "self"
    for clause in sourceClass.invariants:
      qualifyExpr(
        clause, sourceClass.moduleName, invariantLocals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

    for methodDecl in mitems(sourceClass.methods):
      qualifyCallable(
        methodDecl, sourceClass.moduleName, typeParameters, true,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

    for methodDecl in sourceClass.layoutConfigMethods:
      for stmt in methodDecl.body:
        if stmt.kind == skCall:
          checkLayoutConfigDirectory(stmt.call, sourceClass.moduleName, modules, classes, interfaces)

    sourceClass.name = declarationKey(
      sourceClass.moduleName,
      sourceClass.name
    )

  for config in source.layoutConfigCalls:
    checkLayoutConfigDirectory(config.call, config.moduleName, modules, classes, interfaces)

  for sourceLayout in mitems(source.layouts):
    var typeParameters = initHashSet[string]()
    for parameter in sourceLayout.typeParameters:
      typeParameters.incl parameter.name

    qualifyTypeRef(
      sourceLayout.targetType, sourceLayout.moduleName, typeParameters,
      modules, classes, interfaces,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      imports,
      rootModule
    )
    sourceLayout.name = declarationKey(
      sourceLayout.moduleName, sourceLayout.name
    )

  for sourceFunction in mitems(source.functions):
    let localName = sourceFunction.name
    qualifyCallable(
      sourceFunction, sourceFunction.moduleName, noTypeParameters, false,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      imports,
      rootModule
    )
    sourceFunction.name = declarationKey(
      sourceFunction.moduleName,
      localName
    )
