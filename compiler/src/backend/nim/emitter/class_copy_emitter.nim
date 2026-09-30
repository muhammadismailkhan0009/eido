## Generates detached graph copiers for nominal classes.
## Copy allocations use the same representation-neutral class allocation helpers.

import ../../../compile_time/model
import ../../../hir/declarations as hirDeclarations
import ../../../types/model
import ../../../types/storage
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
proc renderInternalCopier(
  classDecl: hirDeclarations.HirClass,
  plan: CompileTimeMemoryPlan
): string =
  let sourceType = className(classDecl.sourceName)
  let tableName = classCopyTableName(classDecl.sourceName)
  result.add "proc " & classCopyInternalName(classDecl.sourceName) &
    "(source: " & sourceType & ", context: var " & copyContextName() &
    "): " & sourceType & " =\n"
  if plan.hasManagedLayout(classDecl.sourceName):
    result.add "  if not eidoGcIsSome(source):\n"
    result.add "    return default(" & sourceType & ")\n"
  else:
    result.add "  if source.isNil:\n"
    result.add "    return nil\n"
  result.add "  for entry in context." & tableName & ":\n"
  result.add "    if entry.source == source:\n"
  result.add "      return entry.target\n"
  result.add "  result = " & classAllocateName(classDecl.sourceName) & "()\n"
  result.add "  context." & tableName &
    ".add((source: source, target: result))\n"

  for field in classDecl.fields:
    let getter = classFieldGetName(classDecl.sourceName, field.sourceName)
    let setter = classFieldSetName(classDecl.sourceName, field.sourceName)
    let sourceValue = getter & "(source)"

    if field.typ.kind == etkClass and
        isConcreteStorageTypeName(field.typ.className):
      result.add "  " & setter & "(result, " & sourceValue & ")\n"
    elif field.typ.kind == etkClass:
      if plan.hasManagedLayout(classDecl.sourceName):
        result.add "  if eidoGcIsSome(" & sourceValue & "):\n"
        result.add "    " & setter & "(result, " &
          classCopyInternalName(field.typ.className) &
          "(" & sourceValue & ", context))\n"
        result.add "  else:\n"
        result.add "    " & setter & "(result, default(" &
          className(field.typ.className) & "))\n"
      elif field.typ.isOptional:
        result.add "  if isSome(" & sourceValue & "):\n"
        result.add "    " & setter & "(result, some(" &
          classCopyInternalName(field.typ.className) &
          "(get(" & sourceValue & "), context)))\n"
        result.add "  else:\n"
        result.add "    " & setter & "(result, none(" &
          className(field.typ.className) & "))\n"
      else:
        result.add "  " & setter & "(result, " &
          classCopyInternalName(field.typ.className) &
          "(" & sourceValue & ", context))\n"
    else:
      result.add "  " & setter & "(result, " & sourceValue & ")\n"
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
proc renderClassCopiers*(
  classes: seq[hirDeclarations.HirClass],
  plan: CompileTimeMemoryPlan = CompileTimeMemoryPlan()
): string =
  var copyableClasses: seq[hirDeclarations.HirClass]
  for classDecl in classes:
    if not isConcreteStorageTypeName(classDecl.sourceName):
      copyableClasses.add classDecl

  if copyableClasses.len == 0:
    return ""

  result.add renderCopyContext(copyableClasses)
  result.add renderCopyDeclarations(copyableClasses)
  for classDecl in copyableClasses:
    result.add renderInternalCopier(classDecl, plan)
  for classDecl in copyableClasses:
    result.add renderPublicCopier(classDecl)
