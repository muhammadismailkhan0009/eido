## Specializes generic class templates into ordinary concrete AST classes before semantic analysis.
## Example: Box<Int> produces one concrete nominal class whose T references have become Int.

import std/[sets, tables]
import ../../diagnostics/errors
import ../../frontend/ast/[declarations, expressions, program, statements, type_references]
import ../../types/storage
import storage_specialization

type
  SpecializationRequest = object
    templateName: string
    concreteName: string
    arguments: seq[TypeRef]

  SpecializationContext = object
    templates: Table[string, ClassDecl]
    interfaceTemplates: Table[string, InterfaceDecl]
    queuedNames: HashSet[string]
    queue: seq[SpecializationRequest]

## Reports whether a source type name is a non-nominal built-in.
## Example: Int and String return true while Account returns false.
proc isBuiltInType(name: string): bool =
  name in ["Bool", "Byte", "Short", "Int", "Float", "Char", "String"]

## Creates the concrete post-specialization form of a type reference.
## Example: Box<Int> is retained as one flat nominal name after its arguments are specialized.
proc flatTypeRef(
  source: TypeRef,
  name: string,
  isOptional: bool = false
): TypeRef =
  TypeRef(
    span: source.span,
    name: name,
    arguments: @[],
    isOptional: isOptional
  )

## Builds the canonical source-facing name of one concrete generic specialization.
## Example: Pair with String and Int becomes Pair<String,Int>.
proc concreteName(baseName: string, arguments: seq[TypeRef]): string =
  result = baseName & "<"
  for index, argument in arguments:
    if index > 0:
      result.add ","
    result.add argument.name
    if argument.isOptional:
      result.add "?"
  result.add ">"

## Queues one concrete generic class exactly once.
## Example: two Box<Int> uses still produce one Box<Int> specialization.
proc queueInstantiation(
  context: var SpecializationContext,
  templateName, name: string,
  arguments: seq[TypeRef]
) =
  if name in context.queuedNames:
    return

  context.queuedNames.incl name
  context.queue.add SpecializationRequest(
    templateName: templateName,
    concreteName: name,
    arguments: arguments
  )

