## Composes project-level compiler phases across multiple source units.
## Example: an executable project containing main.eido and account.eido is analyzed as one semantic program.

import ../project/model
import ../project/modules/model as moduleModel
import ../source/source_unit
import ../stdlib/builtin_sources
import ../frontend/parser/project_parser
import ../hir/program as hirProgram
import ../hir/[copy_usage, string_usage]
import ../compile_time/[instrumentation_model, phase_runner, runtime_policy_phase]
import options
import ../compilation/plan
import ../semantic/analysis/program_analysis
import ../semantic/modules/architecture_validation
import ../backend/nim/emitter/program_emitter


## Reports whether one hidden runtime source is selected for target compilation.
proc runtimeSourceSelected(
  source: SourceUnit,
  languageCapabilities: set[LanguageRuntimeCapability],
  memoryPolicyModule: string
): bool =
  case source.origin
  of soOrdinary:
    true
  of soLanguageRuntime:
    source.runtimeCapability in languageCapabilities
  of soMemoryPolicyRuntime:
    memoryPolicyModule.len > 0 and source.moduleName == memoryPolicyModule

## Filters hidden runtime sources without exposing implementation classes or algorithms.
proc selectRuntimeSources(
  project: EidoProject,
  languageCapabilities: set[LanguageRuntimeCapability],
  memoryPolicyModule: string
): EidoProject =
  result = project
  var excludedPaths: seq[string]
  result.sources = @[]
  for source in project.sources:
    if runtimeSourceSelected(source, languageCapabilities, memoryPolicyModule):
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
  languageCapabilities: set[LanguageRuntimeCapability],
  memoryPolicyModule: string
): EidoProject =
  result = selectRuntimeSources(
    project, languageCapabilities, memoryPolicyModule
  )

  var nextSourceId = 0
  var existingPaths: seq[string]
  for source in result.sources:
    nextSourceId = max(nextSourceId, source.id.value + 1)
    existingPaths.add source.path

  let sdk = builtinStdlibProject(ptLibrary)
  for sdkSource in sdk.sources:
    if sdkSource.origin == soOrdinary or
        not runtimeSourceSelected(
          sdkSource, languageCapabilities, memoryPolicyModule
        ) or sdkSource.path in existingPaths:
      continue

    result.sources.add initSourceUnit(
      nextSourceId,
      sdkSource.path,
      sdkSource.text,
      sdkSource.moduleName,
      sdkSource.origin,
      sdkSource.runtimeCapability
    )
    inc nextSourceId
    existingPaths.add sdkSource.path

    for moduleIndex in 0 ..< result.modules.len:
      if result.modules[moduleIndex].canonicalName == sdkSource.moduleName:
        result.modules[moduleIndex].sourcePaths.add sdkSource.path
        break

## Resolves one selected memory-policy module from the project or installed SDK.
proc resolveMemoryPolicyModule(
  project: EidoProject,
  selection: MemoryPolicySelection
): moduleModel.ModuleSpec =
  if not selection.isSelected:
    return moduleModel.ModuleSpec()

  var matches: seq[moduleModel.ModuleSpec]
  for moduleSpec in project.modules:
    if moduleSpec.canonicalName == selection.moduleName or
        ('.' notin selection.moduleName and moduleSpec.name == selection.moduleName):
      matches.add moduleSpec

  if matches.len == 0:
    let sdk = builtinStdlibProject(ptLibrary)
    for moduleSpec in sdk.modules:
      if moduleSpec.canonicalName == selection.moduleName or
          ('.' notin selection.moduleName and moduleSpec.name == selection.moduleName):
        matches.add moduleSpec

  if matches.len == 0:
    raise newException(
      ValueError,
      "unknown memory policy module '" & selection.moduleName & "'"
    )
  if matches.len > 1:
    raise newException(
      ValueError,
      "ambiguous memory policy module '" & selection.moduleName &
        "'; use its canonical module name"
    )

  result = matches[0]
  if result.policySources.len == 0:
    raise newException(
      ValueError,
      "module '" & result.canonicalName & "' is not a memory policy module"
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
  let policyModule = resolveMemoryPolicyModule(project, options.memoryPolicy)
  let selectedPolicyName =
    if options.memoryPolicy.isSelected: policyModule.canonicalName else: ""
  let baseProject = project.selectRuntimeSources({}, "")
  let baseProgram = analyzeProject(baseProject)
  let memoryMetadata = runStandardCompileTimePhases(
    baseProgram,
    options.memoryPolicy
  )
  var languageCapabilities: set[LanguageRuntimeCapability]
  if baseProgram.usesString:
    languageCapabilities.incl lrcString
  if baseProgram.usesClassCopy:
    languageCapabilities.incl lrcClassCopy
  let needsPolicyRuntime =
    options.memoryPolicy.isSelected and memoryMetadata.types.len > 0

  if languageCapabilities != {} or needsPolicyRuntime:
    let runtimeProject = project.withSelectedRuntime(
      languageCapabilities,
      if needsPolicyRuntime: selectedPolicyName else: ""
    )
    let runtimeProgram = analyzeProject(runtimeProject)
    let instrumentation =
      if needsPolicyRuntime:
        runRuntimePolicyPhase(baseProgram, policyModule)
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
