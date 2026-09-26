## Defines syntax-tree nodes for Eido statements. Example: `notify(10);` becomes an `skCall` statement and `return;` is a return with no value.

import ../../source/span
import expressions

type
  StmtKind* = enum
    skVar,
    skAssign,
    skCall,
    skReturn

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
