## Parses the user-facing Eido command line. Example: `eido build app.eido -o app` becomes source/output paths.

import std/os

type
  CliOptions* = object
    sourcePath*: string
    outputPath*: string

## Returns the CLI usage text. Example: invalid arguments display `Usage: eido build <source.eido> -o <output>`.
proc usage*(): string =
  "Usage: eido build <source.eido> -o <output>"

## Converts command-line words into build options. Example: `["build", "app.eido", "-o", "app"]` selects `app.eido` and output `app`.
proc parseArgs*(args: seq[string]): CliOptions =
  if args.len < 2 or args[0] != "build":
    raise newException(ValueError, usage())

  result.sourcePath = args[1]
  result.outputPath = changeFileExt(result.sourcePath, "")

  if args.len >= 4 and args[2] == "-o":
    result.outputPath = args[3]
  elif args.len != 2:
    raise newException(ValueError, usage())
