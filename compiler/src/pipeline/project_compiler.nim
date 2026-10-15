## Composes project-level compiler phases across multiple source units.
## Example: an executable project containing main.eido and account.eido is analyzed as one semantic program.

import ../project/model
import ../source/source_unit
import ../stdlib/builtin_sources
import ../frontend/parser/project_parser
import ../hir/program as hirProgram
import ../compile_time/[phase_runner, runtime_policy_phase]
import options
import ../compilation/plan
import ../semantic/analysis/program_analysis
import ../semantic/modules/architecture_validation
import ../backend/nim/emitter/program_emitter


## Removes compiler-private runtime sources while retaining their manifest ownership.
## Planning sees only ordinary program declarations; target compilation may reuse the
## original project when the selected strategy requires its hidden runtime sources.
proc withoutCompilerRuntime(project: EidoProject): EidoProject =
  result = project
  var runtimePaths: seq[string]
  result.sources = @[]
  for source in project.sources:
    if source.origin == soCompilerRuntime:
      runtimePaths.add source.path
    else:
      result.sources.add source

  for moduleIndex in 0 ..< result.modules.len:
    var filtered: seq[string]
    for sourcePath in result.modules[moduleIndex].sourcePaths:
      if sourcePath notin runtimePaths:
        filtered.add sourcePath
    result.modules[moduleIndex].sourcePaths = filtered

## Adds every SDK source tagged as compiler-runtime when a raw source project lacks them.
## This is source-origin based: the compiler does not know runtime filenames or classes.
proc withCompilerRuntime(project: EidoProject): EidoProject =
  for source in project.sources:
    if source.origin == soCompilerRuntime:
      return project

  # Module-aware projects normally receive the SDK during module loading. Raw
  # source projects used by standalone compilation/tests need the hidden runtime
  # sources attached explicitly, without importing public stdlib declarations.
  result = project
  let sdk = builtinStdlibProject(ptLibrary)
  for sdkSource in sdk.sources:
    if sdkSource.origin != soCompilerRuntime:
      continue
    result.sources.add initSourceUnit(
      result.sources.len,
      sdkSource.path,
      sdkSource.text,
      sdkSource.moduleName,
      sdkSource.origin
    )

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
  let baseProject = withoutCompilerRuntime(project)
  let baseProgram = analyzeProject(baseProject)
  let memoryMetadata = runStandardCompileTimePhases(
    baseProgram,
    options.memoryStrategy
  )

  # Strategy selection controls which Eido memory runtime is present. Generic
  # compiler metadata itself is computed once from the ordinary program only.
  if options.memoryStrategy == msGc and memoryMetadata.types.len > 0:
    let runtimeProgram = analyzeProject(project.withCompilerRuntime)
    let instrumentation = runRuntimePolicyPhase(options.memoryStrategy)
    return emitNim(
      runtimeProgram,
      CompilationPlan(
        memory: memoryMetadata,
        instrumentation: instrumentation
      )
    )

  emitNim(
    baseProgram,
    CompilationPlan(memory: memoryMetadata)
  )
