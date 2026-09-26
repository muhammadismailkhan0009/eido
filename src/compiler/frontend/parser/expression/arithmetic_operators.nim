## Parses multiplicative and additive arithmetic precedence levels.
## Example: `10 + 20 * 3` keeps multiplication nested inside addition.

## Parses multiplication and division before lower-precedence addition/subtraction.
## Example: `20 * 3` becomes one multiplicative subtree.
proc parseMultiplicative(parser: var Parser): Expr =
  result = parser.parseUnary()

  while parser.check(tkStar) or parser.check(tkSlash):
    let operator = parser.advance()
    let right = parser.parseUnary()
    let op = if operator.kind == tkStar: boMultiply else: boDivide
    result = Expr(
      kind: ekBinary,
      span: binarySpan(result, right),
      op: op,
      left: result,
      right: right
    )

## Parses addition and subtraction using multiplicative expressions as operands.
## Example: `10 + 20 * 3` keeps multiplication nested on the right.
proc parseAdditive(parser: var Parser): Expr =
  result = parser.parseMultiplicative()

  while parser.check(tkPlus) or parser.check(tkMinus):
    let operator = parser.advance()
    let right = parser.parseMultiplicative()
    let op = if operator.kind == tkPlus: boAdd else: boSubtract
    result = Expr(
      kind: ekBinary,
      span: binarySpan(result, right),
      op: op,
      left: result,
      right: right
    )
