## Defines syntax-tree nodes for typed declarations.
## Functions are reused as the source shape of class-owned methods.

import ../../source/span
import type_references
export type_references
import statements
import expressions

type
  Parameter* = object
    span*: SourceSpan
    name*: string
    typeRef*: TypeRef

  FieldDecl* = object
    span*: SourceSpan
    name*: string
    typeRef*: TypeRef
    isClassOwned*: bool
    ownerName*: string
    initializer*: Expr

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
    moduleName*: string
    isNative*: bool
    parameters*: seq[Parameter]
    result*: FunctionResultRef
    requires*: seq[Expr]
    ensures*: seq[Expr]
    body*: seq[Stmt]

  InterfaceDecl* = object
    span*: SourceSpan
    name*: string
    moduleName*: string
    typeParameters*: seq[TypeParameterDecl]
    extends*: seq[string]
    methods*: seq[FunctionDecl]

  ## A compile-time layout declaration. Its body remains syntax until the
  ## layout evaluator is introduced; it has no runtime effect by itself.
  LayoutDecl* = object
    span*: SourceSpan
    name*: string
    moduleName*: string
    typeParameters*: seq[TypeParameterDecl]
    targetType*: TypeRef
    body*: seq[Stmt]

  ClassDecl* = object
    span*: SourceSpan
    name*: string
    moduleName*: string
    typeParameters*: seq[TypeParameterDecl]
    implements*: seq[TypeRef]
    fields*: seq[FieldDecl]
    invariants*: seq[Expr]
    methods*: seq[FunctionDecl]
