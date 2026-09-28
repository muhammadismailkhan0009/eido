## Analyzes one class-owned function after static/instance classification.
## Instance methods bind explicit self to a hidden receiver; inferred static methods receive no receiver.

import ../../diagnostics/errors
import ../../frontend/ast/declarations
import ../../hir/declarations as hirDeclarations
import ../../hir/statements
import ../../types/function_result
import ../../types/model
import ../../types/method_kind
import ../symbols/[functions, ids, model, nominals, scope]
import statement_analysis

## Creates the classified method scope and lowers one checked class function body.
proc analyzeMethod*(
  sourceMethod: FunctionDecl,
  owner: ClassSymbol,
  symbol: MethodSymbol,
  functions: FunctionSymbols,
  classes: NominalSymbols
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
          if parameterType.kind == etkClass: cvpExisting else: cvpNotClass
      )
    )

    parameters.add hirDeclarations.HirParameter(
      span: parameter.span,
      localId: localId,
      sourceName: parameter.name,
      typ: parameterType
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
    body: body,
    kind: symbol.kind
  )

  if symbol.kind == mkInstance:
    result.receiverLocalId = receiverLocalId
