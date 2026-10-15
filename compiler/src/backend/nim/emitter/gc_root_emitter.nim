## Lowers strategy-selected callable roots into lexical stack root descriptors.
## Process-lifetime class-owned roots are emitted separately by class_state_emitter.

import std/strutils
import ../../../compile_time/model
import ../../../hir/declarations
import ../../../semantic/symbols/ids
import ../../../types/[function_result, method_kind]
import names
import type_emitter

## Finds selected roots for one top-level function.
proc rootsForFunction*(
  plan: CompileTimeMemoryPlan,
  functionId: FunctionId
): seq[CompileTimeRoot] =
  for callable in plan.callables:
    if callable.kind == ctkFunction and
        callable.semanticId == functionId.value:
      return callable.roots

## Finds selected roots for one class method.
proc rootsForMethod*(
  plan: CompileTimeMemoryPlan,
  methodId: MethodId
): seq[CompileTimeRoot] =
  for callable in plan.callables:
    if callable.kind == ctkMethod and
        callable.semanticId == methodId.value:
      return callable.roots

## Converts selected roots to LocalId integers used by statement lowering.
proc rootIds*(roots: seq[CompileTimeRoot]): seq[int] =
  for root in roots:
    result.add root.localId

## Reports whether one root id already exists as a callable parameter.
proc isParameterRoot(
  parameters: seq[HirParameter],
  rootId: int
): bool =
  for parameter in parameters:
    if parameter.localId.value == rootId:
      return true
  false

## Registers one source local for exactly its lexical backend scope.
proc renderLocalRootRegistration*(
  localId: LocalId,
  sourceName: string,
  indent: int
): string =
  let pad = repeat(' ', indent)
  let local = localName(localId, sourceName)
  let rootNode = gcRootName(localId)
  result.add pad & "var " & rootNode & ": EidoGcRoot\n"
  result.add pad & "eidoGcPushRoot(addr " & rootNode &
    ", cast[ptr EidoManagedRef](addr " & local & "))\n"
  result.add pad & "defer:\n"
  result.add pad & "  eidoGcPopRoot(addr " & rootNode & ")\n"

## Renders parameter/compiler-result roots whose lifetime is the whole function.
proc renderFunctionRootPreamble*(
  fn: HirFunction,
  roots: seq[CompileTimeRoot]
): string =
  for root in roots:
    let isParameter = fn.parameters.isParameterRoot(root.localId)
    let isResult =
      fn.ensures.len > 0 and fn.result.kind == frSingle and
      fn.ensureResultLocalId.value == root.localId

    if isResult and not isParameter:
      result.add "  var " & localName(
        fn.ensureResultLocalId,
        "result"
      ) & ": " & renderType(fn.result.typ) & "\n"

    if not isParameter and not isResult:
      continue

    let local = localName(LocalId(root.localId), root.sourceName)
    let rootNode = gcRootName(LocalId(root.localId))
    result.add "  var " & rootNode & ": EidoGcRoot\n"
    result.add "  eidoGcPushRoot(addr " & rootNode &
      ", cast[ptr EidoManagedRef](addr " & local & "))\n"
    result.add "  defer:\n"
    result.add "    eidoGcPopRoot(addr " & rootNode & ")\n"

## Renders receiver/parameter/compiler-result roots whose lifetime is the whole method.
proc renderMethodRootPreamble*(
  methodDecl: HirMethod,
  roots: seq[CompileTimeRoot]
): string =
  for root in roots:
    let isParameter =
      methodDecl.parameters.isParameterRoot(root.localId) or
      (
        methodDecl.kind == mkInstance and
        methodDecl.receiverLocalId.value == root.localId
      )
    let isResult =
      methodDecl.ensures.len > 0 and
      methodDecl.result.kind == frSingle and
      methodDecl.ensureResultLocalId.value == root.localId

    if isResult and not isParameter:
      result.add "  var " & localName(
        methodDecl.ensureResultLocalId,
        "result"
      ) & ": " & renderType(methodDecl.result.typ) & "\n"

    if not isParameter and not isResult:
      continue

    let local = localName(LocalId(root.localId), root.sourceName)
    let rootNode = gcRootName(LocalId(root.localId))
    result.add "  var " & rootNode & ": EidoGcRoot\n"
    result.add "  eidoGcPushRoot(addr " & rootNode &
      ", cast[ptr EidoManagedRef](addr " & local & "))\n"
    result.add "  defer:\n"
    result.add "    eidoGcPopRoot(addr " & rootNode & ")\n"

