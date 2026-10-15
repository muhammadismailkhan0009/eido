## Selects and runs compiler-standard Eido memory strategies.
## Strategy entrypoints are build-machine-only and never enter ordinary Eido source.

import ../diagnostics/errors
import ../hir/declarations as hirDeclarations
import ../hir/expressions as hirExpressions
import ../hir/program as hirProgram
import ../hir/statements as hirStatements
import ../pipeline/options
import ../source/span
import ../types/[method_kind, storage]
import memory_metadata_phase
import model

## Reports whether one class declaration requires runtime-backed object identity.
## Storage capabilities and stateless static API classes require no object identity.
proc requiresObjectIdentity(
  classDecl: hirDeclarations.HirClass
): bool =
  if isConcreteStorageTypeName(classDecl.sourceName) or
      classDecl.span.isCompilerRuntime:
    return false
  if classDecl.fields.len > 0:
    return true
  for methodDecl in classDecl.methods:
    if methodDecl.kind == mkInstance:
      return true
  false

## Reports whether one analyzed program contains classes that require object identity.
proc hasIdentityClasses(program: hirProgram.HirProgram): bool =
  for classDecl in program.classes:
    if classDecl.requiresObjectIdentity:
      return true
  false

## Finds an ordinary class construction inside one expression tree.
proc objectConstruction(
  expr: hirExpressions.HirExpr
): hirExpressions.HirExpr =
  if expr.isNil:
    return nil

  case expr.kind
  of hekConstruct:
    if not isConcreteStorageTypeName(expr.constructedTypeName):
      return expr
  of hekOptionalSome, hekOptionalGet:
    return objectConstruction(expr.optionalValue)
  of hekCall:
    for argument in expr.call.arguments:
      let found = objectConstruction(argument)
      if not found.isNil:
        return found
  of hekClassRelation:
    return objectConstruction(expr.relatedValue)
  of hekInterfaceConvert:
    return objectConstruction(expr.interfaceValue)
  of hekFieldAccess:
    return objectConstruction(expr.target)
  of hekClassFieldAccess:
    discard
  of hekMethodCall:
    if expr.methodCall.kind == mkInstance:
      let found = objectConstruction(expr.methodCall.receiver)
      if not found.isNil:
        return found
    for argument in expr.methodCall.arguments:
      let found = objectConstruction(argument)
      if not found.isNil:
        return found
  of hekUnary:
    return objectConstruction(expr.operand)
  of hekBinary:
    let left = objectConstruction(expr.left)
    if not left.isNil:
      return left
    return objectConstruction(expr.right)
  else:
    discard

## Finds an ordinary class construction inside one structured statement tree.
proc objectConstruction(
  statementsToScan: seq[hirStatements.HirStmt]
): hirExpressions.HirExpr =
  for stmt in statementsToScan:
    case stmt.kind
    of hskVar:
      result = objectConstruction(stmt.initializer)
    of hskAssign:
      result = objectConstruction(stmt.assignedValue)
    of hskFieldSet:
      result = objectConstruction(stmt.fieldValue)
    of hskClassFieldSet:
      result = objectConstruction(stmt.classFieldValue)
    of hskCall:
      for argument in stmt.call.arguments:
        result = objectConstruction(argument)
        if not result.isNil:
          return
    of hskMethodCall:
      if stmt.methodCall.kind == mkInstance:
        result = objectConstruction(stmt.methodCall.receiver)
        if not result.isNil:
          return
      for argument in stmt.methodCall.arguments:
        result = objectConstruction(argument)
        if not result.isNil:
          return
    of hskReturn:
      result = objectConstruction(stmt.value)
    of hskIf:
      result = objectConstruction(stmt.condition)
      if result.isNil:
        result = objectConstruction(stmt.thenBranch)
      if result.isNil:
        result = objectConstruction(stmt.elseBranch)
    of hskExists:
      result = objectConstruction(stmt.existsValue)
      if result.isNil:
        result = objectConstruction(stmt.existsBody)
    of hskWhile:
      result = objectConstruction(stmt.whileCondition)
      if result.isNil:
        result = objectConstruction(stmt.body)
    of hskFor:
      result = objectConstruction(@[stmt.forInitializer])
      if result.isNil:
        result = objectConstruction(stmt.forCondition)
      if result.isNil:
        result = objectConstruction(stmt.forBody)
      if result.isNil:
        result = objectConstruction(@[stmt.forUpdate])
    else:
      discard

    if not result.isNil:
      return

## Reports whether one program constructs any ordinary class value.
proc hasObjectConstruction(program: hirProgram.HirProgram): bool =
  for fn in program.functions:
    if not objectConstruction(fn.body).isNil:
      return true

  for classDecl in program.classes:
    for field in classDecl.classFields:
      if not objectConstruction(field.initializer).isNil:
        return true

    for methodDecl in classDecl.methods:
      if methodDecl.isNative:
        continue
      if not objectConstruction(methodDecl.body).isNil:
        return true

  false

## Rejects object-identity declarations while the explicit manual object model is unfinished.
## Primitive/Storage-only and stateless static-API programs may already use manual memory safely.
proc validateManualStrategy(program: hirProgram.HirProgram) =
  for classDecl in program.classes:
    if classDecl.requiresObjectIdentity:
      failAt(
        classDecl.span,
        "manual memory strategy does not support identity-bearing class declarations yet"
      )

  for fn in program.functions:
    let construction = objectConstruction(fn.body)
    if not construction.isNil:
      failAt(
        construction.span,
        "manual memory strategy does not support class construction yet"
      )

  for classDecl in program.classes:
    for field in classDecl.classFields:
      let construction = objectConstruction(field.initializer)
      if not construction.isNil:
        failAt(
          construction.span,
          "manual memory strategy does not support class construction yet"
        )

    for methodDecl in classDecl.methods:
      if methodDecl.isNative:
        continue
      let construction = objectConstruction(methodDecl.body)
      if not construction.isNil:
        failAt(
          construction.span,
          "manual memory strategy does not support class construction yet"
        )

## Builds generic memory metadata required by automatic object runtimes.
## Strategy selection decides runtime availability, not the shape of compiler metadata.
proc runStandardCompileTimePhases*(
  program: hirProgram.HirProgram,
  strategy: MemoryStrategy = msGc
): CompileTimeMemoryMetadata =
  case strategy
  of msGc:
    if program.hasIdentityClasses or program.hasObjectConstruction:
      return runMemoryMetadataPhase(program)
    CompileTimeMemoryMetadata()
  of msManual:
    validateManualStrategy(program)
    CompileTimeMemoryMetadata()
