## Exposes protocol-neutral compiler operations for CLI, MCP, LSP, and other tooling adapters.
## Example: adapters can check or compile a multi-source Eido project without importing parser or semantic internals.

import ../hir/program as hirProgram
import ../project/model
import ../pipeline/compiler
import ../pipeline/project_compiler

## Checks one Eido project through parsing and semantic analysis without backend emission.
## Example: an LSP or MCP client can check a library project that intentionally has no main function.
proc checkProject*(project: EidoProject): hirProgram.HirProgram =
  analyzeProject(project)

## Compiles one Eido project to generated Nim source through the shared project pipeline.
## Example: declarations in main.eido and account.eido are emitted into one backend program.
proc compileProject*(project: EidoProject): string =
  compileProjectToNim(project)

## Compiles one complete anonymous Eido source program through the executable pipeline.
## Example: compileSourceToNim("function main() returns Int { return 1; }") returns generated Nim.
proc compileSourceToNim*(source: string): string =
  compileToNim(source)
