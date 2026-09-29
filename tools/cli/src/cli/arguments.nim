## Parses the user-facing Eido command line.
## Project commands may discover module.yaml, while standalone compile remains manifest-free.

import std/os

type
  CliCommand* = enum
    ccBuild,
    ccCheck,
    ccRun,
    ccClean,
    ccCompile

  CliOptions* = object
    command*: CliCommand
    modulePath*: string
    outputPath*: string
    sourcePaths*: seq[string]
    applicationArgs*: seq[string]

## Returns the default Eido project-tool and standalone compiler usage.
proc usage*(): string =
  "Usage:\n" &
  "  eido build [module.yaml] [-o <output>]\n" &
  "  eido check [module.yaml]\n" &
  "  eido run [module.yaml] [-- <application args...>]\n" &
  "  eido clean [module.yaml]\n" &
  "  eido compile <source.eido>... -o <output>"

## Rejects explicit project entrypoints that are not module.yaml.
proc requireModuleManifest(path: string) =
  if path.extractFilename != "module.yaml":
    raise newException(
      ValueError,
      "Eido projects use module.yaml as their architecture root\n" & usage()
    )

## Parses an optional explicit manifest at the current argument index.
proc parseOptionalManifest(
  args: seq[string],
  index: var int,
  options: var CliOptions
) =
  if index < args.len and args[index] notin ["-o", "--"]:
    options.modulePath = args[index]
    requireModuleManifest(options.modulePath)
    inc index

## Parses the project build command with optional output override.
proc parseBuild(args: seq[string]): CliOptions =
  result.command = ccBuild
  var index = 1
  parseOptionalManifest(args, index, result)

  if index == args.len:
    return
  if index + 2 == args.len and args[index] == "-o":
    result.outputPath = args[index + 1]
    return
  raise newException(ValueError, usage())

## Parses one project command that accepts only an optional explicit manifest.
proc parseManifestOnly(args: seq[string], command: CliCommand): CliOptions =
  result.command = command
  var index = 1
  parseOptionalManifest(args, index, result)
  if index != args.len:
    raise newException(ValueError, usage())

## Parses project execution with application arguments after an explicit separator.
proc parseRun(args: seq[string]): CliOptions =
  result.command = ccRun
  var index = 1
  parseOptionalManifest(args, index, result)

  if index == args.len:
    return
  if args[index] != "--":
    raise newException(ValueError, usage())
  inc index
  if index < args.len:
    result.applicationArgs = args[index .. ^1]

## Parses standalone source compilation without the project/module loader.
proc parseCompile(args: seq[string]): CliOptions =
  result.command = ccCompile
  if args.len < 4:
    raise newException(ValueError, usage())

  var outputIndex = -1
  for index in 1 ..< args.len:
    if args[index] == "-o":
      outputIndex = index
      break

  if outputIndex <= 1 or outputIndex + 1 != args.high:
    raise newException(ValueError, usage())

  result.sourcePaths = args[1 ..< outputIndex]
  result.outputPath = args[outputIndex + 1]
  for sourcePath in result.sourcePaths:
    if sourcePath.splitFile.ext != ".eido":
      raise newException(
        ValueError,
        "standalone compilation accepts only .eido source files\n" & usage()
      )

## Parses all supported project-tool and standalone compiler commands.
proc parseArgs*(args: seq[string]): CliOptions =
  if args.len == 0:
    raise newException(ValueError, usage())

  case args[0]
  of "build": parseBuild(args)
  of "check": parseManifestOnly(args, ccCheck)
  of "run": parseRun(args)
  of "clean": parseManifestOnly(args, ccClean)
  of "compile": parseCompile(args)
  else: raise newException(ValueError, usage())
