## Emits backend-neutral wrappers for built-in String semantics implemented by hidden Eido runtime code.

import ../../../hir/program as hirProgram
import names
import string_runtime_bindings

## Renders generated String operations plus the narrow foreign-native text bridge.
proc renderStringRuntimeSupport*(program: hirProgram.HirProgram): string =
  let bindings = bindStringRuntime(program)

  result.add "proc " & stringAllocateName() & "(length: int64): int64 =\n"
  result.add "  " & bindings.allocate & "(length)\n\n"
  result.add "proc " & stringWriteByteName() &
    "(value: int64, index: int64, byteValue: int8) =\n"
  result.add "  " & bindings.writeByte & "(value, index, byteValue)\n\n"
  result.add "proc " & stringLengthName() & "(value: int64): int64 =\n"
  result.add "  " & bindings.length & "(value)\n\n"
  result.add "proc " & stringByteAtName() &
    "(value: int64, index: int64): int8 =\n"
  result.add "  " & bindings.byteAt & "(value, index)\n\n"
  result.add "proc " & stringConcatName() &
    "(left, right: int64): int64 =\n"
  result.add "  " & bindings.concat & "(left, right)\n\n"
  result.add "proc " & stringEqualName() &
    "(left, right: int64): bool =\n"
  result.add "  " & bindings.equal & "(left, right)\n\n"
  result.add "proc " & stringShutdownName() & "() =\n"
  result.add "  " & bindings.shutdown & "()\n\n"

  result.add "proc " & stringLiteralName() & "(bytes: openArray[int8]): int64 =\n"
  result.add "  result = " & stringAllocateName() & "(int64(bytes.len))\n"
  result.add "  for index, byteValue in bytes:\n"
  result.add "    " & stringWriteByteName() &
    "(result, int64(index), byteValue)\n\n"

  # Foreign/native text never becomes Eido-owned storage. The bridge copies it
  # immediately into the Storage-backed String runtime representation.
  result.add "proc " & stringFromNativeName() & "(value: string): int64 =\n"
  result.add "  result = " & stringAllocateName() & "(int64(value.len))\n"
  result.add "  var index = 0\n"
  result.add "  while index < value.len:\n"
  result.add "    " & stringWriteByteName() &
    "(result, int64(index), cast[int8](uint8(value[index])))\n"
  result.add "    inc index\n\n"

  result.add "proc " & stringToNativeName() & "(value: int64): string =\n"
  result.add "  let length = " & stringLengthName() & "(value)\n"
  result.add "  result = newString(int(length))\n"
  result.add "  var index = int64(0)\n"
  result.add "  while index < length:\n"
  result.add "    result[int(index)] = char(uint8(" &
    stringByteAtName() & "(value, index)))\n"
  result.add "    inc index\n\n"
