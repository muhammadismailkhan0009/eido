## Nim-backend implementation of Eido's initial platform native ABI.
## These procedures are backend support for stdlib Eido declarations, not source-language semantics.

import std/[os, syncio]

## Returns the number of user command-line arguments, excluding the executable path.
proc eido_native_platformArgumentCount*(): int64 =
  int64(paramCount())

## Returns one zero-based user command-line argument.
proc eido_native_platformArgument*(index: int64): string =
  paramStr(int(index) + 1)

## Writes one line to standard output.
proc eido_native_platformWriteLine*(value: string) =
  when defined(nimscript):
    echo value
  else:
    stdout.writeLine(value)

## Writes one line to standard error.
proc eido_native_platformErrorLine*(value: string) =
  when defined(nimscript):
    echo value
  else:
    stderr.writeLine(value)

## Terminates the current process with the requested exit status.
proc eido_native_platformExit*(code: int64) =
  quit(int(code))
