## Composes project-level compiler phases across multiple source units.
## Example: an executable project containing main.eido and account.eido is analyzed as one semantic program.

import ../project/model
import ../source/source_unit
import ../stdlib/builtin_sources
import ../frontend/parser/project_parser
import ../hir/program as hirProgram
import ../compile_time/phase_runner
import options
import ../compilation/plan
import ../semantic/analysis/program_analysis
import ../semantic/modules/architecture_validation
import ../backend/nim/emitter/program_emitter


## Reports whether one source path belongs to compiler-private Eido GC runtime code.
proc isManagedGcRuntimeSource(path: string): bool =
  path == BuiltinManagedGcNativeSourcePath or
    path == BuiltinManagedGcRuntimeSourcePath

## Removes compiler-private GC runtime sources while retaining their manifest ownership.
## This lets the compiler decide whether target runtime code is needed after planning.
proc withoutManagedGcRuntime(project: EidoProject): EidoProject =
  result = project
  result.sources = @[]
  for source in project.sources:
    if not source.path.isManagedGcRuntimeSource:
      result.sources.add source

  for moduleIndex in 0 ..< result.modules.len:
    var filtered: seq[string]
    for sourcePath in result.modules[moduleIndex].sourcePaths:
      if not sourcePath.isManagedGcRuntimeSource:
        filtered.add sourcePath
    result.modules[moduleIndex].sourcePaths = filtered

## Adds compiler-private Eido GC runtime sources only after planning proves they are needed.
proc withManagedGcRuntime(project: EidoProject): EidoProject =
  result = withoutManagedGcRuntime(project)

  var runtimeModule = ""
  if result.modules.len > 0:
    runtimeModule = BuiltinStdlibModuleName
    var foundStdlib = false
    for moduleIndex in 0 ..< result.modules.len:
      if result.modules[moduleIndex].canonicalName == BuiltinStdlibModuleName:
        result.modules[moduleIndex].sourcePaths.add(
          BuiltinManagedGcNativeSourcePath
        )
        result.modules[moduleIndex].sourcePaths.add(
          BuiltinManagedGcRuntimeSourcePath
        )
        foundStdlib = true
        break
    if not foundStdlib:
      raise newException(
        ValueError,
        "compiler invariant: managed GC runtime requires eido.stdlib module"
      )

  var nextId = result.sources.len
  result.sources.add initSourceUnit(
    nextId,
    BuiltinManagedGcNativeSourcePath,
    BuiltinManagedGcNativeSource,
    runtimeModule
  )
  inc nextId
  result.sources.add initSourceUnit(
    nextId,
    BuiltinManagedGcRuntimeSourcePath,
    BuiltinManagedGcRuntimeSource,
    runtimeModule
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
  let baseProject = withoutManagedGcRuntime(project)
  let baseProgram = analyzeProject(baseProject)
  let baseMemoryPlan = runStandardCompileTimePhases(
    baseProgram,
    options.memoryStrategy
  )

  if options.memoryStrategy == msGc and baseMemoryPlan.types.len > 0:
    let runtimeProject = withManagedGcRuntime(baseProject)
    let runtimeProgram = analyzeProject(runtimeProject)
    let runtimeMemoryPlan = runStandardCompileTimePhases(
      runtimeProgram,
      options.memoryStrategy
    )
    return emitNim(
      runtimeProgram,
      CompilationPlan(memory: runtimeMemoryPlan)
    )

  emitNim(baseProgram, CompilationPlan(memory: baseMemoryPlan))
