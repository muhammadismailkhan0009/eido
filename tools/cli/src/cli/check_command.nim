## Owns CLI semantic checking without backend emission or native compilation.
## Example: `eido check main.eido account.eido` checks both files as one executable project.

import ../../../../compiler/src/project/model
import ../../../../compiler/src/project/modules/loader
import ../../../../compiler/src/source/source_unit
import ../../../../compiler/src/tooling/compiler_service

## Loads source files and checks them as one executable Eido project.
## Example: diagnostics can be returned to the CLI while no generated Nim artifact is created.
proc checkFiles*(sourcePaths: seq[string]): ProjectCheckResult =
  var sources: seq[SourceUnit]
  for index, sourcePath in sourcePaths:
    sources.add initSourceUnit(index, sourcePath, readFile(sourcePath))

  checkProject(initProject(ptExecutable, sources))

## Checks a normal Eido project from its mandatory module.yaml without backend emission.
proc checkModuleFile*(manifestPath: string): ProjectCheckResult =
  checkProject(loadModuleProject(manifestPath, ptExecutable))
