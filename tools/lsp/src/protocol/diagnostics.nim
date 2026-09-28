## Converts compiler diagnostics into LSP diagnostics.

import std/json
import ../../../../compiler/src/diagnostics/model
import positions

## Converts a compiler severity to the LSP DiagnosticSeverity integer.
proc lspSeverity*(severity: DiagnosticSeverity): int =
  case severity
  of dsError: 1
  of dsWarning: 2
  of dsInformation: 3
  of dsHint: 4

## Converts one structured compiler diagnostic to an LSP diagnostic.
proc compilerDiagnosticToLsp*(
  diagnostic: CompilerDiagnostic,
  sourceText: string
): JsonNode =
  let diagnosticRange =
    if diagnostic.hasSpan:
      lspRange(
        sourceText,
        diagnostic.span.startOffset,
        diagnostic.span.endOffset
      )
    else:
      lspRange(sourceText, 0, 1)

  %*{
    "range": diagnosticRange,
    "severity": lspSeverity(diagnostic.severity),
    "code": diagnostic.code,
    "source": "eido",
    "message": diagnostic.message
  }

## Builds one publishDiagnostics notification.
proc publishDiagnostics*(
  uri: string,
  diagnostics: seq[JsonNode]
): JsonNode =
  var diagnosticArray = newJArray()
  for diagnostic in diagnostics:
    diagnosticArray.add diagnostic

  %*{
    "jsonrpc": "2.0",
    "method": "textDocument/publishDiagnostics",
    "params": {
      "uri": uri,
      "diagnostics": diagnosticArray
    }
  }
