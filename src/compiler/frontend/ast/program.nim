## Defines the AST root for a source program. Example: two top-level functions are stored in `Program.functions`.

import declarations

type
  Program* = object
    functions*: seq[FunctionDecl]
