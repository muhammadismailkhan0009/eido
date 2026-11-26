## Defines the AST root for a source program. Example: two top-level functions are stored in `Program.functions`.

import declarations
import expressions
import ../../source/span

type
  LayoutConfigCall* = object
    span*: SourceSpan
    moduleName*: string
    call*: Expr

  ImportDecl* = object
    path*: string
    span*: SourceSpan
    nameSpan*: SourceSpan
    moduleName*: string

  Program* = object
    imports*: seq[ImportDecl]
    interfaces*: seq[InterfaceDecl]
    classes*: seq[ClassDecl]
    layouts*: seq[LayoutDecl]
    layoutConfigCalls*: seq[LayoutConfigCall]
    functions*: seq[FunctionDecl]
