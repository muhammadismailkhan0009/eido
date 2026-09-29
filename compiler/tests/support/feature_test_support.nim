## Executes generated Nim through the Nim VM for language-facing feature tests.
## Native code generation itself stays covered by the dedicated compiler pipeline tests.

import std/[os, osproc, strutils]
import pipeline/compiler
import backend/nim/toolchain/native_support
import backend/nim/toolchain/compiler as nimCompiler

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
    args = [
      "e",
      "--hints:off",
      "--warnings:off",
      "--path:" & nativeSupportPath(),
      generatedPath
    ],
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

## Runs an Eido feature through real native Nim compilation.
## Raw runtime features such as manual Storage allocation cannot execute in Nim's VM.
proc runNativeFeatureSource*(source: string, caseName: string): string =
  let outputPath =
    getTempDir() / ("eido_feature_native_" & caseName & "_" & $getCurrentProcessId())
  let generatedPath = outputPath & "_generated.nim"

  defer:
    if fileExists(outputPath):
      removeFile(outputPath)
    if fileExists(generatedPath):
      removeFile(generatedPath)

  nimCompiler.compileWithNim(compileToNim(source), outputPath)
  execProcess(outputPath).strip()

## Runs an Eido native feature expected to fail and returns its process result.
proc runFailingNativeFeatureSource*(
  source: string,
  caseName: string
): tuple[output: string, exitCode: int] =
  let outputPath =
    getTempDir() / ("eido_feature_native_" & caseName & "_" & $getCurrentProcessId())
  let generatedPath = outputPath & "_generated.nim"

  defer:
    if fileExists(outputPath):
      removeFile(outputPath)
    if fileExists(generatedPath):
      removeFile(generatedPath)

  nimCompiler.compileWithNim(compileToNim(source), outputPath)
  execCmdEx(outputPath)
