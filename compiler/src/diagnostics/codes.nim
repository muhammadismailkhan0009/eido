## Defines stable compiler diagnostic codes exposed to CLI, LSP, MCP, CI, and tests.
## Example: EIDO2002 always identifies a missing executable entrypoint.

const
  GenericSourceDiagnosticCode* = "EIDO1000"
  EmptyProjectDiagnosticCode* = "EIDO2001"
  MissingMainDiagnosticCode* = "EIDO2002"
