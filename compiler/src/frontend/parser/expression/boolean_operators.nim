## Parses word `not` below comparison/equality precedence.
## Example: `not age < 18` becomes negation of the completed comparison.
proc parseNot(parser: var Parser): Expr =
  if parser.check(tkNot):
    let operator = parser.advance()
    let operand = parser.parseNot()
    return Expr(
      kind: ekUnary,
      span: coverSpan(operator.span, operand.span),
      unaryOp: uoNot,
      operand: operand
    )

  parser.parseEquality()

## Parses short-circuit conjunction below `not` precedence.
proc parseAnd(parser: var Parser): Expr =
  result = parser.parseNot()

  while parser.check(tkAnd):
    discard parser.advance()
    let right = parser.parseNot()
    result = Expr(
      kind: ekBinary,
      span: binarySpan(result, right),
      op: boAnd,
      left: result,
      right: right
    )

## Parses short-circuit disjunction at the lowest current precedence.
proc parseOr(parser: var Parser): Expr =
  result = parser.parseAnd()

  while parser.check(tkOr):
    discard parser.advance()
    let right = parser.parseAnd()
    result = Expr(
      kind: ekBinary,
      span: binarySpan(result, right),
      op: boOr,
      left: result,
      right: right
    )
