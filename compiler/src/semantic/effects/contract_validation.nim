## Rejects contract expressions whose resolved calls may cause observable effects.
## Concrete Eido callables use compiler-inferred transitive safety; native and dynamic-interface calls are conservative failures.

import ../../diagnostics/errors
import ../../hir/[expressions, program]
import ../../types/method_kind
import model

## Validates one contract expression recursively against inferred callable effects.
proc validateContractExpr(
  expr: HirExpr,
  summary: ContractSafetySummary
) =
  if expr.isNil:
    return

  case expr.kind
  of hekCall:
    if expr.call.isNative:
      failAt(
        expr.call.span,
        "contract expression cannot call native function '" &
          expr.call.functionName & "' because its effects cannot be verified"
      )
    if not summary.isFunctionSafe(expr.call.functionId):
      failAt(
        expr.call.span,
        "contract expression cannot call effectful function '" &
          expr.call.functionName & "'"
      )
    for argument in expr.call.arguments:
      validateContractExpr(argument, summary)

  of hekMethodCall:
    if expr.methodCall.dispatchKind == hmdInterface:
      failAt(
        expr.methodCall.span,
        "contract expression cannot use dynamic interface method '" &
          expr.methodCall.methodName & "' because its effects cannot be proven"
      )
    if expr.methodCall.isNative:
      failAt(
        expr.methodCall.span,
        "contract expression cannot call native method '" &
          expr.methodCall.methodName & "' because its effects cannot be verified"
      )
    if not summary.isMethodSafe(expr.methodCall.methodId):
      failAt(
        expr.methodCall.span,
        "contract expression cannot call effectful method '" &
          expr.methodCall.methodName & "'"
      )
    if expr.methodCall.kind == mkInstance:
      validateContractExpr(expr.methodCall.receiver, summary)
    for argument in expr.methodCall.arguments:
      validateContractExpr(argument, summary)

  of hekConstruct:
    for field in expr.fields:
      validateContractExpr(field.value, summary)

  of hekClassRelation:
    validateContractExpr(expr.relatedValue, summary)

  of hekInterfaceConvert:
    validateContractExpr(expr.interfaceValue, summary)

  of hekFieldAccess:
    validateContractExpr(expr.target, summary)

  of hekOptionalSome, hekOptionalGet:
    validateContractExpr(expr.optionalValue, summary)

  of hekUnary:
    validateContractExpr(expr.operand, summary)

  of hekBinary:
    validateContractExpr(expr.left, summary)
    validateContractExpr(expr.right, summary)

  of hekLocal, hekInteger, hekFloating, hekBoolean, hekChar, hekString, hekNone:
    discard

## Validates every require, ensure, and invariant expression in one checked HIR program.
proc validateContractSafety*(
  program: HirProgram,
  summary: ContractSafetySummary
) =
  for classDecl in program.classes:
    for invariant in classDecl.invariants:
      validateContractExpr(invariant, summary)

    for methodDecl in classDecl.methods:
      for clause in methodDecl.requires:
        validateContractExpr(clause, summary)
      for clause in methodDecl.ensures:
        validateContractExpr(clause, summary)

  for fn in program.functions:
    for clause in fn.requires:
      validateContractExpr(clause, summary)
    for clause in fn.ensures:
      validateContractExpr(clause, summary)
