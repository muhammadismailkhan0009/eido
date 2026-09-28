## Provides protocol-neutral semantic hover information from typed HIR.
## Editor adapters consume this service instead of reimplementing type/member analysis.

import std/strutils
import ../hir/[declarations, expressions, program, statements]
import ../source/span
import ../types/[function_result, method_kind, model]

type
  HoverInfo* = object
    found*: bool
    contents*: string
    span*: SourceSpan

## Returns a concise source-facing display name for one semantic type.
proc toolingTypeName*(typ: EidoType): string =
  var base = typ.displayName
  if typ.kind in {etkClass, etkInterface}:
    let optionalSuffix = if typ.isOptional: "?" else: ""
    if optionalSuffix.len > 0:
      base = base[0 ..< base.len - 1]

    let genericStart = base.find('<')
    let prefix =
      if genericStart >= 0: base[0 ..< genericStart]
      else: base
    let separator = prefix.rfind('.')
    if separator >= 0:
      base = base[separator + 1 .. ^1]

    base.add optionalSuffix

  base

## Formats one function/method result for editor display.
proc resultSuffix(callableResult: FunctionResult): string =
  if callableResult.kind == frSingle:
    " returns " & toolingTypeName(callableResult.typ)
  else:
    ""

## Reports whether one source span contains the requested byte offset.
proc containsOffset(span: SourceSpan, sourcePath: string, offset: int): bool =
  span.sourcePath == sourcePath and
    offset >= span.startOffset and
    offset < max(span.endOffset, span.startOffset + 1)

## Replaces the current hover candidate when a narrower matching span is found.
proc consider(
  best: var HoverInfo,
  span: SourceSpan,
  sourcePath: string,
  offset: int,
  contents: string
) =
  if not containsOffset(span, sourcePath, offset):
    return

  let width = max(1, span.endOffset - span.startOffset)
  let currentWidth =
    if best.found: max(1, best.span.endOffset - best.span.startOffset)
    else: high(int)

  if not best.found or width <= currentWidth:
    best = HoverInfo(
      found: true,
      contents: contents,
      span: span
    )

## Walks one typed HIR expression for the narrowest hover target.
proc visitExpr(
  expr: HirExpr,
  sourcePath: string,
  offset: int,
  best: var HoverInfo
) =
  if expr.isNil or not containsOffset(expr.span, sourcePath, offset):
    return

  case expr.kind
  of hekLocal:
    best.consider(
      expr.span, sourcePath, offset,
      expr.sourceName & ": " & toolingTypeName(expr.typ)
    )
  of hekFieldAccess:
    best.consider(
      expr.span, sourcePath, offset,
      expr.sourceFieldName & ": " & toolingTypeName(expr.typ)
    )
    visitExpr(expr.target, sourcePath, offset, best)
  of hekCall:
    best.consider(
      expr.span, sourcePath, offset,
      "function " & expr.call.functionName &
        expr.call.result.resultSuffix
    )
    for argument in expr.call.arguments:
      visitExpr(argument, sourcePath, offset, best)
  of hekMethodCall:
    best.consider(
      expr.span, sourcePath, offset,
      "method " & expr.methodCall.methodName &
        expr.methodCall.result.resultSuffix
    )
    if expr.methodCall.kind == mkInstance:
      visitExpr(expr.methodCall.receiver, sourcePath, offset, best)
    for argument in expr.methodCall.arguments:
      visitExpr(argument, sourcePath, offset, best)
  of hekConstruct:
    best.consider(
      expr.span, sourcePath, offset,
      toolingTypeName(expr.typ)
    )
    for field in expr.fields:
      visitExpr(field.value, sourcePath, offset, best)
  of hekClassRelation:
    best.consider(
      expr.span, sourcePath, offset,
      toolingTypeName(expr.typ)
    )
    visitExpr(expr.relatedValue, sourcePath, offset, best)
  of hekInterfaceConvert:
    best.consider(
      expr.span, sourcePath, offset,
      toolingTypeName(expr.typ)
    )
    visitExpr(expr.interfaceValue, sourcePath, offset, best)
  of hekOptionalSome, hekOptionalGet:
    best.consider(
      expr.span, sourcePath, offset,
      toolingTypeName(expr.typ)
    )
    visitExpr(expr.optionalValue, sourcePath, offset, best)
  of hekUnary:
    best.consider(
      expr.span, sourcePath, offset,
      toolingTypeName(expr.typ)
    )
    visitExpr(expr.operand, sourcePath, offset, best)
  of hekBinary:
    best.consider(
      expr.span, sourcePath, offset,
      toolingTypeName(expr.typ)
    )
    visitExpr(expr.left, sourcePath, offset, best)
    visitExpr(expr.right, sourcePath, offset, best)
  of hekInteger, hekFloating, hekBoolean, hekChar, hekString, hekNone:
    best.consider(
      expr.span, sourcePath, offset,
      toolingTypeName(expr.typ)
    )

