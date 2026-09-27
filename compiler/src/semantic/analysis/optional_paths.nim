## Builds stable source-path keys for lexical optional proofs.
## Example: employee.address.city becomes "employee.address.city".

import ../../frontend/ast/expressions as astExpressions

## Returns a stable key for identifier/field paths and empty text for unstable expressions.
## Example: user -> "user", employee.address -> "employee.address", call() -> "".
proc optionalPathKey*(expr: astExpressions.Expr): string =
  if expr.isNil:
    return ""

  case expr.kind
  of astExpressions.ekIdentifier:
    expr.name
  of astExpressions.ekFieldAccess:
    let parent = optionalPathKey(expr.target)
    if parent.len == 0:
      ""
    else:
      parent & "." & expr.fieldName
  else:
    ""
