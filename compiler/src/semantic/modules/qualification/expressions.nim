## Rewrites expression-held type/function identities recursively.
proc qualifyExpr(
  source: Expr,
  currentModule: string,
  locals: HashSet[string],
  typeParameters: HashSet[string],
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  functions: FunctionOwnerRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  imports: ImportRegistry,
  rootModule: string
) =
  if source.isNil:
    return

  case source.kind
  of ekInteger, ekFloat, ekBoolean, ekChar, ekString, ekNone, ekIdentifier:
    discard

  of ekTypeReference:
    qualifyTypeRef(
      source.referencedTypeRef,
      currentModule,
      typeParameters,
      modules, classes, interfaces,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      imports,
      rootModule
    )

  of ekCall:
    let localFunction = declarationKey(currentModule, source.callee)
    if localFunction in functions:
      source.callee = localFunction
    for argument in source.arguments:
      qualifyExpr(
        argument, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

  of ekConstruct:
    qualifyTypeRef(
      source.constructionTypeRef,
      currentModule,
      typeParameters,
      modules, classes, interfaces,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      imports,
      rootModule
    )
    for field in source.fields:
      qualifyExpr(
        field.value, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

  of ekClassRelation:
    qualifyExpr(
      source.relatedValue, currentModule, locals, typeParameters,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      imports,
      rootModule
    )

  of ekFieldAccess:
    let path = nominalPath(source.target)
    let canBeType = path.len > 0 and pathRoot(path) notin locals

    if canBeType:
      let resolved = resolveVisibleNominal(
        path,
        currentModule,
        modules,
        classes,
        interfaces,
        publicSurfaces,
        adoptedSurfaces,
        providedSurfaces,
        imports,
        rootModule,
        source.target.span,
        false
      )
      if resolved.len > 0 and resolved in classes:
        source.target = Expr(
          kind: ekIdentifier,
          span: source.target.span,
          name: resolved
        )
      else:
        qualifyExpr(
          source.target, currentModule, locals, typeParameters,
          modules, classes, interfaces, functions,
          publicSurfaces, adoptedSurfaces, providedSurfaces,
          imports,
          rootModule
        )
    else:
      qualifyExpr(
        source.target, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

  of ekMethodCall:
    let path = nominalPath(source.receiver)
    let canBeType =
      path.len > 0 and pathRoot(path) notin locals

    if canBeType:
      let resolved = resolveVisibleNominal(
        path,
        currentModule,
        modules,
        classes,
        interfaces,
        publicSurfaces,
        adoptedSurfaces,
        providedSurfaces,
        imports,
        rootModule,
        source.receiver.span,
        false
      )
      if resolved.len > 0 and resolved in classes:
        source.receiver = Expr(
          kind: ekIdentifier,
          span: source.receiver.span,
          name: resolved
        )
      else:
        qualifyExpr(
          source.receiver, currentModule, locals, typeParameters,
          modules, classes, interfaces, functions,
          publicSurfaces, adoptedSurfaces, providedSurfaces,
          imports,
          rootModule
        )
    else:
      qualifyExpr(
        source.receiver, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

    for argument in source.methodArguments:
      qualifyExpr(
        argument, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

  of ekUnary:
    qualifyExpr(
      source.operand, currentModule, locals, typeParameters,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      imports,
      rootModule
    )

  of ekBinary:
    qualifyExpr(
      source.left, currentModule, locals, typeParameters,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      imports,
      rootModule
    )
    qualifyExpr(
      source.right, currentModule, locals, typeParameters,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      imports,
      rootModule
    )

