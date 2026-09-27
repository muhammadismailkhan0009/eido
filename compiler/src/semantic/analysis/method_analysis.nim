## Analyzes one class-owned instance method with explicit source-level self bound to a hidden receiver.
## Class fields occupy the same effective name namespace as method parameters and locals.

import ../../diagnostics/errors
import ../../frontend/ast/declarations
import ../../hir/declarations as hirDeclarations
import ../../hir/statements
import ../../types/function_result
import ../../types/model
import ../symbols/[classes, functions, model, scope]
import statement_analysis

## Creates field/parameter scope and lowers one checked instance method body.
proc analyzeMethod*(
  sourceMethod: FunctionDecl,
  owner: ClassSymbol,
  symbol: MethodSymbol,
  functions: FunctionSymbols,
  classes: ClassSymbols
): hirDeclarations.HirMethod =
  var locals = initLocalScope()
  let receiverLocalId = locals.nextLocalId()
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

  if symbol.result.kind == frSingle and not blockAlwaysReturns(body):
    failAt(
      sourceMethod.span,
      "method '" & sourceMethod.name & "' must return " &
        symbol.result.typ.displayName
    )

  hirDeclarations.HirMethod(
    span: sourceMethod.span,
    methodId: symbol.id,
    sourceName: sourceMethod.name,
    ownerType: owner.typ,
    receiverLocalId: receiverLocalId,
    parameters: parameters,
    result: symbol.result,
    body: body
  )
