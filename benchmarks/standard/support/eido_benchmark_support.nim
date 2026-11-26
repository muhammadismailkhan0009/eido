# Test-only I/O hooks; never embedded into the shipped SDK.
import std/[os, strutils, monotimes]
import eido_native_bytes
export eido_native_bytes

proc eido_native_benchmarkNanos*(): int64 = getMonoTime().ticks
proc eido_native_benchmarkArgument*(index: int64): int64 =
  int64(parseBiggestInt(paramStr(int(index)+1)))

proc eido_native_method_TraceInput_read*(path: string, address, capacity: int64): int64 =
  let contents = readFile(path)
  if contents.len > capacity or capacity < 0: return -1
  if contents.len > 0:
    copyMem(cast[pointer](address), unsafeAddr contents[0], contents.len)
  int64(contents.len)
