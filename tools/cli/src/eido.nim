## Executable entrypoint connecting the default Eido project tool to reusable compiler APIs.

import std/os
import ../../../compiler/src/diagnostics/[errors, formatting]
import ../../../compiler/src/project/discovery
import cli/[
  arguments, build_command, check_command, clean_command,
  project_layout, run_command, version
]

## Resolves the explicit or discovered project manifest for project-oriented commands.
proc resolvedManifest(options: CliOptions): string =
  resolveProjectManifest(options.modulePath)

when isMainModule:
  try:
    let options = parseArgs(commandLineParams())

    case options.command
    of ccHelp:
      echo usage()

    of ccVersion:
      echo "Eido " & EidoVersion

    of ccBuild:
      let manifestPath = resolvedManifest(options)
      let layout = projectLayout(manifestPath)
      if options.outputPath.len > 0:
        buildModuleFile(
          manifestPath,
          options.outputPath,
          memoryStrategy = options.memoryStrategy
        )
        echo "Built " & options.outputPath
      else:
        layout.prepareProjectLayout()
        buildModuleFile(
          manifestPath,
          layout.executablePath,
          layout.generatedSourcePath,
          options.memoryStrategy
        )
        echo "Built " & layout.executablePath

    of ccCheck:
      let manifestPath = resolvedManifest(options)
      let checkResult = checkModuleFile(manifestPath)
      for diagnostic in checkResult.diagnostics:
        stderr.writeLine(formatDiagnostic(diagnostic))

      if not checkResult.success:
        quit(1)

      echo "Check passed"

    of ccRun:
      let manifestPath = resolvedManifest(options)
      let layout = projectLayout(manifestPath)
      let exitCode = runModuleProject(
        manifestPath,
        options.applicationArgs,
        layout,
        options.memoryStrategy
      )
      if exitCode != 0:
        quit(exitCode)

    of ccClean:
      let manifestPath = resolvedManifest(options)
      cleanModuleProject(manifestPath)
      echo "Cleaned " & projectLayout(manifestPath).buildDirectory

    of ccCompile:
      buildFiles(
        options.sourcePaths,
        options.outputPath,
        options.memoryStrategy
      )
      echo "Built " & options.outputPath

  except CompilerError as error:
    stderr.writeLine(formatDiagnostic(error.diagnostic))
    quit(1)
  except CatchableError as error:
    stderr.writeLine("error: " & error.msg)
    quit(1)
