## Runs program-level semantic analysis in dependency-safe declaration passes.
## Interfaces and classes establish nominal identities before any signature or body is resolved.

import std/strutils
import ../../diagnostics/[codes, errors]
import ../../frontend/ast/declarations as astDeclarations
import ../../frontend/ast/program as astProgram
import ../../hir/declarations
import ../../hir/program as hirProgram
import ../../project/model
import ../../types/model
import ../../types/function_result
import ../../types/method_kind
import ../../types/storage
import ../effects/inference
import ../effects/contract_validation
import ../symbols/ids
import ../generics/class_specialization
import type_resolution
import ../symbols/model
import ../symbols/nominals
import ../symbols/functions
import class_analysis
import interface_analysis
import method_classification
import method_analysis
import function_analysis
import storage_result_provenance

## Rejects unsupported nominal/optional values at the initial native ABI boundary.
proc validateNativeSignature(
  sourceFunction: astDeclarations.FunctionDecl,
  parameterTypes: seq[EidoType],
  functionResult: FunctionResult
) =
  for index, parameterType in parameterTypes:
    if parameterType.isOptional:
      failAt(
        sourceFunction.parameters[index].typeRef.span,
        "native function parameters cannot use optional type '" &
          parameterType.displayName & "' in v0"
      )

    case parameterType.kind
    of etkClass:
      failAt(
        sourceFunction.parameters[index].typeRef.span,
        "native function parameters cannot use class type '" &
          parameterType.className & "'"
      )
    of etkInterface:
      failAt(
        sourceFunction.parameters[index].typeRef.span,
        "native function parameters cannot use interface type '" &
          parameterType.interfaceName & "' in v0"
      )
    else:
      discard

  if functionResult.kind == frSingle:
    if functionResult.typ.isOptional:
      failAt(
        sourceFunction.result.typeRef.span,
        "native function results cannot use optional type '" &
          functionResult.typ.displayName & "' in v0"
      )

    case functionResult.typ.kind
    of etkClass:
      failAt(
        sourceFunction.result.typeRef.span,
        "native function results cannot use class type '" &
          functionResult.typ.className & "'"
      )
    of etkInterface:
      failAt(
        sourceFunction.result.typeRef.span,
        "native function results cannot use interface type '" &
          functionResult.typ.interfaceName & "' in v0"
      )
    else:
      discard

## Converts one resolved interface contract to backend-neutral HIR.
proc lowerInterface(
  source: astDeclarations.InterfaceDecl,
  symbols: NominalSymbols
): HirInterface =
  var methods: seq[HirInterfaceMethod]
  for contract in symbols.requiredInterfaceMethods(source.name):
    methods.add analyzeInterfaceMethodContract(contract, symbols)

  HirInterface(
    span: source.span,
    sourceName: source.name,
    typ: symbols.getInterface(source.name).typ,
    extends: source.extends,
    methods: methods
  )

