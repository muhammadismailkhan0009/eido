## Nim-backend implementation of Eido's compiler-owned Storage<T> substrate.
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

## Transfers one owning raw allocation descriptor into an owning typed descriptor.
## No backing memory is acquired here; the bytes always come from allocateRaw.
proc eidoStorageAdoptRaw[T](storage: EidoStorage[int8]): EidoStorage[T] =
  requireEidoStorageLive(storage)
  if not storage.rawBlocks or not storage.ownsMemory or not storage.releasable:
    raise newException(
      AssertionDefect,
      "Eido typed allocation requires owning raw Storage<Byte>"
    )
  if int64(sizeof(T)) > storage.strideBytes:
    raise newException(
      ValueError,
      "Eido typed allocation type does not fit raw allocation block"
    )

  let targetAddress = cast[uint](storage.data)
  if not storage.data.isNil and targetAddress mod uint(alignof(T)) != 0'u:
    raise newException(ValueError, "Eido typed allocation is misaligned")
  if storage.capacity > 1 and
      uint(storage.strideBytes) mod uint(alignof(T)) != 0'u:
    raise newException(ValueError, "Eido typed allocation stride is misaligned")

  result.data = cast[ptr UncheckedArray[T]](storage.data)
  result.capacity = storage.capacity
  result.strideBytes = storage.strideBytes
  result.ownsMemory = true
  result.releasable = true
  result.rawBlocks = false
  result.live = true

## Allocates one owning typed region by composing the raw allocation substrate.
proc eidoStorageAllocate*[T](allocations: int64): EidoStorage[T] =
  let raw = eidoStorageAllocateRaw(allocations, int64(sizeof(T)))
  eidoStorageAdoptRaw[T](raw)

## Reports the target byte width of one typed Storage slot.
proc eidoStorageSize*[T](): int64 =
  int64(sizeof(T))

## Reports the target alignment required by one typed Storage slot.
proc eidoStorageAlignment*[T](): int64 =
  int64(alignof(T))

## Creates a releasable raw block sequence beginning at an explicit address.
proc eidoStorageFromAddress*(
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
  result.releasable = true
  result.rawBlocks = true
  result.live = true

## Creates an allocation-free typed view over consecutive raw allocation blocks.
proc eidoStorageView*[T](
  storage: EidoStorage[int8],
  start: int64
): EidoStorage[T] =
  requireEidoStorageLive(storage)
  if not storage.rawBlocks:
    raise newException(ValueError, "Eido storage view requires raw Storage<Byte>")
  if start < 0 or start >= storage.capacity:
    raise newException(IndexDefect, "Eido storage view out of bounds")
  if int64(sizeof(T)) > storage.strideBytes:
    raise newException(ValueError, "Eido storage view type does not fit raw allocation block")

  let targetAddress =
    cast[uint](storage.data) + uint(start) * uint(storage.strideBytes)
  if targetAddress mod uint(alignof(T)) != 0'u:
    raise newException(ValueError, "Eido storage view is misaligned")

  let viewCapacity = storage.capacity - start
  if viewCapacity > 1 and
      uint(storage.strideBytes) mod uint(alignof(T)) != 0'u:
    raise newException(ValueError, "Eido storage view is misaligned")

  result.data = cast[ptr UncheckedArray[T]](targetAddress)
  result.capacity = viewCapacity
  result.strideBytes = storage.strideBytes
  result.ownsMemory = false
  result.releasable = false
  result.rawBlocks = false
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
