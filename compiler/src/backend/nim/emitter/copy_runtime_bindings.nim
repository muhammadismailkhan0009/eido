## Resolves compiler-private detached graph-copy memo operations to ordinary Eido runtime methods.

import ../../../hir/program as hirProgram
import ../../../source/span
import names

type
  CopyRuntimeBindings* = object
    beginCopy*: string
    lookup*: string
    remember*: string
    endCopy*: string

## Reports whether the selected hidden language runtime includes graph-copy memo support.
proc hasCopyRuntime*(program: hirProgram.HirProgram): bool =
  for classDecl in program.classes:
    if not classDecl.span.isLanguageRuntime:
      continue
    for methodDecl in classDecl.methods:
      if methodDecl.sourceName == "copyMemoBegin":
        return true
  false

## Resolves one uniquely named graph-copy runtime operation.
proc resolveCopyRuntimeMethod(
  program: hirProgram.HirProgram,
  sourceName: string
): string =
  var resolved = ""
  for classDecl in program.classes:
    if not classDecl.span.isLanguageRuntime:
      continue
    for methodDecl in classDecl.methods:
      if methodDecl.sourceName != sourceName:
        continue
      if resolved.len > 0:
        raise newException(
          ValueError,
          "duplicate copy runtime operation '" & sourceName & "'"
        )
      resolved = methodName(
        methodDecl.methodId,
        classDecl.sourceName,
        methodDecl.sourceName
      )

  if resolved.len == 0:
    raise newException(
      ValueError,
      "missing copy runtime operation '" & sourceName & "'"
    )
  resolved

## Resolves every graph-copy memo operation required by generated copy traversal.
proc bindCopyRuntime*(program: hirProgram.HirProgram): CopyRuntimeBindings =
  CopyRuntimeBindings(
    beginCopy: program.resolveCopyRuntimeMethod("copyMemoBegin"),
    lookup: program.resolveCopyRuntimeMethod("copyMemoLookup"),
    remember: program.resolveCopyRuntimeMethod("copyMemoRemember"),
    endCopy: program.resolveCopyRuntimeMethod("copyMemoEnd")
  )
