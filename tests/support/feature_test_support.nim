## Executes generated Nim through the Nim VM for language-facing feature tests.
## Native code generation itself stays covered by the dedicated compiler pipeline tests.

import std/[os, osproc, strutils]
import compiler/pipeline/compiler

## Runs a complete Eido program through all pure compiler phases, then executes
## the emitted Nim with `nim e`. Example: a main returning 30 produces "30".
proc runFeatureSource*(source: string, caseName: string): string =
  let generatedPath =
    getTempDir() / ("eido_feature_" & caseName & "_" & $getCurrentProcessId() & ".nim")

  defer:
    if fileExists(generatedPath):
      removeFile(generatedPath)

  writeFile(generatedPath, compileToNim(source))

  let nimCompiler = getEnv("NIM", "nim")
  let process = startProcess(
    nimCompiler,
    args = ["e", "--hints:off", "--warnings:off", generatedPath],
    options = {poUsePath, poStdErrToStdOut}
  )
  let (lines, exitCode) = process.readLines()
  process.close()

  if exitCode != 0:
    raise newException(
      OSError,
      "Nim VM feature execution failed:\n" & lines.join("\n")
    )

  lines.join("\n").strip()
