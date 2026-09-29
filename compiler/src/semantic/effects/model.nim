## Defines compiler-inferred callable effect summaries used to constrain contract expressions.
## Contract safety is internal semantic information and does not introduce source-level purity syntax.

import std/tables
import ../symbols/ids

type
  CallableEffectFacts* = object
    directEffect*: bool
    functionDependencies*: seq[FunctionId]
    methodDependencies*: seq[MethodId]

  ContractSafetySummary* = object
    functionSafe: Table[int, bool]
    methodSafe: Table[int, bool]

## Creates an empty contract-safety summary.
proc initContractSafetySummary*(): ContractSafetySummary =
  ContractSafetySummary(
    functionSafe: initTable[int, bool](),
    methodSafe: initTable[int, bool]()
  )

## Records whether one resolved function is observationally safe for contract evaluation.
proc setFunctionSafe*(
  summary: var ContractSafetySummary,
  id: FunctionId,
  safe: bool
) =
  summary.functionSafe[id.value] = safe

## Records whether one resolved class method is observationally safe for contract evaluation.
proc setMethodSafe*(
  summary: var ContractSafetySummary,
  id: MethodId,
  safe: bool
) =
  summary.methodSafe[id.value] = safe

## Reports whether one resolved function is observationally safe for contract evaluation.
proc isFunctionSafe*(
  summary: ContractSafetySummary,
  id: FunctionId
): bool =
  id.value in summary.functionSafe and summary.functionSafe[id.value]

## Reports whether one resolved class method is observationally safe for contract evaluation.
proc isMethodSafe*(
  summary: ContractSafetySummary,
  id: MethodId
): bool =
  id.value in summary.methodSafe and summary.methodSafe[id.value]
