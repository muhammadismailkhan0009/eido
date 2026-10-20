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

## Requires a live storage capability before any operation touches its backing region.
proc requireEidoStorageLive[T](storage: EidoStorage[T]) =
  if not storage.live:
    raise newException(AssertionDefect, "Eido storage access after release")

## Requires an element index to fall inside a storage capability's slot capacity.
proc requireEidoStorageIndex[T](storage: EidoStorage[T], index: int64) =
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

## Returns the byte address of one validated storage slot.
proc eidoStorageSlotAddress[T](storage: EidoStorage[T], index: int64): uint =
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

## Reports the target byte width of one typed Storage slot.
proc eidoStorageSize*[T](): int64 =
  int64(sizeof(T))

## Reports the target alignment required by one typed Storage slot.
proc eidoStorageAlignment*[T](): int64 =
  int64(alignof(T))

## Creates an owning raw descriptor for an existing allocation at an explicit address.
## The caller must provide an address whose lifetime Storage is responsible for.
proc eidoStorageFromAddress*(
  startingAddress: int64,
  allocations: int64,
  bytesPerAllocation: int64
): EidoStorage[int8] =
  if startingAddress < 0:
    raise newException(ValueError, "Eido storage starting address cannot be negative")
  requireEidoStorageLayout(allocations, bytesPerAllocation)
  if allocations > 0 and startingAddress == 0:
    raise newException(ValueError, "owning Storage cannot use a nil address")

  result.data = cast[ptr UncheckedArray[int8]](uint(startingAddress))
  result.capacity = allocations
  result.strideBytes = bytesPerAllocation
  result.ownsMemory = true
  result.releasable = true
  result.rawBlocks = true
  result.live = true

## Creates a non-owning raw descriptor for existing memory at an explicit address.
## Borrowed address storage may be read/written but cannot release its backing memory.
proc eidoStorageBorrowAddress*(
  startingAddress: int64,
  allocations: int64,
  bytesPerAllocation: int64
): EidoStorage[int8] =
  if startingAddress < 0:
    raise newException(ValueError, "Eido storage starting address cannot be negative")
  requireEidoStorageLayout(allocations, bytesPerAllocation)

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

  let targetAddress =
    cast[uint](storage.data) + uint(start) * uint(storage.strideBytes)
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

## Returns the base byte address represented by one live Storage capability.
proc eidoStorageAddress*[T](storage: EidoStorage[T]): int64 =
  requireEidoStorageLive(storage)
  int64(cast[uint](storage.data))

## Reads one typed slot after live and bounds validation.
proc eidoStorageRead*[T](storage: EidoStorage[T], index: int64): T =
  let address = eidoStorageSlotAddress(storage, index)
  cast[ptr T](address)[]

## Writes one typed slot after live and bounds validation.
proc eidoStorageWrite*[T](storage: EidoStorage[T], index: int64, value: T) =
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
      dealloc(storage.data)

  storage.data = nil
  storage.capacity = 0
  storage.strideBytes = 0
  storage.ownsMemory = false
  storage.releasable = false
  storage.rawBlocks = false
  storage.live = false
