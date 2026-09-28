## Executable entrypoint connecting project-aware CLI commands to compiler tooling.

import std/os
import ../../../compiler/src/diagnostics/[errors, formatting]
import cli/[arguments, build_command, check_command]

when isMainModule:
  try:
    let options = parseArgs(commandLineParams())

    case options.command
    of ccBuild:
      buildModuleFile(options.modulePath, options.outputPath)
      echo "Built " & options.outputPath

    of ccCheck:
      let checkResult = checkModuleFile(options.modulePath)
      for diagnostic in checkResult.diagnostics:
        stderr.writeLine(formatDiagnostic(diagnostic))

      if not checkResult.success:
        quit(1)

      echo "Check passed"

  except CompilerError as error:
    stderr.writeLine(formatDiagnostic(error.diagnostic))
    quit(1)
  except CatchableError as error:
    stderr.writeLine("error: " & error.msg)
    quit(1)
