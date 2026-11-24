## Interprets compile-time LayoutPolicy.select calls without injecting runtime API.
## Directives may occur at top level in any source file. An optional user class
## can group such calls in a parameterless static method, invoked at top level.
##
## Calls are deliberately not interpreted inside runtime function bodies:
## layout choices must be fixed before compiling Storage or managed objects.

import std/[sets, strutils]
import ../../diagnostics/errors
import ../../frontend/ast/[declarations, expressions, program, statements]
import ../../hir/declarations as hirDeclarations
import ../../source/span

## Extracts a static class-member path from the Eido expression AST.
proc memberPath(source: Expr): string =
  if source.isNil:
    return ""
  case source.kind
  of ekIdentifier:
    source.name
  of ekFieldAccess:
    let prefix = memberPath(source.target)
    if prefix.len > 0: prefix & "." & source.fieldName else: ""
  else:
    ""

## Identifies the compile-time layout selection intrinsic.
proc isSelectionCall(call: Expr): bool =
  call.kind == ekMethodCall and call.methodName == "select" and
    memberPath(call.receiver) == "LayoutPolicy"

## Validates a literal nonempty layout selection argument.
proc selectLiteral(expr: Expr, label: string): string =
  if expr.kind != ekString:
    failAt(expr.span, "LayoutPolicy.select requires a literal String " & label)
  result = expr.stringValue
  if result.len == 0:
    failAt(expr.span, "LayoutPolicy.select " & label & " cannot be empty")

## Decodes an intrinsic selection call (not a normal runtime method call).
proc addSelection(
  call: Expr, moduleName: string,
  selections: var seq[hirDeclarations.HirLayoutSelection]
) =
  if call.methodArguments.len != 2:
    failAt(call.span,
      "LayoutPolicy.select requires exactly two String literals: class and layout")
  selections.add hirDeclarations.HirLayoutSelection(
    span: call.span,
    moduleName: moduleName,
    targetName: selectLiteral(call.methodArguments[0], "class"),
    layoutName: selectLiteral(call.methodArguments[1], "layout")
  )

## Prefers the caller's module, while requiring globally unique resolution
## for unqualified references to user-defined configuration classes elsewhere.
proc findConfigClass(
  classes: seq[ClassDecl],
  ownerPath, moduleName: string,
  span: SourceSpan
): int =
  let localName = moduleName & "." & ownerPath
  for index, owner in classes:
    if owner.name == ownerPath or owner.name == localName:
      return index

  var matches: seq[int]
  for index, owner in classes:
    if owner.name.endsWith("." & ownerPath):
      matches.add index
  if matches.len == 1:
    return matches[0]
  if matches.len > 1:
    failAt(span, "ambiguous layout configuration class '" & ownerPath & "'")
  failAt(span, "unknown layout configuration class '" & ownerPath & "'")

## Expands only explicitly invoked configuration methods. The methods are
## compiler-time helpers and are omitted from ordinary semantic/runtime HIR.
proc collectCall(
  call: Expr, moduleName: string,
  classes: seq[ClassDecl],
  activeMethods: var HashSet[string],
  selections: var seq[hirDeclarations.HirLayoutSelection]
) =
  if call.isSelectionCall:
    call.addSelection(moduleName, selections)
    return

  if call.kind != ekMethodCall or call.methodArguments.len != 0:
    failAt(call.span,
      "only LayoutPolicy.select or a parameterless class configuration method " &
      "may be called during layout configuration")

  let ownerName = memberPath(call.receiver)
  if ownerName.len == 0:
    failAt(call.span, "expected a user-defined layout configuration class")
  let ownerIndex = findConfigClass(classes, ownerName, moduleName, call.span)
  let owner = classes[ownerIndex]
  for methodDecl in owner.layoutConfigMethods:
    if methodDecl.name != call.methodName:
      continue
    if owner.typeParameters.len != 0 or methodDecl.parameters.len != 0 or
        methodDecl.result.kind != frrNone or
        methodDecl.requires.len > 0 or methodDecl.ensures.len > 0:
      failAt(methodDecl.span,
        "layout configuration methods must be parameterless static methods " &
        "without return values or contracts")

    let key = owner.name & "." & methodDecl.name
    if key in activeMethods:
      failAt(call.span, "recursive layout configuration method: " & key)
    activeMethods.incl key
    for stmt in methodDecl.body:
      if stmt.kind != skCall:
        failAt(stmt.span,
          "layout configuration methods may contain only compile-time calls")
      collectCall(
        stmt.call, owner.moduleName, classes, activeMethods, selections
      )
    activeMethods.excl key
    return

  failAt(call.span, "unknown layout configuration method '" &
    owner.name & "." & call.methodName & "'")

## Collects all compile-time selections without requiring a central class.
proc analyzeLayoutSelections*(
  program: Program
): seq[hirDeclarations.HirLayoutSelection] =
  var activeMethods = initHashSet[string]()
  for config in program.layoutConfigCalls:
    collectCall(
      config.call, config.moduleName, program.classes, activeMethods, result
    )
