## Rewrites a statement block while preserving lexical local-name shadowing.
proc qualifyStatements(
  statements: seq[Stmt],
  currentModule: string,
  initialLocals: HashSet[string],
  typeParameters: HashSet[string],
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  functions: FunctionOwnerRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  imports: ImportRegistry,
  rootModule: string
) =
  var locals = initialLocals

  for statement in statements:
    case statement.kind
    of skVar:
      qualifyExpr(
        statement.initializer, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )
      locals.incl statement.name

    of skAssign:
      qualifyExpr(
        statement.target, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )
      qualifyExpr(
        statement.assignedValue, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

    of skCall:
      qualifyExpr(
        statement.call, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

    of skReturn:
      qualifyExpr(
        statement.value, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

    of skIf:
      qualifyExpr(
        statement.condition, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )
      qualifyStatements(
        statement.thenBranch, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )
      qualifyStatements(
        statement.elseBranch, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

    of skExists:
      qualifyExpr(
        statement.existsTarget, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )
      qualifyStatements(
        statement.existsBody, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

    of skWhile:
      qualifyExpr(
        statement.whileCondition, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )
      qualifyStatements(
        statement.body, currentModule, locals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

    of skFor:
      var loopLocals = locals
      if not statement.forInitializer.isNil:
        qualifyStatements(
          @[statement.forInitializer], currentModule, loopLocals, typeParameters,
          modules, classes, interfaces, functions,
          publicSurfaces, adoptedSurfaces, providedSurfaces,
          imports,
          rootModule
        )
        if statement.forInitializer.kind == skVar:
          loopLocals.incl statement.forInitializer.name
      qualifyExpr(
        statement.forCondition, currentModule, loopLocals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )
      if not statement.forUpdate.isNil:
        qualifyStatements(
          @[statement.forUpdate], currentModule, loopLocals, typeParameters,
          modules, classes, interfaces, functions,
          publicSurfaces, adoptedSurfaces, providedSurfaces,
          imports,
          rootModule
        )
      qualifyStatements(
        statement.forBody, currentModule, loopLocals, typeParameters,
        modules, classes, interfaces, functions,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        imports,
        rootModule
      )

    of skBreak, skContinue:
      discard

