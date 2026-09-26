## Compiles and runs complete Eido programs for language-facing feature tests.
## Example: `runNativeSource(source, "two_params")` returns the executable's stdout.

import std/[os, osproc, strutils]
import compiler/pipeline/compiler
import compiler/backend/nim/toolchain/compiler as nimCompiler

## Compiles Eido source through the real Nim backend and returns trimmed stdout.
## Example: a program whose main returns 30 produces `"30"`.
proc runNativeSource*(source: string, caseName: string): string =
  let outputPath =
    getTempDir() / ("eido_feature_" & caseName & "_" & $getCurrentProcessId())
  let generatedPath = outputPath & "_generated.nim"

  defer:
    if fileExists(outputPath):
      removeFile(outputPath)
    if fileExists(generatedPath):
      removeFile(generatedPath)

  nimCompiler.compileWithNim(compileToNim(source), outputPath)
  execProcess(outputPath).strip()
