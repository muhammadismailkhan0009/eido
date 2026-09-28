## Renders all Eido nominal class/interface layouts in one Nim type section.
## One section permits class fields and interface method signatures to reference each other recursively.

import ../../../hir/declarations as hirDeclarations
import ../../../types/function_result
import names
import type_emitter

## Renders one interface method closure type inside the unified nominal section.
proc renderNominalInterfaceMethodType(
  methodDecl: hirDeclarations.HirInterfaceMethod
): string =
  result = "proc("
  for index, parameterType in methodDecl.parameterTypes:
    if index > 0:
      result.add ", "
    result.add "arg" & $index & ": " & renderType(parameterType)
  result.add ")"
  if methodDecl.result.kind == frSingle:
    result.add ": " & renderType(methodDecl.result.typ)
  result.add " {.closure.}"

## Renders interfaces and classes together so nominal references are order-independent.
proc renderNominalTypes*(
  interfaces: seq[hirDeclarations.HirInterface],
  classes: seq[hirDeclarations.HirClass]
): string =
  if interfaces.len == 0 and classes.len == 0:
    return ""

  result.add "type\n"

  for interfaceDecl in interfaces:
    result.add "  " & interfaceName(interfaceDecl.sourceName) & " = ref object\n"
    if interfaceDecl.methods.len == 0:
      result.add "    discard\n"
    else:
      for methodDecl in interfaceDecl.methods:
        result.add "    " & interfaceMethodFieldName(
          interfaceDecl.sourceName,
          methodDecl.sourceName
        ) & ": " & renderNominalInterfaceMethodType(methodDecl) & "\n"

  for classDecl in classes:
    result.add "  " & className(classDecl.sourceName) & " = ref object\n"
    if classDecl.fields.len == 0:
      result.add "    discard\n"
    else:
      for field in classDecl.fields:
        result.add "    " & fieldName(field.sourceName) &
          ": " & renderType(field.typ) & "\n"

  result.add "\n"
