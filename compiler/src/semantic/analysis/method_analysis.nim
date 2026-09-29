## Analyzes one class-owned function after static/instance classification.
## Instance methods bind explicit self to a hidden receiver; inferred static methods receive no receiver.

import ../../diagnostics/errors
import ../../frontend/ast/declarations
import ../../hir/declarations as hirDeclarations
import ../../hir/statements
import ../../types/function_result
import ../../types/model
import ../../types/storage
import ../../types/method_kind
import ../symbols/[functions, ids, model, nominals, scope]
import statement_analysis
import contracts

## Creates the classified method scope and lowers one checked class function body.
proc analyzeMethod*(
  sourceMethod: FunctionDecl,
  owner: ClassSymbol,
  symbol: MethodSymbol,
  functions: FunctionSymbols,
  classes: NominalSymbols,
  inheritedContracts: seq[InterfaceMethodSymbol] = @[]
): hirDeclarations.HirMethod =
  var locals = initLocalScope()
  var receiverLocalId = LocalId(-1)

  if symbol.kind == mkInstance:
    receiverLocalId = locals.nextLocalId()
    locals.add(
      "self",
      LocalSymbol(
        name: "self",
        typ: owner.typ,
        span: sourceMethod.span,
        kind: bkReceiver,
        id: receiverLocalId,
        classValueProvenance: cvpExisting
      )
    )

  for field in owner.fields:
    locals.add(
      field.name,
      LocalSymbol(
        name: field.name,
        typ: field.typ,
        span: field.span,
        kind: bkField,
        receiverId: receiverLocalId,
        ownerType: owner.typ,
        classValueProvenance:
          if field.typ.kind == etkClass: cvpExisting else: cvpNotClass
      )
    )

  var parameters: seq[hirDeclarations.HirParameter]
  for index, parameter in sourceMethod.parameters:
    if locals.contains(parameter.name):
      failAt(
        parameter.span,
        "method parameter '" & parameter.name &
          "' conflicts with an existing field or parameter"
      )

    let localId = locals.nextLocalId()
    let parameterType = symbol.parameterTypes[index]
    locals.add(
      parameter.name,
      LocalSymbol(
        name: parameter.name,
        typ: parameterType,
        span: parameter.span,
        kind: bkParameter,
        id: localId,
        classValueProvenance:
          if parameterType.kind == etkClass: cvpExisting else: cvpNotClass,
        storageValueProvenance:
          if parameterType.kind == etkClass and
              isConcreteStorageTypeName(parameterType.className):
            svpBorrowed
          else:
            svpNotStorage
      )
    )

    parameters.add hirDeclarations.HirParameter(
      span: parameter.span,
      localId: localId,
      sourceName: parameter.name,
      typ: parameterType
    )

  var inheritedRequires: seq[hirDeclarations.HirInheritedContractClause]
  for contract in inheritedContracts:
    var contractLocals = initLocalScope()
    if symbol.kind == mkInstance:
      contractLocals.add(
        "self",
        LocalSymbol(
          name: "self",
          typ: owner.typ,
          span: contract.span,
          kind: bkReceiver,
          id: receiverLocalId,
          classValueProvenance: cvpExisting
        )
      )
    for index, parameter in contract.sourceDecl.parameters:
      let implementationParameter = parameters[index]
      contractLocals.add(
        parameter.name,
        LocalSymbol(
          name: implementationParameter.sourceName,
          typ: implementationParameter.typ,
          span: parameter.span,
          kind: bkParameter,
          id: implementationParameter.localId,
          classValueProvenance:
            if implementationParameter.typ.kind == etkClass:
              cvpExisting
            else:
              cvpNotClass
        )
      )
    for clause in analyzeContractClauses(
      contract.sourceDecl.requires,
      contractLocals,
      functions,
      classes,
      "require"
    ):
      inheritedRequires.add hirDeclarations.HirInheritedContractClause(
        interfaceName: contract.declaringInterface,
        expr: clause
      )

  let requires = analyzeContractClauses(
    sourceMethod.requires, locals, functions, classes, "require"
  )

  var ensureResultLocalId = LocalId(-1)
  var inheritedEnsures: seq[hirDeclarations.HirInheritedContractClause]
  var inheritedEnsureCount = 0
  for contract in inheritedContracts:
    inheritedEnsureCount += contract.sourceDecl.ensures.len

  let hasAnyEnsures = sourceMethod.ensures.len > 0 or inheritedEnsureCount > 0
  var ensureLocals = locals.fork()
  if hasAnyEnsures and symbol.result.kind == frSingle:
    ensureResultLocalId = locals.nextLocalId()
    ensureLocals = locals.fork()
    ensureLocals.add(
      "result",
      LocalSymbol(
        id: ensureResultLocalId,
        name: "result",
        typ: symbol.result.typ,
        kind: bkParameter,
        span: sourceMethod.span,
        classValueProvenance:
          if symbol.result.typ.kind == etkClass: cvpDetached else: cvpNotClass
      )
    )

  for contract in inheritedContracts:
    if contract.sourceDecl.ensures.len == 0:
      continue
    var contractLocals = initLocalScope()
    if symbol.kind == mkInstance:
      contractLocals.add(
        "self",
        LocalSymbol(
          name: "self",
          typ: owner.typ,
          span: contract.span,
          kind: bkReceiver,
          id: receiverLocalId,
          classValueProvenance: cvpExisting
        )
      )
    for index, parameter in contract.sourceDecl.parameters:
      let implementationParameter = parameters[index]
      contractLocals.add(
        parameter.name,
        LocalSymbol(
          name: implementationParameter.sourceName,
          typ: implementationParameter.typ,
          span: parameter.span,
          kind: bkParameter,
          id: implementationParameter.localId,
          classValueProvenance:
            if implementationParameter.typ.kind == etkClass:
              cvpExisting
            else:
              cvpNotClass
        )
      )
    if symbol.result.kind == frSingle:
      contractLocals.add(
        "result",
        LocalSymbol(
          id: ensureResultLocalId,
          name: "result",
          typ: symbol.result.typ,
          kind: bkParameter,
          span: contract.span,
          classValueProvenance:
            if symbol.result.typ.kind == etkClass: cvpDetached else: cvpNotClass
        )
      )
    for clause in analyzeContractClauses(
      contract.sourceDecl.ensures,
      contractLocals,
      functions,
      classes,
      "ensure",
      symbol.result.kind == frSingle
    ):
      inheritedEnsures.add hirDeclarations.HirInheritedContractClause(
        interfaceName: contract.declaringInterface,
        expr: clause
      )

  let ensures = analyzeContractClauses(
    sourceMethod.ensures, ensureLocals, functions, classes, "ensure",
    symbol.result.kind == frSingle
  )

  var body: seq[HirStmt]
  for statement in sourceMethod.body:
    body.add analyzeStmt(
      statement,
      locals,
      functions,
      classes,
      symbol.result
    )

  if not symbol.isNative and
      symbol.result.kind == frSingle and
      not blockAlwaysReturns(body):
    failAt(
      sourceMethod.span,
      "method '" & sourceMethod.name & "' must return " &
        symbol.result.typ.displayName
    )

  result = hirDeclarations.HirMethod(
    span: sourceMethod.span,
    methodId: symbol.id,
    sourceName: sourceMethod.name,
    isNative: symbol.isNative,
    ownerType: owner.typ,
    parameters: parameters,
    result: symbol.result,
    inheritedRequires: inheritedRequires,
    requires: requires,
    inheritedEnsures: inheritedEnsures,
    ensures: ensures,
    ensureResultLocalId: ensureResultLocalId,
    body: body,
    kind: symbol.kind
  )

  if symbol.kind == mkInstance:
    result.receiverLocalId = receiverLocalId
