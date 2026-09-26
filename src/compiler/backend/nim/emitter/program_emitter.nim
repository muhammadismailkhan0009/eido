## Renders a complete HIR program to Nim, including forward declarations and the temporary `main` harness.

import ../../../hir/program as hirProgram
import ../../../semantic/symbols/ids
import ../../../types/function_result
import names
import class_emitter
import function_emitter

## Renders the full HIR program to compilable Nim source. Example: a zero-result Eido `main` is called directly, while a one-result `main` is echoed by the development harness.
proc emitNim*(program: hirProgram.HirProgram): string =
  result.add renderClasses(program.classes)

  for fn in program.functions:
    result.add renderSignature(fn) & "\n"

  result.add "\n"

  for fn in program.functions:
    result.add renderFunction(fn)
    result.add "\n"

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
    result.add "  echo " & mainName & "()\n"
