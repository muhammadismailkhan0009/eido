## Parses the top-level sequence of functions into one program AST. Example: `main` plus `add` becomes a program containing two functions.

import ../../diagnostics/errors
import ../lexer/token
import ../ast/program
import core
import declaration_parser

## Parses all top-level functions into one program AST. Example: source containing `main` and `add` yields two function declarations.
proc parseProgram*(tokens: seq[Token]): Program =
  var parser = initParser(tokens)

  while not parser.check(tkEof):
    result.functions.add parser.parseFunction()

  if result.functions.len == 0:
    failAt(parser.peek.span, "expected at least one function")
