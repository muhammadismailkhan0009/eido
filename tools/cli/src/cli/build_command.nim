## Owns the CLI build action. Example: reads `app.eido`, uses the compiler tooling API, then asks the Nim toolchain for a native binary.

import ../../../../compiler/src/tooling/compiler_service
import ../../../../compiler/src/backend/nim/toolchain/compiler as nimCompiler

## Builds one Eido source file into a native executable. Example: `buildFile("main.eido", "bin/main")` compiles that program via the Nim backend.
proc buildFile*(sourcePath, outputPath: string) =
  let source = readFile(sourcePath)
  let nimSource = compileSourceToNim(source)
  nimCompiler.compileWithNim(nimSource, outputPath)
