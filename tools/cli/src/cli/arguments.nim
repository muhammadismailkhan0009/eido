## Parses the user-facing Eido command line.
## Example: `eido build main.eido account.eido -o app` selects two project sources and one output path.

import std/os

type
  CliOptions* = object
    sourcePaths*: seq[string]
    outputPath*: string

## Returns the CLI usage text for executable project builds.
## Example: invalid arguments display the accepted multi-source build shape.
proc usage*(): string =
  "Usage: eido build <source.eido> [<source.eido> ...] [-o <output>]"

## Converts command-line words into executable project build options.
## Example: multiple source paths before `-o` become one project source set.
proc parseArgs*(args: seq[string]): CliOptions =
  if args.len < 2 or args[0] != "build":
    raise newException(ValueError, usage())

  var index = 1
  while index < args.len and args[index] != "-o":
    result.sourcePaths.add args[index]
    inc index

  if result.sourcePaths.len == 0:
    raise newException(ValueError, usage())

  result.outputPath = changeFileExt(result.sourcePaths[0], "")

  if index < args.len:
    if args[index] != "-o" or index + 1 >= args.len or index + 2 != args.len:
      raise newException(ValueError, usage())
    result.outputPath = args[index + 1]
