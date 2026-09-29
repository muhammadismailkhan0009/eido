## Validates one declared type reference against concrete-class and interface boundaries.
proc validateTypeRef(
  source: TypeRef,
  currentModule: string,
  typeParameters: HashSet[string],
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  modules: ModuleRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry
) =
  if source.name notin typeParameters:
    if source.name in classes:
      requireClassVisibility(
        modules,
        classes,
        publicSurfaces,
        adoptedSurfaces,
        providedSurfaces,
        currentModule,
        source.name,
        source.span.sourcePath,
        source.span.line,
        source.span.column
      )
    elif source.name in interfaces:
      requireInterfaceVisibility(
        modules,
        interfaces,
        publicSurfaces,
        adoptedSurfaces,
        providedSurfaces,
        currentModule,
        source.name,
        source.span.sourcePath,
        source.span.line,
        source.span.column
      )

  for argument in source.arguments:
    validateTypeRef(
      argument,
      currentModule,
      typeParameters,
      classes,
      interfaces,
      modules,
      publicSurfaces,
      adoptedSurfaces,
      providedSurfaces
    )

## Declares recursive expression architecture validation.
proc validateExpr(
  source: Expr,
  currentModule: string,
  locals: HashSet[string],
  typeParameters: HashSet[string],
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  functions: FunctionOwnerRegistry,
  modules: ModuleRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry
)

## Declares recursive statement architecture validation.
proc validateStmtBlock(
  statements: seq[Stmt],
  currentModule: string,
  initialLocals: HashSet[string],
  typeParameters: HashSet[string],
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  functions: FunctionOwnerRegistry,
  modules: ModuleRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry
)

## Validates architecture-sensitive names inside one expression.
proc validateExpr(
  source: Expr,
  currentModule: string,
  locals: HashSet[string],
  typeParameters: HashSet[string],
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  functions: FunctionOwnerRegistry,
  modules: ModuleRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry
) =
  if source.isNil:
    return

  case source.kind
  of ekInteger, ekFloat, ekBoolean, ekChar, ekString, ekNone, ekIdentifier:
    discard

  of ekTypeReference:
    let typeRef = source.referencedTypeRef
    if typeRef.name in classes and typeRef.name notin typeParameters:
      requireClassVisibility(
        modules,
        classes,
        publicSurfaces,
        adoptedSurfaces,
        providedSurfaces,
        currentModule,
        typeRef.name,
        source.span.sourcePath,
        source.span.line,
        source.span.column
      )
    for argument in typeRef.arguments:
      validateTypeRef(
        argument,
        currentModule,
        typeParameters,
        classes,
        interfaces,
        modules,
        publicSurfaces,
        adoptedSurfaces,
        providedSurfaces
      )

  of ekCall:
    if source.callee in functions and functions[source.callee] != currentModule:
      failAt(
        source.span,
        "top-level function '" & source.callee &
          "' is internal to module '" & functions[source.callee] & "'"
      )
    for argument in source.arguments:
      validateExpr(
        argument, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )

  of ekConstruct:
    validateTypeRef(
      source.constructionTypeRef,
      currentModule,
      typeParameters,
      classes,
      interfaces,
      modules,
      publicSurfaces,
      adoptedSurfaces,
      providedSurfaces
    )
    for field in source.fields:
      validateExpr(
        field.value, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )

  of ekClassRelation:
    validateExpr(
      source.relatedValue, currentModule, locals, typeParameters,
      classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
    )

  of ekFieldAccess:
    validateExpr(
      source.target, currentModule, locals, typeParameters,
      classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
    )

  of ekMethodCall:
    if source.receiver.kind == ekIdentifier and
        source.receiver.name notin locals and
        source.receiver.name in classes:
      requireClassVisibility(
        modules, classes,
        publicSurfaces, adoptedSurfaces, providedSurfaces,
        currentModule, source.receiver.name,
        source.receiver.span.sourcePath,
        source.receiver.span.line,
        source.receiver.span.column
      )
    else:
      validateExpr(
        source.receiver, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )

    for argument in source.methodArguments:
      validateExpr(
        argument, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )

  of ekUnary:
    validateExpr(
      source.operand, currentModule, locals, typeParameters,
      classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
    )

  of ekBinary:
    validateExpr(
      source.left, currentModule, locals, typeParameters,
      classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
    )
    validateExpr(
      source.right, currentModule, locals, typeParameters,
      classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
    )

