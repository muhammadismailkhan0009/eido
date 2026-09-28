## Resolves interface inheritance/contracts and verifies explicit class conformance.

import std/[sets]
import ../../diagnostics/errors
import ../../frontend/ast/declarations
import ../../types/[function_result, method_kind, model]
import ../symbols/[interfaces, model, nominals]
import type_resolution

## Verifies that interface inheritance is acyclic and references interfaces only.
proc validateInterfaceInheritance*(
  sourceInterfaces: seq[InterfaceDecl],
  symbols: NominalSymbols
) =
  for sourceInterface in sourceInterfaces:
    for parent in sourceInterface.extends:
      if not symbols.containsInterface(parent):
        failAt(
          sourceInterface.span,
          "interface '" & sourceInterface.name &
            "' extends unknown interface '" & parent & "'"
        )

  var visiting = initHashSet[string]()
  var visited = initHashSet[string]()

  proc visit(name: string) =
    if name in visited:
      return
    if name in visiting:
      failAt(
        symbols.getInterface(name).span,
        "interface extension cycle contains '" & name & "'"
      )

    visiting.incl name
    for parent in symbols.getInterface(name).extends:
      visit(parent)
    visiting.excl name
    visited.incl name

  for sourceInterface in sourceInterfaces:
    visit(sourceInterface.name)

## Resolves direct method signatures for every interface.
proc resolveInterfaceMethods*(
  sourceInterfaces: seq[InterfaceDecl],
  symbols: var NominalSymbols
) =
  for sourceInterface in sourceInterfaces:
    var interfaceSymbol = symbols.getInterface(sourceInterface.name)
    var methodNames = initHashSet[string]()

    for sourceMethod in sourceInterface.methods:
      if sourceMethod.name in methodNames:
        failAt(
          sourceMethod.span,
          "duplicate method '" & sourceMethod.name &
            "' in interface '" & sourceInterface.name & "'"
        )
      methodNames.incl sourceMethod.name

      var parameterTypes: seq[EidoType]
      for parameter in sourceMethod.parameters:
        let parameterType = resolveDeclaredType(parameter.typeRef, symbols)
        if parameterType.kind == etkClass:
          failAt(
            parameter.typeRef.span,
            "interface contracts cannot expose concrete class type '" &
              parameterType.className & "'"
          )
        parameterTypes.add parameterType

      let methodResult = resolveFunctionResult(sourceMethod.result, symbols)
      if methodResult.kind == frSingle and methodResult.typ.kind == etkClass:
        failAt(
          sourceMethod.result.typeRef.span,
          "interface contracts cannot expose concrete class type '" &
            methodResult.typ.className & "'"
        )

      interfaceSymbol.methods.add InterfaceMethodSymbol(
        name: sourceMethod.name,
        parameterTypes: parameterTypes,
        result: methodResult,
        span: sourceMethod.span
      )

    symbols.addInterface(interfaceSymbol)

## Reports exact callable signature equality for interface conformance.
proc sameInterfaceSignature(
  methodSymbol: MethodSymbol,
  contract: InterfaceMethodSymbol
): bool =
  if methodSymbol.parameterTypes != contract.parameterTypes:
    return false
  if methodSymbol.result.kind != contract.result.kind:
    return false
  if methodSymbol.result.kind == frSingle:
    return methodSymbol.result.typ == contract.result.typ
  true

## Verifies all explicitly implemented interface contracts for one class.
proc validateClassInterfaces*(
  sourceClass: ClassDecl,
  symbols: NominalSymbols
) =
  var seen = initHashSet[string]()

  for interfaceName in sourceClass.implements:
    if interfaceName in seen:
      failAt(
        sourceClass.span,
        "class '" & sourceClass.name &
          "' repeats implemented interface '" & interfaceName & "'"
      )
    seen.incl interfaceName

    if not symbols.containsInterface(interfaceName):
      failAt(
        sourceClass.span,
        "class '" & sourceClass.name &
          "' implements unknown interface '" & interfaceName & "'"
      )

    let classSymbol = symbols.getClass(sourceClass.name)
    for contract in symbols.requiredInterfaceMethods(interfaceName):
      if not classSymbol.containsMethod(contract.name):
        failAt(
          sourceClass.span,
          "class '" & sourceClass.name & "' does not implement interface method '" &
            interfaceName & "." & contract.name & "'"
        )

      let implementation = classSymbol.getMethod(contract.name)
      if implementation.kind != mkInstance:
        failAt(
          implementation.span,
          "interface method '" & interfaceName & "." & contract.name &
            "' requires an instance method implementation"
        )

      if not sameInterfaceSignature(implementation, contract):
        failAt(
          implementation.span,
          "method '" & sourceClass.name & "." & contract.name &
            "' does not match interface signature '" &
            interfaceName & "." & contract.name & "'"
        )
