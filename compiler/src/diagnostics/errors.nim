## Creates structured source-aware compiler failures while preserving ValueError compatibility.
## Example: semantic code raises CompilerError while tooling reads the embedded CompilerDiagnostic directly.

import ../source/[source_unit, span]
import codes
import model
import formatting

type
  CompilerError* = object of ValueError
    diagnostic*: CompilerDiagnostic

## Raises one structured compiler diagnostic as a ValueError-compatible exception.
## Example: existing semantic tests can still expect ValueError while tooling consumes error.diagnostic.
proc raiseDiagnostic*(diagnostic: CompilerDiagnostic) {.noreturn.} =
  let error = newException(CompilerError, formatDiagnostic(diagnostic))
  error.diagnostic = diagnostic
  raise error

## Raises a source-bound compiler error at a SourceSpan.
## Example: an unresolved `x` reports source file, line, column, code, severity, and message.
proc failAt*(
  span: SourceSpan,
  message: string,
  code: string = GenericSourceDiagnosticCode
) {.noreturn.} =
  raiseDiagnostic(initDiagnostic(code, dsError, message, span))

## Raises a compiler error from explicit line/column numbers.
## Example: anonymous in-memory lexing can still report an unexpected character at `2:5`.
proc failAt*(
  line, column: int,
  message: string,
  code: string = GenericSourceDiagnosticCode
) {.noreturn.} =
  failAt(
    initSourceSpan(SourceId(-1), "", 0, 0, line, column),
    message,
    code
  )

## Raises a compiler error from explicit source-path, line, and column coordinates.
## Example: lexing account.eido can report an invalid character at `src/account.eido:2:5`.
proc failAt*(
  sourcePath: string,
  line, column: int,
  message: string,
  code: string = GenericSourceDiagnosticCode
) {.noreturn.} =
  failAt(
    initSourceSpan(SourceId(-1), sourcePath, 0, 0, line, column),
    message,
    code
  )

## Raises a project/global diagnostic without a source span.
## Example: an executable project with no main uses EIDO2002.
proc fail*(code, message: string) {.noreturn.} =
  raiseDiagnostic(initDiagnostic(code, dsError, message))
