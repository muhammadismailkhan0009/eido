## Runs program-level semantic analysis in passes: collect signatures first, then analyze bodies. Example: `main` may call a later-declared function with any number of primitive parameters.

import ../../diagnostics/errors
import ../../frontend/ast/program as astProgram
import ../../hir/declarations
import ../../hir/program as hirProgram
import ../../types/model
import ../symbols/ids
import type_resolution
import ../symbols/model
import ../symbols/functions
import function_analysis

## Collects every function signature, validates zero-argument `main`, then analyzes all bodies. Example: a 12-parameter function is fully registered before any call to it is checked.
proc analyzeProgram*(program: astProgram.Program): hirProgram.HirProgram =
  var functions = initFunctionSymbols()
  var mainFound = false
  var mainId = FunctionId(-1)

  for index, fn in program.functions:
    if functions.contains(fn.name):
      raise newException(ValueError, "duplicate function '" & fn.name & "'")

    var parameterTypes: seq[EidoType]
    for parameter in fn.parameters:
      parameterTypes.add resolveType(parameter.typeRef)

    let functionResult = resolveFunctionResult(fn.result)
    let symbol = FunctionSymbol(
      id: FunctionId(index),
      name: fn.name,
      parameterTypes: parameterTypes,
      result: functionResult,
      span: fn.span
    )
    functions.add symbol

    if fn.name == "main":
      mainFound = true
      mainId = symbol.id
      if fn.parameters.len != 0:
        failAt(fn.span, "main function must not declare parameters")

  if not mainFound:
    raise newException(ValueError, "program must declare function main()")

  var analyzedFunctions: seq[HirFunction]
  for fn in program.functions:
    analyzedFunctions.add analyzeFunction(
      fn,
      functions.get(fn.name),
      functions
    )

  hirProgram.HirProgram(
    functions: analyzedFunctions,
    mainFunctionId: mainId
  )
