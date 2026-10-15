## Renders class-owned Eido methods as Nim procedures.
## Instance methods receive a hidden receiver; inferred static methods do not.

import ../../../compile_time/model
import ../../../hir/declarations as hirDeclarations
import ../../../semantic/symbols/ids
import ../../../hir/expressions as hirExpressions
import ../../../types/function_result
import ../../../types/method_kind
import ../../../source/span
import runtime_bindings
import names
import type_emitter
import statement_emitter
import contract_emitter
import normal_exit
import instrumentation_emitter

## Renders one generated method signature with a receiver only for instance methods.
proc renderMethodSignature*(methodDecl: hirDeclarations.HirMethod): string =
  let renderedMethodName = methodName(
    methodDecl.methodId,
    methodDecl.ownerType.className,
    methodDecl.sourceName
  )
  result = "proc " & renderedMethodName & "("

  var hasPreviousParameter = false
  if methodDecl.kind == mkInstance:
    result.add localName(methodDecl.receiverLocalId, "receiver") &
      ": " & renderType(methodDecl.ownerType)
    hasPreviousParameter = true

  for parameter in methodDecl.parameters:
    if hasPreviousParameter:
      result.add ", "
    result.add localName(parameter.localId, parameter.sourceName) &
      ": " & renderType(parameter.typ)
    hasPreviousParameter = true

  result.add ")"
  if methodDecl.result.kind == frSingle:
    result.add ": " & renderType(methodDecl.result.typ)

## Renders one complete generated method body.
proc renderMethod*(
  methodDecl: hirDeclarations.HirMethod,
  enforceInvariant: bool = false,
  memoryMetadata: CompileTimeMemoryMetadata = CompileTimeMemoryMetadata(),
  runtimeBindings: RuntimeBindings = RuntimeBindings()
): string =
  result.add renderMethodSignature(methodDecl) & " =\n"

  # Compiler-runtime implementation methods consume metadata; they must not
  # recursively report their own lexical lifetime/boundary events.
  let isCompilerRuntimeMethod = methodDecl.span.isHiddenRuntime
  let identityValues =
    if isCompilerRuntimeMethod:
      @[]
    else:
      memoryMetadata.identityValuesForMethod(methodDecl.methodId)
  if memoryMetadata.types.len > 0 and not isCompilerRuntimeMethod:
    result.add renderMethodValuePreamble(methodDecl, identityValues, runtimeBindings)

  let hasInvariant = enforceInvariant and methodDecl.kind == mkInstance
  let receiverName =
    if methodDecl.kind == mkInstance:
      localName(methodDecl.receiverLocalId, "receiver")
    else:
      ""

  var effectiveEnsures: seq[hirExpressions.HirExpr]
  for inherited in methodDecl.inheritedEnsures:
    effectiveEnsures.add inherited.expr
  for clause in methodDecl.ensures:
    effectiveEnsures.add clause

  var resultIdentityValueId = -1
  for value in identityValues:
    if effectiveEnsures.len > 0 and methodDecl.result.kind == frSingle and
        value.localId == methodDecl.ensureResultLocalId.value:
      resultIdentityValueId = value.localId

  let exitContext = NormalExitContext(
    contractClauses: effectiveEnsures,
    contractMessage: "ensure contract failed in method '" &
      methodDecl.sourceName & "'",
    resultBindingName:
      if effectiveEnsures.len > 0 and methodDecl.result.kind == frSingle:
        localName(methodDecl.ensureResultLocalId, "result")
      else:
        "",
    invariantOwner:
      if hasInvariant: methodDecl.ownerType.className else: "",
    invariantReceiver: receiverName,
    ownerClassName: methodDecl.ownerType.className,
    instrumentationEnabled: memoryMetadata.types.len > 0 and not isCompilerRuntimeMethod,
    identityValueIds: identityValues.identityValueIds,
    resultIdentityValueId: resultIdentityValueId,
    runtimeBindings: runtimeBindings
  )

  if hasInvariant:
    result.add renderInvariantValidation(exitContext, 2)

  for inherited in methodDecl.inheritedRequires:
    result.add renderContractCheck(
      inherited.expr,
      "require contract inherited from interface '" &
        inherited.interfaceName & "' failed in method '" &
        methodDecl.sourceName & "'",
      2
    )

  for clause in methodDecl.requires:
    result.add renderContractCheck(
      clause,
      "require contract failed in method '" & methodDecl.sourceName & "'",
      2
    )

  if methodDecl.body.len == 0:
    if exitContext.hasNormalExitChecks:
      result.add renderNormalExitChecks(exitContext, 2)
    elif methodDecl.inheritedRequires.len == 0 and
        methodDecl.requires.len == 0 and
        not hasInvariant:
      result.add "  discard\n"
  else:
    for stmt in methodDecl.body:
      result.add renderStmtAt(stmt, 2, exitContext)
    if methodDecl.result.kind == frNone:
      result.add renderNormalExitChecks(exitContext, 2)
