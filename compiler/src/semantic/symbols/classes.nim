## Stores nominal class symbols collected before member-body analysis.

import std/tables
import model

type
  ClassSymbols* = object
    byName: Table[string, ClassSymbol]

## Creates an empty nominal class registry.
proc initClassSymbols*(): ClassSymbols =
  ClassSymbols(byName: initTable[string, ClassSymbol]())

## Reports whether a nominal class name has already been registered.
proc contains*(symbols: ClassSymbols, name: string): bool =
  name in symbols.byName

## Registers or updates one nominal class symbol after validation.
proc add*(symbols: var ClassSymbols, symbol: ClassSymbol) =
  symbols.byName[symbol.name] = symbol

## Retrieves a previously registered nominal class symbol by source name.
proc get*(symbols: ClassSymbols, name: string): ClassSymbol =
  symbols.byName[name]

## Reports whether a class already owns a method with the given source name.
proc containsMethod*(symbol: ClassSymbol, name: string): bool =
  for candidate in symbol.methods:
    if candidate.name == name:
      return true
  false

## Retrieves one previously registered class method by source name.
proc getMethod*(symbol: ClassSymbol, name: string): MethodSymbol =
  for candidate in symbol.methods:
    if candidate.name == name:
      return candidate
  raise newException(KeyError, "unknown method '" & name & "'")
