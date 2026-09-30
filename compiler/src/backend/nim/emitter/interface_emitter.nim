## Lowers interface contracts to either managed interface boxes or the bootstrap
## closure representation when no managed memory strategy is active.

import ../../../hir/declarations as hirDeclarations
import ../../../types/function_result
import names
import type_emitter

## Finds one interface HIR declaration by source name.
proc findInterface(
  interfaces: seq[hirDeclarations.HirInterface],
  name: string
): hirDeclarations.HirInterface =
  for interfaceDecl in interfaces:
    if interfaceDecl.sourceName == name:
      return interfaceDecl
  raise newException(ValueError, "backend invariant: missing interface '" & name & "'")

## Finds one class method by source name after semantic conformance validation.
proc findClassMethod(
  classDecl: hirDeclarations.HirClass,
  name: string
): hirDeclarations.HirMethod =
  for methodDecl in classDecl.methods:
    if methodDecl.sourceName == name:
      return methodDecl
  raise newException(
    ValueError,
    "backend invariant: class '" & classDecl.sourceName &
      "' lacks interface method '" & name & "'"
  )

## Reports whether one interface extends another, including identity.
proc hirInterfaceExtends(
  interfaces: seq[hirDeclarations.HirInterface],
  childName, ancestorName: string
): bool =
  if childName == ancestorName:
    return true
  let child = findInterface(interfaces, childName)
  for parent in child.extends:
    if hirInterfaceExtends(interfaces, parent, ancestorName):
      return true
  false

## Renders representation-neutral interface dispatch helpers used by expressions.
proc renderInterfaceDispatchers*(
  interfaces: seq[hirDeclarations.HirInterface],
  managedRuntime: bool
): string =
  for interfaceDecl in interfaces:
    for methodDecl in interfaceDecl.methods:
      result.add "proc " & interfaceDispatchName(
        interfaceDecl.sourceName,
        methodDecl.sourceName
      ) & "(source: " & interfaceName(interfaceDecl.sourceName)

      for index, parameterType in methodDecl.parameterTypes:
        result.add ", arg" & $index & ": " & renderType(parameterType)
      result.add ")"
      if methodDecl.result.kind == frSingle:
        result.add ": " & renderType(methodDecl.result.typ)
      result.add " =\n"

      if managedRuntime:
        result.add "  let payload = eidoGcPayload[" &
          interfacePayloadName(interfaceDecl.sourceName) &
          "](source)\n"
        result.add "  "
        if methodDecl.result.kind == frSingle:
          result.add "return "
        result.add "payload[]." & interfaceMethodFieldName(
          interfaceDecl.sourceName,
          methodDecl.sourceName
        ) & "(payload[].eido_receiver"
        for index in 0 ..< methodDecl.parameterTypes.len:
          result.add ", arg" & $index
        result.add ")\n\n"
      else:
        result.add "  "
        if methodDecl.result.kind == frSingle:
          result.add "return "
        result.add "source." & interfaceMethodFieldName(
          interfaceDecl.sourceName,
          methodDecl.sourceName
        ) & "("
        for index in 0 ..< methodDecl.parameterTypes.len:
          if index > 0:
            result.add ", "
          result.add "arg" & $index
        result.add ")\n\n"

## Renders managed interface trace/destroy/allocation helpers.
proc renderManagedInterfaceSupport*(
  interfaces: seq[hirDeclarations.HirInterface]
): string =
  for interfaceDecl in interfaces:
    let sourceName = interfaceDecl.sourceName
    let payloadType = interfacePayloadName(sourceName)

    result.add "proc " & interfaceTraceName(sourceName) &
      "(payloadAddress: pointer) {.nimcall.} =\n"
    result.add "  let payload = cast[ptr " & payloadType &
      "](payloadAddress)\n"
    result.add "  eidoGcMark(payload[].eido_receiver)\n\n"

    result.add "proc " & interfaceDestroyName(sourceName) &
      "(payloadAddress: pointer) {.nimcall.} =\n"
    result.add "  cast[ptr " & payloadType &
      "](payloadAddress)[] = default(" & payloadType & ")\n\n"

    result.add "proc " & interfaceAllocateName(sourceName) & "(): " &
      interfaceName(sourceName) & " =\n"
    result.add "  result = eidoGcAllocate(\n"
    result.add "    int64(sizeof(" & payloadType & ")),\n"
    result.add "    int64(alignof(" & payloadType & ")),\n"
    result.add "    " & interfaceTraceName(sourceName) & ",\n"
    result.add "    " & interfaceDestroyName(sourceName) & "\n"
    result.add "  )\n\n"

