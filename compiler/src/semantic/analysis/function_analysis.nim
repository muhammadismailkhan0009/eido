## Builds parameter scope and lowers one checked function body to HIR. Example: eight mixed primitive parameters each receive a LocalId before the body is analyzed.

import ../../diagnostics/errors
import ../../frontend/ast/declarations
import ../../hir/declarations as hirDeclarations
import ../../hir/statements
import ../../types/model
import ../../types/function_result
import ../symbols/model
import ../symbols/ids
import ../symbols/functions
import ../symbols/nominals
import ../symbols/scope
import statement_analysis
import contracts

## Creates parameter scope and analyzes one function body into resolved HIR. Example: `add(Int a, Int b)` registers both parameters before analyzing `return a + b;`.
proc analyzeFunction*(
  fn: FunctionDecl,
  symbol: FunctionSymbol,
  functions: FunctionSymbols,
  classes: NominalSymbols
): hirDeclarations.HirFunction =
  var locals = initLocalScope()
  var parameters: seq[HirParameter]

  for index, parameter in fn.parameters:
    if locals.contains(parameter.name):
      failAt(parameter.span, "duplicate parameter '" & parameter.name & "'")

    let typ = symbol.parameterTypes[index]
    let localId = locals.nextLocalId()
    let localSymbol = LocalSymbol(
      id: localId,
      name: parameter.name,
      typ: typ,
      kind: bkParameter,
      span: parameter.span,
      classValueProvenance:
        if typ.kind == etkClass: cvpExisting else: cvpNotClass
    )
    locals.add(parameter.name, localSymbol)

    parameters.add HirParameter(
      span: parameter.span,
      localId: localId,
      sourceName: parameter.name,
      typ: typ
    )

  let requires = analyzeContractClauses(
    fn.requires, locals, functions, classes, "require"
  )

  var ensureResultLocalId = LocalId(-1)
  var ensureLocals = locals.fork()
  if fn.ensures.len > 0 and symbol.result.kind == frSingle:
    ensureResultLocalId = locals.nextLocalId()
    ensureLocals = locals.fork()
    ensureLocals.add(
      "result",
      LocalSymbol(
        id: ensureResultLocalId,
        name: "result",
        typ: symbol.result.typ,
        kind: bkParameter,
        span: fn.span,
        classValueProvenance:
          if symbol.result.typ.kind == etkClass: cvpDetached else: cvpNotClass
      )
    )
  let ensures = analyzeContractClauses(
    fn.ensures, ensureLocals, functions, classes, "ensure"
  )

  var body: seq[HirStmt]
  for stmt in fn.body:
    body.add analyzeStmt(
      stmt,
      locals,
      functions,
      classes,
      symbol.result
    )

  if not fn.isNative and symbol.result.kind == frSingle:
    if not blockAlwaysReturns(body):
      failAt(
        fn.span,
        "function '" & fn.name & "' must return " & symbol.result.typ.displayName
      )

  HirFunction(
    span: fn.span,
    functionId: symbol.id,
    sourceName: fn.name,
    isNative: fn.isNative,
    parameters: parameters,
    result: symbol.result,
    requires: requires,
    ensures: ensures,
    ensureResultLocalId: ensureResultLocalId,
    body: body
  )
