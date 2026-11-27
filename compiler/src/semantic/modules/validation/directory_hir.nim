## Resolved-use checks complement name binding: inferred receiver types,
## returned objects and field access must not bypass internal adoption.

type
  DirectoryUseContext = object
    modules: ModuleRegistry
    sourceModules: Table[string, string]
    targets: Table[string, SourceSpan]
    functions: Table[string, SourceSpan]
    layouts: Table[string, SourceSpan]
    localTypes: Table[int, EidoType]
    templateArguments: HashSet[string]

## Reduces a specialized nominal to its original declaration identity.
proc directoryNominalBase(name: string): string =
  let bracket = name.find('<')
  if bracket < 0: name else: name[0 ..< bracket]

## Extracts the nominal tokens of a specialized type, including nested arguments.
proc directoryTypeNames(name: string): seq[string] =
  for token in name.split({'<', '>', ',', '?', ' '}):
    if token.len > 0: result.add token

## Records types selected by the caller, not referenced by the generic author.
proc setDirectoryTemplate(context: var DirectoryUseContext, name: string) =
  context.templateArguments.clear()
  let bracket = name.find('<')
  if bracket >= 0:
    for token in directoryTypeNames(name[bracket .. ^1]):
      context.templateArguments.incl token

## Checks only same-module uses; existing inter-module API rules govern others.
proc checkDirectoryTarget(context: DirectoryUseContext, key: string,
    targets: Table[string, SourceSpan], span: SourceSpan) =
  if key notin targets or span.sourcePath notin context.sourceModules: return
  let target = targets[key]
  let owner = context.sourceModules.getOrDefault(span.sourcePath)
  if owner.len > 0 and context.sourceModules.getOrDefault(target.sourcePath) == owner:
    requireDirectoryAccess(context.modules, owner, key, target, span)

## Checks the declaration of a nominal type.
proc checkDirectoryTarget(context: DirectoryUseContext, name: string, span: SourceSpan) =
  context.checkDirectoryTarget(directoryNominalBase(name), context.targets, span)

## Checks a resolved type, including nested nominal arguments. Types selected
## through a generic parameter belong to the caller's choice, so the template
## is not charged for merely carrying those values. Explicit source references
## and member owners are checked independently.
proc checkDirectoryType(context: DirectoryUseContext, typ: EidoType, span: SourceSpan,
    inferred = false) =
  let name = case typ.kind
    of etkClass: typ.className
    of etkInterface: typ.interfaceName
    else: return
  if inferred:
    for key in directoryTypeNames(name):
      if key notin context.templateArguments:
        context.checkDirectoryTarget(key, context.targets, span)
  else:
    context.checkDirectoryTarget(name, span)

## Declares the recursive resolved expression visitor.
proc checkDirectoryExpr(context: DirectoryUseContext, expr: HirExpr)

## Checks a resolved top-level call and its operands.
proc checkDirectoryCall(context: DirectoryUseContext, call: HirCall) =
  context.checkDirectoryTarget(call.functionName, context.functions, call.span)
  if call.result.kind == frSingle:
    context.checkDirectoryType(call.result.typ, call.span, inferred = true)
  for arg in call.arguments: context.checkDirectoryExpr(arg)

## Checks the actual method owner, including calls on inferred receiver values.
proc checkDirectoryMethod(context: DirectoryUseContext, call: HirMethodCall) =
  context.checkDirectoryType(call.ownerType, call.span)
  if call.result.kind == frSingle:
    context.checkDirectoryType(call.result.typ, call.span, inferred = true)
  if call.kind == mkInstance: context.checkDirectoryExpr(call.receiver)
  for arg in call.arguments: context.checkDirectoryExpr(arg)

## Walks resolved expressions without charging generic parameter substitutions
## to the template author. Explicit generic references were checked in the AST.
proc checkDirectoryExpr(context: DirectoryUseContext, expr: HirExpr) =
  if expr.isNil: return
  context.checkDirectoryType(expr.typ, expr.span, inferred = true)
  case expr.kind
  of hekOptionalSome, hekOptionalGet:
    context.checkDirectoryExpr(expr.optionalValue)
  of hekCall: context.checkDirectoryCall(expr.call)
  of hekConstruct:
    context.checkDirectoryTarget(expr.constructedTypeName, expr.span)
    for field in expr.fields: context.checkDirectoryExpr(field.value)
  of hekClassRelation: context.checkDirectoryExpr(expr.relatedValue)
  of hekInterfaceConvert: context.checkDirectoryExpr(expr.interfaceValue)
  of hekFieldAccess:
    context.checkDirectoryType(expr.target.typ, expr.span)
    context.checkDirectoryExpr(expr.target)
  of hekClassFieldAccess: context.checkDirectoryType(expr.classFieldOwner, expr.span)
  of hekMethodCall: context.checkDirectoryMethod(expr.methodCall)
  of hekUnary: context.checkDirectoryExpr(expr.operand)
  of hekBinary:
    context.checkDirectoryExpr(expr.left)
    context.checkDirectoryExpr(expr.right)
  else: discard

