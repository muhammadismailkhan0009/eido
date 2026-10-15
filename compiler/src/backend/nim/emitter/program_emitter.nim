## Renders a complete HIR program to Nim, including runtime-backed object representation and the temporary main harness.

import ../../../hir/program as hirProgram
import ../../../hir/declarations as hirDeclarations
import ../../../compilation/plan
import ../../../semantic/symbols/ids
import ../../../types/[function_result, model, storage]
import ../../../source/span
import names
import interface_emitter
import nominal_type_emitter
import class_copy_emitter
import method_emitter
import function_emitter
import invariant_emitter
import storage_support
import memory_metadata_emitter
import object_runtime_emitter
import class_state_emitter
import runtime_bindings
import string_runtime_emitter

## Renders the full HIR program plus generic compiler memory metadata to Nim source.
proc emitNim*(
  program: hirProgram.HirProgram,
  plan: CompilationPlan
): string =
  result.add "import std/options\n"
  let runtimeBackedObjects = plan.memory.types.len > 0
  let runtimeBindings =
    if runtimeBackedObjects:
      bindRuntimeInstrumentation(program, plan.instrumentation)
    else:
      RuntimeBindings()

  var ordinaryClasses: seq[hirDeclarations.HirClass]
  var runtimeClasses: seq[hirDeclarations.HirClass]
  var hasStringRuntime = false
  for classDecl in program.classes:
    if classDecl.span.isLanguageRuntime:
      hasStringRuntime = true
    if classDecl.span.isHiddenRuntime and
        not isConcreteStorageTypeName(classDecl.sourceName):
      runtimeClasses.add classDecl
    else:
      ordinaryClasses.add classDecl

  var hasStorage = false
  for classDecl in program.classes:
    if isConcreteStorageTypeName(classDecl.sourceName) or
        classDecl.classFields.len > 0:
      hasStorage = true
      break
  if hasStorage:
    result.add "import eido_storage\n"

  var hasNativeDeclarations = false
  for fn in program.functions:
    if fn.isNative:
      hasNativeDeclarations = true
      break

  if not hasNativeDeclarations:
    for classDecl in program.classes:
      if classDecl.span.isHiddenRuntime:
        continue
      for methodDecl in classDecl.methods:
        if methodDecl.isNative and
            not isConcreteStorageTypeName(classDecl.sourceName):
          hasNativeDeclarations = true
          break
      if hasNativeDeclarations:
        break

  if hasNativeDeclarations:
    result.add "import eido_native\n"

  result.add "\n"
  result.add renderNominalTypes(program.interfaces, ordinaryClasses, plan.memory)
  result.add renderMemoryMetadata(plan.memory, program.interfaces)
  result.add renderStorageSupport(ordinaryClasses)

  # Runtime-backed generated helpers may call ordinary Eido runtime methods, so
  # all Eido-bodied methods are forward-declared before helper emission.
  for classDecl in program.classes:
    for methodDecl in classDecl.methods:
      if not methodDecl.isNative:
        result.add renderMethodSignature(methodDecl) & "\n"

  for fn in program.functions:
    if not fn.isNative:
      result.add renderSignature(fn) & "\n"

  result.add "\n"
  if hasStringRuntime:
    result.add renderStringRuntimeSupport(program)
  if runtimeBackedObjects:
    result.add "template eidoMemoryPayloadAt(T: typedesc, identity: untyped): untyped =\n"
    result.add "  cast[ptr T](cast[uint](identity))\n"
    result.add "template eidoMemoryPresent(identity: int64): bool = identity != int64(0)\n"
    result.add "template eidoMemoryGet(identity: int64): int64 =\n"
    result.add "  block:\n"
    result.add "    if identity == int64(0):\n"
    result.add "      raise newException(AssertionDefect, \"optional identity value is absent\")\n"
    result.add "    identity\n"
    if runtimeBindings.temporaryEnter.len > 0 and
        runtimeBindings.temporaryLeave.len > 0:
      result.add "template eidoMemoryTemporaryScope(body: untyped): untyped =\n"
      result.add "  block:\n"
      result.add "    " & runtimeBindings.temporaryEnter & "()\n"
      result.add "    defer:\n"
      result.add "      " & runtimeBindings.temporaryLeave & "()\n"
      result.add "    body\n\n"
    else:
      result.add "template eidoMemoryTemporaryScope(body: untyped): untyped = body\n\n"
  else:
    result.add "template eidoMemoryTemporaryScope(body: untyped): untyped = body\n\n"

  result.add renderClassStateDeclarations(program.classes, runtimeBackedObjects)
  result.add renderClassRuntimeSupport(ordinaryClasses, plan.memory, runtimeBindings)
  if runtimeBackedObjects:
    result.add renderRuntimeInterfaceSupport(program.interfaces, runtimeBindings)
  result.add renderInterfaceDispatchers(
    program.interfaces,
    runtimeBackedObjects,
    runtimeBindings
  )
  result.add renderClassCopiers(ordinaryClasses, plan.memory)

  result.add renderClassInvariantCheckers(ordinaryClasses)
  result.add renderInterfaceUpcasts(
    program.interfaces,
    runtimeBackedObjects,
    runtimeBindings
  )
  result.add renderClassInterfaceAdapters(
    program.interfaces,
    ordinaryClasses,
    runtimeBackedObjects,
    runtimeBindings
  )

  # Compiler-runtime class state bootstraps before generic program metadata/value
  # reporting, preventing runtime implementation state from reporting itself.
  result.add renderClassStateInitializers(runtimeClasses, false)
  if runtimeBackedObjects:
    result.add renderMemoryMetadataInitializers(
      plan.memory,
      ordinaryClasses,
      program.interfaces,
      runtimeBindings
    )
  result.add renderClassStateInitializers(
    ordinaryClasses,
    runtimeBackedObjects,
    runtimeBindings
  )

  for classDecl in program.classes:
    for methodDecl in classDecl.methods:
      if not methodDecl.isNative:
        result.add renderMethod(
          methodDecl,
          classDecl.invariants.len > 0,
          plan.memory,
          runtimeBindings
        )
        result.add "\n"

  for fn in program.functions:
    if not fn.isNative:
      result.add renderFunction(fn, plan.memory, runtimeBindings)
      result.add "\n"

  if program.hasMain:
    var mainIndex = -1
    for index, fn in program.functions:
      if fn.functionId.value == program.mainFunctionId.value:
        mainIndex = index
        break

    let mainFn = program.functions[mainIndex]
    let mainName = functionName(mainFn.functionId, mainFn.sourceName)

    result.add "when isMainModule:\n"
    if mainFn.result.kind == frNone:
      result.add "  " & mainName & "()\n"
    elif hasStringRuntime and mainFn.result.typ.kind == etkString:
      result.add "  let eido_runtime_main_result = " & mainName & "()\n"
      result.add "  echo " & stringToNativeName() & "(eido_runtime_main_result)\n"
    elif runtimeBackedObjects or hasStringRuntime:
      result.add "  let eido_runtime_main_result = " & mainName & "()\n"
      result.add "  echo eido_runtime_main_result\n"
    else:
      result.add "  echo " & mainName & "()\n"

    if runtimeBackedObjects and runtimeBindings.programExit.len > 0:
      result.add "  " & runtimeBindings.programExit & "()\n"
    if hasStringRuntime:
      result.add "  " & stringShutdownName() & "()\n"

## Preserves low-level emitter tests/callers that intentionally bypass compiler metadata execution.
proc emitNim*(program: hirProgram.HirProgram): string =
  emitNim(program, CompilationPlan())
