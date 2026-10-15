## Renders a complete HIR program to Nim, including class methods, functions, and the temporary main harness.

import ../../../hir/program as hirProgram
import ../../../hir/declarations as hirDeclarations
import ../../../compilation/plan
import ../../../semantic/symbols/ids
import ../../../types/function_result
import ../../../types/storage
import ../../../types/managed_gc_runtime
import names
import interface_emitter
import nominal_type_emitter
import class_copy_emitter
import method_emitter
import function_emitter
import invariant_emitter
import storage_support
import gc_metadata_emitter
import managed_class_emitter
import class_state_emitter

## Renders the full HIR program plus validated compilation strategy decisions
## to compilable Nim source.
proc emitNim*(
  program: hirProgram.HirProgram,
  plan: CompilationPlan
): string =
  result.add "import std/options\n"
  let managedRuntime = plan.memory.types.len > 0
  var ordinaryClasses: seq[hirDeclarations.HirClass]
  for classDecl in program.classes:
    if not isManagedGcInternalClassName(classDecl.sourceName):
      ordinaryClasses.add classDecl
  if managedRuntime:
    result.add "import eido_managed_gc\n"
  else:
    result.add "template eidoGcProtected(body: untyped): untyped = body\n"
  var hasStorage = false
  for classDecl in program.classes:
    if isConcreteStorageTypeName(classDecl.sourceName):
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
      if isManagedGcInternalClassName(classDecl.sourceName):
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
  result.add renderNominalTypes(
    program.interfaces,
    ordinaryClasses,
    plan.memory
  )
  result.add renderGcMetadata(plan.memory)
  result.add renderStorageSupport(ordinaryClasses)

  # Forward declare Eido-bodied callables before generated class/interface helpers
  # because managed allocation/trace helpers call the hidden Eido GC runtime.
  for classDecl in program.classes:
    if isManagedGcInternalClassName(classDecl.sourceName) and not managedRuntime:
      continue
    for methodDecl in classDecl.methods:
      if not methodDecl.isNative:
        result.add renderMethodSignature(methodDecl) & "\n"

  for fn in program.functions:
    if not fn.isNative:
      result.add renderSignature(fn) & "\n"

  result.add "\n"
  result.add renderClassStateDeclarations(program.classes, managedRuntime)
  result.add renderClassRuntimeSupport(ordinaryClasses, plan.memory)
  if managedRuntime:
    result.add renderManagedInterfaceSupport(program.interfaces)
  result.add renderInterfaceDispatchers(
    program.interfaces,
    managedRuntime
  )
  result.add renderClassCopiers(ordinaryClasses, plan.memory)

  result.add renderClassInvariantCheckers(ordinaryClasses)
  result.add renderInterfaceUpcasts(
    program.interfaces,
    managedRuntime
  )
  result.add renderClassInterfaceAdapters(
    program.interfaces,
    ordinaryClasses,
    managedRuntime
  )
  result.add renderClassStateInitializers(program.classes, managedRuntime)

  for classDecl in program.classes:
    if isManagedGcInternalClassName(classDecl.sourceName) and not managedRuntime:
      continue
    for methodDecl in classDecl.methods:
      if not methodDecl.isNative:
        result.add renderMethod(
          methodDecl,
          classDecl.invariants.len > 0,
          plan.memory
        )
        result.add "\n"

  for fn in program.functions:
    if not fn.isNative:
      result.add renderFunction(fn, plan.memory)
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
      if managedRuntime:
        result.add "  " & managedGcRuntimeMethodName("shutdown") & "()\n"
    else:
      # Temporary v0 harness: result printing remains until process-exit/stdlib semantics replace it.
      if managedRuntime:
        result.add "  let eido_runtime_main_result = " & mainName & "()\n"
        result.add "  echo eido_runtime_main_result\n"
        result.add "  " & managedGcRuntimeMethodName("shutdown") & "()\n"
      else:
        result.add "  echo " & mainName & "()\n"


## Preserves low-level emitter tests/callers that intentionally bypass compiler
## strategy execution. Normal compilation goes through the plan-aware overload.
proc emitNim*(program: hirProgram.HirProgram): string =
  emitNim(program, CompilationPlan())
