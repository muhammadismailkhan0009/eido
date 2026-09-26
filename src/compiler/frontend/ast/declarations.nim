## Defines syntax-tree nodes for typed parameters and functions. Example: `function notify(Int id) {}` stores one parameter and no result type.

import ../../source/span
import statements

type
  TypeRef* = object
    span*: SourceSpan
    name*: string

  Parameter* = object
    span*: SourceSpan
    name*: string
    typeRef*: TypeRef

  FunctionResultRefKind* = enum
    frrNone,
    frrSingle

  FunctionResultRef* = object
    case kind*: FunctionResultRefKind
    of frrNone:
      discard
    of frrSingle:
      typeRef*: TypeRef

  FunctionDecl* = object
    span*: SourceSpan
    name*: string
    parameters*: seq[Parameter]
    result*: FunctionResultRef
    body*: seq[Stmt]
