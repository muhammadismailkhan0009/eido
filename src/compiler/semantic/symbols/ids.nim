## Defines stable semantic identities for functions and locals. Example: two source names can still be distinguished internally as different `LocalId` values.

type
  FunctionId* = distinct int
  LocalId* = distinct int

## Extracts an integer from a `FunctionId`. Example: `FunctionId(1)` yields `1` when generating `eido_fn_1_add`.
proc value*(id: FunctionId): int = int(id)
## Extracts an integer from a `LocalId`. Example: `LocalId(0)` yields `0` when generating `eido_local_0_salary`.
proc value*(id: LocalId): int = int(id)