## Resolves type parameters and generic applications to concrete flat type references.
## Example: Box<T> under T=Int becomes the concrete nominal reference Box<Int>.
proc specializeTypeRef(
  context: var SpecializationContext,
  source: TypeRef,
  bindings: Table[string, TypeRef]
): TypeRef =
  if source.name in bindings:
    if source.arguments.len != 0:
      failAt(source.span, "generic type parameter '" & source.name &
        "' cannot receive type arguments")
    let bound = bindings[source.name]
    return flatTypeRef(
      source,
      bound.name,
      source.isOptional or bound.isOptional
    )

  if isBuiltInType(source.name):
    if source.arguments.len != 0:
      failAt(source.span, "built-in type '" & source.name &
        "' cannot receive type arguments")
    return flatTypeRef(source, source.name, source.isOptional)

  if isStorageTypeConstructor(source.name):
    if source.arguments.len != 1:
      failAt(source.span, "Storage expects exactly one type argument")
    let elementType = specializeTypeRef(context, source.arguments[0], bindings)
    # Concrete generic class applications are queued earlier during recursive
    # type specialization; interface applications and Storage descriptors are
    # not identity-bearing class element representations.
    var nominalClass = elementType.name in context.templates
    if not nominalClass:
      for request in context.queue:
        if request.concreteName == elementType.name and
            request.templateName in context.templates:
          nominalClass = true
          break
    if isConcreteStorageTypeName(elementType.name):
      failAt(source.arguments[0].span, "nested Storage capabilities are not supported as elements")
    if elementType.isOptional and not isBuiltInType(elementType.name) and nominalClass:
      failAt(source.arguments[0].span,
        "optional inline class Storage needs an explicit element-presence model; use Storage<Class>")
    if not isBuiltInType(elementType.name) and not nominalClass:
      failAt(
        source.arguments[0].span,
        "Storage element must be a primitive, String, or nominal class; got '" &
          elementType.name & "'"
      )

    if elementType.name != "Byte" and source.name notin context.templates:
      failAt(
        source.span,
        "typed Storage requires the SDK Storage<T> template"
      )

    let storageBase =
      if source.name in context.templates: source.name
      else: StorageTypeConstructorName
    let name = concreteName(storageBase, @[elementType])
    context.queueInstantiation(storageBase, name, @[elementType])

    if elementType.name != "Byte":
      let byteType = TypeRef(
        span: source.span,
        name: "Byte",
        arguments: @[],
        isOptional: false
      )
      context.queueInstantiation(
        storageBase,
        concreteName(storageBase, @[byteType]),
        @[byteType]
      )
    return flatTypeRef(source, name, source.isOptional)

  if source.name in context.interfaceTemplates:
    let interfaceTemplate = context.interfaceTemplates[source.name]
    if source.arguments.len != interfaceTemplate.typeParameters.len:
      failAt(
        source.span,
        "interface '" & source.name & "' expects " &
          $interfaceTemplate.typeParameters.len & " type arguments but got " &
          $source.arguments.len
      )

    if interfaceTemplate.typeParameters.len == 0:
      return flatTypeRef(source, source.name, source.isOptional)

    var arguments: seq[TypeRef]
    for argument in source.arguments:
      arguments.add specializeTypeRef(context, argument, bindings)

    let name = concreteName(source.name, arguments)
    context.queueInstantiation(source.name, name, arguments)
    return flatTypeRef(source, name, source.isOptional)

  if source.name notin context.templates:
    if source.arguments.len != 0:
      failAt(source.span, "unknown generic class '" & source.name & "'")
    return flatTypeRef(source, source.name, source.isOptional)

  let classTemplate = context.templates[source.name]
  if source.arguments.len != classTemplate.typeParameters.len:
    failAt(
      source.span,
      "class '" & source.name & "' expects " &
        $classTemplate.typeParameters.len & " type arguments but got " &
        $source.arguments.len
    )

  if classTemplate.typeParameters.len == 0:
    return flatTypeRef(source, source.name, source.isOptional)

  var arguments: seq[TypeRef]
  for argument in source.arguments:
    arguments.add specializeTypeRef(context, argument, bindings)

  let name = concreteName(source.name, arguments)
  context.queueInstantiation(source.name, name, arguments)
  flatTypeRef(source, name, source.isOptional)

## Declares recursive expression specialization used while cloning generic method bodies.
## Example: Box<T> construction is rewritten after T is bound.
proc specializeExpr(
  context: var SpecializationContext,
  source: Expr,
  bindings: Table[string, TypeRef]
): Expr

## Declares recursive statement specialization used while cloning generic method bodies.
## Example: a return containing Box<T> is rewritten with the concrete type argument.
proc specializeStmt(
  context: var SpecializationContext,
  source: Stmt,
  bindings: Table[string, TypeRef]
): Stmt