## Walks resolved statements, including field mutations on inferred receivers.
proc checkDirectoryStmt(context: var DirectoryUseContext, stmt: HirStmt) =
  if stmt.isNil: return
  case stmt.kind
  of hskVar:
    context.localTypes[stmt.localId.value] = stmt.typ
    context.checkDirectoryType(stmt.typ, stmt.span, inferred = true)
    context.checkDirectoryExpr(stmt.initializer)
  of hskAssign: context.checkDirectoryExpr(stmt.assignedValue)
  of hskFieldSet:
    if stmt.receiverId.value in context.localTypes:
      context.checkDirectoryType(context.localTypes[stmt.receiverId.value], stmt.span)
    context.checkDirectoryExpr(stmt.fieldValue)
  of hskClassFieldSet:
    context.checkDirectoryType(stmt.classFieldOwner, stmt.span)
    context.checkDirectoryExpr(stmt.classFieldValue)
  of hskCall: context.checkDirectoryCall(stmt.call)
  of hskMethodCall: context.checkDirectoryMethod(stmt.methodCall)
  of hskReturn: context.checkDirectoryExpr(stmt.value)
  of hskIf:
    context.checkDirectoryExpr(stmt.condition)
    for child in stmt.thenBranch: context.checkDirectoryStmt(child)
    for child in stmt.elseBranch: context.checkDirectoryStmt(child)
  of hskExists:
    context.checkDirectoryExpr(stmt.existsValue)
    for child in stmt.existsBody: context.checkDirectoryStmt(child)
  of hskWhile:
    context.checkDirectoryExpr(stmt.whileCondition)
    for child in stmt.body: context.checkDirectoryStmt(child)
  of hskFor:
    context.checkDirectoryStmt(stmt.forInitializer)
    context.checkDirectoryExpr(stmt.forCondition)
    context.checkDirectoryStmt(stmt.forUpdate)
    for child in stmt.forBody: context.checkDirectoryStmt(child)
  else: discard

## Checks inferred uses after normal semantic analysis, including generic
## instantiations and compile-time layout selection references.
proc validateResolvedDirectoryUses*(source: Program, program: hirProgram.HirProgram,
    project: projectModel.EidoProject) =
  if project.modules.len == 0: return
  var context: DirectoryUseContext
  for spec in project.modules:
    context.modules[spec.canonicalName] = spec
  for unit in project.sources:
    context.sourceModules[unit.path] = unit.moduleName
  for decl in source.classes: context.targets[decl.name] = decl.span
  for decl in source.interfaces: context.targets[decl.name] = decl.span
  for decl in source.layouts: context.layouts[decl.name] = decl.span
  for decl in source.functions: context.functions[decl.name] = decl.span

  for decl in program.interfaces:
    context.setDirectoryTemplate(decl.sourceName)
    for meth in decl.methods:
      for expr in meth.requires: context.checkDirectoryExpr(expr)
      for expr in meth.ensures: context.checkDirectoryExpr(expr)
  for decl in program.classes:
    context.setDirectoryTemplate(decl.sourceName)
    for field in decl.classFields: context.checkDirectoryExpr(field.initializer)
    for expr in decl.invariants: context.checkDirectoryExpr(expr)
    for meth in decl.methods:
      context.localTypes.clear()
      if meth.kind == mkInstance: context.localTypes[meth.receiverLocalId.value] = meth.ownerType
      for param in meth.parameters: context.localTypes[param.localId.value] = param.typ
      for expr in meth.requires: context.checkDirectoryExpr(expr)
      for expr in meth.ensures: context.checkDirectoryExpr(expr)
      for stmt in meth.body: context.checkDirectoryStmt(stmt)
  context.setDirectoryTemplate("")
  for fn in program.functions:
    context.localTypes.clear()
    for param in fn.parameters: context.localTypes[param.localId.value] = param.typ
    for expr in fn.requires: context.checkDirectoryExpr(expr)
    for expr in fn.ensures: context.checkDirectoryExpr(expr)
    for stmt in fn.body: context.checkDirectoryStmt(stmt)
  for selection in program.layoutSelections:
    for name in directoryTypeNames(selection.targetName):
      let key = if '.' in name: name else: declarationKey(selection.moduleName, name)
      context.checkDirectoryTarget(key, context.targets, selection.span)
    let layout = directoryNominalBase(selection.layoutName)
    let key = if '.' in layout: layout else: declarationKey(selection.moduleName, layout)
    context.checkDirectoryTarget(key, context.layouts, selection.span)
