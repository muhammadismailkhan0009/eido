## Renders HIR function signatures and bodies. Example: no-result Eido `notify(Int id)` becomes a Nim `proc` with no result type.

import ../../../compile_time/model
import ../../../hir/declarations as hirDeclarations
import ../../../semantic/symbols/ids
import ../../../types/function_result
import names
import type_emitter
import statement_emitter
import contract_emitter
import normal_exit
import gc_root_emitter

## Renders a Nim procedure signature from an HIR function. Example: `add(Int a, Int b) returns Int` becomes a proc with two `int64` parameters and an `int64` result.
proc renderSignature*(fn: hirDeclarations.HirFunction): string =
  result = "proc " & functionName(fn.functionId, fn.sourceName) & "("
  for index, parameter in fn.parameters:
    if index > 0:
      result.add ", "
    result.add localName(parameter.localId, parameter.sourceName) &
      ": " & renderType(parameter.typ)
  result.add ")"

  if fn.result.kind == frSingle:
    result.add ": " & renderType(fn.result.typ)

## Renders a complete Nim procedure body from an HIR function. Example: an empty no-result Eido function emits `discard` so the Nim body remains valid.
proc renderFunction*(
  fn: hirDeclarations.HirFunction,
  memoryPlan: CompileTimeMemoryPlan = CompileTimeMemoryPlan()
): string =
  result.add renderSignature(fn) & " =\n"

  let roots = memoryPlan.rootsForFunction(fn.functionId)
  if memoryPlan.types.len > 0:
    result.add renderFunctionRootPreamble(fn, roots)

  for clause in fn.requires:
    result.add renderContractCheck(
      clause, "require contract failed in function '" & fn.sourceName & "'", 2
    )

  var resultRootId = -1
  for root in roots:
    if fn.ensures.len > 0 and fn.result.kind == frSingle and
        root.localId == fn.ensureResultLocalId.value:
      resultRootId = root.localId

  let exitContext = NormalExitContext(
    contractClauses: fn.ensures,
    contractMessage: "ensure contract failed in function '" & fn.sourceName & "'",
    resultBindingName:
      if fn.ensures.len > 0 and fn.result.kind == frSingle:
        localName(fn.ensureResultLocalId, "result")
      else:
        "",
    ownerClassName: "",
    gcEnabled: memoryPlan.types.len > 0,
    gcRootIds: roots.rootIds,
    resultRootId: resultRootId
  )

  if fn.body.len == 0:
    if fn.ensures.len > 0:
      result.add renderNormalExitChecks(exitContext, 2)
    elif fn.requires.len == 0:
      result.add "  discard\n"
  else:
    for stmt in fn.body:
      result.add renderStmtAt(stmt, 2, exitContext)
    if fn.result.kind == frNone:
      result.add renderNormalExitChecks(exitContext, 2)
