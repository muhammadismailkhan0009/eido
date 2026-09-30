## Selects and runs compiler-standard Eido memory strategies.
## Strategy entrypoints are build-machine-only and never enter ordinary Eido source.

import ../diagnostics/errors
import ../hir/declarations as hirDeclarations
import ../hir/expressions as hirExpressions
import ../hir/program as hirProgram
import ../hir/statements as hirStatements
import ../pipeline/options
import ../types/[managed_gc_runtime, method_kind, storage]
import gc_memory_strategy
import model

## Reports whether one class declaration requires an instance/managed representation.
## Storage capabilities and stateless static API classes require no managed object identity.
proc requiresManagedRepresentation(
  classDecl: hirDeclarations.HirClass
): bool =
  if isConcreteStorageTypeName(classDecl.sourceName) or
      isManagedGcInternalClassName(classDecl.sourceName):
    return false
  if classDecl.fields.len > 0:
    return true
  for methodDecl in classDecl.methods:
    if methodDecl.kind == mkInstance:
      return true
  false

## Reports whether one analyzed program contains classes that require managed identity.
proc hasManagedClasses(program: hirProgram.HirProgram): bool =
  for classDecl in program.classes:
    if classDecl.requiresManagedRepresentation:
      return true
  false

## Finds an ordinary class construction inside one expression tree.
proc managedConstruction(
  expr: hirExpressions.HirExpr
): hirExpressions.HirExpr =
  if expr.isNil:
    return nil

  case expr.kind
  of hekConstruct:
    if not isConcreteStorageTypeName(expr.constructedTypeName):
      return expr
  of hekOptionalSome, hekOptionalGet:
    return managedConstruction(expr.optionalValue)
  of hekCall:
    for argument in expr.call.arguments:
      let found = managedConstruction(argument)
      if not found.isNil:
        return found
  of hekClassRelation:
    return managedConstruction(expr.relatedValue)
  of hekInterfaceConvert:
    return managedConstruction(expr.interfaceValue)
  of hekFieldAccess:
    return managedConstruction(expr.target)
  of hekMethodCall:
    if expr.methodCall.kind == mkInstance:
      let found = managedConstruction(expr.methodCall.receiver)
      if not found.isNil:
        return found
    for argument in expr.methodCall.arguments:
      let found = managedConstruction(argument)
      if not found.isNil:
        return found
  of hekUnary:
    return managedConstruction(expr.operand)
  of hekBinary:
    let left = managedConstruction(expr.left)
    if not left.isNil:
      return left
    return managedConstruction(expr.right)
  else:
    discard

## Finds an ordinary class construction inside one structured statement tree.
proc managedConstruction(
  statementsToScan: seq[hirStatements.HirStmt]
): hirExpressions.HirExpr =
  for stmt in statementsToScan:
    case stmt.kind
    of hskVar:
      result = managedConstruction(stmt.initializer)
    of hskAssign:
      result = managedConstruction(stmt.assignedValue)
    of hskFieldSet:
      result = managedConstruction(stmt.fieldValue)
    of hskCall:
      for argument in stmt.call.arguments:
        result = managedConstruction(argument)
        if not result.isNil:
          return
    of hskMethodCall:
      if stmt.methodCall.kind == mkInstance:
        result = managedConstruction(stmt.methodCall.receiver)
        if not result.isNil:
          return
      for argument in stmt.methodCall.arguments:
        result = managedConstruction(argument)
        if not result.isNil:
          return
    of hskReturn:
      result = managedConstruction(stmt.value)
    of hskIf:
      result = managedConstruction(stmt.condition)
      if result.isNil:
        result = managedConstruction(stmt.thenBranch)
      if result.isNil:
        result = managedConstruction(stmt.elseBranch)
    of hskExists:
      result = managedConstruction(stmt.existsValue)
      if result.isNil:
        result = managedConstruction(stmt.existsBody)
    of hskWhile:
      result = managedConstruction(stmt.whileCondition)
      if result.isNil:
        result = managedConstruction(stmt.body)
    of hskFor:
      result = managedConstruction(@[stmt.forInitializer])
      if result.isNil:
        result = managedConstruction(stmt.forCondition)
      if result.isNil:
        result = managedConstruction(stmt.forBody)
      if result.isNil:
        result = managedConstruction(@[stmt.forUpdate])
    else:
      discard

    if not result.isNil:
      return

## Reports whether one program constructs any ordinary class value.
proc hasManagedConstruction(program: hirProgram.HirProgram): bool =
  for fn in program.functions:
    if not managedConstruction(fn.body).isNil:
      return true

  for classDecl in program.classes:
    for methodDecl in classDecl.methods:
      if methodDecl.isNative:
        continue
      if not managedConstruction(methodDecl.body).isNil:
        return true

  false

## Rejects managed class declarations while the explicit manual object model is unfinished.
## Primitive/Storage-only and stateless static-API programs may already use manual memory safely.
proc validateManualStrategy(program: hirProgram.HirProgram) =
  for classDecl in program.classes:
    if classDecl.requiresManagedRepresentation:
      failAt(
        classDecl.span,
        "manual memory strategy does not support managed class declarations yet"
      )

  for fn in program.functions:
    let construction = managedConstruction(fn.body)
    if not construction.isNil:
      failAt(
        construction.span,
        "manual memory strategy does not support class construction yet"
      )

  for classDecl in program.classes:
    for methodDecl in classDecl.methods:
      if methodDecl.isNative:
        continue
      let construction = managedConstruction(methodDecl.body)
      if not construction.isNil:
        failAt(
          construction.span,
          "manual memory strategy does not support class construction yet"
        )

## Runs the selected compiler-standard memory strategy.
## GC currently selects the precise mark-and-sweep planner; manual performs no managed planning.
proc runStandardCompileTimePhases*(
  program: hirProgram.HirProgram,
  strategy: MemoryStrategy = msGc
): CompileTimeMemoryPlan =
  case strategy
  of msGc:
    if program.hasManagedClasses or program.hasManagedConstruction:
      return runGcMemoryStrategy(program)
    CompileTimeMemoryPlan()
  of msManual:
    validateManualStrategy(program)
    CompileTimeMemoryPlan()
