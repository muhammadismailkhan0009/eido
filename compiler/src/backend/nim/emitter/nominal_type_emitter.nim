## Renders Eido nominal layouts for the Nim backend.
## GC-selected classes/interfaces use one-pointer EidoManagedRef handles plus
## explicit payload objects; manual/unplanned declarations retain the bootstrap
## backend representation when no managed runtime representation is required.

import ../../../compile_time/model
import ../../../hir/declarations as hirDeclarations
import ../../../types/function_result
import ../../../types/storage
import names
import type_emitter
import storage_support

## Renders one managed interface method-pointer type.
proc renderManagedInterfaceMethodType(
  methodDecl: hirDeclarations.HirInterfaceMethod
): string =
  result = "proc(receiver: EidoManagedRef"
  for index, parameterType in methodDecl.parameterTypes:
    result.add ", arg" & $index & ": " & renderType(parameterType)
  result.add ")"
  if methodDecl.result.kind == frSingle:
    result.add ": " & renderType(methodDecl.result.typ)
  result.add " {.nimcall.}"

## Renders one bootstrap closure method type when no managed runtime is selected.
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
  plan: CompileTimeMemoryPlan = CompileTimeMemoryPlan()
): string =
  if interfaces.len == 0 and classes.len == 0:
    return ""

  let managedRuntime = plan.types.len > 0
  result.add "type\n"

  # First declare stable nominal handle names.
  for interfaceDecl in interfaces:
    if managedRuntime:
      result.add "  " & interfaceName(interfaceDecl.sourceName) &
        " = EidoManagedRef\n"
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
    elif plan.hasManagedLayout(classDecl.sourceName):
      result.add "  " & className(classDecl.sourceName) &
        " = EidoManagedRef\n"
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

  # Managed class payloads hold fields separately from their one-pointer handles.
  for classDecl in classes:
    if not plan.hasManagedLayout(classDecl.sourceName):
      continue

    result.add "  " & classPayloadName(classDecl.sourceName) & " = object\n"
    if classDecl.fields.len == 0:
      result.add "    discard\n"
    else:
      for field in classDecl.fields:
        result.add "    " & fieldName(field.sourceName) &
          ": " & renderType(field.typ) & "\n"

  # Managed interface boxes are themselves GC objects. The receiver is first so
  # tracing and root representation remain one managed-reference operation.
  if managedRuntime:
    for interfaceDecl in interfaces:
      result.add "  " & interfacePayloadName(interfaceDecl.sourceName) &
        " = object\n"
      result.add "    eido_receiver: EidoManagedRef\n"
      for methodDecl in interfaceDecl.methods:
        result.add "    " & interfaceMethodFieldName(
          interfaceDecl.sourceName,
          methodDecl.sourceName
        ) & ": " & renderManagedInterfaceMethodType(methodDecl) & "\n"

  result.add "\n"