## Walks one typed HIR statement recursively.
proc visitStmt(
  stmt: HirStmt,
  sourcePath: string,
  offset: int,
  best: var HoverInfo
) =
  if stmt.isNil or not containsOffset(stmt.span, sourcePath, offset):
    return

  case stmt.kind
  of hskVar:
    best.consider(
      stmt.span, sourcePath, offset,
      "var " & stmt.sourceName & ": " & toolingTypeName(stmt.typ)
    )
    visitExpr(stmt.initializer, sourcePath, offset, best)
  of hskAssign:
    visitExpr(stmt.assignedValue, sourcePath, offset, best)
  of hskFieldSet:
    visitExpr(stmt.fieldValue, sourcePath, offset, best)
  of hskCall:
    best.consider(
      stmt.span, sourcePath, offset,
      "function " & stmt.call.functionName & stmt.call.result.resultSuffix
    )
    for argument in stmt.call.arguments:
      visitExpr(argument, sourcePath, offset, best)
  of hskMethodCall:
    best.consider(
      stmt.span, sourcePath, offset,
      "method " & stmt.methodCall.methodName &
        stmt.methodCall.result.resultSuffix
    )
    if stmt.methodCall.kind == mkInstance:
      visitExpr(stmt.methodCall.receiver, sourcePath, offset, best)
    for argument in stmt.methodCall.arguments:
      visitExpr(argument, sourcePath, offset, best)
  of hskReturn:
    visitExpr(stmt.value, sourcePath, offset, best)
  of hskIf:
    visitExpr(stmt.condition, sourcePath, offset, best)
    for child in stmt.thenBranch:
      visitStmt(child, sourcePath, offset, best)
    for child in stmt.elseBranch:
      visitStmt(child, sourcePath, offset, best)
  of hskExists:
    visitExpr(stmt.existsValue, sourcePath, offset, best)
    for child in stmt.existsBody:
      visitStmt(child, sourcePath, offset, best)
  of hskWhile:
    visitExpr(stmt.whileCondition, sourcePath, offset, best)
    for child in stmt.body:
      visitStmt(child, sourcePath, offset, best)
  of hskFor:
    visitStmt(stmt.forInitializer, sourcePath, offset, best)
    visitExpr(stmt.forCondition, sourcePath, offset, best)
    visitStmt(stmt.forUpdate, sourcePath, offset, best)
    for child in stmt.forBody:
      visitStmt(child, sourcePath, offset, best)
  of hskBreak, hskContinue:
    discard

## Formats one callable signature for hover fallback.
proc callableSignature(
  prefix, name: string,
  parameters: seq[HirParameter],
  callableResult: FunctionResult
): string =
  result = prefix & " " & name & "("
  for index, parameter in parameters:
    if index > 0:
      result.add ", "
    result.add parameter.sourceName & ": " & toolingTypeName(parameter.typ)
  result.add ")"
  result.add callableResult.resultSuffix

## Finds the narrowest semantic hover target in an analyzed program.
proc hoverInfoAt*(
  program: HirProgram,
  sourcePath: string,
  byteOffset: int
): HoverInfo =
  for interfaceDecl in program.interfaces:
    result.consider(
      interfaceDecl.span,
      sourcePath,
      byteOffset,
      "interface " & toolingTypeName(interfaceDecl.typ)
    )

  for classDecl in program.classes:
    result.consider(
      classDecl.span,
      sourcePath,
      byteOffset,
      "class " & toolingTypeName(classDecl.typ)
    )

    for field in classDecl.fields:
      result.consider(
        field.span,
        sourcePath,
        byteOffset,
        field.sourceName & ": " & toolingTypeName(field.typ)
      )

    for methodDecl in classDecl.methods:
      result.consider(
        methodDecl.span,
        sourcePath,
        byteOffset,
        callableSignature(
          "method",
          methodDecl.sourceName,
          methodDecl.parameters,
          methodDecl.result
        )
      )
      for parameter in methodDecl.parameters:
        result.consider(
          parameter.span,
          sourcePath,
          byteOffset,
          parameter.sourceName & ": " & toolingTypeName(parameter.typ)
        )
      for stmt in methodDecl.body:
        visitStmt(stmt, sourcePath, byteOffset, result)

  for functionDecl in program.functions:
    result.consider(
      functionDecl.span,
      sourcePath,
      byteOffset,
      callableSignature(
        "function",
        functionDecl.sourceName,
        functionDecl.parameters,
        functionDecl.result
      )
    )
    for parameter in functionDecl.parameters:
      result.consider(
        parameter.span,
        sourcePath,
        byteOffset,
        parameter.sourceName & ": " & toolingTypeName(parameter.typ)
      )
    for stmt in functionDecl.body:
      visitStmt(stmt, sourcePath, byteOffset, result)
