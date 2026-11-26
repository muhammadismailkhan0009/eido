# Native Storage diagnostic: same 20-slot replacement trace, with/without
# committing every page. Separate from the Eido benchmark's timed executable.
import std/[os, strutils, monotimes, volatile, posix]
import eido_storage

proc rssKiB(): int64 =
  for line in readFile("/proc/self/status").splitLines():
    if line.startsWith("VmRSS:"):
      return parseBiggestInt(line.splitWhitespace()[1])
  raise newException(IOError, "VmRSS missing")

let trace = readFile(paramStr(1)).strip().splitLines()
doAssert trace.len == 2000
let touch = paramStr(2) == "touch"
let diagnose = paramStr(3) == "profile"
let page = int64(sysconf(SC_PAGESIZE))
doAssert page > 0
var slots: array[20, EidoStorage[int8]]
var sizes: array[20, int64]
var live, peak, allocNs, touchNs, releaseNs, checksum: int64
if diagnose: echo "START ", rssKiB()
for i, line in trace:
  let fields = line.splitWhitespace()
  let slot = parseInt(fields[0])
  let size = parseBiggestInt(fields[1])
  let t = getMonoTime().ticks
  var next = eidoStorageAllocateRaw(size, 1)
  allocNs += getMonoTime().ticks - t
  live += size
  peak = max(peak,live)
  if touch:
    let start = getMonoTime().ticks
    let base = uint(eidoStorageAddress(next))
    # Write one byte per physical page, including both endpoints for an
    # unaligned allocation. Volatile accesses cannot be optimized away.
    var offset = 0'i64
    while offset < size:
      let p = cast[ptr int8](base + uint(offset))
      doAssert volatileLoad(p) == 0
      volatileStore(p, 1'i8)
      checksum += int64(volatileLoad(p))
      offset += page
    let last = cast[ptr int8](base + uint(size-1))
    if (size-1) mod page != 0:
      volatileStore(last, 1'i8)
      checksum += int64(volatileLoad(last))
    touchNs += getMonoTime().ticks - start
  if diagnose and i mod 100 == 0:
    echo "ALLOC ", i, " ", live, " ", rssKiB()
  let r = getMonoTime().ticks
  if sizes[slot] > 0: eidoStorageRelease(slots[slot])
  releaseNs += getMonoTime().ticks - r
  live -= sizes[slot]
  slots[slot] = next
  sizes[slot] = size
  if diagnose and i mod 100 == 0:
    echo "REPLACE ", i, " ", live, " ", rssKiB()
for i in 0..<20:
  if sizes[i] > 0:
    let r = getMonoTime().ticks
    eidoStorageRelease(slots[i])
    releaseNs += getMonoTime().ticks - r
    live -= sizes[i]
doAssert live == 0
if diagnose:
  echo "END ", rssKiB()
  sleep(100)
  echo "IDLE ", rssKiB()
echo "RESULT ", peak, " ", allocNs, " ", touchNs, " ", releaseNs, " ", checksum
