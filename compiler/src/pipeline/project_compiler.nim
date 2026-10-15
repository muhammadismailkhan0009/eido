## Composes project-level compiler phases across multiple source units.
## Example: an executable project containing main.eido and account.eido is analyzed as one semantic program.

import ../project/model
import ../source/source_unit
import ../stdlib/builtin_sources
import ../frontend/parser/project_parser
import ../hir/program as hirProgram
import ../hir/string_usage
import ../compile_time/[instrumentation_model, phase_runner, runtime_policy_phase]
import options
import ../compilation/plan
import ../semantic/analysis/program_analysis
import ../semantic/modules/architecture_validation
import ../backend/nim/emitter/program_emitter


## Reports whether one hidden runtime origin is selected for target compilation.
proc runtimeOriginSelected(
  origin: SourceOrigin,
  includeLanguageRuntime, includePolicyRuntime: bool
): bool =
  case origin
  of soOrdinary:
    true
  of soLanguageRuntime:
    includeLanguageRuntime
  of soCompilerRuntime:
    includePolicyRuntime

## Filters hidden runtime sources without exposing their implementation class names.
proc selectRuntimeSources(
  project: EidoProject,
  includeLanguageRuntime, includePolicyRuntime: bool
): EidoProject =
  result = project
  var excludedPaths: seq[string]
  result.sources = @[]
  for source in project.sources:
    if runtimeOriginSelected(
      source.origin, includeLanguageRuntime, includePolicyRuntime
    ):
      result.sources.add source
    else:
      excludedPaths.add source.path

  for moduleIndex in 0 ..< result.modules.len:
    var filtered: seq[string]
    for sourcePath in result.modules[moduleIndex].sourcePaths:
      if sourcePath notin excludedPaths:
        filtered.add sourcePath
    result.modules[moduleIndex].sourcePaths = filtered

## Adds selected hidden SDK runtime sources when raw source projects do not carry them.
proc withSelectedRuntime(
  project: EidoProject,
  includeLanguageRuntime, includePolicyRuntime: bool
): EidoProject =
  result = selectRuntimeSources(
    project, includeLanguageRuntime, includePolicyRuntime
  )

  var nextSourceId = 0
  var existingPaths: seq[string]
  for source in result.sources:
    nextSourceId = max(nextSourceId, source.id.value + 1)
    existingPaths.add source.path

  let sdk = builtinStdlibProject(ptLibrary)
  for sdkSource in sdk.sources:
    if sdkSource.origin == soOrdinary or
        not runtimeOriginSelected(
          sdkSource.origin, includeLanguageRuntime, includePolicyRuntime
        ) or sdkSource.path in existingPaths:
      continue

    result.sources.add initSourceUnit(
      nextSourceId,
      sdkSource.path,
      sdkSource.text,
      sdkSource.moduleName,
      sdkSource.origin
    )
    inc nextSourceId
    existingPaths.add sdkSource.path

    for moduleIndex in 0 ..< result.modules.len:
      if result.modules[moduleIndex].canonicalName == sdkSource.moduleName:
        result.modules[moduleIndex].sourcePaths.add sdkSource.path
        break

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
  let baseProject = project.selectRuntimeSources(false, false)
  let baseProgram = analyzeProject(baseProject)
  let memoryMetadata = runStandardCompileTimePhases(
    baseProgram,
    options.memoryStrategy
  )
  let needsLanguageRuntime = baseProgram.usesString
  let needsPolicyRuntime =
    options.memoryStrategy == msGc and memoryMetadata.types.len > 0

  if needsLanguageRuntime or needsPolicyRuntime:
    let runtimeProject = project.withSelectedRuntime(
      needsLanguageRuntime, needsPolicyRuntime
    )
    let runtimeProgram = analyzeProject(runtimeProject)
    let instrumentation =
      if needsPolicyRuntime:
        runRuntimePolicyPhase(options.memoryStrategy)
      else:
        CompileTimeInstrumentationPlan()
    return emitNim(
      runtimeProgram,
      CompilationPlan(
        memory: memoryMetadata,
        instrumentation: instrumentation
      )
    )

  emitNim(baseProgram, CompilationPlan(memory: memoryMetadata))
