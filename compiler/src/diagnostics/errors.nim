## Creates source-aware compiler failures.
## Example: an unknown variable can become `unknown local x at src/main.eido:3:9`.

import ../source/span
import formatting

## Raises a compiler error at a SourceSpan.
## Example: an unresolved `x` reports its source file, line, and column when known.
proc failAt*(span: SourceSpan, message: string) {.noreturn.} =
  raise newException(ValueError, message & " at " & formatLocation(span))

## Raises a compiler error from explicit line/column numbers.
## Example: legacy in-memory lexing can report an unexpected `$` at `2:5`.
proc failAt*(line, column: int, message: string) {.noreturn.} =
  raise newException(ValueError, message & " at " & formatLocation(line, column))

## Raises a compiler error from explicit source-path, line, and column coordinates.
## Example: lexing account.eido can report an unexpected character at `src/account.eido:2:5`.
proc failAt*(sourcePath: string, line, column: int, message: string) {.noreturn.} =
  raise newException(
    ValueError,
    message & " at " & formatLocation(sourcePath, line, column)
  )
