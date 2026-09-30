## Composes project-level compiler phases across multiple source units.
## Example: an executable project containing main.eido and account.eido is analyzed as one semantic program.

import ../project/model
import ../frontend/parser/project_parser
import ../hir/program as hirProgram
import ../compile_time/phase_runner
import options
import ../semantic/analysis/program_analysis
import ../semantic/modules/architecture_validation
import ../backend/nim/emitter/program_emitter

## Analyzes every source in one Eido project into resolved typed HIR.
## Example: a function in service.eido can resolve a class declared in account.eido.
proc analyzeProject*(project: EidoProject): hirProgram.HirProgram =
  var parsed = parseProject(project)
  resolveModuleArchitecture(parsed, project)
  analyzeProgram(parsed, project.target)

## Compiles one Eido project through semantic analysis to generated Nim source.
## Example: an executable project emits one Nim program containing declarations from all supplied Eido files.
proc compileProjectToNim*(
  project: EidoProject,
  options: CompilationOptions = DefaultCompilationOptions
): string =
  let program = analyzeProject(project)
  discard runStandardCompileTimePhases(program, options.memoryStrategy)
  emitNim(program)
