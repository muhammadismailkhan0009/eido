# Independent native reference: equivalent payloads, initialized and read
# directly through typed pointers, no Eido SDK or policy.
import std/os
const N = 2_000_000
const Passes = 12
type
  DefaultRow = object
    flag: int8
    value: int64
    category: int8
    other: int64
  CompactRow = object
    value, other: int64
    flag, category: int8
  WideRow = object
    value {.align: 64.}: int64
    other: int64
    flag, category: int8
static:
  doAssert sizeof(DefaultRow) == 32 and alignof(DefaultRow) == 8
  doAssert sizeof(CompactRow) == 24 and alignof(CompactRow) == 8
  doAssert sizeof(WideRow) == 64 and alignof(WideRow) == 64
  doAssert offsetOf(DefaultRow, value) == 8 and offsetOf(DefaultRow, other) == 24
  doAssert offsetOf(CompactRow, value) == 0 and offsetOf(CompactRow, other) == 8
  doAssert offsetOf(WideRow, value) == 0 and offsetOf(WideRow, other) == 8
  doAssert offsetOf(DefaultRow, flag) == 0 and offsetOf(DefaultRow, category) == 16
  doAssert offsetOf(CompactRow, flag) == 16 and offsetOf(CompactRow, category) == 17
  doAssert offsetOf(WideRow, flag) == 16 and offsetOf(WideRow, category) == 17
proc scan[T](): int64 {.noinline.} =
  let raw = alloc0(N * sizeof(T) + alignof(T) - 1)
  let base = (cast[uint](raw) + uint(alignof(T) - 1)) and not uint(alignof(T) - 1)
  let rows = cast[ptr UncheckedArray[T]](base)
  for i in 0..<N:
    rows[i] = T(flag: 1, value: int64(i+1), category: 2, other: int64(i+2))
  for pass in 0..<Passes:
    for i in 0..<N:
      result += rows[i].value + rows[i].other
  # Make both byte fields observable as well, outside the hot scan.
  doAssert rows[0].flag == 1 and rows[N-1].category == 2
  dealloc(raw)
case paramStr(1)
of "default": echo scan[DefaultRow]()
of "compact": echo scan[CompactRow]()
of "wide": echo scan[WideRow]()
else: quit(2)
