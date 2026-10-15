## Renders Eido nominal layouts for the Nim backend.
## Runtime-backed classes/interfaces use direct int64 identity handles plus
## explicit payload objects; declarations without object-runtime metadata retain
## the bootstrap backend representation.

import ../../../compile_time/model
import ../../../hir/declarations as hirDeclarations
import ../../../types/function_result
import ../../../types/storage
import names
import type_emitter
import storage_support

## Renders one runtime-backed interface method-pointer type.
proc renderRuntimeInterfaceMethodType(
  methodDecl: hirDeclarations.HirInterfaceMethod
): string =
  result = "proc(receiver: int64"
  for index, parameterType in methodDecl.parameterTypes:
    result.add ", arg" & $index & ": " & renderType(parameterType)
  result.add ")"
  if methodDecl.result.kind == frSingle:
    result.add ": " & renderType(methodDecl.result.typ)
  result.add " {.nimcall.}"

## Renders one bootstrap closure method type when no object runtime is selected.
proc renderBootstrapInterfaceMethodType(
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

## Renders interfaces and classes together so nominal references remain order-independent.
proc renderNominalTypes*(
  interfaces: seq[hirDeclarations.HirInterface],
  classes: seq[hirDeclarations.HirClass],
  plan: CompileTimeMemoryMetadata = CompileTimeMemoryMetadata()
): string =
  if interfaces.len == 0 and classes.len == 0:
    return ""

  let runtimeBackedObjects = plan.types.len > 0
  result.add "type\n"

  # First declare stable nominal handle names.
  for interfaceDecl in interfaces:
    if runtimeBackedObjects:
      result.add "  " & interfaceName(interfaceDecl.sourceName) &
        " = int64\n"
    else:
      result.add "  " & interfaceName(interfaceDecl.sourceName) &
        " = ref object\n"
      if interfaceDecl.methods.len == 0:
        result.add "    discard\n"
      else:
        for methodDecl in interfaceDecl.methods:
          result.add "    " & interfaceMethodFieldName(
            interfaceDecl.sourceName,
            methodDecl.sourceName
          ) & ": " & renderBootstrapInterfaceMethodType(methodDecl) & "\n"

  for classDecl in classes:
    if isConcreteStorageTypeName(classDecl.sourceName):
      result.add "  " & className(classDecl.sourceName) & " = EidoStorage[" &
        renderType(storageElementType(classDecl)) & "]\n"
    elif plan.hasObjectLayout(classDecl.sourceName):
      result.add "  " & className(classDecl.sourceName) &
        " = int64\n"
    else:
      result.add "  " & className(classDecl.sourceName) & " = ref object\n"
      if classDecl.invariants.len > 0:
        result.add "    " & invariantEvaluationDepthFieldName() & ": int\n"
      if classDecl.fields.len == 0 and classDecl.invariants.len == 0:
        result.add "    discard\n"
      else:
        for field in classDecl.fields:
          result.add "    " & fieldName(field.sourceName) &
            ": " & renderType(field.typ) & "\n"

  # Runtime-backed class payloads hold fields separately from their identity handles.
  for classDecl in classes:
    if not plan.hasObjectLayout(classDecl.sourceName):
      continue

    result.add "  " & classPayloadName(classDecl.sourceName) & " = object\n"
    if classDecl.fields.len == 0:
      result.add "    discard\n"
    else:
      for field in classDecl.fields:
        result.add "    " & fieldName(field.sourceName) &
          ": " & renderType(field.typ) & "\n"

  # Runtime-backed interface boxes carry one receiver identity plus method pointers.
  # The receiver occupies the first payload field and is described through generic metadata.
  if runtimeBackedObjects:
    for interfaceDecl in interfaces:
      result.add "  " & interfacePayloadName(interfaceDecl.sourceName) &
        " = object\n"
      result.add "    eido_receiver: int64\n"
      for methodDecl in interfaceDecl.methods:
        result.add "    " & interfaceMethodFieldName(
          interfaceDecl.sourceName,
          methodDecl.sourceName
        ) & ": " & renderRuntimeInterfaceMethodType(methodDecl) & "\n"

  result.add "\n"
