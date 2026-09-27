## Nim-backend implementation of Eido's initial platform native ABI.
## These procedures are backend support for stdlib Eido declarations, not source-language semantics.

import std/[os, syncio]

## Returns the number of user command-line arguments for Process.argumentCount().
proc eido_native_method_Process_argumentCount*(): int64 =
  int64(paramCount())

## Compatibility export for top-level native-function conformance coverage.
proc eido_native_platformArgumentCount*(): int64 =
  eido_native_method_Process_argumentCount()

## Returns one zero-based user command-line argument for Process.argument().
proc eido_native_method_Process_argument*(index: int64): string =
  paramStr(int(index) + 1)

## Compatibility export for top-level native-function conformance coverage.
proc eido_native_platformArgument*(index: int64): string =
  eido_native_method_Process_argument(index)

## Writes one line to standard output for Console.writeLine().
proc eido_native_method_Console_writeLine*(value: string) =
  when defined(nimscript):
    echo value
  else:
    stdout.writeLine(value)

## Compatibility export for top-level native-function conformance coverage.
proc eido_native_platformWriteLine*(value: string) =
  eido_native_method_Console_writeLine(value)

## Writes one line to standard error for Console.errorLine().
proc eido_native_method_Console_errorLine*(value: string) =
  when defined(nimscript):
    echo value
  else:
    stderr.writeLine(value)

## Compatibility export for top-level native-function conformance coverage.
proc eido_native_platformErrorLine*(value: string) =
  eido_native_method_Console_errorLine(value)

## Terminates the current process for Process.exit().
proc eido_native_method_Process_exit*(code: int64) =
  quit(int(code))

## Compatibility export for top-level native-function conformance coverage.
proc eido_native_platformExit*(code: int64) =
  eido_native_method_Process_exit(code)
