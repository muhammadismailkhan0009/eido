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
import instrumentation_emitter
import runtime_bindings

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

## Renders a complete Nim procedure body from an HIR function.
proc renderFunction*(
  fn: hirDeclarations.HirFunction,
  memoryMetadata: CompileTimeMemoryMetadata = CompileTimeMemoryMetadata(),
  runtimeBindings: RuntimeBindings = RuntimeBindings()
): string =
  result.add renderSignature(fn) & " =\n"

  let identityValues = memoryMetadata.identityValuesForFunction(fn.functionId)
  if memoryMetadata.types.len > 0:
    result.add renderFunctionValuePreamble(fn, identityValues, runtimeBindings)

  for clause in fn.requires:
    result.add renderContractCheck(
      clause, "require contract failed in function '" & fn.sourceName & "'", 2
    )

  var resultIdentityValueId = -1
  for value in identityValues:
    if fn.ensures.len > 0 and fn.result.kind == frSingle and
        value.localId == fn.ensureResultLocalId.value:
      resultIdentityValueId = value.localId

  let exitContext = NormalExitContext(
    contractClauses: fn.ensures,
    contractMessage: "ensure contract failed in function '" & fn.sourceName & "'",
    resultBindingName:
      if fn.ensures.len > 0 and fn.result.kind == frSingle:
        localName(fn.ensureResultLocalId, "result")
      else:
        "",
    ownerClassName: "",
    instrumentationEnabled: memoryMetadata.types.len > 0,
    identityValueIds: identityValues.identityValueIds,
    resultIdentityValueId: resultIdentityValueId,
    runtimeBindings: runtimeBindings
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
