## Tracks locals and parameters visible inside one function. Example: after `var x = 5;`, looking up `x` returns its local symbol.

import std/tables
import ids
import model

type
  LocalScope* = object
    byName: Table[string, LocalSymbol]
    nextId: int

## Creates an empty function-local scope and resets local-ID allocation. Example: every function starts local numbering from zero.
proc initLocalScope*(): LocalScope =
  LocalScope(
    byName: initTable[string, LocalSymbol](),
    nextId: 0
  )

## Checks whether a local/parameter name is already visible. Example: it prevents a local `value` from redeclaring parameter `value`.
proc contains*(scope: LocalScope, name: string): bool =
  name in scope.byName

## Retrieves a local/parameter symbol from the current scope. Example: resolving `x` returns its type, binding kind, and `LocalId`.
proc get*(scope: LocalScope, name: string): LocalSymbol =
  scope.byName[name]

## Adds a local or parameter symbol to the current function scope. Example: checked `var x = 5;` adds `x` after its initializer is analyzed.
proc add*(
  scope: var LocalScope,
  name: string,
  typ: LocalSymbol
) =
  scope.byName[name] = typ

## Allocates the next unique local ID in a function. Example: parameters/local variables receive `LocalId(0)`, then `LocalId(1)`, and so on.
proc nextLocalId*(scope: var LocalScope): LocalId =
  result = LocalId(scope.nextId)
  inc scope.nextId
