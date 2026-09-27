## Defines stable semantic identities for functions, methods, and locals.

type
  FunctionId* = distinct int
  MethodId* = distinct int
  LocalId* = distinct int

## Extracts an integer from a FunctionId.
proc value*(id: FunctionId): int = int(id)
## Extracts an integer from a MethodId.
proc value*(id: MethodId): int = int(id)
## Extracts an integer from a LocalId.
proc value*(id: LocalId): int = int(id)
