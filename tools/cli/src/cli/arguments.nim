## Parses the user-facing Eido command line.
## Normal project commands are manifest-driven: module.yaml is mandatory.

import std/os

type
  CliCommand* = enum
    ccBuild,
    ccCheck

  CliOptions* = object
    command*: CliCommand
    modulePath*: string
    outputPath*: string

## Returns manifest-driven CLI usage for normal Eido projects.
proc usage*(): string =
  "Usage:\n" &
  "  eido build <module.yaml> [-o <output>]\n" &
  "  eido check <module.yaml>"

## Rejects user project entrypoints that are not named module.yaml.
proc requireModuleManifest(path: string) =
  if path.extractFilename != "module.yaml":
    raise newException(
      ValueError,
      "Eido projects must be built or checked through module.yaml\n" & usage()
    )

## Parses build/check commands rooted at one mandatory module.yaml.
proc parseArgs*(args: seq[string]): CliOptions =
  if args.len < 2:
    raise newException(ValueError, usage())

  result.modulePath = args[1]
  requireModuleManifest(result.modulePath)

  case args[0]
  of "build":
    result.command = ccBuild
    if args.len == 2:
      let projectDir = parentDir(result.modulePath)
      let projectName =
        if projectDir.len == 0: "eido-app"
        else: projectDir.extractFilename
      result.outputPath =
        if projectDir.len == 0: projectName
        else: projectDir / projectName
    elif args.len == 4 and args[2] == "-o":
      result.outputPath = args[3]
    else:
      raise newException(ValueError, usage())

  of "check":
    result.command = ccCheck
    if args.len != 2:
      raise newException(ValueError, usage())

  else:
    raise newException(ValueError, usage())
