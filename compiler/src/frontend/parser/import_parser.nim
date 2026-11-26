## Parses explicit, file-local nominal imports before declarations.
import ../../source/span
import ../../diagnostics/errors
import ../ast/program
import ../lexer/token
import core

## Consumes the leading sequence of explicit nominal imports.
proc parseImports*(parser: var Parser): seq[ImportDecl] =
  while parser.check(tkImport):
    let start = parser.advance()
    var name = parser.consume(tkIdentifier, "expected canonical module path after import")
    var path = name.lexeme
    if not parser.check(tkDot):
      failAt(name.span, "import requires a module-qualified type name")
    while parser.check(tkDot):
      discard parser.advance()
      name = parser.consume(tkIdentifier, "expected identifier in import path")
      path.add "." & name.lexeme
    let finish = parser.consume(tkSemicolon, "expected ';' after import")
    result.add ImportDecl(path: path, span: coverSpan(start.span, finish.span),
      nameSpan: name.span)

## Extracts a source import header for tooling without parsing declaration bodies.
proc parseSourceImports*(tokens: seq[Token]): seq[ImportDecl] =
  var parser = initParser(tokens)
  parser.parseImports()
