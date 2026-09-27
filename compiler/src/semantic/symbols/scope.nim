## Tracks locals, parameters, and lexical optional-presence proofs inside one function.
## Example: after `if user exists`, a forked block scope records user as proven present.

import std/[sets, tables]
import ids
import model

type
  LocalScope* = object
    byName: Table[string, LocalSymbol]
    nextId: int
    optionalProofs: HashSet[string]

## Creates an empty function-local scope and resets local-ID allocation.
## Example: every function starts local numbering from zero with no optional proofs.
proc initLocalScope*(): LocalScope =
  LocalScope(
    byName: initTable[string, LocalSymbol](),
    nextId: 0,
    optionalProofs: initHashSet[string]()
  )

## Checks whether a local/parameter name is already visible.
## Example: it prevents a local value from redeclaring parameter value.
proc contains*(scope: LocalScope, name: string): bool =
  name in scope.byName

## Retrieves a local/parameter symbol from the current scope.
## Example: resolving x returns its type, binding kind, and LocalId.
proc get*(scope: LocalScope, name: string): LocalSymbol =
  scope.byName[name]

## Adds a local or parameter symbol to the current function scope.
## Example: checked var x = 5 adds x after its initializer is analyzed.
proc add*(
  scope: var LocalScope,
  name: string,
  typ: LocalSymbol
) =
  scope.byName[name] = typ

## Allocates the next unique local ID in a function.
## Example: parameters/local variables receive LocalId(0), then LocalId(1), and so on.
proc nextLocalId*(scope: var LocalScope): LocalId =
  result = LocalId(scope.nextId)
  inc scope.nextId

## Records one exact optional path as proven present in this lexical scope.
## Example: proving employee.address does not also prove employee.address.city.
proc proveOptional*(scope: var LocalScope, path: string) =
  scope.optionalProofs.incl path

## Reports whether one exact optional path is proven present in this lexical scope.
## Example: employee.address is true only inside its matching exists block.
proc isOptionalProven*(scope: LocalScope, path: string): bool =
  path in scope.optionalProofs

## Creates an isolated branch scope containing visible bindings and active proofs.
## Example: nested exists blocks inherit outer proofs without leaking new proofs back out.
proc fork*(scope: LocalScope): LocalScope =
  result = initLocalScope()
  result.nextId = scope.nextId
  for name, symbol in scope.byName.pairs:
    result.byName[name] = symbol
  for proof in scope.optionalProofs:
    result.optionalProofs.incl proof

## Advances a parent scope's local-ID allocator after analyzing an isolated branch.
## Example: locals created in then/else branches still receive unique function-wide LocalIds.
proc synchronizeNextId*(scope: var LocalScope, branch: LocalScope) =
  if branch.nextId > scope.nextId:
    scope.nextId = branch.nextId
