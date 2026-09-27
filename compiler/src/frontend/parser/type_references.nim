## Parses recursive declared type references such as Int, Box<User>, and Pair<String, Int>.

import ../../source/span
import ../../diagnostics/errors
import ../lexer/token
import ../ast/type_references
import core

## Parses one recursively nested declared type reference.
## Example: Result<List<User>, Error> produces a Result ref containing two type arguments.
proc parseDeclaredTypeRef*(parser: var Parser): TypeRef =
  if not (
    parser.check(tkPrimitiveType) or
    parser.check(tkStringType) or
    parser.check(tkIdentifier)
  ):
    failAt(parser.peek.span, "expected declared type")

  let typeToken = parser.advance()
  if typeToken.lexeme in ["Long", "Double"]:
    failAt(typeToken.span, "removed numeric type '" & typeToken.lexeme & "'")

  var arguments: seq[TypeRef]
  var endSpan = typeToken.span

  if parser.check(tkLess):
    discard parser.advance()
    if parser.check(tkGreater):
      failAt(parser.peek.span, "generic type arguments cannot be empty")

    while true:
      arguments.add parser.parseDeclaredTypeRef()
      if parser.check(tkComma):
        discard parser.advance()
        continue

      let close = parser.consume(
        tkGreater,
        "expected '>' after generic type arguments"
      )
      endSpan = close.span
      break

  TypeRef(
    span: coverSpan(typeToken.span, endSpan),
    name: typeToken.lexeme,
    arguments: arguments
  )
