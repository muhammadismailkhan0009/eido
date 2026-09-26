## Stores nominal class symbols collected before field-type resolution.
## Example: Address may be resolved from an Employee field even when Address is declared later.

import std/tables
import model

type
  ClassSymbols* = object
    byName: Table[string, ClassSymbol]

## Creates an empty nominal class registry for the program-level collection pass.
proc initClassSymbols*(): ClassSymbols =
  ClassSymbols(byName: initTable[string, ClassSymbol]())

## Reports whether a nominal class name has already been registered.
proc contains*(symbols: ClassSymbols, name: string): bool =
  name in symbols.byName

## Registers one nominal class symbol after duplicate-name validation.
proc add*(symbols: var ClassSymbols, symbol: ClassSymbol) =
  symbols.byName[symbol.name] = symbol

## Retrieves a previously registered nominal class symbol by source name.
proc get*(symbols: ClassSymbols, name: string): ClassSymbol =
  symbols.byName[name]
