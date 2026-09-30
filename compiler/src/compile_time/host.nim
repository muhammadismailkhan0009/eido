## Generic host for compiler-standard Eido compile-time phases.
## A phase is ordinary Eido source compiled to a cached build-machine executable.
## Its private native module receives a per-invocation semantic snapshot.

import std/[hashes, os, osproc, sets, strutils]
import ../backend/nim/emitter/program_emitter
import ../backend/nim/toolchain/compiler as nimCompiler
import ../frontend/parser/project_parser
import ../project/model as projectModel
import ../project/modules/[manifest_parser]
import ../project/modules/model as moduleModel
import ../semantic/analysis/program_analysis
import ../semantic/modules/architecture_validation
import ../source/source_unit

type
  CompileTimePhaseSource* = object
    ## Manifest-relative source entry and compiler-owned source text.
    entry*: string
    text*: string

## Ensures one compiler cache directory exists before phase artifacts are written.
proc ensureDirectory(path: string) =
  if not dirExists(path):
    createDir(path)

## Returns the shared cache root for compiler-standard Eido phase artifacts.
proc compileTimeCacheRoot(): string =
  let root = getCacheDir("eido")
  ensureDirectory(root)
  result = root / "compile-time"
  ensureDirectory(result)

## Compiles one compiler-owned Eido phase module without recursively invoking
## standard compile-time phases.
proc lowerPhaseModuleToNim(
  phaseName,
  manifestSource: string,
  phaseSources: seq[CompileTimePhaseSource]
): string =
  let manifestPath =
    "<eido-compile-time>/" & phaseName & "/module.yaml"
  let manifest = parseModuleManifest(manifestSource, manifestPath)

  if manifest.children.len > 0 or
      manifest.dependencies.len > 0 or
      manifest.provides.len > 0 or
      manifest.adopts.len > 0 or
      manifest.exports.len > 0:
    raise newException(
      ValueError,
      "compiler-standard Eido phase modules must remain private and self-contained"
    )

  if manifest.sources.len != phaseSources.len:
    raise newException(
      ValueError,
      "compiler-standard Eido phase source set does not match its module manifest"
    )

  let canonicalName = "eido.compile_time." & manifest.name
  let phaseDirectory = "<eido-compile-time>/" & phaseName
  var sourceUnits: seq[SourceUnit]
  var sourcePaths: seq[string]
  var seenEntries = initHashSet[string]()

  for sourceEntry in manifest.sources:
    var found = false
    for phaseSource in phaseSources:
      if phaseSource.entry != sourceEntry:
        continue
      if sourceEntry in seenEntries:
        raise newException(
          ValueError,
          "compiler-standard Eido phase source is declared more than once: " &
            sourceEntry
        )

      seenEntries.incl sourceEntry
      let sourcePath = phaseDirectory & "/" & sourceEntry
      sourcePaths.add sourcePath
      sourceUnits.add initSourceUnit(
        sourceUnits.len,
        sourcePath,
        phaseSource.text,
        canonicalName
      )
      found = true
      break

    if not found:
      raise newException(
        ValueError,
        "compiler-standard Eido phase manifest references missing source '" &
          sourceEntry & "'"
      )

  let phaseModule = moduleModel.ModuleSpec(
    name: manifest.name,
    canonicalName: canonicalName,
    parentName: "",
    manifestPath: manifestPath,
    directory: phaseDirectory,
    sourcePaths: sourcePaths,
    children: @[],
    dependencies: @[],
    exports: @[],
    provides: @[],
    adopts: @[]
  )
  let project = projectModel.initModuleProject(
    projectModel.ptExecutable,
    sourceUnits,
    @[phaseModule],
    canonicalName
  )

  var parsed = parseProject(project)
  resolveModuleArchitecture(parsed, project)
  emitNim(analyzeProgram(parsed, project.target))

## Derives a cache fingerprint from one phase module and its private native bridge.
proc phaseFingerprint(
  manifestSource: string,
  phaseSources: seq[CompileTimePhaseSource],
  nativeSupport: string
): string =
  var content = manifestSource
  for phaseSource in phaseSources:
    content.add "\n" & phaseSource.entry & "\n" & phaseSource.text
  $hash(content & "\n" & nativeSupport)

## Builds or reuses one cached build-machine executable for an Eido phase.
proc materializePhaseExecutable(
  phaseName,
  manifestSource,
  nativeSupport: string,
  phaseSources: seq[CompileTimePhaseSource]
): string =
  let root = compileTimeCacheRoot()
  let fingerprint = phaseFingerprint(
    manifestSource,
    phaseSources,
    nativeSupport
  )
  let phaseDirectory = root / (phaseName & "-" & fingerprint)
  ensureDirectory(phaseDirectory)

  let supportDirectory = phaseDirectory / "native"
  ensureDirectory(supportDirectory)

  let supportPath = supportDirectory / "eido_native.nim"
  if not fileExists(supportPath) or readFile(supportPath) != nativeSupport:
    writeFile(supportPath, nativeSupport)

  let executablePath = phaseDirectory / (phaseName & "-phase")
  if fileExists(executablePath):
    return executablePath

  # Multiple compiler processes may populate one cache entry concurrently.
  # Each builds a process-local artifact and atomically renames the final binary.
  let suffix = $getCurrentProcessId()
  let temporaryExecutable = executablePath & "." & suffix
  let generatedSource = phaseDirectory / (phaseName & "_phase_" & suffix & ".nim")

  nimCompiler.compileWithNim(
    lowerPhaseModuleToNim(phaseName, manifestSource, phaseSources),
    temporaryExecutable,
    generatedSource,
    additionalImportPaths = @[supportDirectory]
  )

  try:
    moveFile(temporaryExecutable, executablePath)
  except OSError:
    if fileExists(executablePath):
      if fileExists(temporaryExecutable):
        removeFile(temporaryExecutable)
    else:
      raise

  if fileExists(generatedSource):
    removeFile(generatedSource)

  executablePath

## Runs one private compile-time Eido phase and returns its protocol output.
proc runCompileTimeEidoPhase*(
  phaseName,
  manifestSource,
  nativeSupport,
  snapshot: string,
  phaseSources: seq[CompileTimePhaseSource]
): seq[string] =
  let executablePath =
    materializePhaseExecutable(
      phaseName,
      manifestSource,
      nativeSupport,
      phaseSources
    )
  let invocationDirectory = compileTimeCacheRoot() / "invocations"
  ensureDirectory(invocationDirectory)

  let snapshotPath =
    invocationDirectory / (phaseName & "-" & $getCurrentProcessId() & ".json")
  writeFile(snapshotPath, snapshot)

  let process = startProcess(
    executablePath,
    args = @[snapshotPath],
    options = {poUsePath, poStdErrToStdOut}
  )
  let (lines, exitCode) = process.readLines()
  process.close()

  if fileExists(snapshotPath):
    removeFile(snapshotPath)

  if exitCode != 0:
    raise newException(
      OSError,
      "compiler-standard Eido phase '" & phaseName & "' failed:\n" &
        lines.join("\n")
    )

  lines
