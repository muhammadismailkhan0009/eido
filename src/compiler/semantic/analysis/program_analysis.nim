## Runs program-level semantic analysis in declaration passes.
## Class names are collected before class fields are resolved; function signatures are collected before bodies.

import ../../diagnostics/errors
import ../../frontend/ast/program as astProgram
import ../../hir/declarations
import ../../hir/program as hirProgram
import ../../types/model
import ../symbols/ids
import type_resolution
import ../symbols/model
import ../symbols/classes
import ../symbols/functions
import class_analysis
import function_analysis

## Collects nominal classes and function signatures before analyzing their contents.
proc analyzeProgram*(program: astProgram.Program): hirProgram.HirProgram =
  var classes = initClassSymbols()

  # Pass 1: establish nominal class identities so fields may reference later classes.
  for sourceClass in program.classes:
    if classes.contains(sourceClass.name):
      failAt(sourceClass.span, "duplicate class '" & sourceClass.name & "'")

    classes.add ClassSymbol(
      name: sourceClass.name,
      typ: classType(sourceClass.name),
      fields: @[],
      span: sourceClass.span
    )

  # Pass 2: resolve field types against the complete class registry.
  var analyzedClasses: seq[HirClass]
  for sourceClass in program.classes:
    let analyzedClass = analyzeClass(sourceClass, classes)
    analyzedClasses.add analyzedClass

    var classSymbol = classes.get(sourceClass.name)
    for field in analyzedClass.fields:
      classSymbol.fields.add ClassFieldSymbol(
        name: field.sourceName,
        typ: field.typ,
        span: field.span
      )
    classes.add classSymbol

  # Existing function-signature collection remains primitive-only for this class slice.
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
      functions,
      classes
    )

  hirProgram.HirProgram(
    classes: analyzedClasses,
    functions: analyzedFunctions,
    mainFunctionId: mainId
  )