## Renders one class-to-interface adapter after class methods are forward-declared.
proc renderClassInterfaceAdapter(
  classDecl: hirDeclarations.HirClass,
  interfaceDecl: hirDeclarations.HirInterface,
  managedRuntime: bool
): string =
  if managedRuntime:
    for contract in interfaceDecl.methods:
      let implementation = findClassMethod(classDecl, contract.sourceName)
      result.add "proc " & interfaceThunkName(
        classDecl.sourceName,
        interfaceDecl.sourceName,
        contract.sourceName
      ) & "(receiver: EidoManagedRef"

      for index, parameterType in contract.parameterTypes:
        result.add ", arg" & $index & ": " & renderType(parameterType)
      result.add ")"
      if contract.result.kind == frSingle:
        result.add ": " & renderType(contract.result.typ)
      result.add " {.nimcall.} =\n"
      result.add "  "
      if contract.result.kind == frSingle:
        result.add "return "
      result.add methodName(
        implementation.methodId,
        classDecl.sourceName,
        implementation.sourceName
      ) & "(receiver"
      for index in 0 ..< contract.parameterTypes.len:
        result.add ", arg" & $index
      result.add ")\n\n"

  result.add "proc " & interfaceAdapterName(
    classDecl.sourceName,
    interfaceDecl.sourceName
  ) & "(source: " & className(classDecl.sourceName) & "): " &
    interfaceName(interfaceDecl.sourceName) & " =\n"

  if managedRuntime:
    result.add "  result = " & interfaceAllocateName(
      interfaceDecl.sourceName
    ) & "()\n"
    result.add "  let payload = eidoGcPayload[" &
      interfacePayloadName(interfaceDecl.sourceName) & "](result)\n"
    result.add "  payload[].eido_receiver = source\n"

    for contract in interfaceDecl.methods:
      result.add "  payload[]." & interfaceMethodFieldName(
        interfaceDecl.sourceName,
        contract.sourceName
      ) & " = " & interfaceThunkName(
        classDecl.sourceName,
        interfaceDecl.sourceName,
        contract.sourceName
      ) & "\n"
  else:
    result.add "  result = " & interfaceName(interfaceDecl.sourceName) & "()\n"
    for contract in interfaceDecl.methods:
      let implementation = findClassMethod(classDecl, contract.sourceName)
      let field = interfaceMethodFieldName(
        interfaceDecl.sourceName,
        contract.sourceName
      )
      result.add "  result." & field & " = proc("
      for index, parameterType in contract.parameterTypes:
        if index > 0:
          result.add ", "
        result.add "arg" & $index & ": " & renderType(parameterType)
      result.add ")"
      if contract.result.kind == frSingle:
        result.add ": " & renderType(contract.result.typ)
      result.add " =\n"
      result.add "    "
      if contract.result.kind == frSingle:
        result.add "return "
      result.add methodName(
        implementation.methodId,
        classDecl.sourceName,
        implementation.sourceName
      ) & "(source"
      for index in 0 ..< contract.parameterTypes.len:
        result.add ", arg" & $index
      result.add ")\n"

  if interfaceDecl.methods.len == 0 and not managedRuntime:
    result.add "  discard\n"
  result.add "\n"

## Renders adapters for every direct or inherited interface a class conforms to.
proc renderClassInterfaceAdapters*(
  interfaces: seq[hirDeclarations.HirInterface],
  classes: seq[hirDeclarations.HirClass],
  managedRuntime: bool = false
): string =
  for classDecl in classes:
    var emitted: seq[string]
    for implemented in classDecl.implements:
      for candidate in interfaces:
        if hirInterfaceExtends(
          interfaces,
          implemented,
          candidate.sourceName
        ) and candidate.sourceName notin emitted:
          result.add renderClassInterfaceAdapter(
            classDecl,
            candidate,
            managedRuntime
          )
          emitted.add candidate.sourceName

## Renders interface-extension upcasts.
proc renderInterfaceUpcasts*(
  interfaces: seq[hirDeclarations.HirInterface],
  managedRuntime: bool = false
): string =
  for source in interfaces:
    for target in interfaces:
      if source.sourceName == target.sourceName:
        continue
      if not hirInterfaceExtends(
        interfaces,
        source.sourceName,
        target.sourceName
      ):
        continue

      result.add "proc " & interfaceUpcastName(
        source.sourceName,
        target.sourceName
      ) & "(source: " & interfaceName(source.sourceName) & "): " &
        interfaceName(target.sourceName) & " =\n"

      if managedRuntime:
        result.add "  result = " & interfaceAllocateName(
          target.sourceName
        ) & "()\n"
        result.add "  let sourcePayload = eidoGcPayload[" &
          interfacePayloadName(source.sourceName) & "](source)\n"
        result.add "  let targetPayload = eidoGcPayload[" &
          interfacePayloadName(target.sourceName) & "](result)\n"
        result.add "  targetPayload[].eido_receiver = " &
          "sourcePayload[].eido_receiver\n"
        for methodDecl in target.methods:
          result.add "  targetPayload[]." & interfaceMethodFieldName(
            target.sourceName,
            methodDecl.sourceName
          ) & " = sourcePayload[]." & interfaceMethodFieldName(
            source.sourceName,
            methodDecl.sourceName
          ) & "\n"
      else:
        result.add "  result = " & interfaceName(target.sourceName) & "()\n"
        for methodDecl in target.methods:
          result.add "  result." & interfaceMethodFieldName(
            target.sourceName,
            methodDecl.sourceName
          ) & " = source." & interfaceMethodFieldName(
            source.sourceName,
            methodDecl.sourceName
          ) & "\n"

      if target.methods.len == 0 and not managedRuntime:
        result.add "  discard\n"
      result.add "\n"
