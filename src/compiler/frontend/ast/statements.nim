## Defines syntax-tree nodes for Eido statements. Example: `notify(10);` becomes an `skCall` statement and `return;` is a return with no value.

import ../../source/span
import expressions

type
  StmtKind* = enum
    skVar,
    skAssign,
    skCall,
    skReturn,
    skIf,
    skWhile,
    skFor,
    skBreak,
    skContinue

  Stmt* = ref object
    span*: SourceSpan
    case kind*: StmtKind
    of skVar:
      name*: string
      initializer*: Expr
    of skAssign:
      target*: string
      assignedValue*: Expr
    of skCall:
      call*: Expr
    of skReturn:
      value*: Expr
    of skIf:
      condition*: Expr
      thenBranch*: seq[Stmt]
      elseBranch*: seq[Stmt]
    of skWhile:
      whileCondition*: Expr
      body*: seq[Stmt]
    of skFor:
      forInitializer*: Stmt
      forCondition*: Expr
      forUpdate*: Stmt
      forBody*: seq[Stmt]
    of skBreak, skContinue:
      discard
