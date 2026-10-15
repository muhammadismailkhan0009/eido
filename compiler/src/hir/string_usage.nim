## Detects whether resolved HIR depends on the built-in String runtime.

import std/strutils
import ../types/[function_result, method_kind, model]
import declarations
import expressions
import program as hirProgram
import statements

## Reports whether one semantic type uses built-in String storage.
proc typeUsesString(typ: EidoType): bool =
  typ.kind == etkString

## Reports whether one declaration belongs to ordinary embedded stdlib API source.
proc isBuiltinStdlibSource(sourcePath: string): bool =
  sourcePath.startsWith("eido://stdlib/")

## Reports whether one resolved expression contains String data or operations.
proc expressionUsesString(expr: HirExpr): bool =
  if expr.isNil:
    return false
  if expr.typ.typeUsesString:
    return true

  case expr.kind
  of hekInteger, hekFloating, hekBoolean, hekChar, hekString, hekNone,
      hekLocal, hekClassFieldAccess:
    expr.kind == hekString
  of hekOptionalSome, hekOptionalGet:
    expressionUsesString(expr.optionalValue)
  of hekCall:
    for argument in expr.call.arguments:
      if expressionUsesString(argument): return true
    expr.call.result.kind == frSingle and expr.call.result.typ.typeUsesString
  of hekConstruct:
    for field in expr.fields:
      if expressionUsesString(field.value): return true
    false
  of hekClassRelation:
    expressionUsesString(expr.relatedValue)
  of hekInterfaceConvert:
    expressionUsesString(expr.interfaceValue)
  of hekFieldAccess:
    expressionUsesString(expr.target)
  of hekMethodCall:
    if expr.methodCall.kind == mkInstance and
        expressionUsesString(expr.methodCall.receiver):
      return true
    for argument in expr.methodCall.arguments:
      if expressionUsesString(argument): return true
    expr.methodCall.result.kind == frSingle and
      expr.methodCall.result.typ.typeUsesString
  of hekUnary:
    expressionUsesString(expr.operand)
  of hekBinary:
    expressionUsesString(expr.left) or expressionUsesString(expr.right)

## Reports whether one resolved statement contains String data or operations.
proc statementUsesString(stmt: HirStmt): bool =
  if stmt.isNil:
    return false

  case stmt.kind
  of hskVar:
    stmt.typ.typeUsesString or expressionUsesString(stmt.initializer)
  of hskAssign:
    expressionUsesString(stmt.assignedValue)
  of hskFieldSet:
    expressionUsesString(stmt.fieldValue)
  of hskClassFieldSet:
    expressionUsesString(stmt.classFieldValue)
  of hskCall:
    for argument in stmt.call.arguments:
      if expressionUsesString(argument): return true
    stmt.call.result.kind == frSingle and stmt.call.result.typ.typeUsesString
  of hskMethodCall:
    if stmt.methodCall.kind == mkInstance and
        expressionUsesString(stmt.methodCall.receiver):
      return true
    for argument in stmt.methodCall.arguments:
      if expressionUsesString(argument): return true
    stmt.methodCall.result.kind == frSingle and
      stmt.methodCall.result.typ.typeUsesString
  of hskReturn:
    expressionUsesString(stmt.value)
  of hskIf:
    if expressionUsesString(stmt.condition): return true
    for child in stmt.thenBranch:
      if statementUsesString(child): return true
    for child in stmt.elseBranch:
      if statementUsesString(child): return true
    false
  of hskExists:
    if expressionUsesString(stmt.existsValue): return true
    for child in stmt.existsBody:
      if statementUsesString(child): return true
    false
  of hskWhile:
    if expressionUsesString(stmt.whileCondition): return true
    for child in stmt.body:
      if statementUsesString(child): return true
    false
  of hskFor:
    if statementUsesString(stmt.forInitializer) or
        expressionUsesString(stmt.forCondition) or
        statementUsesString(stmt.forUpdate):
      return true
    for child in stmt.forBody:
      if statementUsesString(child): return true
    false
  of hskBreak, hskContinue:
    false

## Reports whether any declaration in one resolved program requires String runtime support.
proc usesString*(program: hirProgram.HirProgram): bool =
  for interfaceDecl in program.interfaces:
    if interfaceDecl.span.sourcePath.isBuiltinStdlibSource:
      continue
    for methodDecl in interfaceDecl.methods:
      for parameterType in methodDecl.parameterTypes:
        if parameterType.typeUsesString: return true
      if methodDecl.result.kind == frSingle and methodDecl.result.typ.typeUsesString:
        return true
      for clause in methodDecl.requires:
        if expressionUsesString(clause): return true
      for clause in methodDecl.ensures:
        if expressionUsesString(clause): return true

  for classDecl in program.classes:
    if classDecl.span.sourcePath.isBuiltinStdlibSource:
      continue
    for field in classDecl.fields:
      if field.typ.typeUsesString: return true
    for field in classDecl.classFields:
      if field.typ.typeUsesString or expressionUsesString(field.initializer): return true
    for clause in classDecl.invariants:
      if expressionUsesString(clause): return true
    for methodDecl in classDecl.methods:
      for parameter in methodDecl.parameters:
        if parameter.typ.typeUsesString: return true
      if methodDecl.result.kind == frSingle and methodDecl.result.typ.typeUsesString:
        return true
      for clause in methodDecl.requires:
        if expressionUsesString(clause): return true
      for clause in methodDecl.ensures:
        if expressionUsesString(clause): return true
      for statement in methodDecl.body:
        if statementUsesString(statement): return true

  for fn in program.functions:
    if fn.span.sourcePath.isBuiltinStdlibSource:
      continue
    for parameter in fn.parameters:
      if parameter.typ.typeUsesString: return true
    if fn.result.kind == frSingle and fn.result.typ.typeUsesString:
      return true
    for clause in fn.requires:
      if expressionUsesString(clause): return true
    for clause in fn.ensures:
      if expressionUsesString(clause): return true
    for statement in fn.body:
      if statementUsesString(statement): return true

  false
