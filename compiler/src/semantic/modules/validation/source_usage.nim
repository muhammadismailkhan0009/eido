## Validates one declared type reference against concrete-class and interface boundaries.
proc validateTypeRef(
  source: TypeRef,
  currentModule: string,
  typeParameters: HashSet[string],
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  modules: ModuleRegistry,
  rootModule: string
) =
  if source.name notin typeParameters:
    if source.name in classes:
      let owner = classes[source.name].moduleName
      if owner != currentModule:
        failAt(
          source.span,
          "concrete class type '" & source.name & "' belongs to module '" &
            owner & "' and cannot cross into module '" & currentModule & "'"
        )
    elif source.name in interfaces:
      requireInterfaceVisibility(
        modules,
        interfaces,
        rootModule,
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
      rootModule
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
  rootModule: string
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
  rootModule: string
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
  rootModule: string
) =
  if source.isNil:
    return

  case source.kind
  of ekInteger, ekFloat, ekBoolean, ekChar, ekString, ekNone, ekIdentifier:
    discard

  of ekTypeReference:
    let typeRef = source.referencedTypeRef
    if typeRef.name in classes and typeRef.name notin typeParameters:
      requireStaticVisibility(
        modules,
        classes,
        rootModule,
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
        rootModule
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
        classes, interfaces, functions, modules, rootModule
      )

  of ekConstruct:
    validateTypeRef(
      source.constructionTypeRef,
      currentModule,
      typeParameters,
      classes,
      interfaces,
      modules,
      rootModule
    )
    for field in source.fields:
      validateExpr(
        field.value, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )

  of ekClassRelation:
    validateExpr(
      source.relatedValue, currentModule, locals, typeParameters,
      classes, interfaces, functions, modules, rootModule
    )

  of ekFieldAccess:
    validateExpr(
      source.target, currentModule, locals, typeParameters,
      classes, interfaces, functions, modules, rootModule
    )

  of ekMethodCall:
    if source.receiver.kind == ekIdentifier and
        source.receiver.name notin locals and
        source.receiver.name in classes:
      requireStaticVisibility(
        modules, classes, rootModule, currentModule, source.receiver.name,
        source.receiver.span.sourcePath,
        source.receiver.span.line,
        source.receiver.span.column
      )
    else:
      validateExpr(
        source.receiver, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )

    for argument in source.methodArguments:
      validateExpr(
        argument, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )

  of ekUnary:
    validateExpr(
      source.operand, currentModule, locals, typeParameters,
      classes, interfaces, functions, modules, rootModule
    )

  of ekBinary:
    validateExpr(
      source.left, currentModule, locals, typeParameters,
      classes, interfaces, functions, modules, rootModule
    )
    validateExpr(
      source.right, currentModule, locals, typeParameters,
      classes, interfaces, functions, modules, rootModule
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
  rootModule: string
) =
  var locals = initialLocals

  for statement in statements:
    case statement.kind
    of skVar:
      validateExpr(
        statement.initializer, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )
      locals.incl statement.name

    of skAssign:
      validateExpr(
        statement.target, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )
      validateExpr(
        statement.assignedValue, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )

    of skCall:
      validateExpr(
        statement.call, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )

    of skReturn:
      validateExpr(
        statement.value, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )

    of skIf:
      validateExpr(
        statement.condition, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )
      validateStmtBlock(
        statement.thenBranch, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )
      validateStmtBlock(
        statement.elseBranch, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )

    of skExists:
      validateExpr(
        statement.existsTarget, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )
      validateStmtBlock(
        statement.existsBody, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )

    of skWhile:
      validateExpr(
        statement.whileCondition, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )
      validateStmtBlock(
        statement.body, currentModule, locals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )

    of skFor:
      var loopLocals = locals
      if not statement.forInitializer.isNil:
        validateStmtBlock(
          @[statement.forInitializer], currentModule, loopLocals,
          typeParameters, classes, interfaces, functions, modules, rootModule
        )
        if statement.forInitializer.kind == skVar:
          loopLocals.incl statement.forInitializer.name
      validateExpr(
        statement.forCondition, currentModule, loopLocals, typeParameters,
        classes, interfaces, functions, modules, rootModule
      )
      if not statement.forUpdate.isNil:
        validateStmtBlock(
          @[statement.forUpdate], currentModule, loopLocals,
          typeParameters, classes, interfaces, functions, modules, rootModule
        )
      validateStmtBlock(
        statement.forBody, currentModule, loopLocals, typeParameters,
        classes, interfaces, functions, modules, rootModule
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
  rootModule: string,
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
      rootModule
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
      rootModule
    )

  validateStmtBlock(
    source.body, currentModule, locals, typeParameters,
    classes, interfaces, functions, modules, rootModule
  )