## Clones an expression while replacing every generic type use with its concrete specialization.
## Example: Box<T>.create inside Box<Int> becomes a class-qualified Box<Int> call.
proc specializeExpr(
  context: var SpecializationContext,
  source: Expr,
  bindings: Table[string, TypeRef]
): Expr =
  if source.isNil:
    return nil

  case source.kind
  of ekInteger, ekFloat, ekBoolean, ekChar, ekString, ekNone, ekIdentifier:
    return source

  of ekTypeReference:
    let concrete = specializeTypeRef(
      context, source.referencedTypeRef, bindings
    )
    return Expr(kind: ekIdentifier, span: source.span, name: concrete.name)

  of ekCall:
    var arguments: seq[Expr]
    for argument in source.arguments:
      arguments.add specializeExpr(context, argument, bindings)
    return Expr(
      kind: ekCall,
      span: source.span,
      callee: source.callee,
      arguments: arguments
    )

  of ekConstruct:
    var fields: seq[ConstructionField]
    for field in source.fields:
      fields.add ConstructionField(
        span: field.span,
        name: field.name,
        value: specializeExpr(context, field.value, bindings)
      )
    return Expr(
      kind: ekConstruct,
      span: source.span,
      constructionTypeRef: specializeTypeRef(
        context, source.constructionTypeRef, bindings
      ),
      fields: fields
    )

  of ekClassRelation:
    return Expr(
      kind: ekClassRelation,
      span: source.span,
      relationKind: source.relationKind,
      relatedValue: specializeExpr(context, source.relatedValue, bindings)
    )

  of ekFieldAccess:
    return Expr(
      kind: ekFieldAccess,
      span: source.span,
      target: specializeExpr(context, source.target, bindings),
      fieldName: source.fieldName
    )

  of ekMethodCall:
    var arguments: seq[Expr]
    for argument in source.methodArguments:
      arguments.add specializeExpr(context, argument, bindings)
    return Expr(
      kind: ekMethodCall,
      span: source.span,
      receiver: specializeExpr(context, source.receiver, bindings),
      methodName: source.methodName,
      methodArguments: arguments
    )

  of ekUnary:
    return Expr(
      kind: ekUnary,
      span: source.span,
      unaryOp: source.unaryOp,
      operand: specializeExpr(context, source.operand, bindings)
    )

  of ekBinary:
    return Expr(
      kind: ekBinary,
      span: source.span,
      op: source.op,
      left: specializeExpr(context, source.left, bindings),
      right: specializeExpr(context, source.right, bindings)
    )

## Clones one statement and recursively specializes every contained expression.
## Example: a var initialized by Pair<T, Int> receives the bound concrete class type.
proc specializeStmt(
  context: var SpecializationContext,
  source: Stmt,
  bindings: Table[string, TypeRef]
): Stmt =
  case source.kind
  of skVar:
    Stmt(
      kind: skVar,
      span: source.span,
      name: source.name,
      initializer: specializeExpr(context, source.initializer, bindings)
    )
  of skAssign:
    Stmt(
      kind: skAssign,
      span: source.span,
      target: specializeExpr(context, source.target, bindings),
      assignedValue: specializeExpr(context, source.assignedValue, bindings)
    )
  of skCall:
    Stmt(
      kind: skCall,
      span: source.span,
      call: specializeExpr(context, source.call, bindings)
    )
  of skReturn:
    Stmt(
      kind: skReturn,
      span: source.span,
      value: specializeExpr(context, source.value, bindings)
    )
  of skExists:
    var body: seq[Stmt]
    for statement in source.existsBody:
      body.add specializeStmt(context, statement, bindings)
    Stmt(
      kind: skExists,
      span: source.span,
      existsTarget: specializeExpr(context, source.existsTarget, bindings),
      existsBody: body
    )
  of skIf:
    var thenBranch: seq[Stmt]
    var elseBranch: seq[Stmt]
    for statement in source.thenBranch:
      thenBranch.add specializeStmt(context, statement, bindings)
    for statement in source.elseBranch:
      elseBranch.add specializeStmt(context, statement, bindings)
    Stmt(
      kind: skIf,
      span: source.span,
      condition: specializeExpr(context, source.condition, bindings),
      thenBranch: thenBranch,
      elseBranch: elseBranch
    )
  of skWhile:
    var body: seq[Stmt]
    for statement in source.body:
      body.add specializeStmt(context, statement, bindings)
    Stmt(
      kind: skWhile,
      span: source.span,
      whileCondition: specializeExpr(
        context, source.whileCondition, bindings
      ),
      body: body
    )
  of skFor:
    var body: seq[Stmt]
    for statement in source.forBody:
      body.add specializeStmt(context, statement, bindings)
    Stmt(
      kind: skFor,
      span: source.span,
      forInitializer: specializeStmt(
        context, source.forInitializer, bindings
      ),
      forCondition: specializeExpr(
        context, source.forCondition, bindings
      ),
      forUpdate: specializeStmt(context, source.forUpdate, bindings),
      forBody: body
    )
  of skBreak:
    Stmt(kind: skBreak, span: source.span)
  of skContinue:
    Stmt(kind: skContinue, span: source.span)

