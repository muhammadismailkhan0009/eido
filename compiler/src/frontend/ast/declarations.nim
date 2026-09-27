## Defines syntax-tree nodes for typed declarations.
## Functions are reused as the source shape of class-owned methods.

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

  FieldDecl* = object
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
    isNative*: bool
    parameters*: seq[Parameter]
    result*: FunctionResultRef
    body*: seq[Stmt]

  ClassDecl* = object
    span*: SourceSpan
    name*: string
    fields*: seq[FieldDecl]
    methods*: seq[FunctionDecl]