## Validates architecture-sensitive names inside one statement block.
proc validateStmtBlock(
  statements: seq[Stmt],
  currentModule: string,
  initialLocals: HashSet[string],
  typeParameters: HashSet[string],
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  functions: FunctionOwnerRegistry,
  modules: ModuleRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry
) =
  var locals = initialLocals

  for statement in statements:
    case statement.kind
    of skVar:
      validateExpr(
        statement.initializer, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )
      locals.incl statement.name

    of skAssign:
      validateExpr(
        statement.target, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )
      validateExpr(
        statement.assignedValue, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )

    of skCall:
      validateExpr(
        statement.call, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )

    of skReturn:
      validateExpr(
        statement.value, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )

    of skIf:
      validateExpr(
        statement.condition, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )
      validateStmtBlock(
        statement.thenBranch, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )
      validateStmtBlock(
        statement.elseBranch, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )

    of skExists:
      validateExpr(
        statement.existsTarget, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )
      validateStmtBlock(
        statement.existsBody, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )

    of skWhile:
      validateExpr(
        statement.whileCondition, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )
      validateStmtBlock(
        statement.body, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )

    of skFor:
      var loopLocals = locals
      if not statement.forInitializer.isNil:
        validateStmtBlock(
          @[statement.forInitializer], currentModule, loopLocals,
          typeParameters, classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
        )
        if statement.forInitializer.kind == skVar:
          loopLocals.incl statement.forInitializer.name
      validateExpr(
        statement.forCondition, currentModule, loopLocals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )
      if not statement.forUpdate.isNil:
        validateStmtBlock(
          @[statement.forUpdate], currentModule, loopLocals,
          typeParameters, classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
        )
      validateStmtBlock(
        statement.forBody, currentModule, loopLocals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )

    of skBreak, skContinue:
      discard

## Validates one callable signature/body against module architecture.
proc validateCallable(
  source: FunctionDecl,
  currentModule: string,
  typeParameters: HashSet[string],
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  functions: FunctionOwnerRegistry,
  modules: ModuleRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  includeSelf: bool
) =
  var locals = initHashSet[string]()
  if includeSelf:
    locals.incl "self"

  for parameter in source.parameters:
    validateTypeRef(
      parameter.typeRef,
      currentModule,
      typeParameters,
      classes,
      interfaces,
      modules,
      publicSurfaces,
      adoptedSurfaces,
      providedSurfaces
    )
    locals.incl parameter.name

  if source.result.kind == frrSingle:
    validateTypeRef(
      source.result.typeRef,
      currentModule,
      typeParameters,
      classes,
      interfaces,
      modules,
      publicSurfaces,
      adoptedSurfaces,
      providedSurfaces
    )

  for clause in source.requires:
    validateExpr(
      clause, currentModule, locals, typeParameters,
      classes, interfaces, functions, modules,
      publicSurfaces, adoptedSurfaces, providedSurfaces
    )
  var ensureLocals = locals
  if source.result.kind == frrSingle:
    ensureLocals.incl "result"
  for clause in source.ensures:
    validateExpr(
      clause, currentModule, ensureLocals, typeParameters,
      classes, interfaces, functions, modules,
      publicSurfaces, adoptedSurfaces, providedSurfaces
    )

  validateStmtBlock(
    source.body, currentModule, locals, typeParameters,
    classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
  )

