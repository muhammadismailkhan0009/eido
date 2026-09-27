## Composes project-level compiler phases across multiple source units.
## Example: an executable project containing main.eido and account.eido is analyzed as one semantic program.

import ../project/model
import ../frontend/parser/project_parser
import ../hir/program as hirProgram
import ../semantic/analysis/program_analysis
import ../backend/nim/emitter/program_emitter

## Analyzes every source in one Eido project into resolved typed HIR.
## Example: a function in service.eido can resolve a class declared in account.eido.
proc analyzeProject*(project: EidoProject): hirProgram.HirProgram =
  analyzeProgram(parseProject(project), project.target)

## Compiles one Eido project through semantic analysis to generated Nim source.
## Example: an executable project emits one Nim program containing declarations from all supplied Eido files.
proc compileProjectToNim*(project: EidoProject): string =
  emitNim(analyzeProject(project))
