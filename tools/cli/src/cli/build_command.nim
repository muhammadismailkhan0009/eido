## Owns CLI executable-project builds through the protocol-neutral compiler tooling API.
## Example: main.eido and account.eido are loaded as one project before native compilation.

import ../../../../compiler/src/project/model
import ../../../../compiler/src/project/modules/loader
import ../../../../compiler/src/source/source_unit
import ../../../../compiler/src/tooling/compiler_service
import ../../../../compiler/src/backend/nim/toolchain/compiler as nimCompiler

## Builds multiple Eido source files as one executable project.
## Example: `buildFiles(@["main.eido", "account.eido"], "app")` resolves declarations across both files.
proc buildFiles*(sourcePaths: seq[string], outputPath: string) =
  var sources: seq[SourceUnit]
  for index, sourcePath in sourcePaths:
    sources.add initSourceUnit(index, sourcePath, readFile(sourcePath))

  let nimSource = compileProject(initProject(ptExecutable, sources))
  nimCompiler.compileWithNim(nimSource, outputPath)

## Builds a normal Eido project from its mandatory module.yaml architecture root.
proc buildModuleFile*(manifestPath, outputPath: string) =
  let project = loadModuleProject(manifestPath, ptExecutable)
  let nimSource = compileProject(project)
  nimCompiler.compileWithNim(nimSource, outputPath)

## Preserves the one-file bootstrap convenience API for compiler/internal tests.
proc buildFile*(sourcePath, outputPath: string) =
  buildFiles(@[sourcePath], outputPath)
