## Computes conservative declaration reachability after full semantic validation.
## Classes are atomic units because generated constructors, copy helpers, interface
## adapters and Storage bridges may refer to methods without an explicit HIR call.
import std/[sets, tables]
import ../types/[model, function_result, method_kind]
import ../semantic/symbols/ids
import ../source/span
import program, declarations, expressions, statements

type
  Reachability = object
    classes: HashSet[string]
    interfaces: HashSet[string]
    functions: HashSet[int]
    classQueue: seq[string]
    interfaceQueue: seq[string]
    functionQueue: seq[int]

## Marks a class and schedules its declaration dependencies once.
proc markClass(reach: var Reachability, name: string) =
  if name notin reach.classes:
    reach.classes.incl name
    reach.classQueue.add name

## Marks an interface and schedules its signature and inheritance dependencies.
proc markInterface(reach: var Reachability, name: string) =
  if name notin reach.interfaces:
    reach.interfaces.incl name
    reach.interfaceQueue.add name

## Marks a resolved function identity once, including recursive calls.
proc markFunction(reach: var Reachability, id: FunctionId) =
  if id.value notin reach.functions:
    reach.functions.incl id.value
    reach.functionQueue.add id.value

## Marks nominal representation dependencies (including optional classes).
proc markType(reach: var Reachability, typ: EidoType) =
  case typ.kind
  of etkClass: reach.markClass(typ.className)
  of etkInterface: reach.markInterface(typ.interfaceName)
  else: discard

## Marks a callable result representation when present.
proc markResult(reach: var Reachability, value: FunctionResult) =
  if value.kind == frSingle:
    reach.markType(value.typ)

## Walks resolved expressions, not source spelling.
proc scanExpr(reach: var Reachability, expr: HirExpr)
## Records a function call and all arguments/results.
proc scanCall(reach: var Reachability, call: HirCall) =
  reach.markFunction(call.functionId)
  reach.markResult(call.result)
  for arg in call.arguments:
    reach.scanExpr(arg)

## Records a method's nominal owner and all receiver/argument dependencies.
proc scanMethodCall(reach: var Reachability, call: HirMethodCall) =
  reach.markType(call.ownerType)
  reach.markResult(call.result)
  if call.kind == mkInstance:
    reach.scanExpr(call.receiver)
  for arg in call.arguments:
    reach.scanExpr(arg)

## Walks resolved expressions, including class state and conversion operands.
proc scanExpr(reach: var Reachability, expr: HirExpr) =
  if expr.isNil: return
  reach.markType(expr.typ)
  case expr.kind
  of hekOptionalSome, hekOptionalGet:
    reach.scanExpr(expr.optionalValue)
  of hekCall:
    reach.scanCall(expr.call)
  of hekConstruct:
    reach.markClass(expr.constructedTypeName)
    for field in expr.fields: reach.scanExpr(field.value)
  of hekClassRelation:
    reach.scanExpr(expr.relatedValue)
  of hekInterfaceConvert:
    reach.scanExpr(expr.interfaceValue)
  of hekFieldAccess:
    reach.scanExpr(expr.target)
  of hekClassFieldAccess:
    reach.markType(expr.classFieldOwner)
  of hekMethodCall:
    reach.scanMethodCall(expr.methodCall)
  of hekUnary:
    reach.scanExpr(expr.operand)
  of hekBinary:
    reach.scanExpr(expr.left)
    reach.scanExpr(expr.right)
  of hekInteger, hekFloating, hekBoolean, hekChar, hekString, hekNone, hekLocal:
    discard

## Walks all structured statements and their expression dependencies.
proc scanStmt(reach: var Reachability, stmt: HirStmt) =
  if stmt.isNil: return
  case stmt.kind
  of hskVar:
    reach.markType(stmt.typ)
    reach.scanExpr(stmt.initializer)
  of hskAssign:
    reach.scanExpr(stmt.assignedValue)
  of hskFieldSet:
    reach.scanExpr(stmt.fieldValue)
  of hskClassFieldSet:
    reach.markType(stmt.classFieldOwner)
    reach.scanExpr(stmt.classFieldValue)
  of hskCall:
    reach.scanCall(stmt.call)
  of hskMethodCall:
    reach.scanMethodCall(stmt.methodCall)
  of hskReturn:
    reach.scanExpr(stmt.value)
  of hskIf:
    reach.scanExpr(stmt.condition)
    for child in stmt.thenBranch: reach.scanStmt(child)
    for child in stmt.elseBranch: reach.scanStmt(child)
  of hskExists:
    reach.scanExpr(stmt.existsValue)
    for child in stmt.existsBody: reach.scanStmt(child)
  of hskWhile:
    reach.scanExpr(stmt.whileCondition)
    for child in stmt.body: reach.scanStmt(child)
  of hskFor:
    reach.scanStmt(stmt.forInitializer)
    reach.scanExpr(stmt.forCondition)
    reach.scanStmt(stmt.forUpdate)
    for child in stmt.forBody: reach.scanStmt(child)
  of hskBreak, hskContinue:
    discard

