## Parses Eido expressions with precedence and primitive literals. Example: `10 + 20 * 3` becomes addition whose right side is multiplication.

import std/strutils
import ../../source/span
import ../../diagnostics/errors
import ../lexer/token
import ../ast/expressions
import core

## Parses a complete currently-supported expression. Example: `salary + bonus * 2` returns one AST expression tree.
proc parseExpression*(parser: var Parser): Expr

## Converts one hexadecimal digit to its numeric value. Example: `'F'` becomes 15 while decoding `'\u004F'`.
proc hexValue(c: char): uint16 =
  case c
  of '0'..'9': uint16(ord(c) - ord('0'))
  of 'a'..'f': uint16(ord(c) - ord('a') + 10)
  of 'A'..'F': uint16(ord(c) - ord('A') + 10)
  else: 0'u16

## Decodes a validated Char-token spelling into one 16-bit code unit. Example: `'A'` and `'\u0041'` both become 65.
proc parseCharValue(token: Token): uint16 =
  let text = token.lexeme
  if text.len == 3:
    return uint16(ord(text[1]))

  if text.len >= 4 and text[1] == '\\':
    case text[2]
    of 'n': return 10'u16
    of 'r': return 13'u16
    of 't': return 9'u16
    of 'b': return 8'u16
    of 'f': return 12'u16
    of '\\': return 92'u16
    of '\'': return 39'u16
    of 'u':
      var value = 0'u16
      for index in 3 .. 6:
        value = uint16(value * 16'u16 + hexValue(text[index]))
      return value
    else:
      discard

  failAt(token.span, "invalid Char literal")

## Parses a function-call expression after its name. Example: `add(10, 20)` becomes a call with callee `add` and two arguments.
proc parseCall(parser: var Parser, name: Token): Expr =
  discard parser.consume(tkLParen, "expected '(' after function name")
  var arguments: seq[Expr]

  if not parser.check(tkRParen):
    while true:
      arguments.add parser.parseExpression()
      if not parser.check(tkComma):
        break
      discard parser.advance()

  let closeParen = parser.consume(tkRParen, "expected ')' after arguments")
  Expr(
    kind: ekCall,
    span: SourceSpan(
      startOffset: name.span.startOffset,
      endOffset: closeParen.span.endOffset,
      line: name.span.line,
      column: name.span.column
    ),
    callee: name.lexeme,
    arguments: arguments
  )

## Parses an expression inside one already-opened grouping delimiter and requires its matching closer.
## Example: after consuming `[`, this parses `1 + 2` and requires `]`, not `)` or `}`.
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

## Parses atomic expressions and all three mathematical grouping forms.
## Example: `5`, `salary`, `(a + b)`, `[a + b]`, and `{a + b}` all start here.
proc parsePrimary(parser: var Parser): Expr =
  if parser.check(tkInteger):
    let token = parser.advance()
    return Expr(
      kind: ekInteger,
      span: token.span,
      intValue: parseBiggestInt(token.lexeme).int64
    )

  if parser.check(tkFloat):
    let token = parser.advance()
    return Expr(
      kind: ekFloat,
      span: token.span,
      floatValue: parseFloat(token.lexeme)
    )

  if parser.check(tkBoolean):
    let token = parser.advance()
    return Expr(
      kind: ekBoolean,
      span: token.span,
      boolValue: token.lexeme == "true"
    )

  if parser.check(tkChar):
    let token = parser.advance()
    return Expr(
      kind: ekChar,
      span: token.span,
      charValue: parseCharValue(token)
    )

  if parser.check(tkIdentifier):
    let token = parser.advance()
    if parser.check(tkLParen):
      return parser.parseCall(token)
    return Expr(
      kind: ekIdentifier,
      span: token.span,
      name: token.lexeme
    )

  if parser.check(tkLParen):
    discard parser.advance()
    return parser.parseGrouped(tkRParen, ")")

  if parser.check(tkLBracket):
    discard parser.advance()
    return parser.parseGrouped(tkRBracket, "]")

  if parser.check(tkLBrace):
    discard parser.advance()
    return parser.parseGrouped(tkRBrace, "}")

  failAt(
    parser.peek.span,
    "expected primitive literal, identifier, call, or grouped expression"
  )

## Parses unary numeric negation before multiplicative/additive operators.
## Example: `-2 * 3` becomes multiplication whose left operand is unary negation of `2`.
proc parseUnary(parser: var Parser): Expr =
  if parser.check(tkMinus):
    let operator = parser.advance()
    let operand = parser.parseUnary()
    return Expr(
      kind: ekUnary,
      span: SourceSpan(
        startOffset: operator.span.startOffset,
        endOffset: operand.span.endOffset,
        line: operator.span.line,
        column: operator.span.column
      ),
      unaryOp: uoNegate,
      operand: operand
    )

  parser.parsePrimary()

## Creates a source span covering both sides of a binary expression. Example: the span for `a + 5` starts at `a` and ends after `5`.
proc binarySpan(left, right: Expr): SourceSpan =
  SourceSpan(
    startOffset: left.span.startOffset,
    endOffset: right.span.endOffset,
    line: left.span.line,
    column: left.span.column
  )

## Parses `*` and `/` expressions before lower-precedence addition. Example: `20 * 3` becomes one multiplicative subtree.
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

## Parses `+` and `-` expressions using multiplicative expressions as operands. Example: `10 + 20 * 3` keeps multiplication nested on the right.
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

## Parses ordered comparisons below arithmetic precedence.
## Example: `1 + 2 < 4 * 2` compares the two completed arithmetic subexpressions.
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

## Parses a complete currently-supported expression. Example: `salary + bonus * 2 >= limit` returns one AST expression tree.
proc parseExpression*(parser: var Parser): Expr =
  parser.parseEquality()
