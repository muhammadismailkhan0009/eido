## Invokes the external Nim compiler on generated Nim source. Example: generated `app_generated.nim` is compiled into native `app`.

import std/[os, osproc, strutils]
import artifacts

## Writes generated Nim and invokes `nim c` to create a native executable. Example: Nim source for output `bin/app` is compiled into `bin/app`.
proc compileWithNim*(nimSource, outputPath: string) =
  let nimPath = writeGeneratedNim(outputPath, nimSource)
  let nimCompiler = getEnv("NIM", "nim")
  let process = startProcess(
    nimCompiler,
    args = ["c", "-d:release", "-o:" & outputPath, nimPath],
    options = {poUsePath, poStdErrToStdOut}
  )

  let (lines, exitCode) = process.readLines()
  process.close()

  if exitCode != 0:
    raise newException(
      OSError,
      "Nim backend compilation failed:\n" & lines.join("\n")
    )
