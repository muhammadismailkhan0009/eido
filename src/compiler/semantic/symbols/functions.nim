## Stores and retrieves top-level function symbols. Example: `add(Int, Int) -> Int` is registered before function bodies are analyzed.

import std/tables
import model

type
  FunctionSymbols* = object
    byName: Table[string, FunctionSymbol]

## Creates an empty function-symbol registry. Example: program analysis starts with this before registering `main` and `add`.
proc initFunctionSymbols*(): FunctionSymbols =
  FunctionSymbols(byName: initTable[string, FunctionSymbol]())

## Checks whether a function name has already been registered. Example: a second `add` declaration is detected as a duplicate.
proc contains*(symbols: FunctionSymbols, name: string): bool =
  name in symbols.byName

## Registers a resolved function symbol. Example: `add(Int, Int) -> Int` is stored before body analysis.
proc add*(symbols: var FunctionSymbols, symbol: FunctionSymbol) =
  symbols.byName[symbol.name] = symbol

## Retrieves a registered function symbol. Example: analyzing `add(10, 20)` looks up the signature for `add`.
proc get*(symbols: FunctionSymbols, name: string): FunctionSymbol =
  symbols.byName[name]
