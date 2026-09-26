## Defines typed, resolved HIR statements. Example: `notify(10);` stores a resolved `HirCall`, while `return;` stores no value.

import ../source/span
import ../types/model
import ../semantic/symbols/ids
import expressions

type
  HirStmtKind* = enum
    hskVar,
    hskAssign,
    hskCall,
    hskReturn,
    hskIf

  HirStmt* = ref object
    span*: SourceSpan
    case kind*: HirStmtKind
    of hskVar:
      localId*: LocalId
      sourceName*: string
      typ*: EidoType
      initializer*: HirExpr
    of hskAssign:
      targetId*: LocalId
      targetName*: string
      assignedValue*: HirExpr
    of hskCall:
      call*: HirCall
    of hskReturn:
      value*: HirExpr
    of hskIf:
      condition*: HirExpr
      thenBranch*: seq[HirStmt]
      elseBranch*: seq[HirStmt]
