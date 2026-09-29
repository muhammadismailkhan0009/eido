## Runs executable Eido projects through the default project-tool workflow.
## Compilation remains delegated to the reusable explicit build operation.

import std/osproc
import build_command
import project_layout

## Builds one module project into the supplied layout and runs it with forwarded arguments.
## Standard streams are inherited so the executable behaves like a directly launched program.
proc runModuleProject*(
  manifestPath: string,
  applicationArgs: seq[string],
  layout: ProjectLayout
): int =
  layout.prepareProjectLayout()
  buildModuleFile(
    manifestPath,
    layout.executablePath,
    layout.generatedSourcePath
  )

  let process = startProcess(
    layout.executablePath,
    args = applicationArgs,
    options = {poParentStreams}
  )
  result = process.waitForExit()
  process.close()
