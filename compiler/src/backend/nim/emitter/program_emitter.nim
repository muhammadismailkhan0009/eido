## Renders a complete HIR program to Nim, including class methods, functions, and the temporary main harness.

import ../../../hir/program as hirProgram
import ../../../semantic/symbols/ids
import ../../../types/function_result
import names
import class_emitter
import class_copy_emitter
import method_emitter
import function_emitter

## Renders the full HIR program to compilable Nim source.
proc emitNim*(program: hirProgram.HirProgram): string =
  var hasNativeFunctions = false
  for fn in program.functions:
    if fn.isNative:
      hasNativeFunctions = true
      break

  if hasNativeFunctions:
    result.add "import eido_native\n\n"

  result.add renderClasses(program.classes)
  result.add renderClassCopiers(program.classes)

  # Forward declare every method and function before any callable body.
  for classDecl in program.classes:
    for methodDecl in classDecl.methods:
      result.add renderMethodSignature(methodDecl) & "\n"

  for fn in program.functions:
    if not fn.isNative:
      result.add renderSignature(fn) & "\n"

  result.add "\n"

  for classDecl in program.classes:
    for methodDecl in classDecl.methods:
      result.add renderMethod(methodDecl)
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