## Clones a callable signature/body under one concrete class-type binding environment.
## Example: a Box<T> method in Box<Int> receives Int parameters/results where it used T.
proc specializeFunction(
  context: var SpecializationContext,
  source: FunctionDecl,
  bindings: Table[string, TypeRef]
): FunctionDecl =
  var parameters: seq[Parameter]
  for parameter in source.parameters:
    parameters.add Parameter(
      span: parameter.span,
      name: parameter.name,
      typeRef: specializeTypeRef(context, parameter.typeRef, bindings)
    )

  var functionResult: FunctionResultRef
  case source.result.kind
  of frrNone:
    functionResult = FunctionResultRef(kind: frrNone)
  of frrSingle:
    functionResult = FunctionResultRef(
      kind: frrSingle,
      typeRef: specializeTypeRef(
        context, source.result.typeRef, bindings
      )
    )

  var requires: seq[Expr]
  for clause in source.requires:
    requires.add specializeExpr(context, clause, bindings)

  var ensures: seq[Expr]
  for clause in source.ensures:
    ensures.add specializeExpr(context, clause, bindings)

  var body: seq[Stmt]
  for statement in source.body:
    body.add specializeStmt(context, statement, bindings)

  FunctionDecl(
    span: source.span,
    name: source.name,
    moduleName: source.moduleName,
    isNative: source.isNative,
    parameters: parameters,
    result: functionResult,
    requires: requires,
    ensures: ensures,
    body: body
  )


## Materializes one concrete class AST from a generic class template.
## Example: Box<T> plus Int becomes the ordinary concrete class Box<Int>.
proc specializeClass(
  context: var SpecializationContext,
  source: ClassDecl,
  arguments: seq[TypeRef],
  name: string
): ClassDecl =
  var bindings = initTable[string, TypeRef]()
  for index, parameter in source.typeParameters:
    bindings[parameter.name] = arguments[index]

  var fields: seq[FieldDecl]
  for field in source.fields:
    fields.add FieldDecl(
      span: field.span,
      name: field.name,
      typeRef: specializeTypeRef(context, field.typeRef, bindings),
      isClassOwned: field.isClassOwned,
      ownerName:
        if field.isClassOwned: name
        else: "",
      initializer:
        if field.initializer.isNil: nil
        else: specializeExpr(context, field.initializer, bindings)
    )

  var invariants: seq[Expr]
  for clause in source.invariants:
    invariants.add specializeExpr(context, clause, bindings)

  var methods: seq[FunctionDecl]
  for methodDecl in source.methods:
    if source.typeParameters.len > 0 and methodDecl.isNative and
        not (
          isSdkStorageDeclaration(source.moduleName, source.name) and
          methodDecl.name in ["size", "alignment"]
        ):
      failAt(
        methodDecl.span,
        "generic classes cannot declare native functions in v0"
      )
    methods.add specializeFunction(context, methodDecl, bindings)

  var implementedInterfaces: seq[TypeRef]
  for implemented in source.implements:
    implementedInterfaces.add specializeTypeRef(
      context, implemented, bindings
    )

  ClassDecl(
    span: source.span,
    name: name,
    moduleName: source.moduleName,
    typeParameters: @[],
    implements: implementedInterfaces,
    fields: fields,
    invariants: invariants,
    methods: methods
  )

