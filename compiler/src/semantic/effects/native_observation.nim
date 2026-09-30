## Identifies compiler-owned native operations whose observable effects are proven.
## Ordinary native functions/methods remain conservative and contract-unsafe.

import ../../hir/expressions
import ../../types/model
import ../../types/storage

## Reports whether one native method call is a verified observational Storage query.
proc isVerifiedObservationalNativeMethod*(call: HirMethodCall): bool =
  call.isNative and
    call.dispatchKind == hmdClass and
    call.ownerType.kind == etkClass and
    isConcreteStorageTypeName(call.ownerType.className) and
    call.methodName in ["capacity", "size", "alignment"]
