## Generates detached graph copiers for nominal classes.
## Backend memo identity lists preserve sharing/cycles while keeping Eido semantics backend-neutral.

import ../../../hir/declarations as hirDeclarations
import ../../../types/model
import names

## Renders the heterogeneous per-class memo state used during one graph copy.
proc renderCopyContext(classes: seq[hirDeclarations.HirClass]): string =
  if classes.len == 0:
    return ""

  result.add "type\n"
  result.add "  " & copyContextName() & " = object\n"
  for classDecl in classes:
    let sourceType = className(classDecl.sourceName)
    result.add "    " & classCopyTableName(classDecl.sourceName) &
      ": seq[tuple[source: " & sourceType & ", target: " &
      sourceType & "]]\n"
  result.add "\n"

## Renders forward declarations so recursive class graphs can call peer copiers.
proc renderCopyDeclarations(classes: seq[hirDeclarations.HirClass]): string =
  for classDecl in classes:
    let sourceType = className(classDecl.sourceName)
    result.add "proc " & classCopyInternalName(classDecl.sourceName) &
      "(source: " & sourceType & ", context: var " & copyContextName() &
      "): " & sourceType & "\n"
    result.add "proc " & classCopyName(classDecl.sourceName) &
      "(source: " & sourceType & "): " & sourceType & "\n"
  result.add "\n"

## Renders one memoized recursive copier body.
proc renderInternalCopier(classDecl: hirDeclarations.HirClass): string =
  let sourceType = className(classDecl.sourceName)
  let tableName = classCopyTableName(classDecl.sourceName)
  result.add "proc " & classCopyInternalName(classDecl.sourceName) &
    "(source: " & sourceType & ", context: var " & copyContextName() &
    "): " & sourceType & " =\n"
  result.add "  if source.isNil:\n"
  result.add "    return nil\n"
  result.add "  for entry in context." & tableName & ":\n"
  result.add "    if entry.source == source:\n"
  result.add "      return entry.target\n"
  result.add "  result = " & sourceType & "()\n"
  result.add "  context." & tableName &
    ".add((source: source, target: result))\n"

  for field in classDecl.fields:
    let target = "result." & fieldName(field.sourceName)
    let source = "source." & fieldName(field.sourceName)
    if field.typ.kind == etkClass:
      result.add "  " & target & " = " &
        classCopyInternalName(field.typ.className) &
        "(" & source & ", context)\n"
    else:
      result.add "  " & target & " = " & source & "\n"
  result.add "\n"

## Renders the public copy entry point that creates an empty memo context.
proc renderPublicCopier(
  classDecl: hirDeclarations.HirClass
): string =
  let sourceType = className(classDecl.sourceName)
  result.add "proc " & classCopyName(classDecl.sourceName) &
    "(source: " & sourceType & "): " & sourceType & " =\n"
  result.add "  var context: " & copyContextName() & "\n"
  result.add "  result = " & classCopyInternalName(classDecl.sourceName) &
    "(source, context)\n\n"

## Renders all copy support needed by the program's nominal classes.
proc renderClassCopiers*(classes: seq[hirDeclarations.HirClass]): string =
  if classes.len == 0:
    return ""

  result.add renderCopyContext(classes)
  result.add renderCopyDeclarations(classes)
  for classDecl in classes:
    result.add renderInternalCopier(classDecl)
  for classDecl in classes:
    result.add renderPublicCopier(classDecl)