## Materializes one concrete interface AST from a generic interface template.
proc specializeInterface(
  context: var SpecializationContext,
  source: InterfaceDecl,
  arguments: seq[TypeRef],
  name: string
): InterfaceDecl =
  var bindings = initTable[string, TypeRef]()
  for index, parameter in source.typeParameters:
    bindings[parameter.name] = arguments[index]

  var methods: seq[FunctionDecl]
  for methodDecl in source.methods:
    methods.add specializeFunction(context, methodDecl, bindings)

  InterfaceDecl(
    span: source.span,
    name: name,
    moduleName: source.moduleName,
    typeParameters: @[],
    extends: source.extends,
    methods: methods
  )

## Validates generic arity and referenced type names without creating specializations.
## Example: Pair<Int> is rejected when Pair declares two type parameters.
proc validateTypeRef(
  context: SpecializationContext,
  source: TypeRef,
  typeParameters: HashSet[string]
) =
  if source.name in typeParameters:
    if source.arguments.len != 0:
      failAt(source.span, "generic type parameter '" & source.name &
        "' cannot receive type arguments")
    return

  if isBuiltInType(source.name):
    if source.arguments.len != 0:
      failAt(source.span, "built-in type '" & source.name &
        "' cannot receive type arguments")
    return

  if isStorageTypeConstructor(source.name):
    if source.arguments.len != 1:
      failAt(source.span, "Storage expects exactly one type argument")
    validateTypeRef(context, source.arguments[0], typeParameters)
    return

  if source.name in context.interfaceTemplates:
    let interfaceTemplate = context.interfaceTemplates[source.name]
    if source.arguments.len != interfaceTemplate.typeParameters.len:
      failAt(
        source.span,
        "interface '" & source.name & "' expects " &
          $interfaceTemplate.typeParameters.len & " type arguments but got " &
          $source.arguments.len
      )
    for argument in source.arguments:
      validateTypeRef(context, argument, typeParameters)
    return

  if source.name notin context.templates:
    failAt(source.span, "unknown type '" & source.name & "'")

  let classTemplate = context.templates[source.name]
  if source.arguments.len != classTemplate.typeParameters.len:
    failAt(
      source.span,
      "class '" & source.name & "' expects " &
        $classTemplate.typeParameters.len & " type arguments but got " &
        $source.arguments.len
    )

  for argument in source.arguments:
    validateTypeRef(context, argument, typeParameters)

## Declares recursive type-reference validation for expressions in generic templates.
## Example: an unused template still rejects Missing<Int> in a construction.
proc validateExprTypeRefs(
  context: SpecializationContext,
  source: Expr,
  typeParameters: HashSet[string]
)

## Declares recursive type-reference validation for statements in generic templates.
## Example: nested control flow is scanned for malformed generic applications.
proc validateStmtTypeRefs(
  context: SpecializationContext,
  source: Stmt,
  typeParameters: HashSet[string]
)

## Validates every explicit type reference nested inside one expression.
## Example: Box<Int>.create validates Box arity even before Box<Int> is instantiated.
proc validateExprTypeRefs(
  context: SpecializationContext,
  source: Expr,
  typeParameters: HashSet[string]
) =
  if source.isNil:
    return

  case source.kind
  of ekInteger, ekFloat, ekBoolean, ekChar, ekString, ekNone, ekIdentifier:
    discard
  of ekTypeReference:
    validateTypeRef(context, source.referencedTypeRef, typeParameters)
  of ekCall:
    for argument in source.arguments:
      validateExprTypeRefs(context, argument, typeParameters)
  of ekConstruct:
    validateTypeRef(context, source.constructionTypeRef, typeParameters)
    for field in source.fields:
      validateExprTypeRefs(context, field.value, typeParameters)
  of ekClassRelation:
    validateExprTypeRefs(context, source.relatedValue, typeParameters)
  of ekFieldAccess:
    validateExprTypeRefs(context, source.target, typeParameters)
  of ekMethodCall:
    validateExprTypeRefs(context, source.receiver, typeParameters)
    for argument in source.methodArguments:
      validateExprTypeRefs(context, argument, typeParameters)
  of ekUnary:
    validateExprTypeRefs(context, source.operand, typeParameters)
  of ekBinary:
    validateExprTypeRefs(context, source.left, typeParameters)
    validateExprTypeRefs(context, source.right, typeParameters)

