## Parses grouped expressions and enforces matching delimiters.
## Example: after `[`, the parser accepts an expression and requires `]`.

## Parses an expression inside one opened grouping delimiter and requires its matching closer.
## Example: after consuming `[`, this parses `1 + 2` and requires `]`.
proc parseGrouped(
  parser: var Parser,
  closeKind: TokenKind,
  closeText: string
): Expr =
  let expression = parser.parseExpression()
  discard parser.consume(
    closeKind,
    "expected '" & closeText & "' after grouped expression"
  )
  expression
