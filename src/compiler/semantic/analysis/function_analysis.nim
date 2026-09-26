## Builds parameter scope and lowers one checked function body to HIR. Example: eight mixed primitive parameters each receive a LocalId before the body is analyzed.

import ../../diagnostics/errors
import ../../frontend/ast/declarations
import ../../hir/declarations as hirDeclarations
import ../../hir/statements
import ../../types/model
import ../../types/function_result
import type_resolution
import ../symbols/model
import ../symbols/functions
import ../symbols/scope
import statement_analysis

## Creates parameter scope and analyzes one function body into resolved HIR. Example: `add(Int a, Int b)` registers both parameters before analyzing `return a + b;`.
proc analyzeFunction*(
  fn: FunctionDecl,
  symbol: FunctionSymbol,
  functions: FunctionSymbols
): hirDeclarations.HirFunction =
  var locals = initLocalScope()
  var parameters: seq[HirParameter]

  for parameter in fn.parameters:
    if locals.contains(parameter.name):
      failAt(parameter.span, "duplicate parameter '" & parameter.name & "'")

    let typ = resolveType(parameter.typeRef)
    let localId = locals.nextLocalId()
    let localSymbol = LocalSymbol(
      id: localId,
      name: parameter.name,
      typ: typ,
      kind: bkParameter,
      span: parameter.span
    )
    locals.add(parameter.name, localSymbol)

    parameters.add HirParameter(
      span: parameter.span,
      localId: localId,
      sourceName: parameter.name,
      typ: typ
    )

  var body: seq[HirStmt]
  for stmt in fn.body:
    body.add analyzeStmt(stmt, locals, functions, symbol.result)

  if symbol.result.kind == frSingle:
    if body.len == 0 or body[^1].kind != hskReturn:
      failAt(
        fn.span,
        "function '" & fn.name & "' must return " & symbol.result.typ.displayName
      )

  HirFunction(
    span: fn.span,
    functionId: symbol.id,
    sourceName: fn.name,
    parameters: parameters,
    result: symbol.result,
    body: body
  )
