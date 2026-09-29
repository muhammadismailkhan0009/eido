## Describes checks that run only when an Eido callable exits normally.
## Postconditions and stable-boundary invariants use this instead of Nim defer.

import ../../../hir/expressions as hirExpressions
import std/strutils
import names
import contract_emitter

type
  NormalExitContext* = object
    contractClauses*: seq[hirExpressions.HirExpr]
    contractMessage*: string
    resultBindingName*: string
    invariantOwner*: string
    invariantReceiver*: string

## Reports whether any normal-exit work is configured.
proc hasNormalExitChecks*(context: NormalExitContext): bool =
  context.contractClauses.len > 0 or context.invariantOwner.len > 0

## Renders one invariant check unless that invariant is already being evaluated.
proc renderInvariantValidation*(
  context: NormalExitContext,
  indent: int
): string =
  if context.invariantOwner.len == 0:
    return

  let pad = " ".repeat(indent)
  result.add pad & "if " & context.invariantReceiver & "." &
    invariantEvaluationDepthFieldName() & " == 0:\n"
  result.add pad & "  discard " & classInvariantName(context.invariantOwner) &
    "(" & context.invariantReceiver & ")\n"

## Renders postconditions followed by the callable's class-invariant check.
proc renderNormalExitChecks*(
  context: NormalExitContext,
  indent: int
): string =
  for clause in context.contractClauses:
    result.add renderContractCheck(clause, context.contractMessage, indent)

  result.add renderInvariantValidation(context, indent)
