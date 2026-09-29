## Stores interface contract symbols independently from concrete class symbols.

import std/tables
import ../../source/span
import ../../types/[function_result, model]
import ../../frontend/ast/declarations

type
  InterfaceMethodSymbol* = object
    name*: string
    declaringInterface*: string
    parameterTypes*: seq[EidoType]
    result*: FunctionResult
    sourceDecl*: FunctionDecl
    span*: SourceSpan

  InterfaceSymbol* = object
    name*: string
    moduleName*: string
    typ*: EidoType
    extends*: seq[string]
    methods*: seq[InterfaceMethodSymbol]
    span*: SourceSpan

  InterfaceSymbols* = object
    byName: Table[string, InterfaceSymbol]

## Creates an empty interface registry.
proc initInterfaceSymbols*(): InterfaceSymbols =
  InterfaceSymbols(byName: initTable[string, InterfaceSymbol]())

## Reports whether an interface name is registered.
proc contains*(symbols: InterfaceSymbols, name: string): bool =
  name in symbols.byName

## Registers or replaces one validated interface symbol.
proc add*(symbols: var InterfaceSymbols, symbol: InterfaceSymbol) =
  symbols.byName[symbol.name] = symbol

## Retrieves one registered interface symbol.
proc get*(symbols: InterfaceSymbols, name: string): InterfaceSymbol =
  symbols.byName[name]

## Reports whether an interface directly declares one method name.
proc containsMethod*(symbol: InterfaceSymbol, name: string): bool =
  for methodSymbol in symbol.methods:
    if methodSymbol.name == name:
      return true
  false

## Retrieves one directly declared interface method.
proc getMethod*(symbol: InterfaceSymbol, name: string): InterfaceMethodSymbol =
  for methodSymbol in symbol.methods:
    if methodSymbol.name == name:
      return methodSymbol
  raise newException(KeyError, "unknown interface method '" & name & "'")
