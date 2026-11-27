## Nim-backend implementation of Eido's raw Storage<Byte> substrate and
## private representation bridges used by the SDK Eido Storage<T> wrapper.
## Handles are allocation-free values; owning allocation operations alone acquire backing memory.

type
  EidoStorage*[T] = object
    data*: ptr UncheckedArray[T]
    capacity*: int64
    strideBytes*: int64
    ownsMemory*: bool
    releasable*: bool
    rawBlocks*: bool
    live*: bool
    ## Original allocation address when a typed raw allocation needs alignment.
    ## The public starting address may be an aligned address inside this block.
    allocationBase*: pointer

## Requires a live storage capability before any operation touches its backing region.
proc requireEidoStorageLive[T](storage: EidoStorage[T]) {.inline.} =
  if not storage.live:
    raise newException(AssertionDefect, "Eido storage access after release")

## Requires an element index to fall inside a storage capability's slot capacity.
proc requireEidoStorageIndex[T](storage: EidoStorage[T], index: int64) {.inline.} =
  if index < 0 or index >= storage.capacity:
    raise newException(IndexDefect, "Eido storage index out of bounds")

## Validates a slot count and stride against the target address space.
proc requireEidoStorageLayout(allocations, strideBytes: int64) =
  if allocations < 0:
    raise newException(ValueError, "Eido storage allocation count cannot be negative")
  if strideBytes <= 0:
    raise newException(ValueError, "Eido storage bytes per allocation must be positive")
  if allocations > int64(high(int)) div strideBytes:
    raise newException(ValueError, "Eido storage allocation exceeds target address space")

## Eido addresses are signed Int values even on an unsigned pointer target.
## Validate before narrowing to uint; no address may wrap or truncate.
const maxStorageAddress = min(uint64(high(uint)), uint64(high(int64)))

proc requireEidoStorageAddressRange(address, count, stride: int64) =
  requireEidoStorageLayout(count, stride)
  if address < 0 or uint64(address) > maxStorageAddress:
    raise newException(ValueError, "Eido storage address exceeds target address space")
  if count > 0:
    if address == 0:
      raise newException(ValueError, "nonempty native Storage cannot use a nil address")
    let lastOffset = uint64(count * stride - 1)
    if lastOffset > maxStorageAddress - uint64(address):
      raise newException(ValueError, "Eido storage region exceeds target address space")

## Returns the byte address of one validated storage slot.
proc eidoStorageSlotAddress[T](storage: EidoStorage[T], index: int64): uint {.inline.} =
  requireEidoStorageLive(storage)
  requireEidoStorageIndex(storage, index)
  cast[uint](storage.data) + uint(index) * uint(storage.strideBytes)

## Allocates one owning raw fixed-stride block sequence.
## This is the single physical allocation path for all owned Storage backing.
proc eidoStorageAllocateRaw*(
  allocations: int64,
  bytesPerAllocation: int64
): EidoStorage[int8] =
  requireEidoStorageLayout(allocations, bytesPerAllocation)

  result.capacity = allocations
  result.strideBytes = bytesPerAllocation
  result.ownsMemory = true
  result.releasable = true
  result.rawBlocks = true
  result.live = true
  if allocations == 0:
    return

  let byteCount = int(allocations * bytesPerAllocation)
  result.data = cast[ptr UncheckedArray[int8]](alloc0(byteCount))
  if result.data.isNil:
    raise newException(OutOfMemDefect, "Eido raw storage allocation failed")

## Verifies a candidate address/extent is within a live raw backing region.
proc checkedStorageSubrange(
  region: EidoStorage[int8], address, count, stride: int64
): uint =
  requireEidoStorageLive(region)
  requireEidoStorageAddressRange(address, count, stride)
  requireEidoStorageLayout(region.capacity, region.strideBytes)
  let base = cast[uint](region.data)
  let regionBytes = uint(region.capacity * region.strideBytes)
  let start = uint(address)
  let claimBytes = uint(count * stride)
  if start < base or start - base > regionBytes or
      claimBytes > regionBytes - (start - base):
    raise newException(IndexDefect, "explicit Storage reservation outside backing region")
  start

## Creates a releasable explicit placement inside an existing region.
## Release of the result ends only this placement; it never deallocates the
## caller-owned region. Overlap tracking is an optional allocator policy.
proc eidoStorageReserveAt*(
  region: EidoStorage[int8],
  address, count, stride: int64
): EidoStorage[int8] =
  let start = checkedStorageSubrange(region, address, count, stride)
  result.data = cast[ptr UncheckedArray[int8]](start)
  result.capacity = count
  result.strideBytes = stride
  result.ownsMemory = false
  result.releasable = true
  result.rawBlocks = true
  result.live = true