## Validates type references recursively across one statement tree.
## Example: generic constructions inside if/while/for bodies are checked in unused templates.
proc validateStmtTypeRefs(
  context: SpecializationContext,
  source: Stmt,
  typeParameters: HashSet[string]
) =
  case source.kind
  of skVar:
    validateExprTypeRefs(context, source.initializer, typeParameters)
  of skAssign:
    validateExprTypeRefs(context, source.target, typeParameters)
    validateExprTypeRefs(context, source.assignedValue, typeParameters)
  of skCall:
    validateExprTypeRefs(context, source.call, typeParameters)
  of skReturn:
    validateExprTypeRefs(context, source.value, typeParameters)
  of skExists:
    validateExprTypeRefs(context, source.existsTarget, typeParameters)
    for statement in source.existsBody:
      validateStmtTypeRefs(context, statement, typeParameters)
  of skIf:
    validateExprTypeRefs(context, source.condition, typeParameters)
    for statement in source.thenBranch:
      validateStmtTypeRefs(context, statement, typeParameters)
    for statement in source.elseBranch:
      validateStmtTypeRefs(context, statement, typeParameters)
  of skWhile:
    validateExprTypeRefs(context, source.whileCondition, typeParameters)
    for statement in source.body:
      validateStmtTypeRefs(context, statement, typeParameters)
  of skFor:
    validateStmtTypeRefs(context, source.forInitializer, typeParameters)
    validateExprTypeRefs(context, source.forCondition, typeParameters)
    validateStmtTypeRefs(context, source.forUpdate, typeParameters)
    for statement in source.forBody:
      validateStmtTypeRefs(context, statement, typeParameters)
  of skBreak, skContinue:
    discard

## Validates callable signature/body type references against visible class type parameters.
## Example: T is accepted inside Box<T> while Unknown is rejected.
proc validateFunctionTypes(
  context: SpecializationContext,
  source: FunctionDecl,
  typeParameters: HashSet[string]
) =
  for parameter in source.parameters:
    validateTypeRef(context, parameter.typeRef, typeParameters)

  if source.result.kind == frrSingle:
    validateTypeRef(context, source.result.typeRef, typeParameters)

  for clause in source.requires:
    validateExprTypeRefs(context, clause, typeParameters)
  for clause in source.ensures:
    validateExprTypeRefs(context, clause, typeParameters)

  for statement in source.body:
    validateStmtTypeRefs(context, statement, typeParameters)

## Validates one generic class template independently of whether it is instantiated.
## Example: duplicate T parameters and duplicate members are rejected in unused Box<T>.
proc validateTemplateShape(
  context: SpecializationContext,
  source: ClassDecl
) =
  var parameterNames = initHashSet[string]()
  for parameter in source.typeParameters:
    if parameter.name in parameterNames:
      failAt(
        parameter.span,
        "duplicate generic type parameter '" & parameter.name & "'"
      )
    parameterNames.incl parameter.name

  for implemented in source.implements:
    validateTypeRef(context, implemented, parameterNames)

  var fieldNames = initHashSet[string]()
  for field in source.fields:
    if field.name in fieldNames:
      failAt(field.span, "duplicate field '" & field.name & "'")
    fieldNames.incl field.name
    validateTypeRef(context, field.typeRef, parameterNames)
    if field.isClassOwned and not field.initializer.isNil:
      validateExprTypeRefs(context, field.initializer, parameterNames)

  for clause in source.invariants:
    validateExprTypeRefs(context, clause, parameterNames)

  var methodNames = initHashSet[string]()
  for methodDecl in source.methods:
    if methodDecl.name in methodNames:
      failAt(
        methodDecl.span,
        "duplicate method '" & methodDecl.name &
          "' in class '" & source.name & "'"
      )
    methodNames.incl methodDecl.name

    if source.typeParameters.len > 0 and methodDecl.isNative and
        not (
          isSdkStorageDeclaration(source.moduleName, source.name) and
          methodDecl.name in ["size", "alignment"]
        ):
      failAt(
        methodDecl.span,
        "generic classes cannot declare native functions in v0"
      )

    validateFunctionTypes(context, methodDecl, parameterNames)