## Collects declarations in dependency-safe passes, then analyzes callable bodies.
proc analyzeProgram*(
  program: astProgram.Program,
  target: ProjectTarget = ptExecutable
): hirProgram.HirProgram =
  let specializedProgram = specializeGenericClasses(program)
  var symbols = initNominalSymbols()

  # Pass 1: establish interface identities before any signatures.
  for sourceInterface in specializedProgram.interfaces:
    if symbols.containsNominal(sourceInterface.name):
      failAt(
        sourceInterface.span,
        "duplicate nominal type '" & sourceInterface.name & "'"
      )

    symbols.addInterface InterfaceSymbol(
      name: sourceInterface.name,
      moduleName: sourceInterface.moduleName,
      typ: interfaceType(sourceInterface.name),
      extends: sourceInterface.extends,
      methods: @[],
      span: sourceInterface.span
    )

  # Pass 2: establish class identities.
  for sourceClass in specializedProgram.classes:
    if symbols.containsNominal(sourceClass.name):
      failAt(
        sourceClass.span,
        "duplicate nominal type '" & sourceClass.name & "'"
      )

    symbols.addClass ClassSymbol(
      name: sourceClass.name,
      moduleName: sourceClass.moduleName,
      typ: classType(sourceClass.name),
      implements: sourceClass.implements,
      hasInvariant: sourceClass.invariants.len > 0,
      fields: @[],
      methods: @[],
      span: sourceClass.span
    )

  # Pass 3: resolve interface inheritance and direct method contracts.
  validateInterfaceInheritance(specializedProgram.interfaces, symbols)
  resolveInterfaceMethods(specializedProgram.interfaces, symbols)
  validateInterfaceRedeclarations(specializedProgram.interfaces, symbols)

  # Pass 4: resolve class field schemas against the complete nominal registry.
  var analyzedClasses: seq[HirClass]
  for sourceClass in specializedProgram.classes:
    let analyzedClass = analyzeClass(sourceClass, symbols)
    analyzedClasses.add analyzedClass

    var classSymbol = symbols.getClass(sourceClass.name)
    for field in analyzedClass.fields:
      classSymbol.fields.add ClassFieldSymbol(
        name: field.sourceName,
        typ: field.typ,
        span: field.span
      )
    symbols.addClass classSymbol

  # Pass 5: collect every class method signature before conformance/body analysis.
  var nextMethodId = 0
  for sourceClass in specializedProgram.classes:
    var classSymbol = symbols.getClass(sourceClass.name)

    for sourceMethod in sourceClass.methods:
      if classSymbol.containsMethod(sourceMethod.name):
        failAt(
          sourceMethod.span,
          "duplicate method '" & sourceMethod.name &
            "' in class '" & sourceClass.name & "'"
        )

      var parameterTypes: seq[EidoType]
      for parameter in sourceMethod.parameters:
        parameterTypes.add resolveDeclaredType(parameter.typeRef, symbols)

      let methodResult = resolveFunctionResult(sourceMethod.result, symbols)
      if sourceMethod.isNative and
          not isConcreteStorageTypeName(sourceClass.name):
        validateNativeSignature(sourceMethod, parameterTypes, methodResult)

      let storageResultProvenance =
        if isConcreteStorageTypeName(sourceClass.name):
          case sourceMethod.name
          of "allocate", "allocateRaw", "fromAddress":
            svpOwned
          of "view", "slice":
            svpBorrowed
          else:
            svpNotStorage
        else:
          inferStorageResultProvenance(sourceMethod)

      classSymbol.methods.add MethodSymbol(
        id: MethodId(nextMethodId),
        name: sourceMethod.name,
        isNative: sourceMethod.isNative,
        kind:
          if sourceMethod.isNative: mkStatic
          else: inferMethodKind(sourceMethod),
        parameterTypes: parameterTypes,
        result: methodResult,
        storageResultProvenance: storageResultProvenance,
        span: sourceMethod.span
      )
      inc nextMethodId

    symbols.addClass classSymbol

  # Interface contract expressions may observe class-valued parameters, so lower
  # them only after every class method signature is available.
  var analyzedInterfaces: seq[HirInterface]
  for sourceInterface in specializedProgram.interfaces:
    analyzedInterfaces.add lowerInterface(sourceInterface, symbols)

  # Pass 6: verify explicit class/interface architectural conformance.
  for sourceClass in specializedProgram.classes:
    validateClassInterfaces(sourceClass, symbols)

  # Pass 7: collect top-level function signatures.
  var functions = initFunctionSymbols()
  var mainFound = false
  var mainId = FunctionId(-1)

  for index, fn in specializedProgram.functions:
    if functions.contains(fn.name):
      failAt(fn.span, "duplicate function '" & fn.name & "'")

    var parameterTypes: seq[EidoType]
    for parameter in fn.parameters:
      parameterTypes.add resolveDeclaredType(parameter.typeRef, symbols)

    let functionResult = resolveFunctionResult(fn.result, symbols)
    if fn.isNative:
      validateNativeSignature(fn, parameterTypes, functionResult)

    let symbol = FunctionSymbol(
      id: FunctionId(index),
      name: fn.name,
      isNative: fn.isNative,
      parameterTypes: parameterTypes,
      result: functionResult,
      storageResultProvenance: inferStorageResultProvenance(fn),
      span: fn.span
    )
    functions.add symbol

    let localFunctionName =
      block:
        let separator = fn.name.rfind('.')
        if separator < 0: fn.name else: fn.name[separator + 1 .. ^1]

    if target == ptExecutable and localFunctionName == "main":
      if mainFound:
        failAt(fn.span, "executable project must declare exactly one function main()")
      if fn.isNative:
        failAt(fn.span, "main function cannot be native")
      mainFound = true
      mainId = symbol.id
      if fn.parameters.len != 0:
        failAt(fn.span, "main function must not declare parameters")

  if target == ptExecutable and not mainFound:
    fail(
      MissingMainDiagnosticCode,
      "executable project must declare function main()"
    )

  # Class invariants resolve after both method and top-level callable signatures exist.
  for classIndex, sourceClass in specializedProgram.classes:
    let owner = symbols.getClass(sourceClass.name)
    analyzeClassInvariants(
      sourceClass, analyzedClasses[classIndex], owner, functions, symbols
    )

  # Pass 8: analyze class-owned method bodies.
  for classIndex, sourceClass in specializedProgram.classes:
    let owner = symbols.getClass(sourceClass.name)
    for sourceMethod in sourceClass.methods:
      analyzedClasses[classIndex].methods.add analyzeMethod(
        sourceMethod,
        owner,
        owner.getMethod(sourceMethod.name),
        functions,
        symbols,
        inheritedInterfaceContracts(
          sourceClass,
          sourceMethod.name,
          symbols
        )
      )

  # Pass 9: analyze top-level function bodies.
  var analyzedFunctions: seq[HirFunction]
  for fn in specializedProgram.functions:
    analyzedFunctions.add analyzeFunction(
      fn,
      functions.get(fn.name),
      functions,
      symbols
    )

  let analyzedProgram = hirProgram.HirProgram(
    interfaces: analyzedInterfaces,
    classes: analyzedClasses,
    functions: analyzedFunctions,
    hasMain: mainFound,
    mainFunctionId: mainId
  )

  let contractSafety = inferContractSafety(analyzedProgram)
  validateContractSafety(analyzedProgram, contractSafety)
  analyzedProgram
