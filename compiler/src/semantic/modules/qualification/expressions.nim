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
        rootModule
      )

  of ekConstruct:
    qualifyTypeRef(
      source.constructionTypeRef,
      currentModule,
      typeParameters,
      modules, classes, interfaces,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      rootModule
    )
    for field in source.fields:
      qualifyExpr(
        field.value, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        rootModule
      )

  of ekClassRelation:
    qualifyExpr(
      source.relatedValue, currentModule, locals, typeParameters,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      rootModule
    )

  of ekFieldAccess:
    qualifyExpr(
      source.target, currentModule, locals, typeParameters,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
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
          rootModule
        )
    else:
      qualifyExpr(
        source.receiver, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        rootModule
      )

    for argument in source.methodArguments:
      qualifyExpr(
        argument, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        rootModule
      )

  of ekUnary:
    qualifyExpr(
      source.operand, currentModule, locals, typeParameters,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      rootModule
    )

  of ekBinary:
    qualifyExpr(
      source.left, currentModule, locals, typeParameters,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      rootModule
    )
    qualifyExpr(
      source.right, currentModule, locals, typeParameters,
      modules, classes, interfaces, functions,
      publicSurfaces, adoptedSurfaces, providedSurfaces,
      rootModule
    )

