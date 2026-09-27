## Formats source locations for diagnostics. Example: line 3 and column 9 become `3:9`.

import ../source/span

## Formats a `SourceSpan` location. Example: a span beginning at line 4, column 7 becomes `4:7`.
proc formatLocation*(span: SourceSpan): string =
  $span.line & ":" & $span.column

## Formats explicit line/column numbers. Example: `formatLocation(4, 7)` returns `4:7`.
proc formatLocation*(line, column: int): string =
  $line & ":" & $column
