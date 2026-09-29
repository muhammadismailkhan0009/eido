## Renders a complete HIR program to Nim, including class methods, functions, and the temporary main harness.

import ../../../hir/program as hirProgram
import ../../../semantic/symbols/ids
import ../../../types/function_result
import ../../../types/storage
import names
import interface_emitter
import nominal_type_emitter
import class_copy_emitter
import method_emitter
import function_emitter
import invariant_emitter
import storage_support

## Renders the full HIR program to compilable Nim source.
proc emitNim*(program: hirProgram.HirProgram): string =
  result.add "import std/options\n"
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
  result.add renderNominalTypes(program.interfaces, program.classes)
  result.add renderStorageSupport(program.classes)
  result.add renderClassCopiers(program.classes)

  # Forward declare every Eido-bodied method and function before adapters or callable bodies.
  for classDecl in program.classes:
    for methodDecl in classDecl.methods:
      if not methodDecl.isNative:
        result.add renderMethodSignature(methodDecl) & "\n"

  for fn in program.functions:
    if not fn.isNative:
      result.add renderSignature(fn) & "\n"

  result.add "\n"
  result.add renderClassInvariantCheckers(program.classes)
  result.add renderInterfaceUpcasts(program.interfaces)
  result.add renderClassInterfaceAdapters(
    program.interfaces,
    program.classes
  )

  for classDecl in program.classes:
    for methodDecl in classDecl.methods:
      if not methodDecl.isNative:
        result.add renderMethod(methodDecl, classDecl.invariants.len > 0)
        result.add "\n"

  for fn in program.functions:
    if not fn.isNative:
      result.add renderFunction(fn)
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
    else:
      # Temporary v0 harness: result printing remains until process-exit/stdlib semantics replace it.
      result.add "  echo " & mainName & "()\n"
