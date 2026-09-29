## Owns the complete nominal type environment shared by semantic analysis.
## Classes and interfaces remain separate symbol families behind one lookup boundary.

import ../../diagnostics/errors
import ../../source/span
import ../../types/model
import classes
import interfaces
import model
export classes, interfaces

type
  NominalSymbols* = object
    classes*: ClassSymbols
    interfaces*: InterfaceSymbols

## Creates empty class and interface registries.
proc initNominalSymbols*(): NominalSymbols =
  NominalSymbols(
    classes: initClassSymbols(),
    interfaces: initInterfaceSymbols()
  )

## Reports whether a concrete class name is registered.
proc containsClass*(symbols: NominalSymbols, name: string): bool =
  symbols.classes.contains(name)

## Reports whether an interface name is registered.
proc containsInterface*(symbols: NominalSymbols, name: string): bool =
  symbols.interfaces.contains(name)

## Retrieves one concrete class symbol.
proc getClass*(symbols: NominalSymbols, name: string): ClassSymbol =
  symbols.classes.get(name)

## Retrieves one interface symbol.
proc getInterface*(symbols: NominalSymbols, name: string): InterfaceSymbol =
  symbols.interfaces.get(name)

## Registers a concrete class symbol.
proc addClass*(symbols: var NominalSymbols, symbol: ClassSymbol) =
  symbols.classes.add(symbol)

## Registers an interface symbol.
proc addInterface*(symbols: var NominalSymbols, symbol: InterfaceSymbol) =
  symbols.interfaces.add(symbol)

## Reports whether a nominal name belongs to either class or interface space.
proc containsNominal*(symbols: NominalSymbols, name: string): bool =
  symbols.containsClass(name) or symbols.containsInterface(name)

## Resolves a registered nominal name to its semantic type.
proc nominalType*(symbols: NominalSymbols, name: string, span: SourceSpan): EidoType =
  if symbols.containsClass(name):
    return symbols.getClass(name).typ
  if symbols.containsInterface(name):
    return symbols.getInterface(name).typ
  failAt(span, "unknown type '" & name & "'")

## Reports whether one interface extends another, including identity.
proc interfaceExtends*(
  symbols: NominalSymbols,
  childName, ancestorName: string
): bool =
  if childName == ancestorName:
    return true
  if not symbols.containsInterface(childName):
    return false

  let child = symbols.getInterface(childName)
  for parent in child.extends:
    if symbols.interfaceExtends(parent, ancestorName):
      return true
  false

## Reports whether a class explicitly implements an interface or one of its descendants.
proc classImplements*(
  symbols: NominalSymbols,
  className, interfaceName: string
): bool =
  if not symbols.containsClass(className):
    return false
  let sourceClass = symbols.getClass(className)
  for implemented in sourceClass.implements:
    if symbols.interfaceExtends(implemented, interfaceName):
      return true
  false

## Reports whether an actual semantic type may flow into an expected type.
## Optional injection is handled separately by expected-type analysis.
proc isAssignable*(symbols: NominalSymbols, actual, expected: EidoType): bool =
  if actual == expected:
    return true
  if actual.isOptional or expected.isOptional:
    return false

  if actual.kind == etkClass and expected.kind == etkInterface:
    return symbols.classImplements(actual.className, expected.interfaceName)

  if actual.kind == etkInterface and expected.kind == etkInterface:
    return symbols.interfaceExtends(actual.interfaceName, expected.interfaceName)

  false

## Collects effective interface methods in stable parent-first order.
## A child redeclaration replaces the inherited dispatch signature while preserving its contract chain separately.
proc requiredInterfaceMethods*(
  symbols: NominalSymbols,
  interfaceName: string
): seq[InterfaceMethodSymbol] =
  let sourceInterface = symbols.getInterface(interfaceName)

  for parent in sourceInterface.extends:
    for inherited in symbols.requiredInterfaceMethods(parent):
      result.add inherited

  for own in sourceInterface.methods:
    var replaced = false
    for index in 0 ..< result.len:
      if result[index].name == own.name:
        result[index] = own
        replaced = true
        break
    if not replaced:
      result.add own

## Collects every declaration contributing contracts to one effective interface method.
proc interfaceMethodContractChain*(
  symbols: NominalSymbols,
  interfaceName, methodName: string
): seq[InterfaceMethodSymbol] =
  let sourceInterface = symbols.getInterface(interfaceName)
  for parent in sourceInterface.extends:
    for inherited in symbols.interfaceMethodContractChain(parent, methodName):
      result.add inherited

  for own in sourceInterface.methods:
    if own.name == methodName:
      result.add own

## Retrieves one direct or inherited interface method contract.
proc getInterfaceMethod*(
  symbols: NominalSymbols,
  interfaceName, methodName: string
): InterfaceMethodSymbol =
  for methodSymbol in symbols.requiredInterfaceMethods(interfaceName):
    if methodSymbol.name == methodName:
      return methodSymbol
  raise newException(
    KeyError,
    "unknown interface method '" & interfaceName & "." & methodName & "'"
  )

## Reports whether one direct or inherited interface method exists.
proc containsInterfaceMethod*(
  symbols: NominalSymbols,
  interfaceName, methodName: string
): bool =
  for methodSymbol in symbols.requiredInterfaceMethods(interfaceName):
    if methodSymbol.name == methodName:
      return true
  false
