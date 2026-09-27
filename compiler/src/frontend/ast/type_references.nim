## Defines source-level type references independently of declarations and expressions.
## Generic applications are recursive: Result<List<User>, Error> nests TypeRef values.

import ../../source/span

type
  TypeRef* = object
    span*: SourceSpan
    name*: string
    arguments*: seq[TypeRef]

  TypeParameterDecl* = object
    span*: SourceSpan
    name*: string
