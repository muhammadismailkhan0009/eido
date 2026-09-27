## Formats source locations and structured diagnostics for human-facing adapters.
## Example: a source diagnostic renders as `src/main.eido:3:9 error EIDO1000: unknown function 'broken'`.

import ../source/span
import model

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

## Returns the stable human-readable name of one diagnostic severity.
## Example: dsError renders as `error`.
proc severityName*(severity: DiagnosticSeverity): string =
  case severity
  of dsError: "error"
  of dsWarning: "warning"
  of dsInformation: "information"
  of dsHint: "hint"

## Renders one structured diagnostic for CLI or logs without discarding machine-readable fields.
## Example: a span-bound EIDO1000 error includes path, line, column, severity, code, and message.
proc formatDiagnostic*(diagnostic: CompilerDiagnostic): string =
  let body =
    severityName(diagnostic.severity) & " " & diagnostic.code & ": " &
    diagnostic.message
  if diagnostic.hasSpan:
    formatLocation(diagnostic.span) & " " & body
  else:
    body
