## Defines machine-readable compiler diagnostics shared by CLI, LSP, MCP, CI, and tests.
## Example: a semantic error can carry code EIDO1000, severity error, message, and src/main.eido span.

import ../source/span

type
  DiagnosticSeverity* = enum
    dsError,
    dsWarning,
    dsInformation,
    dsHint

  CompilerDiagnostic* = object
    code*: string
    severity*: DiagnosticSeverity
    message*: string
    hasSpan*: bool
    span*: SourceSpan

## Creates a source-bound compiler diagnostic.
## Example: unknown function use at src/main.eido:3:5 becomes one error diagnostic with a stable code.
proc initDiagnostic*(
  code: string,
  severity: DiagnosticSeverity,
  message: string,
  span: SourceSpan
): CompilerDiagnostic =
  CompilerDiagnostic(
    code: code,
    severity: severity,
    message: message,
    hasSpan: true,
    span: span
  )

## Creates a project/global diagnostic with no source span.
## Example: an executable project with no main function can still report a stable diagnostic code.
proc initDiagnostic*(
  code: string,
  severity: DiagnosticSeverity,
  message: string
): CompilerDiagnostic =
  CompilerDiagnostic(
    code: code,
    severity: severity,
    message: message,
    hasSpan: false
  )
