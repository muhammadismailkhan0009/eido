## Resolves compiler-private built-in String operations to ordinary Eido runtime methods.

import ../../../hir/program as hirProgram
import ../../../source/span
import names

type
  StringRuntimeBindings* = object
    allocate*: string
    writeByte*: string
    length*: string
    byteAt*: string
    concat*: string
    equal*: string
    shutdown*: string

## Resolves one uniquely named built-in String runtime operation.
proc resolveStringRuntimeMethod(
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
          "duplicate String runtime operation '" & sourceName & "'"
        )
      resolved = methodName(
        methodDecl.methodId,
        classDecl.sourceName,
        methodDecl.sourceName
      )

  if resolved.len == 0:
    raise newException(
      ValueError,
      "missing String runtime operation '" & sourceName & "'"
    )
  resolved

## Resolves every built-in String semantic operation required by generated code.
proc bindStringRuntime*(program: hirProgram.HirProgram): StringRuntimeBindings =
  StringRuntimeBindings(
    allocate: program.resolveStringRuntimeMethod("stringAllocate"),
    writeByte: program.resolveStringRuntimeMethod("stringWriteByte"),
    length: program.resolveStringRuntimeMethod("stringLength"),
    byteAt: program.resolveStringRuntimeMethod("stringByteAt"),
    concat: program.resolveStringRuntimeMethod("stringConcat"),
    equal: program.resolveStringRuntimeMethod("stringEqual"),
    shutdown: program.resolveStringRuntimeMethod("stringShutdown")
  )
