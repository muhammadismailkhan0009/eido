## Exposes protocol-neutral compiler operations for CLI, MCP, LSP, CI, and other tooling adapters.
## Example: adapters can check or compile a multi-source Eido project without parsing human compiler output.

import ../diagnostics/[errors, model]
import ../hir/program as hirProgram
import ../project/model
import ../pipeline/compiler
import ../pipeline/project_compiler

type
  ProjectCheckResult* = object
    success*: bool
    diagnostics*: seq[CompilerDiagnostic]
    program*: hirProgram.HirProgram

## Checks one Eido project through parsing and semantic analysis without backend emission.
## Example: LSP/MCP callers receive structured diagnostics rather than catching compiler text errors.
proc checkProject*(project: EidoProject): ProjectCheckResult =
  try:
    result.program = analyzeProject(project)
    result.success = true
  except CompilerError as error:
    result.success = false
    result.diagnostics.add error.diagnostic

## Requires a semantically valid project and returns its analyzed HIR or raises the original structured compiler error.
## Example: compiler-internal tests that need HIR can use this when failure should remain exceptional.
proc requireCheckedProject*(project: EidoProject): hirProgram.HirProgram =
  analyzeProject(project)

## Compiles one Eido project to generated Nim source through the shared project pipeline.
## Example: declarations in main.eido and account.eido are emitted into one backend program.
proc compileProject*(project: EidoProject): string =
  compileProjectToNim(project)

## Compiles one complete anonymous Eido source program through the executable pipeline.
## Example: compileSourceToNim("function main() returns Int { return 1; }") returns generated Nim.
proc compileSourceToNim*(source: string): string =
  compileToNim(source)