## Validates one generic interface template independently of instantiation.
proc validateInterfaceTemplateShape(
  context: SpecializationContext,
  source: InterfaceDecl
) =
  # Parent interface names currently carry no type arguments. Do not let a
  # raw generic parent escape validation simply because the child is unused.
  for parent in source.extends:
    if parent in context.interfaceTemplates and
        context.interfaceTemplates[parent].typeParameters.len > 0:
      failAt(
        source.span,
        "extending a generic interface requires generic interface inheritance, " &
        "which is not supported yet: '" & parent & "'"
      )

  var parameterNames = initHashSet[string]()
  for parameter in source.typeParameters:
    if parameter.name in parameterNames:
      failAt(
        parameter.span,
        "duplicate generic type parameter '" & parameter.name & "'"
      )
    parameterNames.incl parameter.name

  var methodNames = initHashSet[string]()
  for methodDecl in source.methods:
    if methodDecl.name in methodNames:
      failAt(
        methodDecl.span,
        "duplicate method '" & methodDecl.name &
          "' in interface '" & source.name & "'"
      )
    methodNames.incl methodDecl.name
    validateFunctionTypes(context, methodDecl, parameterNames)

## Verifies layout targets and template parameters before specialization.
## Layouts do not cause class instantiations until layout selection exists.
proc validateLayoutTemplates(context: SpecializationContext, layouts: seq[LayoutDecl]) =
  var seen = initHashSet[string]()
  for layout in layouts:
    if layout.name in seen:
      failAt(layout.span, "duplicate layout declaration '" & layout.name & "'")
    seen.incl layout.name

    if layout.targetType.name notin context.templates:
      failAt(
        layout.targetType.span,
        "layout '" & layout.name & "' must target a class, got '" &
          layout.targetType.name & "'"
      )

    let target = context.templates[layout.targetType.name]
    if layout.typeParameters.len != target.typeParameters.len or
        layout.targetType.arguments.len != target.typeParameters.len:
      failAt(layout.targetType.span,
        "layout '" & layout.name & "' must declare the same number of generic parameters as class '" &
          target.name & "'")

    var parameters = initHashSet[string]()
    for index, parameter in layout.typeParameters:
      if parameter.name in parameters:
        failAt(parameter.span, "duplicate layout type parameter '" & parameter.name & "'")
      parameters.incl parameter.name
      let argument = layout.targetType.arguments[index]
      if argument.isOptional or argument.arguments.len != 0 or
          argument.name != parameter.name:
        failAt(argument.span,
          "layout target generic arguments must match its declared type parameters in order")

## Specializes one compile-time layout body and class association without
## selecting or evaluating that layout.
proc specializeLayout(
  context: var SpecializationContext,
  source: LayoutDecl,
  name, concreteTarget: string,
  bindings: Table[string, TypeRef]
): LayoutDecl =
  var body: seq[Stmt]
  for statement in source.body:
    body.add specializeStmt(context, statement, bindings)
  LayoutDecl(
    span: source.span,
    name: name,
    moduleName: source.moduleName,
    targetType: flatTypeRef(source.targetType, concreteTarget),
    body: body,
    bodySource: source.bodySource
  )

