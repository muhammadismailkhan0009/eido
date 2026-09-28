## Lowers interface contracts to closure-backed Nim wrapper types and adapters.
## Concrete implementation identity remains hidden behind the generated closures.

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

## Renders one interface method closure type.
proc renderInterfaceMethodType(methodDecl: hirDeclarations.HirInterfaceMethod): string =
  result = "proc("
  for index, parameterType in methodDecl.parameterTypes:
    if index > 0:
      result.add ", "
    result.add "arg" & $index & ": " & renderType(parameterType)
  result.add ")"
  if methodDecl.result.kind == frSingle:
    result.add ": " & renderType(methodDecl.result.typ)
  result.add " {.closure.}"

## Renders all interface wrapper types in one Nim type section.
proc renderInterfaces*(interfaces: seq[hirDeclarations.HirInterface]): string =
  if interfaces.len == 0:
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
        ) & ": " & renderInterfaceMethodType(methodDecl) & "\n"
  result.add "\n"

## Renders one class-to-interface adapter after class methods have been forward-declared.
proc renderClassInterfaceAdapter(
  classDecl: hirDeclarations.HirClass,
  interfaceDecl: hirDeclarations.HirInterface
): string =
  result.add "proc " & interfaceAdapterName(
    classDecl.sourceName,
    interfaceDecl.sourceName
  ) & "(source: " & className(classDecl.sourceName) & "): " &
    interfaceName(interfaceDecl.sourceName) & " =\n"
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

  if interfaceDecl.methods.len == 0:
    result.add "  discard\n"
  result.add "\n"

## Renders adapters for every direct or inherited interface a class conforms to.
proc renderClassInterfaceAdapters*(
  interfaces: seq[hirDeclarations.HirInterface],
  classes: seq[hirDeclarations.HirClass]
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
          result.add renderClassInterfaceAdapter(classDecl, candidate)
          emitted.add candidate.sourceName

## Renders interface-extension upcasts by copying already-bound method closures.
proc renderInterfaceUpcasts*(
  interfaces: seq[hirDeclarations.HirInterface]
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
      result.add "  result = " & interfaceName(target.sourceName) & "()\n"

      for methodDecl in target.methods:
        result.add "  result." & interfaceMethodFieldName(
          target.sourceName,
          methodDecl.sourceName
        ) & " = source." & interfaceMethodFieldName(
          source.sourceName,
          methodDecl.sourceName
        ) & "\n"

      if target.methods.len == 0:
        result.add "  discard\n"
      result.add "\n"
