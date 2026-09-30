## Parses the user-facing Eido command line.
## Project commands may discover module.yaml, while standalone compile remains manifest-free.

import std/[os, strutils]
import ../../../../compiler/src/pipeline/options
export options

type
  CliCommand* = enum
    ccHelp,
    ccVersion,
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
    memoryStrategy*: MemoryStrategy

const
  MemoryOptionPrefix = "--memory="

## Returns the default Eido project-tool and standalone compiler usage.
proc usage*(): string =
  "Eido compiler and project tool\n\n" &
  "Usage:\n" &
  "  eido build [module.yaml] [--memory=gc|manual] [-o <output>]\n" &
  "  eido check [module.yaml]\n" &
  "  eido run [module.yaml] [--memory=gc|manual] [-- <application args...>]\n" &
  "  eido clean [module.yaml]\n" &
  "  eido compile <source.eido>... [--memory=gc|manual] -o <output>\n" &
  "  eido --help\n" &
  "  eido --version"

## Rejects explicit project entrypoints that are not module.yaml.
proc requireModuleManifest(path: string) =
  if path.extractFilename != "module.yaml":
    raise newException(
      ValueError,
      "Eido projects use module.yaml as their architecture root\n" & usage()
    )

## Parses one --memory=<strategy> option when present.
proc parseMemoryOption(arg: string, options: var CliOptions): bool =
  if not arg.startsWith(MemoryOptionPrefix):
    return false

  let name = arg[MemoryOptionPrefix.len .. ^1]
  if name.len == 0:
    raise newException(ValueError, usage())
  options.memoryStrategy = parseMemoryStrategy(name)
  true

## Parses an optional explicit manifest at the current argument index.
proc parseOptionalManifest(
  args: seq[string],
  index: var int,
  options: var CliOptions
) =
  if index < args.len and not args[index].startsWith("-"):
    options.modulePath = args[index]
    requireModuleManifest(options.modulePath)
    inc index

## Parses the project build command with optional output and memory strategy.
proc parseBuild(args: seq[string]): CliOptions =
  result.command = ccBuild
  result.memoryStrategy = msGc
  var index = 1
  parseOptionalManifest(args, index, result)

  while index < args.len:
    if parseMemoryOption(args[index], result):
      inc index
      continue
    if args[index] == "-o" and index + 1 < args.len:
      if result.outputPath.len > 0:
        raise newException(ValueError, usage())
      result.outputPath = args[index + 1]
      index += 2
      continue
    raise newException(ValueError, usage())

## Parses one project command that accepts only an optional explicit manifest.
proc parseManifestOnly(args: seq[string], command: CliCommand): CliOptions =
  result.command = command
  result.memoryStrategy = msGc
  var index = 1
  parseOptionalManifest(args, index, result)
  if index != args.len:
    raise newException(ValueError, usage())

## Parses project execution with memory strategy and application arguments.
proc parseRun(args: seq[string]): CliOptions =
  result.command = ccRun
  result.memoryStrategy = msGc
  var index = 1
  parseOptionalManifest(args, index, result)

  while index < args.len and args[index] != "--":
    if parseMemoryOption(args[index], result):
      inc index
      continue
    raise newException(ValueError, usage())

  if index < args.len and args[index] == "--":
    inc index
    if index < args.len:
      result.applicationArgs = args[index .. ^1]

## Parses standalone source compilation without the project/module loader.
proc parseCompile(args: seq[string]): CliOptions =
  result.command = ccCompile
  result.memoryStrategy = msGc
  var index = 1

  while index < args.len:
    if parseMemoryOption(args[index], result):
      inc index
      continue

    if args[index] == "-o":
      if index + 1 >= args.len or result.outputPath.len > 0:
        raise newException(ValueError, usage())
      result.outputPath = args[index + 1]
      index += 2
      continue

    let sourcePath = args[index]
    if sourcePath.splitFile.ext != ".eido":
      raise newException(
        ValueError,
        "standalone compilation accepts only .eido source files\n" & usage()
      )
    result.sourcePaths.add sourcePath
    inc index

  if result.sourcePaths.len == 0 or result.outputPath.len == 0:
    raise newException(ValueError, usage())

## Parses all supported project-tool and standalone compiler commands.
proc parseArgs*(args: seq[string]): CliOptions =
  if args.len == 0:
    return CliOptions(command: ccHelp, memoryStrategy: msGc)

  case args[0]
  of "help", "--help", "-h":
    if args.len != 1:
      raise newException(ValueError, usage())
    CliOptions(command: ccHelp, memoryStrategy: msGc)
  of "version", "--version", "-V":
    if args.len != 1:
      raise newException(ValueError, usage())
    CliOptions(command: ccVersion, memoryStrategy: msGc)
  of "build": parseBuild(args)
  of "check": parseManifestOnly(args, ccCheck)
  of "run": parseRun(args)
  of "clean": parseManifestOnly(args, ccClean)
  of "compile": parseCompile(args)
  else: raise newException(ValueError, usage())
