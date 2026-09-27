## Parses top-level class and function declarations into one program AST.

import ../../diagnostics/errors
import ../lexer/token
import ../ast/program
import core
import declaration_parser

## Parses all supported top-level declarations.
proc parseProgram*(tokens: seq[Token]): Program =
  var parser = initParser(tokens)

  while not parser.check(tkEof):
    if parser.check(tkClass):
      result.classes.add parser.parseClass()
    elif parser.check(tkNative):
      result.functions.add parser.parseNativeFunction()
    elif parser.check(tkFunction):
      result.functions.add parser.parseFunction()
    else:
      failAt(
        parser.peek.span,
        "expected top-level class, function, or native function declaration"
      )

  if result.classes.len == 0 and result.functions.len == 0:
    failAt(parser.peek.span, "expected at least one declaration")