## Rebase an owning raw allocation to an Eido-calculated aligned slot range.
## All alignment/padding arithmetic and original-base bookkeeping is in Eido.
## This bridge only preserves the allocator's original pointer for deallocation.
proc eidoStorageRebaseOwnedRaw*(
  storage: EidoStorage[int8],
  alignedAddress, count, stride: int64
): EidoStorage[int8] =
  requireEidoStorageLive(storage)
  if not storage.rawBlocks or not storage.ownsMemory or not storage.releasable or
      not storage.allocationBase.isNil:
    raise newException(ValueError, "rebase requires owning original raw Storage")
  if storage.capacity != 1:
    raise newException(ValueError, "rebase requires a single raw allocation block")
  if count == 0:
    raise newException(ValueError, "rebase requires nonempty Storage; allocate an empty root directly")
  let target = checkedStorageSubrange(storage, alignedAddress, count, stride)
  result = storage
  result.data = cast[ptr UncheckedArray[int8]](target)
  result.capacity = count
  result.strideBytes = stride
  if target != cast[uint](storage.data):
    result.allocationBase = storage.data

## Reinterprets one raw Storage<Byte> descriptor as typed storage without
## changing ownership, release, capacity, or stride semantics.
proc eidoStorageFromRaw*[T](storage: EidoStorage[int8]): EidoStorage[T] =
  requireEidoStorageLive(storage)
  if not storage.rawBlocks:
    raise newException(ValueError, "typed Storage requires raw Storage<Byte>")
  if int64(sizeof(T)) > storage.strideBytes:
    raise newException(
      ValueError,
      "Eido storage view type does not fit raw allocation block"
    )

  let targetAddress = cast[uint](storage.data)
  if not storage.data.isNil and targetAddress mod uint(alignof(T)) != 0'u:
    raise newException(ValueError, "Eido storage view is misaligned")
  if storage.capacity > 1 and
      uint(storage.strideBytes) mod uint(alignof(T)) != 0'u:
    raise newException(ValueError, "Eido storage view stride is misaligned")

  result.data = cast[ptr UncheckedArray[T]](storage.data)
  result.capacity = storage.capacity
  result.strideBytes = storage.strideBytes
  result.ownsMemory = storage.ownsMemory
  result.releasable = storage.releasable
  result.rawBlocks = false
  result.live = storage.live
  result.allocationBase = storage.allocationBase

## Exposes a typed descriptor as the equivalent raw Storage<Byte> capability.
proc eidoStorageRaw*[T](storage: EidoStorage[T]): EidoStorage[int8] =
  requireEidoStorageLive(storage)
  result.data = cast[ptr UncheckedArray[int8]](storage.data)
  result.capacity = storage.capacity
  result.strideBytes = storage.strideBytes
  result.ownsMemory = storage.ownsMemory
  result.releasable = storage.releasable
  result.rawBlocks = true
  result.live = storage.live
  result.allocationBase = storage.allocationBase

## Reports the target byte width of one typed Storage slot.
proc eidoStorageSize*[T](): int64 =
  int64(sizeof(T))

## Reports the target alignment required by one typed Storage slot.
proc eidoStorageAlignment*[T](): int64 =
  int64(alignof(T))

## Single physical native deallocation operation.
proc releaseNativeBacking(base: pointer) =
  if not base.isNil:
    dealloc(base)

## Trusted SDK-only release of an original native allocation base.
## This never constructs an owning or readable descriptor from an address.
proc eidoStorageReleaseNativeAddress*(startingAddress: int64) =
  requireEidoStorageAddressRange(startingAddress, 1, 1)
  releaseNativeBacking(cast[pointer](uint(startingAddress)))

## Creates a non-owning raw descriptor for existing memory at an explicit address.
## Borrowed address storage may be read/written but cannot release its backing memory.
proc eidoStorageBorrowAddress*(
  startingAddress: int64,
  allocations: int64,
  bytesPerAllocation: int64
): EidoStorage[int8] =
  requireEidoStorageAddressRange(startingAddress, allocations, bytesPerAllocation)

  result.data = cast[ptr UncheckedArray[int8]](uint(startingAddress))
  result.capacity = allocations
  result.strideBytes = bytesPerAllocation
  result.ownsMemory = false
  result.releasable = false
  result.rawBlocks = true
  result.live = true

