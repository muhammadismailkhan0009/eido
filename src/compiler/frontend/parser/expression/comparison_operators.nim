## Parses ordered and equality comparisons below arithmetic precedence.
## Example: `1 + 2 < 4 == true` completes arithmetic, then ordering, then equality.

## Parses ordered comparisons below arithmetic precedence.
## Example: `1 + 2 < 4 * 2` compares two completed arithmetic subexpressions.
proc parseRelational(parser: var Parser): Expr =
  result = parser.parseAdditive()

  while parser.check(tkLess) or parser.check(tkLessEqual) or
      parser.check(tkGreater) or parser.check(tkGreaterEqual):
    let operator = parser.advance()
    let right = parser.parseAdditive()
    let op =
      case operator.kind
      of tkLess: boLess
      of tkLessEqual: boLessEqual
      of tkGreater: boGreater
      of tkGreaterEqual: boGreaterEqual
      else: boLess
    result = Expr(
      kind: ekBinary,
      span: binarySpan(result, right),
      op: op,
      left: result,
      right: right
    )

## Parses equality comparisons below ordered-comparison precedence.
## Example: `1 < 2 == true` compares the Bool result of `1 < 2` with `true`.
proc parseEquality(parser: var Parser): Expr =
  result = parser.parseRelational()

  while parser.check(tkEqualEqual) or parser.check(tkBangEqual):
    let operator = parser.advance()
    let right = parser.parseRelational()
    let op = if operator.kind == tkEqualEqual: boEqual else: boNotEqual
    result = Expr(
      kind: ekBinary,
      span: binarySpan(result, right),
      op: op,
      left: result,
      right: right
    )
