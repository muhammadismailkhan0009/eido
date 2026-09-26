## Owns the CLI build action. Example: reads `app.eido`, runs the compiler pipeline, then asks the Nim toolchain for a native binary.

import ../compiler/pipeline/compiler
import ../compiler/backend/nim/toolchain/compiler as nimCompiler

## Builds one Eido source file into a native executable. Example: `buildFile("main.eido", "bin/main")` compiles that program via the Nim backend.
proc buildFile*(sourcePath, outputPath: string) =
  let source = readFile(sourcePath)
  let nimSource = compileToNim(source)
  nimCompiler.compileWithNim(nimSource, outputPath)
