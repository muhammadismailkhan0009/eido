## Executable entrypoint that connects CLI parsing to the build command and reports errors to the user.

import std/os
import cli/arguments
import cli/build_command

when isMainModule:
  try:
    let options = parseArgs(commandLineParams())
    buildFile(options.sourcePath, options.outputPath)
    echo "Built " & options.outputPath
  except CatchableError as error:
    stderr.writeLine("error: " & error.msg)
    quit(1)
