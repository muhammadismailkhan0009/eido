## Provides token-cursor mechanics shared by all parser modules. Example: `consume(tkSemicolon, ...)` requires the next token to be `;`.

import ../../diagnostics/errors
import ../lexer/token

type
  Parser* = object
    tokens: seq[Token]
    current: int

## Creates a parser positioned at the first token. Example: the token list for `function main...` starts with current index 0.
proc initParser*(tokens: seq[Token]): Parser =
  Parser(tokens: tokens, current: 0)

## Returns the next parser token without consuming it. Example: statement parsing checks whether the next token is `tkVar` or `tkReturn`.
proc peek*(parser: Parser): Token =
  parser.tokens[parser.current]

## Returns the token most recently consumed by the parser. Example: after consuming `return`, this returns the `tkReturn` token.
proc previous*(parser: Parser): Token =
  parser.tokens[parser.current - 1]

## Tests the next token kind without consuming it. Example: `check(tkVar)` decides whether the next statement is a variable declaration.
proc check*(parser: Parser, kind: TokenKind): bool =
  parser.peek.kind == kind

## Tests a token one position after the current token. Example: an identifier followed by `(` starts a call statement, while one followed by `=` starts assignment.
proc checkNext*(parser: Parser, kind: TokenKind): bool =
  let index = parser.current + 1
  index < parser.tokens.len and parser.tokens[index].kind == kind

## Consumes the current parser token and returns it. Example: consuming `tkPlus` moves expression parsing to the right operand.
proc advance*(parser: var Parser): Token =
  if not parser.check(tkEof):
    inc parser.current
  parser.previous

## Requires a specific next token and consumes it, otherwise reports a syntax error. Example: function declarations require `(` after the function name.
proc consume*(
  parser: var Parser,
  kind: TokenKind,
  message: string
): Token =
  if parser.check(kind):
    return parser.advance()
  failAt(parser.peek.span, message)
