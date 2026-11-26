# Byte/String representation primitives. No file, protocol or scheduling policy here.
import std/strutils

proc eido_native_method_Bytes_unsigned*(value: int8): int64 =
  int64(cast[uint8](value))

proc eido_native_method_Bytes_fromUnsigned*(value: int64): int8 =
  if value < 0 or value > 255:
    raise newException(ValueError, "byte value outside unsigned range")
  cast[int8](uint8(value))

proc eido_native_method_Text_length*(value: string): int64 =
  int64(value.len)

proc eido_native_method_Text_byteAt*(value: string, index: int64): int64 =
  if index < 0 or index >= int64(value.len): return -1
  int64(uint8(value[int(index)]))

proc eido_native_method_Text_slice*(value: string, start, count: int64): string =
  if start < 0 or count < 0 or start > int64(value.len) or count > int64(value.len) - start:
    raise newException(ValueError, "invalid String slice")
  value[int(start) ..< int(start + count)]

proc eido_native_method_Text_indexOf*(value, needle: string): int64 =
  int64(value.find(needle))

proc eido_native_method_Text_fromInt*(value: int64): string =
  $value

when not defined(nimscript):
  # Private primitive ABI receives ranges validated by public Eido wrappers.
  proc eido_native_method_NativeBytes_move*(source, destination, count: int64): int64 =
    if count < 0: return -22
    if count > 0:
      moveMem(cast[pointer](destination), cast[pointer](source), int(count))
    count

  proc eido_native_method_NativeBytes_textWrite*(value: string, address, count: int64): int64 =
    if count != int64(value.len): return -22
    if count > 0:
      copyMem(cast[pointer](address), unsafeAddr value[0], int(count))
    count

  proc eido_native_method_NativeBytes_textMatches*(value: string, address, count: int64): bool =
    if count != int64(value.len): return false
    if count == 0: return true
    equalMem(cast[pointer](address), unsafeAddr value[0], int(count))
