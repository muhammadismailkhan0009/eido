## Invokes the external Nim compiler on generated Nim source.
## Build tools may choose both the native output and internal generated-source location.

import std/[os, osproc, strutils]
import artifacts
import native_support

## Writes generated Nim and invokes `nim c` to create a native executable.
## Supplying generatedSourcePath lets external build tools isolate backend artifacts.
proc compileWithNim*(
  nimSource,
  outputPath: string,
  generatedSourcePath: string = "",
  memoryMode: string = ""
) =
  let outputDirectory = parentDir(outputPath)
  if outputDirectory.len > 0:
    createDir(outputDirectory)

  let nimPath =
    if generatedSourcePath.len > 0:
      writeGeneratedNimAt(generatedSourcePath, nimSource)
    else:
      writeGeneratedNim(outputPath, nimSource)

  let nimCompiler = getEnv("NIM", "nim")
  var compilerArgs = @["c", "-d:release"]
  if memoryMode.len > 0:
    compilerArgs.add "--mm:" & memoryMode
  compilerArgs.add "--path:" & nativeSupportPath()
  compilerArgs.add "-o:" & outputPath
  compilerArgs.add nimPath

  let process = startProcess(
    nimCompiler,
    args = compilerArgs,
    options = {poUsePath, poStdErrToStdOut}
  )

  let (lines, exitCode) = process.readLines()
  process.close()

  if exitCode != 0:
    raise newException(
      OSError,
      "Nim backend compilation failed:\n" & lines.join("\n")
    )
