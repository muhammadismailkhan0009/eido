import std/[os, volatile]
import eido_storage
const N = 2_000_000
const Passes = 12
const Churn = 1_000_000
proc arrayScan(): int64 =
  var values = newSeq[int64](N)
  for i in 0..<N: values[i] = int64(i + 1)
  for pass in 0..<Passes:
    for i in 0..<N: result += values[i]
proc sdkScan(): int64 =
  var raw = eidoStorageAllocateRaw(N, 8)
  let values = eidoStorageFromRaw[int64](raw)
  for i in 0..<N: eidoStorageWrite(values, i, int64(i+1))
  for pass in 0..<Passes:
    for i in 0..<N: result += eidoStorageRead(values, i)
  eidoStorageRelease(raw)
proc rawChurn(): int64 =
  for i in 0..<Churn:
    let p = cast[ptr int64](alloc0(16 * sizeof(int64)))
    p[] = int64(i+1)
    result += volatileLoad(p)
    dealloc(p)
# Same native Storage substrate, without the Eido alignment/ownership wrapper.
proc sdkChurn(): int64 =
  for i in 0..<Churn:
    var raw = eidoStorageAllocateRaw(16, 8)
    let values = eidoStorageFromRaw[int64](raw)
    eidoStorageWrite(values, 0, int64(i+1))
    result += eidoStorageRead(values, 0)
    eidoStorageRelease(raw)
proc sdkReuse(): int64 =
  var raw = eidoStorageAllocateRaw(16, 8)
  let values = eidoStorageFromRaw[int64](raw)
  for i in 0..<Churn:
    eidoStorageWrite(values, 0, int64(i+1))
    result += eidoStorageRead(values, 0)
  eidoStorageRelease(raw)
proc sdkPlacement(): int64 =
  var raw = eidoStorageAllocateRaw(16, 8)
  let address = eidoStorageAddress(raw)
  for i in 0..<Churn:
    var placed = eidoStorageReserveAt(raw, address, 16, 8)
    let values = eidoStorageFromRaw[int64](placed)
    eidoStorageWrite(values, 0, int64(i+1))
    result += eidoStorageRead(values, 0)
    eidoStorageRelease(placed)
  eidoStorageRelease(raw)
case paramStr(1)
of "array": echo arrayScan()
of "sdk": echo sdkScan()
of "churn": echo rawChurn()
of "sdk-churn": echo sdkChurn()
of "sdk-reuse": echo sdkReuse()
of "sdk-placement": echo sdkPlacement()
else: quit(2)
