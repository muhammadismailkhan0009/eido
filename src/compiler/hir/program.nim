## Defines the resolved HIR program root and identifies the entry function. Example: `mainFunctionId` tells the backend which function to execute.

import ../semantic/symbols/ids
import declarations

type
  HirProgram* = object
    functions*: seq[HirFunction]
    mainFunctionId*: FunctionId
