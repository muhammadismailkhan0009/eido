## Runs program-level semantic analysis in declaration passes.
## Class names/fields/method signatures and top-level function signatures are collected before any callable body is analyzed.

import ../../diagnostics/[codes, errors]
import ../../frontend/ast/program as astProgram
import ../../hir/declarations
import ../../hir/program as hirProgram
import ../../project/model
import ../../types/model
import ../symbols/ids
import type_resolution
import ../symbols/model
import ../symbols/classes
import ../symbols/functions
import class_analysis
import method_analysis
import function_analysis

## Collects declarations in dependency-safe passes, then analyzes method/function bodies for the selected target.
## Example: executable targets require a zero-parameter main while library targets do not.
proc analyzeProgram*(
  program: astProgram.Program,
  target: ProjectTarget = ptExecutable
): hirProgram.HirProgram =
  var classes = initClassSymbols()

  # Pass 1: establish nominal class identities.
  for sourceClass in program.classes:
    if classes.contains(sourceClass.name):
      failAt(sourceClass.span, "duplicate class '" & sourceClass.name & "'")

    classes.add ClassSymbol(
      name: sourceClass.name,
      typ: classType(sourceClass.name),
      fields: @[],
      methods: @[],
      span: sourceClass.span
    )

  # Pass 2: resolve field schemas against the complete class registry.
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

  # Pass 3: collect every class method signature before any method body.
  var nextMethodId = 0
  for sourceClass in program.classes:
    var classSymbol = classes.get(sourceClass.name)

    for sourceMethod in sourceClass.methods:
      if classSymbol.containsMethod(sourceMethod.name):
        failAt(
          sourceMethod.span,
          "duplicate method '" & sourceMethod.name &
            "' in class '" & sourceClass.name & "'"
        )

      var parameterTypes: seq[EidoType]
      for parameter in sourceMethod.parameters:
        parameterTypes.add resolveDeclaredType(parameter.typeRef, classes)

      classSymbol.methods.add MethodSymbol(
        id: MethodId(nextMethodId),
        name: sourceMethod.name,
        parameterTypes: parameterTypes,
        result: resolveFunctionResult(sourceMethod.result, classes),
        span: sourceMethod.span
      )
      inc nextMethodId

    classes.add classSymbol

  # Pass 4: collect top-level function signatures before analyzing methods.
  var functions = initFunctionSymbols()
  var mainFound = false
  var mainId = FunctionId(-1)

  for index, fn in program.functions:
    if functions.contains(fn.name):
      failAt(fn.span, "duplicate function '" & fn.name & "'")

    var parameterTypes: seq[EidoType]
    for parameter in fn.parameters:
      parameterTypes.add resolveDeclaredType(parameter.typeRef, classes)

    let functionResult = resolveFunctionResult(fn.result, classes)
    let symbol = FunctionSymbol(
      id: FunctionId(index),
      name: fn.name,
      parameterTypes: parameterTypes,
      result: functionResult,
      span: fn.span
    )
    functions.add symbol

    if target == ptExecutable and fn.name == "main":
      mainFound = true
      mainId = symbol.id
      if fn.parameters.len != 0:
        failAt(fn.span, "main function must not declare parameters")

  if target == ptExecutable and not mainFound:
    fail(
      MissingMainDiagnosticCode,
      "executable project must declare function main()"
    )

  # Pass 5: analyze class-owned method bodies with source-level self bound to hidden receivers.
  for classIndex, sourceClass in program.classes:
    let owner = classes.get(sourceClass.name)
    for sourceMethod in sourceClass.methods:
      analyzedClasses[classIndex].methods.add analyzeMethod(
        sourceMethod,
        owner,
        owner.getMethod(sourceMethod.name),
        functions,
        classes
      )

  # Pass 6: analyze top-level function bodies.
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
    hasMain: mainFound,
    mainFunctionId: mainId
  )
