## Resolves interface inheritance/contracts and verifies explicit class conformance.

import std/[sets, tables]
import ../../diagnostics/errors
import ../../frontend/ast/declarations
import ../../hir/declarations as hirDeclarations
import ../../types/[function_result, method_kind, model]
import ../symbols/[functions, ids, interfaces, model, nominals, scope]
import type_resolution
import contracts

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

  ## Visits one interface inheritance path for cycle detection.
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

## Resolves direct method signatures and preserves their source contracts.
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
        parameterTypes.add resolveDeclaredType(parameter.typeRef, symbols)

      let methodResult = resolveFunctionResult(sourceMethod.result, symbols)

      interfaceSymbol.methods.add InterfaceMethodSymbol(
        name: sourceMethod.name,
        declaringInterface: sourceInterface.name,
        parameterTypes: parameterTypes,
        result: methodResult,
        sourceDecl: sourceMethod,
        span: sourceMethod.span
      )

    symbols.addInterface(interfaceSymbol)

## Reports exact callable signature equality between two interface declarations.
proc sameInterfaceSignature(
  left, right: InterfaceMethodSymbol
): bool =
  if left.parameterTypes != right.parameterTypes:
    return false
  if left.result.kind != right.result.kind:
    return false
  if left.result.kind == frSingle:
    return left.result.typ == right.result.typ
  true

## Reports exact callable signature equality for concrete interface conformance.
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

## Verifies that a child redeclaration preserves the inherited callable signature.
proc validateInterfaceRedeclarations*(
  sourceInterfaces: seq[InterfaceDecl],
  symbols: NominalSymbols
) =
  for sourceInterface in sourceInterfaces:
    if sourceInterface.extends.len == 0:
      continue

    let parentName = sourceInterface.extends[0]
    for own in symbols.getInterface(sourceInterface.name).methods:
      if not symbols.containsInterfaceMethod(parentName, own.name):
        continue
      let inherited = symbols.getInterfaceMethod(parentName, own.name)
      if not sameInterfaceSignature(own, inherited):
        failAt(
          own.span,
          "interface method '" & sourceInterface.name & "." & own.name &
            "' must preserve inherited signature '" &
            parentName & "." & own.name & "'"
        )

## Builds interface-local contract HIR for tooling and semantic inspection.
proc analyzeInterfaceMethodContract*(
  contract: InterfaceMethodSymbol,
  symbols: NominalSymbols
): hirDeclarations.HirInterfaceMethod =
  var locals = initLocalScope()
  let receiverLocalId = locals.nextLocalId()
  locals.add(
    "self",
    LocalSymbol(
      name: "self",
      typ: interfaceType(contract.declaringInterface),
      span: contract.span,
      kind: bkReceiver,
      id: receiverLocalId,
      classValueProvenance: cvpNotClass
    )
  )

  var parameters: seq[hirDeclarations.HirParameter]
  for index, parameter in contract.sourceDecl.parameters:
    let parameterType = contract.parameterTypes[index]
    let localId = locals.nextLocalId()
    locals.add(
      parameter.name,
      LocalSymbol(
        name: parameter.name,
        typ: parameterType,
        span: parameter.span,
        kind: bkParameter,
        id: localId,
        classValueProvenance:
          if parameterType.kind == etkClass: cvpExisting else: cvpNotClass
      )
    )
    parameters.add hirDeclarations.HirParameter(
      span: parameter.span,
      localId: localId,
      sourceName: parameter.name,
      typ: parameterType
    )

  let noFunctions = initFunctionSymbols()
  let requires = analyzeContractClauses(
    contract.sourceDecl.requires,
    locals,
    noFunctions,
    symbols,
    "require"
  )

  var ensureResultLocalId = LocalId(-1)
  var ensureLocals = locals.fork()
  if contract.sourceDecl.ensures.len > 0 and contract.result.kind == frSingle:
    ensureResultLocalId = locals.nextLocalId()
    ensureLocals = locals.fork()
    ensureLocals.add(
      "result",
      LocalSymbol(
        id: ensureResultLocalId,
        name: "result",
        typ: contract.result.typ,
        kind: bkParameter,
        span: contract.span,
        classValueProvenance:
          if contract.result.typ.kind == etkClass: cvpDetached else: cvpNotClass
      )
    )

  let ensures = analyzeContractClauses(
    contract.sourceDecl.ensures,
    ensureLocals,
    noFunctions,
    symbols,
    "ensure",
    contract.result.kind == frSingle
  )

  hirDeclarations.HirInterfaceMethod(
    span: contract.span,
    sourceName: contract.name,
    declaringInterface: contract.declaringInterface,
    parameterTypes: contract.parameterTypes,
    parameters: parameters,
    result: contract.result,
    requires: requires,
    ensures: ensures,
    receiverLocalId: receiverLocalId,
    ensureResultLocalId: ensureResultLocalId
  )

## Collects all inherited contract declarations for one concrete class method.
proc inheritedInterfaceContracts*(
  sourceClass: ClassDecl,
  methodName: string,
  symbols: NominalSymbols
): seq[InterfaceMethodSymbol] =
  var seen = initHashSet[string]()
  for interfaceName in sourceClass.implements:
    if not symbols.containsInterfaceMethod(interfaceName, methodName):
      continue
    for contract in symbols.interfaceMethodContractChain(interfaceName, methodName):
      let key = contract.declaringInterface & "." & contract.name
      if key notin seen:
        seen.incl key
        result.add contract

## Verifies all explicitly implemented interface contracts for one class.
proc validateClassInterfaces*(
  sourceClass: ClassDecl,
  symbols: NominalSymbols
) =
  var seenInterfaces = initHashSet[string]()
  var effectiveDeclarations = initTable[string, InterfaceMethodSymbol]()

  for interfaceName in sourceClass.implements:
    if interfaceName in seenInterfaces:
      failAt(
        sourceClass.span,
        "class '" & sourceClass.name &
          "' repeats implemented interface '" & interfaceName & "'"
      )
    seenInterfaces.incl interfaceName

    if not symbols.containsInterface(interfaceName):
      failAt(
        sourceClass.span,
        "class '" & sourceClass.name &
          "' implements unknown interface '" & interfaceName & "'"
      )

    for contract in symbols.requiredInterfaceMethods(interfaceName):
      if contract.name in effectiveDeclarations:
        let previous = effectiveDeclarations[contract.name]
        if previous.declaringInterface != contract.declaringInterface:
          failAt(
            sourceClass.span,
            "class '" & sourceClass.name &
              "' cannot implement independent interface declarations '" &
              previous.declaringInterface & "." & previous.name & "' and '" &
              contract.declaringInterface & "." & contract.name & "'"
          )
      else:
        effectiveDeclarations[contract.name] = contract

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