## Lowers generic source templates/applications into concrete nominal declarations.
## Example: Box<Int> and Readable<Int> become ordinary specialized nominals before normal semantics.
proc specializeGenericClasses*(source: Program): Program =
  var context = SpecializationContext(
    templates: initTable[string, ClassDecl](),
    interfaceTemplates: initTable[string, InterfaceDecl](),
    queuedNames: initHashSet[string](),
    queue: @[]
  )

  for interfaceDecl in source.interfaces:
    if interfaceDecl.name in context.interfaceTemplates:
      failAt(interfaceDecl.span, "duplicate interface '" & interfaceDecl.name & "'")
    context.interfaceTemplates[interfaceDecl.name] = interfaceDecl

  for classDecl in source.classes:
    if isStorageTypeConstructor(classDecl.name) and
        not isSdkStorageDeclaration(classDecl.moduleName, classDecl.name):
      failAt(
        classDecl.span,
        "type name 'Storage' is reserved by the Eido SDK"
      )
    if classDecl.name in context.templates:
      failAt(classDecl.span, "duplicate class '" & classDecl.name & "'")
    if classDecl.name in context.interfaceTemplates:
      failAt(classDecl.span, "type name '" & classDecl.name & "' is already used by an interface")
    context.templates[classDecl.name] = classDecl

  for interfaceDecl in source.interfaces:
    validateInterfaceTemplateShape(context, interfaceDecl)

  for classDecl in source.classes:
    validateTemplateShape(context, classDecl)

  validateLayoutTemplates(context, source.layouts)

  var noTypeParameters = initHashSet[string]()
  for fn in source.functions:
    validateFunctionTypes(context, fn, noTypeParameters)

  var emptyBindings = initTable[string, TypeRef]()

  for interfaceDecl in source.interfaces:
    if interfaceDecl.typeParameters.len == 0:
      result.interfaces.add specializeInterface(
        context, interfaceDecl, @[], interfaceDecl.name
      )

  for classDecl in source.classes:
    if classDecl.typeParameters.len == 0:
      result.classes.add specializeClass(
        context, classDecl, @[], classDecl.name
      )

  for fn in source.functions:
    result.functions.add specializeFunction(
      context, fn, emptyBindings
    )

  for layout in source.layouts:
    if layout.typeParameters.len == 0:
      result.layouts.add specializeLayout(
        context, layout, layout.name, layout.targetType.name, emptyBindings
      )

  var index = 0
  while index < context.queue.len:
    let request = context.queue[index]

    if isStorageTypeConstructor(request.templateName) and
        request.arguments.len == 1 and request.arguments[0].name == "Byte":
      let moduleName =
        if request.templateName in context.templates:
          context.templates[request.templateName].moduleName
        else:
          ""
      result.classes.add specializeRawStorageClass(
        request.concreteName,
        request.arguments[0],
        moduleName
      )
    elif request.templateName in context.interfaceTemplates:
      result.interfaces.add specializeInterface(
        context,
        context.interfaceTemplates[request.templateName],
        request.arguments,
        request.concreteName
      )
    elif request.templateName in context.templates:
      let classTemplate = context.templates[request.templateName]
      var concrete = specializeClass(
        context,
        classTemplate,
        request.arguments,
        request.concreteName
      )
      if isStorageTypeConstructor(request.templateName):
        let byteType = TypeRef(
          span: request.arguments[0].span,
          name: "Byte",
          arguments: @[],
          isOptional: false
        )
        concrete.addTypedStorageBridges(
          request.arguments[0],
          concreteName(request.templateName, @[byteType])
        )
      result.classes.add concrete
    else:
      failAt(
        request.arguments[0].span,
        "unknown generic nominal template '" & request.templateName & "'"
      )
    inc index

  # Reuse only already-instantiated concrete class applications. Declaring a
  # layout has no effect on the set of classes compiled into the program.
  for layout in source.layouts:
    if layout.typeParameters.len == 0:
      continue
    for request in context.queue:
      if request.templateName != layout.targetType.name:
        continue
      var bindings = initTable[string, TypeRef]()
      for paramIndex, parameter in layout.typeParameters:
        bindings[parameter.name] = request.arguments[paramIndex]
      result.layouts.add specializeLayout(
        context,
        layout,
        layout.name & request.concreteName[request.templateName.len .. ^1],
        request.concreteName,
        bindings
      )
