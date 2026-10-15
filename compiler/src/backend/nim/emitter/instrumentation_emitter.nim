## Lowers compiler-described identity-value lifetimes into generic Eido runtime metadata.

import std/strutils
import ../../../compile_time/model
import ../../../hir/declarations
import ../../../semantic/symbols/ids
import ../../../types/[function_result, method_kind]
import names
import type_emitter
import runtime_bindings

## Returns identity-valued lexical slots described for one function.
proc identityValuesForFunction*(
  metadata: CompileTimeMemoryMetadata,
  functionId: FunctionId
): seq[CompileTimeIdentityValue] =
  for callable in metadata.callables:
    if callable.kind == ctkFunction and callable.semanticId == functionId.value:
      return callable.identityValues

## Returns identity-valued lexical slots described for one method.
proc identityValuesForMethod*(
  metadata: CompileTimeMemoryMetadata,
  methodId: MethodId
): seq[CompileTimeIdentityValue] =
  for callable in metadata.callables:
    if callable.kind == ctkMethod and callable.semanticId == methodId.value:
      return callable.identityValues

## Extracts LocalIds from compiler-described identity values.
proc identityValueIds*(values: seq[CompileTimeIdentityValue]): seq[int] =
  for value in values:
    result.add value.localId

## Reports whether one described identity value corresponds to a callable parameter.
proc isParameterValue(parameters: seq[HirParameter], valueId: int): bool =
  for parameter in parameters:
    if parameter.localId.value == valueId:
      return true
  false

## Renders generic runtime registration and lexical removal for one identity value.
proc renderValueRegistration(
  local, valueNode, pad: string,
  runtimeBindings: RuntimeBindings
): string =
  if runtimeBindings.bindingEnter.len == 0 or runtimeBindings.bindingLeave.len == 0:
    return ""
  result.add pad & "var " & valueNode & " = " &
    runtimeBindings.bindingEnter & "(" & local & ")\n"
  result.add pad & "defer:\n"
  result.add pad & "  " & runtimeBindings.bindingLeave & "(" & valueNode & ")\n"

## Renders generic lifetime registration for one local identity declaration.
proc renderLocalValueRegistration*(
  localId: LocalId,
  sourceName: string,
  indent: int,
  runtimeBindings: RuntimeBindings
): string =
  let pad = repeat(' ', indent)
  renderValueRegistration(
    localName(localId, sourceName),
    memoryValueSlotName(localId),
    pad,
    runtimeBindings
  )

## Renders parameter/result identity-value setup required at function entry.
proc renderFunctionValuePreamble*(
  fn: HirFunction,
  values: seq[CompileTimeIdentityValue],
  runtimeBindings: RuntimeBindings
): string =
  for value in values:
    let isParameter = fn.parameters.isParameterValue(value.localId)
    let isResult = fn.ensures.len > 0 and fn.result.kind == frSingle and
      fn.ensureResultLocalId.value == value.localId
    if isResult and not isParameter:
      result.add "  var " & localName(fn.ensureResultLocalId, "result") &
        ": " & renderType(fn.result.typ) & "\n"
    if not isParameter and not isResult:
      continue
    result.add renderValueRegistration(
      localName(LocalId(value.localId), value.sourceName),
      memoryValueSlotName(LocalId(value.localId)),
      "  ",
      runtimeBindings
    )

## Renders receiver/parameter/result identity-value setup required at method entry.
proc renderMethodValuePreamble*(
  methodDecl: HirMethod,
  values: seq[CompileTimeIdentityValue],
  runtimeBindings: RuntimeBindings
): string =
  for value in values:
    let isParameter = methodDecl.parameters.isParameterValue(value.localId) or
      (methodDecl.kind == mkInstance and methodDecl.receiverLocalId.value == value.localId)
    let isResult = methodDecl.ensures.len > 0 and methodDecl.result.kind == frSingle and
      methodDecl.ensureResultLocalId.value == value.localId
    if isResult and not isParameter:
      result.add "  var " & localName(methodDecl.ensureResultLocalId, "result") &
        ": " & renderType(methodDecl.result.typ) & "\n"
    if not isParameter and not isResult:
      continue
    result.add renderValueRegistration(
      localName(LocalId(value.localId), value.sourceName),
      memoryValueSlotName(LocalId(value.localId)),
      "  ",
      runtimeBindings
    )
