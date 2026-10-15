## Generates detached graph copiers for nominal classes.
## Graph topology is compiler semantics; memo storage belongs to hidden Eido runtime code.

import ../../../compile_time/model
import ../../../hir/declarations as hirDeclarations
import ../../../types/model
import ../../../types/storage
import names

## Renders one class value as the generic integer identity consumed by copy memo runtime.
proc renderCopyIdentity(
  value: string,
  classSourceName: string,
  plan: CompileTimeMemoryMetadata
): string =
  if plan.hasObjectLayout(classSourceName):
    value
  else:
    "int64(cast[uint](" & value & "))"

## Renders one memoized integer identity back to the active class representation.
proc renderCopiedIdentity(
  identity: string,
  classSourceName: string,
  plan: CompileTimeMemoryMetadata
): string =
  if plan.hasObjectLayout(classSourceName):
    identity
  else:
    "cast[" & className(classSourceName) & "](uint(" & identity & "))"

## Renders forward declarations so recursive class graphs can call peer copiers.
proc renderCopyDeclarations(classes: seq[hirDeclarations.HirClass]): string =
  for classDecl in classes:
    let sourceType = className(classDecl.sourceName)
    result.add "proc " & classCopyInternalName(classDecl.sourceName) &
      "(source: " & sourceType & "): " & sourceType & "\n"
    result.add "proc " & classCopyName(classDecl.sourceName) &
      "(source: " & sourceType & "): " & sourceType & "\n"
  result.add "\n"

## Renders one memoized recursive copier body.
proc renderInternalCopier(
  classDecl: hirDeclarations.HirClass,
  plan: CompileTimeMemoryMetadata
): string =
  let sourceType = className(classDecl.sourceName)
  result.add "proc " & classCopyInternalName(classDecl.sourceName) &
    "(source: " & sourceType & "): " & sourceType & " =\n"
  if plan.hasObjectLayout(classDecl.sourceName):
    result.add "  if not eidoMemoryPresent(source):\n"
    result.add "    return default(" & sourceType & ")\n"
  else:
    result.add "  if source.isNil:\n"
    result.add "    return nil\n"

  let sourceIdentity = renderCopyIdentity(
    "source", classDecl.sourceName, plan
  )
  result.add "  let eido_copy_existing = " & copyMemoLookupName() &
    "(" & sourceIdentity & ")\n"
  result.add "  if eido_copy_existing != int64(0):\n"
  result.add "    return " & renderCopiedIdentity(
    "eido_copy_existing", classDecl.sourceName, plan
  ) & "\n"

  result.add "  result = " & classAllocateName(classDecl.sourceName) & "()\n"
  result.add "  " & copyMemoRememberName() & "(" & sourceIdentity & ", " &
    renderCopyIdentity("result", classDecl.sourceName, plan) & ")\n"

  for field in classDecl.fields:
    let getter = classFieldGetName(classDecl.sourceName, field.sourceName)
    let setter = classFieldSetName(classDecl.sourceName, field.sourceName)
    let sourceValue = getter & "(source)"

    if field.typ.kind == etkClass and
        isConcreteStorageTypeName(field.typ.className):
      result.add "  " & setter & "(result, " & sourceValue & ")\n"
    elif field.typ.kind == etkClass:
      if plan.hasObjectLayout(classDecl.sourceName):
        result.add "  if eidoMemoryPresent(" & sourceValue & "):\n"
        result.add "    " & setter & "(result, " &
          classCopyInternalName(field.typ.className) &
          "(" & sourceValue & "))\n"
        result.add "  else:\n"
        result.add "    " & setter & "(result, default(" &
          className(field.typ.className) & "))\n"
      elif field.typ.isOptional:
        result.add "  if isSome(" & sourceValue & "):\n"
        result.add "    " & setter & "(result, some(" &
          classCopyInternalName(field.typ.className) &
          "(get(" & sourceValue & "))))\n"
        result.add "  else:\n"
        result.add "    " & setter & "(result, none(" &
          className(field.typ.className) & "))\n"
      else:
        result.add "  " & setter & "(result, " &
          classCopyInternalName(field.typ.className) &
          "(" & sourceValue & "))\n"
    else:
      result.add "  " & setter & "(result, " & sourceValue & ")\n"
  result.add "\n"

## Renders the public copy entry point around one explicitly owned memo lifetime.
proc renderPublicCopier(
  classDecl: hirDeclarations.HirClass
): string =
  let sourceType = className(classDecl.sourceName)
  result.add "proc " & classCopyName(classDecl.sourceName) &
    "(source: " & sourceType & "): " & sourceType & " =\n"
  result.add "  " & copyMemoBeginName() & "()\n"
  result.add "  result = " & classCopyInternalName(classDecl.sourceName) &
    "(source)\n"
  result.add "  " & copyMemoEndName() & "()\n\n"

## Renders all copy support needed by the program's nominal classes.
proc renderClassCopiers*(
  classes: seq[hirDeclarations.HirClass],
  plan: CompileTimeMemoryMetadata = CompileTimeMemoryMetadata()
): string =
  var copyableClasses: seq[hirDeclarations.HirClass]
  for classDecl in classes:
    if not isConcreteStorageTypeName(classDecl.sourceName):
      copyableClasses.add classDecl

  if copyableClasses.len == 0:
    return ""

  result.add renderCopyDeclarations(copyableClasses)
  for classDecl in copyableClasses:
    result.add renderInternalCopier(classDecl, plan)
  for classDecl in copyableClasses:
    result.add renderPublicCopier(classDecl)
