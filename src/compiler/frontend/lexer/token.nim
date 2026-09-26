## Defines the token vocabulary produced by lexical analysis.
## Example: `var x = 2.5;` contains `tkVar`, identifier, `tkEqual`, `tkFloat`, and semicolon.

import ../../source/span

type
  TokenKind* = enum
    tkEof,
    tkIdentifier,
    tkInteger,
    tkFloat,
    tkBoolean,
    tkChar,
    tkFunction,
    tkClass,
    tkReturns,
    tkReturn,
    tkVar,
    tkIf,
    tkElse,
    tkWhile,
    tkFor,
    tkBreak,
    tkContinue,
    tkNot,
    tkAnd,
    tkOr,
    tkPrimitiveType,
    tkLParen,
    tkRParen,
    tkLBracket,
    tkRBracket,
    tkLBrace,
    tkRBrace,
    tkSemicolon,
    tkComma,
    tkColon,
    tkEqual,
    tkEqualEqual,
    tkBangEqual,
    tkLess,
    tkLessEqual,
    tkGreater,
    tkGreaterEqual,
    tkPlus,
    tkMinus,
    tkStar,
    tkSlash

  Token* = object
    kind*: TokenKind
    lexeme*: string
    span*: SourceSpan
