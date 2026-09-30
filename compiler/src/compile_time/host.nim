## Generic host for compiler-standard Eido compile-time phases.
## A phase is ordinary Eido source compiled to a cached build-machine executable.
## Its private native module receives a per-invocation semantic snapshot.

import std/[hashes, os, osproc, strutils]
import ../backend/nim/emitter/program_emitter
import ../backend/nim/toolchain/compiler as nimCompiler
import ../frontend/parser/project_parser
import ../project/model as projectModel
import ../semantic/analysis/program_analysis
import ../semantic/modules/architecture_validation
import ../source/source_unit

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

## Compiles compiler-owned Eido source without recursively invoking standard
## compile-time phases.
proc lowerPhaseSourceToNim(source: string): string =
  let project = projectModel.initProject(
    projectModel.ptExecutable,
    @[initSourceUnit(0, "<eido-compile-time-phase>", source)]
  )

  var parsed = parseProject(project)
  resolveModuleArchitecture(parsed, project)
  emitNim(analyzeProgram(parsed, project.target))

## Derives a cache fingerprint from one phase source and its private native bridge.
proc phaseFingerprint(source, nativeSupport: string): string =
  $hash(source & "\n" & nativeSupport)

## Builds or reuses one cached build-machine executable for an Eido phase.
proc materializePhaseExecutable(
  phaseName,
  source,
  nativeSupport: string
): string =
  let root = compileTimeCacheRoot()
  let phaseDirectory = root / (phaseName & "-" & phaseFingerprint(source, nativeSupport))
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
    lowerPhaseSourceToNim(source),
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
  source,
  nativeSupport,
  snapshot: string
): seq[string] =
  let executablePath =
    materializePhaseExecutable(phaseName, source, nativeSupport)
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
