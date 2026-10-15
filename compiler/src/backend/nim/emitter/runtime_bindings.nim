## Resolves Eido-selected generic program-event bindings to ordinary Eido methods.
## The compiler validates the generic event contract but never chooses memory-policy behavior.

import std/strutils
import ../../../compile_time/instrumentation_model
import ../../../hir/program as hirProgram
import ../../../hir/declarations as hirDeclarations
import ../../../source/span
import ../../../types/[function_result, method_kind, model]
import names

type
  RuntimeBindings* = object
    bindingEnter*: string
    bindingWrite*: string
    bindingLeave*: string
    metadataType*: string
    metadataField*: string
    objectAcquire*: string
    temporaryEnter*: string
    temporaryLeave*: string
    statementBoundary*: string
    invariantEnter*: string
    invariantLeave*: string
    invariantClear*: string
    programExit*: string

  BindingContract = object
    parameters: seq[EidoType]
    result: FunctionResult

## Returns the typed handler contract for one policy-neutral compiler event.
proc bindingContract(eventName: string): BindingContract =
  case eventName
  of "bindingEnter":
    BindingContract(parameters: @[etInt], result: singleResult(etInt))
  of "bindingWrite":
    BindingContract(parameters: @[etInt, etInt], result: noResult())
  of "bindingLeave":
    BindingContract(parameters: @[etInt], result: noResult())
  of "typeMetadata":
    BindingContract(parameters: @[etInt, etInt], result: noResult())
  of "fieldMetadata":
    BindingContract(parameters: @[etInt, etInt, etInt, etBool], result: noResult())
  of "objectAcquire":
    BindingContract(parameters: @[etInt, etInt, etInt], result: singleResult(etInt))
  of "temporaryEnter", "temporaryLeave", "executionBoundary", "programExit":
    BindingContract(parameters: @[], result: noResult())
  of "invariantEnter", "invariantLeave":
    BindingContract(parameters: @[etInt], result: noResult())
  of "invariantClear":
    BindingContract(parameters: @[etInt], result: singleResult(etBool))
  else:
    raise newException(
      ValueError,
      "compiler invariant: unknown memory-policy event contract '" & eventName & "'"
    )

## Reports whether one callable result matches the policy event result contract.
proc sameResult(actual, expected: FunctionResult): bool =
  if actual.kind != expected.kind:
    return false
  case expected.kind
  of frNone:
    true
  of frSingle:
    actual.typ == expected.typ

## Validates one selected handler against the stable typed event contract.
proc validateBindingSignature(
  methodDecl: hirDeclarations.HirMethod,
  eventName,
  reference: string
) =
  if methodDecl.kind != mkStatic:
    raise newException(
      ValueError,
      "memory policy handler '" & reference & "' for event '" & eventName &
        "' must be a static Eido method"
    )

  let contract = bindingContract(eventName)
  if methodDecl.parameters.len != contract.parameters.len:
    raise newException(
      ValueError,
      "memory policy handler '" & reference & "' has wrong parameter count for event '" &
        eventName & "'"
    )
  for index, parameter in methodDecl.parameters:
    if parameter.typ != contract.parameters[index]:
      raise newException(
        ValueError,
        "memory policy handler '" & reference & "' has incompatible parameter " &
          $index & " for event '" & eventName & "'"
      )
  if not sameResult(methodDecl.result, contract.result):
    raise newException(
      ValueError,
      "memory policy handler '" & reference & "' has incompatible result for event '" &
        eventName & "'"
    )

## Resolves one class-qualified policy handler from the selected policy runtime.
proc resolveBinding(
  program: hirProgram.HirProgram,
  eventName,
  reference: string
): string =
  if reference.len == 0:
    return ""

  let separator = reference.rfind('.')
  if separator <= 0 or separator == reference.high:
    raise newException(
      ValueError,
      "memory policy handler reference must use 'Class.method': '" & reference & "'"
    )
  let ownerName = reference[0 ..< separator]
  let methodSourceName = reference[separator + 1 .. ^1]

  var found = false
  for classDecl in program.classes:
    if not classDecl.span.isMemoryPolicyRuntime:
      continue
    let localClassName =
      if '.' in classDecl.typ.className:
        classDecl.typ.className[classDecl.typ.className.rfind('.') + 1 .. ^1]
      else:
        classDecl.typ.className
    if classDecl.sourceName != ownerName and
        classDecl.typ.className != ownerName and
        localClassName != ownerName:
      continue
    for methodDecl in classDecl.methods:
      if methodDecl.sourceName != methodSourceName:
        continue
      if found:
        raise newException(
          ValueError,
          "duplicate memory-policy runtime binding '" & reference & "'"
        )
      found = true
      validateBindingSignature(methodDecl, eventName, reference)
      result = methodName(
        methodDecl.methodId,
        methodDecl.ownerType.className,
        methodDecl.sourceName
      )

  if not found:
    raise newException(
      ValueError,
      "missing selected memory-policy runtime handler '" & reference & "'"
    )

## Resolves the Eido-selected instrumentation plan against ordinary runtime methods.
proc bindRuntimeInstrumentation*(
  program: hirProgram.HirProgram,
  plan: CompileTimeInstrumentationPlan
): RuntimeBindings =
  RuntimeBindings(
    bindingEnter: program.resolveBinding("bindingEnter", plan.bindingEnter),
    bindingWrite: program.resolveBinding("bindingWrite", plan.bindingWrite),
    bindingLeave: program.resolveBinding("bindingLeave", plan.bindingLeave),
    metadataType: program.resolveBinding("typeMetadata", plan.metadataType),
    metadataField: program.resolveBinding("fieldMetadata", plan.metadataField),
    objectAcquire: program.resolveBinding("objectAcquire", plan.objectAcquire),
    temporaryEnter: program.resolveBinding("temporaryEnter", plan.temporaryEnter),
    temporaryLeave: program.resolveBinding("temporaryLeave", plan.temporaryLeave),
    statementBoundary: program.resolveBinding(
      "executionBoundary", plan.statementBoundary
    ),
    invariantEnter: program.resolveBinding("invariantEnter", plan.invariantEnter),
    invariantLeave: program.resolveBinding("invariantLeave", plan.invariantLeave),
    invariantClear: program.resolveBinding("invariantClear", plan.invariantClear),
    programExit: program.resolveBinding("programExit", plan.programExit)
  )
