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
    interfaceNames: HashSet[string]
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
    if not isBuiltInType(elementType.name):
      failAt(
        source.arguments[0].span,
        "Storage currently supports primitive and String element types; got '" &
          elementType.name & "'"
      )
    let name = concreteName(StorageTypeConstructorName, @[elementType])
    context.queueInstantiation(
      StorageTypeConstructorName, name, @[elementType]
    )
    if elementType.name != "Byte":
      let byteType = TypeRef(
        span: source.span,
        name: "Byte",
        arguments: @[],
        isOptional: false
      )
      context.queueInstantiation(
        StorageTypeConstructorName,
        concreteName(StorageTypeConstructorName, @[byteType]),
        @[byteType]
      )
    return flatTypeRef(source, name, source.isOptional)

  if source.name in context.interfaceNames:
    if source.arguments.len != 0:
      failAt(source.span, "interfaces are non-generic in v0")
    return flatTypeRef(source, source.name, source.isOptional)

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
      typeRef: specializeTypeRef(context, field.typeRef, bindings)
    )

  var invariants: seq[Expr]
  for clause in source.invariants:
    invariants.add specializeExpr(context, clause, bindings)

  var methods: seq[FunctionDecl]
  for methodDecl in source.methods:
    if source.typeParameters.len > 0 and methodDecl.isNative:
      failAt(
        methodDecl.span,
        "generic classes cannot declare native functions in v0"
      )
    methods.add specializeFunction(context, methodDecl, bindings)

  ClassDecl(
    span: source.span,
    name: name,
    moduleName: source.moduleName,
    typeParameters: @[],
    implements: source.implements,
    fields: fields,
    invariants: invariants,
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

  if source.name in context.interfaceNames:
    if source.arguments.len != 0:
      failAt(source.span, "interfaces are non-generic in v0")
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

  var fieldNames = initHashSet[string]()
  for field in source.fields:
    if field.name in fieldNames:
      failAt(field.span, "duplicate field '" & field.name & "'")
    fieldNames.incl field.name
    validateTypeRef(context, field.typeRef, parameterNames)

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

    if source.typeParameters.len > 0 and methodDecl.isNative:
      failAt(
        methodDecl.span,
        "generic classes cannot declare native functions in v0"
      )

    validateFunctionTypes(context, methodDecl, parameterNames)

## Lowers generic source templates/applications into a program containing concrete classes only.
## Example: one Box<Int> use emits one specialized Box<Int> AST class before normal semantics.
proc specializeGenericClasses*(source: Program): Program =
  var context = SpecializationContext(
    templates: initTable[string, ClassDecl](),
    interfaceNames: initHashSet[string](),
    queuedNames: initHashSet[string](),
    queue: @[]
  )

  for interfaceDecl in source.interfaces:
    if interfaceDecl.name in context.interfaceNames:
      failAt(interfaceDecl.span, "duplicate interface '" & interfaceDecl.name & "'")
    context.interfaceNames.incl interfaceDecl.name

  for classDecl in source.classes:
    if isStorageTypeConstructor(classDecl.name):
      failAt(
        classDecl.span,
        "type name 'Storage' is reserved by the Eido toolchain"
      )
    if classDecl.name in context.templates:
      failAt(classDecl.span, "duplicate class '" & classDecl.name & "'")
    if classDecl.name in context.interfaceNames:
      failAt(classDecl.span, "type name '" & classDecl.name & "' is already used by an interface")
    context.templates[classDecl.name] = classDecl

  for classDecl in source.classes:
    validateTemplateShape(context, classDecl)

  var noTypeParameters = initHashSet[string]()
  for interfaceDecl in source.interfaces:
    for methodDecl in interfaceDecl.methods:
      validateFunctionTypes(context, methodDecl, noTypeParameters)

  for fn in source.functions:
    validateFunctionTypes(context, fn, noTypeParameters)

  var emptyBindings = initTable[string, TypeRef]()

  for interfaceDecl in source.interfaces:
    var methods: seq[FunctionDecl]
    for methodDecl in interfaceDecl.methods:
      methods.add specializeFunction(context, methodDecl, emptyBindings)
    result.interfaces.add InterfaceDecl(
      span: interfaceDecl.span,
      name: interfaceDecl.name,
      moduleName: interfaceDecl.moduleName,
      extends: interfaceDecl.extends,
      methods: methods
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

  var index = 0
  while index < context.queue.len:
    let request = context.queue[index]
    if request.templateName == StorageTypeConstructorName:
      result.classes.add specializeStorageClass(
        request.concreteName, request.arguments[0]
      )
    else:
      let classTemplate = context.templates[request.templateName]
      result.classes.add specializeClass(
        context,
        classTemplate,
        request.arguments,
        request.concreteName
      )
    inc index
