## Defines the resolved HIR program root and optional executable entry function.
## Example: executable programs set `hasMain`, while library targets carry declarations without an entry harness.

import ../semantic/symbols/ids
import declarations

type
  HirProgram* = object
    interfaces*: seq[HirInterface]
    classes*: seq[HirClass]
    functions*: seq[HirFunction]
    hasMain*: bool
    mainFunctionId*: FunctionId
