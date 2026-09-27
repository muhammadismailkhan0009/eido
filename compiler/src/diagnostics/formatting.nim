## Formats source locations for diagnostics.
## Example: a span in `src/main.eido` at line 3, column 9 becomes `src/main.eido:3:9`.

import ../source/span

## Formats a SourceSpan using its file identity when available.
## Example: an in-memory span without a path remains `4:7` for compatibility.
proc formatLocation*(span: SourceSpan): string =
  let location = $span.line & ":" & $span.column
  if span.sourcePath.len == 0:
    location
  else:
    span.sourcePath & ":" & location

## Formats explicit line/column numbers without a source path.
## Example: `formatLocation(4, 7)` returns `4:7`.
proc formatLocation*(line, column: int): string =
  $line & ":" & $column

## Formats explicit source-path, line, and column coordinates.
## Example: `formatLocation("main.eido", 4, 7)` returns `main.eido:4:7`.
proc formatLocation*(sourcePath: string, line, column: int): string =
  if sourcePath.len == 0:
    formatLocation(line, column)
  else:
    sourcePath & ":" & formatLocation(line, column)
