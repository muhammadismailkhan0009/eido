## Infers observable callable effects from resolved HIR and propagates them through the call graph.
## Local-variable mutation is intentionally not observable; field mutation, native calls, and dynamic interface dispatch are.

import std/tables
import ../../hir/[declarations, expressions, program, statements]
import ../../types/method_kind
import ../symbols/ids
import model
import native_observation

## Collects observable-effect facts from one HIR expression.
proc collectExprEffects(
  expr: HirExpr,
  facts: var CallableEffectFacts
) =
  if expr.isNil:
    return

  case expr.kind
  of hekCall:
    if expr.call.isNative:
      facts.directEffect = true
    else:
      facts.functionDependencies.add expr.call.functionId
    for argument in expr.call.arguments:
      collectExprEffects(argument, facts)

  of hekMethodCall:
    if expr.methodCall.dispatchKind == hmdInterface or
        (expr.methodCall.isNative and
          not isVerifiedObservationalNativeMethod(expr.methodCall)):
      facts.directEffect = true
    elif not expr.methodCall.isNative:
      facts.methodDependencies.add expr.methodCall.methodId
    if expr.methodCall.kind == mkInstance:
      collectExprEffects(expr.methodCall.receiver, facts)
    for argument in expr.methodCall.arguments:
      collectExprEffects(argument, facts)

  of hekConstruct:
    for field in expr.fields:
      collectExprEffects(field.value, facts)

  of hekClassRelation:
    collectExprEffects(expr.relatedValue, facts)

  of hekInterfaceConvert:
    collectExprEffects(expr.interfaceValue, facts)

  of hekFieldAccess:
    collectExprEffects(expr.target, facts)

  of hekOptionalSome, hekOptionalGet:
    collectExprEffects(expr.optionalValue, facts)

  of hekUnary:
    collectExprEffects(expr.operand, facts)

  of hekBinary:
    collectExprEffects(expr.left, facts)
    collectExprEffects(expr.right, facts)

  of hekLocal, hekInteger, hekFloating, hekBoolean, hekChar, hekString, hekNone:
    discard

## Collects observable-effect facts from one HIR statement tree.
proc collectStmtEffects(
  stmt: HirStmt,
  facts: var CallableEffectFacts
) =
  if stmt.isNil:
    return

  case stmt.kind
  of hskVar:
    collectExprEffects(stmt.initializer, facts)

  of hskAssign:
    collectExprEffects(stmt.assignedValue, facts)

  of hskFieldSet:
    facts.directEffect = true
    collectExprEffects(stmt.fieldValue, facts)

  of hskCall:
    if stmt.call.isNative:
      facts.directEffect = true
    else:
      facts.functionDependencies.add stmt.call.functionId
    for argument in stmt.call.arguments:
      collectExprEffects(argument, facts)

  of hskMethodCall:
    if stmt.methodCall.dispatchKind == hmdInterface or
        (stmt.methodCall.isNative and
          not isVerifiedObservationalNativeMethod(stmt.methodCall)):
      facts.directEffect = true
    elif not stmt.methodCall.isNative:
      facts.methodDependencies.add stmt.methodCall.methodId
    if stmt.methodCall.kind == mkInstance:
      collectExprEffects(stmt.methodCall.receiver, facts)
    for argument in stmt.methodCall.arguments:
      collectExprEffects(argument, facts)

  of hskReturn:
    collectExprEffects(stmt.value, facts)

  of hskIf:
    collectExprEffects(stmt.condition, facts)
    for child in stmt.thenBranch:
      collectStmtEffects(child, facts)
    for child in stmt.elseBranch:
      collectStmtEffects(child, facts)

  of hskExists:
    collectExprEffects(stmt.existsValue, facts)
    for child in stmt.existsBody:
      collectStmtEffects(child, facts)

  of hskWhile:
    collectExprEffects(stmt.whileCondition, facts)
    for child in stmt.body:
      collectStmtEffects(child, facts)

  of hskFor:
    collectStmtEffects(stmt.forInitializer, facts)
    collectExprEffects(stmt.forCondition, facts)
    collectStmtEffects(stmt.forUpdate, facts)
    for child in stmt.forBody:
      collectStmtEffects(child, facts)

  of hskBreak, hskContinue:
    discard

## Collects body-level effects for one top-level function.
proc functionFacts(fn: HirFunction): CallableEffectFacts =
  if fn.isNative:
    result.directEffect = true
    return
  for stmt in fn.body:
    collectStmtEffects(stmt, result)

## Collects body-level effects for one class method.
proc methodFacts(methodDecl: HirMethod): CallableEffectFacts =
  if methodDecl.isNative:
    result.directEffect = true
    return
  for stmt in methodDecl.body:
    collectStmtEffects(stmt, result)

## Reports whether all transitive dependencies of one fact set are currently contract-safe.
proc dependenciesSafe(
  facts: CallableEffectFacts,
  summary: ContractSafetySummary
): bool =
  if facts.directEffect:
    return false
  for dependency in facts.functionDependencies:
    if not summary.isFunctionSafe(dependency):
      return false
  for dependency in facts.methodDependencies:
    if not summary.isMethodSafe(dependency):
      return false
  true

## Infers a transitive contract-safety summary for every concrete Eido callable.
proc inferContractSafety*(program: HirProgram): ContractSafetySummary =
  var functionEffects = initTable[int, CallableEffectFacts]()
  var methodEffects = initTable[int, CallableEffectFacts]()
  result = initContractSafetySummary()

  for fn in program.functions:
    let facts = functionFacts(fn)
    functionEffects[fn.functionId.value] = facts
    result.setFunctionSafe(fn.functionId, not facts.directEffect)

  for classDecl in program.classes:
    for methodDecl in classDecl.methods:
      let facts = methodFacts(methodDecl)
      methodEffects[methodDecl.methodId.value] = facts
      result.setMethodSafe(methodDecl.methodId, not facts.directEffect)

  var changed = true
  while changed:
    changed = false

    for fn in program.functions:
      if result.isFunctionSafe(fn.functionId) and
          not dependenciesSafe(functionEffects[fn.functionId.value], result):
        result.setFunctionSafe(fn.functionId, false)
        changed = true

    for classDecl in program.classes:
      for methodDecl in classDecl.methods:
        if result.isMethodSafe(methodDecl.methodId) and
            not dependenciesSafe(methodEffects[methodDecl.methodId.value], result):
          result.setMethodSafe(methodDecl.methodId, false)
          changed = true
