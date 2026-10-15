## Emits representation-neutral graph-copy memo wrappers backed by hidden Eido runtime code.

import ../../../hir/program as hirProgram
import names
import copy_runtime_bindings

## Renders generated graph-copy memo operations over the hidden Eido CopyRuntime.
proc renderCopyRuntimeSupport*(program: hirProgram.HirProgram): string =
  let bindings = bindCopyRuntime(program)

  result.add "proc " & copyMemoBeginName() & "() =\n"
  result.add "  " & bindings.beginCopy & "()\n\n"
  result.add "proc " & copyMemoLookupName() & "(source: int64): int64 =\n"
  result.add "  " & bindings.lookup & "(source)\n\n"
  result.add "proc " & copyMemoRememberName() &
    "(source, target: int64) =\n"
  result.add "  " & bindings.remember & "(source, target)\n\n"
  result.add "proc " & copyMemoEndName() & "() =\n"
  result.add "  " & bindings.endCopy & "()\n\n"
