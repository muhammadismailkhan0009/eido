## Detects whether resolved user HIR requires detached class graph-copy runtime support.

import std/strutils
import ../types/method_kind
import declarations
import expressions
import program as hirProgram
import statements

## Reports whether one declaration belongs to an embedded stdlib/runtime source.
proc isBuiltinStdlibSource(sourcePath: string): bool =
  sourcePath.startsWith("eido://stdlib/")

## Reports whether one resolved expression contains an explicit detached class copy.
proc expressionUsesClassCopy(expr: HirExpr): bool =
  if expr.isNil:
    return false

  case expr.kind
  of hekInteger, hekFloating, hekBoolean, hekChar, hekString, hekNone,
      hekLocal, hekClassFieldAccess:
    false
  of hekOptionalSome, hekOptionalGet:
    expressionUsesClassCopy(expr.optionalValue)
  of hekCall:
    for argument in expr.call.arguments:
      if expressionUsesClassCopy(argument): return true
    false
  of hekConstruct:
    for field in expr.fields:
      if expressionUsesClassCopy(field.value): return true
    false
  of hekClassRelation:
    expr.classRelationKind == hcvrCopy or expressionUsesClassCopy(expr.relatedValue)
  of hekInterfaceConvert:
    expressionUsesClassCopy(expr.interfaceValue)
  of hekFieldAccess:
    expressionUsesClassCopy(expr.target)
  of hekMethodCall:
    if expr.methodCall.kind == mkInstance and
        expressionUsesClassCopy(expr.methodCall.receiver):
      return true
    for argument in expr.methodCall.arguments:
      if expressionUsesClassCopy(argument): return true
    false
  of hekUnary:
    expressionUsesClassCopy(expr.operand)
  of hekBinary:
    expressionUsesClassCopy(expr.left) or expressionUsesClassCopy(expr.right)

## Reports whether one resolved statement contains an explicit detached class copy.
proc statementUsesClassCopy(stmt: HirStmt): bool =
  if stmt.isNil:
    return false

  case stmt.kind
  of hskVar:
    expressionUsesClassCopy(stmt.initializer)
  of hskAssign:
    expressionUsesClassCopy(stmt.assignedValue)
  of hskFieldSet:
    expressionUsesClassCopy(stmt.fieldValue)
  of hskClassFieldSet:
    expressionUsesClassCopy(stmt.classFieldValue)
  of hskCall:
    for argument in stmt.call.arguments:
      if expressionUsesClassCopy(argument): return true
    false
  of hskMethodCall:
    if stmt.methodCall.kind == mkInstance and
        expressionUsesClassCopy(stmt.methodCall.receiver):
      return true
    for argument in stmt.methodCall.arguments:
      if expressionUsesClassCopy(argument): return true
    false
  of hskReturn:
    expressionUsesClassCopy(stmt.value)
  of hskIf:
    if expressionUsesClassCopy(stmt.condition): return true
    for child in stmt.thenBranch:
      if statementUsesClassCopy(child): return true
    for child in stmt.elseBranch:
      if statementUsesClassCopy(child): return true
    false
  of hskExists:
    if expressionUsesClassCopy(stmt.existsValue): return true
    for child in stmt.existsBody:
      if statementUsesClassCopy(child): return true
    false
  of hskWhile:
    if expressionUsesClassCopy(stmt.whileCondition): return true
    for child in stmt.body:
      if statementUsesClassCopy(child): return true
    false
  of hskFor:
    if statementUsesClassCopy(stmt.forInitializer) or
        expressionUsesClassCopy(stmt.forCondition) or
        statementUsesClassCopy(stmt.forUpdate):
      return true
    for child in stmt.forBody:
      if statementUsesClassCopy(child): return true
    false
  of hskBreak, hskContinue:
    false

## Reports whether ordinary user declarations require class graph-copy runtime support.
proc usesClassCopy*(program: hirProgram.HirProgram): bool =
  for classDecl in program.classes:
    if classDecl.span.sourcePath.isBuiltinStdlibSource:
      continue
    for field in classDecl.classFields:
      if expressionUsesClassCopy(field.initializer): return true
    for clause in classDecl.invariants:
      if expressionUsesClassCopy(clause): return true
    for methodDecl in classDecl.methods:
      for clause in methodDecl.requires:
        if expressionUsesClassCopy(clause): return true
      for clause in methodDecl.ensures:
        if expressionUsesClassCopy(clause): return true
      for statement in methodDecl.body:
        if statementUsesClassCopy(statement): return true

  for fn in program.functions:
    if fn.span.sourcePath.isBuiltinStdlibSource:
      continue
    for clause in fn.requires:
      if expressionUsesClassCopy(clause): return true
    for clause in fn.ensures:
      if expressionUsesClassCopy(clause): return true
    for statement in fn.body:
      if statementUsesClassCopy(statement): return true

  false
