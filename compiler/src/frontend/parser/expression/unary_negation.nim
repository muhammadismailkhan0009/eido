## Parses recursive numeric unary negation.
## Example: `--5` becomes nested unary-negation AST nodes.

## Parses recursive unary numeric negation before multiplicative/additive operators.
## Example: `-2 * 3` becomes multiplication whose left operand is negation of `2`.
proc parseUnary(parser: var Parser): Expr =
  if parser.check(tkMinus):
    let operator = parser.advance()
    let operand = parser.parseUnary()
    return Expr(
      kind: ekUnary,
      span: coverSpan(operator.span, operand.span),
      unaryOp: uoNegate,
      operand: operand
    )

  parser.parsePrimary()