## Creates a borrowed raw descriptor at a byte offset inside the first raw block.
## The remaining bytes in that block become the new raw stride so a later typed
## reinterpretation can validate whether its element representation fits.
proc eidoStorageRawViewAt*(
  storage: EidoStorage[int8],
  byteOffset: int64
): EidoStorage[int8] =
  requireEidoStorageLive(storage)
  if not storage.rawBlocks:
    raise newException(ValueError, "Eido byte-offset view requires raw Storage<Byte>")
  if storage.capacity <= 0:
    raise newException(IndexDefect, "Eido byte-offset view requires a raw block")
  if byteOffset < 0 or byteOffset >= storage.strideBytes:
    raise newException(ValueError, "Eido byte offset is outside raw allocation block")

  result.data = cast[ptr UncheckedArray[int8]](
    cast[uint](storage.data) + uint(byteOffset)
  )
  result.capacity = 1
  result.strideBytes = storage.strideBytes - byteOffset
  result.ownsMemory = false
  result.releasable = false
  result.rawBlocks = true
  result.live = true

## Creates an allocation-free borrowed subrange of existing storage slots.
proc eidoStorageSlice*[T](
  storage: EidoStorage[T],
  start: int64,
  count: int64
): EidoStorage[T] =
  requireEidoStorageLive(storage)
  if start < 0 or count < 0 or
      start > storage.capacity or count > storage.capacity - start:
    raise newException(IndexDefect, "Eido storage slice out of bounds")

  # A zero-length slice at the end still exposes an address. Do not let
  # the one-past-end calculation wrap or produce an unrepresentable Int.
  let base = uint64(cast[uint](storage.data))
  let offset = uint64(start * storage.strideBytes)
  if base > maxStorageAddress or offset > maxStorageAddress - base:
    raise newException(ValueError, "Eido storage slice address exceeds target address space")
  let targetAddress = uint(base + offset)
  result.data = cast[ptr UncheckedArray[T]](targetAddress)
  result.capacity = count
  result.strideBytes = storage.strideBytes
  result.ownsMemory = false
  result.releasable = false
  result.rawBlocks = storage.rawBlocks
  result.live = true

## Returns the slot count represented by one live storage capability.
proc eidoStorageCapacity*[T](storage: EidoStorage[T]): int64 =
  requireEidoStorageLive(storage)
  storage.capacity

## Returns the byte distance between consecutive slots in a live descriptor.
proc eidoStorageStrideBytes*[T](storage: EidoStorage[T]): int64 =
  requireEidoStorageLive(storage)
  storage.strideBytes

## Returns the base byte address represented by one live Storage capability.
proc eidoStorageAddress*[T](storage: EidoStorage[T]): int64 =
  requireEidoStorageLive(storage)
  int64(cast[uint](storage.data))

## Returns the address of one inline typed slot as an object identity.
## No allocation, reference ownership, or policy bookkeeping occurs here.
proc eidoStorageSlotIdentity*[T](storage: EidoStorage[T], index: int64): int64 {.inline.} =
  int64(eidoStorageSlotAddress(storage, index))

## Reads one typed slot after live and bounds validation.
proc eidoStorageRead*[T](storage: EidoStorage[T], index: int64): T {.inline.} =
  let address = eidoStorageSlotAddress(storage, index)
  cast[ptr T](address)[]

## Writes one typed slot after live and bounds validation.
proc eidoStorageWrite*[T](storage: EidoStorage[T], index: int64, value: T) {.inline.} =
  let address = eidoStorageSlotAddress(storage, index)
  cast[ptr T](address)[] = value

## Releases or invalidates one releasable root storage capability.
proc eidoStorageRelease*[T](storage: var EidoStorage[T]) =
  requireEidoStorageLive(storage)
  if not storage.releasable:
    raise newException(
      AssertionDefect,
      "borrowed Storage views cannot release backing memory"
    )

  if storage.ownsMemory:
    if not storage.rawBlocks:
      var index = 0'i64
      while index < storage.capacity:
        let address = cast[uint](storage.data) +
          uint(index) * uint(storage.strideBytes)
        cast[ptr T](address)[] = default(T)
        inc index
    if not storage.data.isNil:
      if storage.allocationBase.isNil:
        releaseNativeBacking(storage.data)
      else:
        releaseNativeBacking(storage.allocationBase)

  storage.allocationBase = nil
  storage.data = nil
  storage.capacity = 0
  storage.strideBytes = 0
  storage.ownsMemory = false
  storage.releasable = false
  storage.rawBlocks = false
  storage.live = false
