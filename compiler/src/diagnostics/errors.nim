## Creates source-aware compiler failures. Example: an unknown variable can become `unknown local x at 3:9`.

import ../source/span
import formatting

## Raises a compiler error at a `SourceSpan`. Example: an unresolved `x` can report `unknown local x at 3:9`.
proc failAt*(span: SourceSpan, message: string) {.noreturn.} =
  raise newException(ValueError, message & " at " & formatLocation(span))

## Raises a compiler error from explicit line/column numbers. Example: the lexer can report an unexpected `$` at `2:5`.
proc failAt*(line, column: int, message: string) {.noreturn.} =
  raise newException(ValueError, message & " at " & formatLocation(line, column))
