## Parses the user-facing Eido command line.
## Example: `eido build main.eido account.eido -o app` and `eido check main.eido account.eido`.

import std/os

type
  CliCommand* = enum
    ccBuild,
    ccCheck

  CliOptions* = object
    command*: CliCommand
    sourcePaths*: seq[string]
    outputPath*: string

## Returns the CLI usage text for build and semantic-check commands.
## Example: invalid arguments display both accepted multi-source command shapes.
proc usage*(): string =
  "Usage:\n" &
  "  eido build <source.eido> [<source.eido> ...] [-o <output>]\n" &
  "  eido check <source.eido> [<source.eido> ...]"

## Parses source paths shared by build/check until an optional build output flag.
## Example: two file arguments become one ordered project source set.
proc parseSourcePaths(
  args: seq[string],
  startIndex: int
): tuple[paths: seq[string], nextIndex: int] =
  result.nextIndex = startIndex
  while result.nextIndex < args.len and args[result.nextIndex] != "-o":
    result.paths.add args[result.nextIndex]
    inc result.nextIndex

## Converts command-line words into project-aware CLI options.
## Example: check accepts one or more source files and never accepts an output path.
proc parseArgs*(args: seq[string]): CliOptions =
  if args.len < 2:
    raise newException(ValueError, usage())

  case args[0]
  of "build":
    result.command = ccBuild
    let parsed = parseSourcePaths(args, 1)
    result.sourcePaths = parsed.paths
    if result.sourcePaths.len == 0:
      raise newException(ValueError, usage())

    result.outputPath = changeFileExt(result.sourcePaths[0], "")
    if parsed.nextIndex < args.len:
      if args[parsed.nextIndex] != "-o" or
          parsed.nextIndex + 1 >= args.len or
          parsed.nextIndex + 2 != args.len:
        raise newException(ValueError, usage())
      result.outputPath = args[parsed.nextIndex + 1]

  of "check":
    result.command = ccCheck
    let parsed = parseSourcePaths(args, 1)
    result.sourcePaths = parsed.paths
    if result.sourcePaths.len == 0 or parsed.nextIndex != args.len:
      raise newException(ValueError, usage())

  else:
    raise newException(ValueError, usage())