## Includes callable signature, contract and body dependencies.
proc scanCallable(reach: var Reachability, parameters: seq[HirParameter],
    value: FunctionResult, requires, ensures: seq[HirExpr], body: seq[HirStmt]) =
  for param in parameters: reach.markType(param.typ)
  reach.markResult(value)
  for clause in requires: reach.scanExpr(clause)
  for clause in ensures: reach.scanExpr(clause)
  for stmt in body: reach.scanStmt(stmt)

## Includes all methods of retained classes and their hidden representation needs.
proc scanClass(reach: var Reachability, decl: HirClass) =
  for implemented in decl.implements: reach.markInterface(implemented)
  for field in decl.fields: reach.markType(field.typ)
  for field in decl.classFields:
    reach.markType(field.typ)
    reach.scanExpr(field.initializer)
  for clause in decl.invariants: reach.scanExpr(clause)
  for meth in decl.methods:
    reach.scanCallable(meth.parameters, meth.result, meth.requires, meth.ensures, meth.body)
    for clause in meth.inheritedRequires: reach.scanExpr(clause.expr)
    for clause in meth.inheritedEnsures: reach.scanExpr(clause.expr)

## Includes the nominal dependencies of a retained interface. Implementations
## are reached through actual class use (including interface conversions),
## not merely because a contract exists in the implicit SDK.
proc scanInterface(reach: var Reachability, decl: HirInterface) =
  for parent in decl.extends: reach.markInterface(parent)
  for meth in decl.methods:
    for typ in meth.parameterTypes: reach.markType(typ)
    reach.scanCallable(meth.parameters, meth.result, meth.requires, meth.ensures, @[])

## Retains declarations reachable from main, eager state, interface adapters,
## runtime hooks and explicit metadata roots. During SDK selection preserve every
## user declaration, so compile-time semantic/layout and policy validation sees
## the original user program. Libraries remain intact for external consumers.
proc reachableProgram*(source: HirProgram, preserveUser = false,
    requiredClasses: openArray[string] = []): HirProgram =
  if not source.hasMain: return source
  var reach: Reachability
  var classes = initTable[string, int]()
  var functions = initTable[int, int]()
  var interfaces = initTable[string, int]()
  for i, decl in source.classes:
    classes[decl.sourceName] = i
    if (preserveUser and not decl.span.embeddedSdk) or
        decl.span.isHiddenRuntime or decl.classFields.len > 0:
      reach.markClass(decl.sourceName)
  for i, fn in source.functions:
    functions[fn.functionId.value] = i
    if (preserveUser and not fn.span.embeddedSdk) or fn.span.isHiddenRuntime:
      reach.markFunction(fn.functionId)
  reach.markFunction(source.mainFunctionId)
  for name in requiredClasses: reach.markClass(name)
  for layout in source.layouts: reach.markClass(layout.targetClass)
  for i, decl in source.interfaces:
    interfaces[decl.sourceName] = i
    if (preserveUser and not decl.span.embeddedSdk) or decl.span.isHiddenRuntime:
      reach.markInterface(decl.sourceName)
  var ci = 0
  var fi = 0
  var ii = 0
  while ci < reach.classQueue.len or fi < reach.functionQueue.len or
      ii < reach.interfaceQueue.len:
    while ii < reach.interfaceQueue.len:
      let name = reach.interfaceQueue[ii]
      inc ii
      if interfaces.hasKey(name): reach.scanInterface(source.interfaces[interfaces[name]])
    while ci < reach.classQueue.len:
      let name = reach.classQueue[ci]
      inc ci
      if classes.hasKey(name): reach.scanClass(source.classes[classes[name]])
    while fi < reach.functionQueue.len:
      let id = reach.functionQueue[fi]
      inc fi
      if functions.hasKey(id):
        let fn = source.functions[functions[id]]
        reach.scanCallable(fn.parameters, fn.result, fn.requires, fn.ensures, fn.body)
  result = source
  result.classes = @[]
  result.interfaces = @[]
  for decl in source.interfaces:
    if decl.sourceName in reach.interfaces: result.interfaces.add decl
  result.functions = @[]
  for decl in source.classes:
    if decl.sourceName in reach.classes: result.classes.add decl
  for fn in source.functions:
    if fn.functionId.value in reach.functions: result.functions.add fn
