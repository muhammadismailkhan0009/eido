## Nim-backend implementation of Eido's compiler-owned Storage<T> substrate.
## Handles are allocation-free values; only owning allocate operations acquire backing memory.

type
  EidoStorage*[T] = object
    data*: ptr UncheckedArray[T]
    capacity*: int64
    ownsMemory*: bool
    live*: bool

## Requires a live storage capability before any operation touches its backing region.
proc requireEidoStorageLive[T](storage: EidoStorage[T]) =
  if not storage.live:
    raise newException(AssertionDefect, "Eido storage access after release")

## Requires an element index to fall inside a storage capability's typed capacity.
proc requireEidoStorageIndex[T](storage: EidoStorage[T], index: int64) =
  if index < 0 or index >= storage.capacity:
    raise newException(IndexDefect, "Eido storage index out of bounds")

## Allocates and initializes one owning fixed-capacity typed storage region.
proc eidoStorageAllocate*[T](capacity: int64, initialValue: T): EidoStorage[T] =
  if capacity < 0:
    raise newException(ValueError, "Eido storage capacity cannot be negative")
  if capacity > int64(high(int) div sizeof(T)):
    raise newException(ValueError, "Eido storage capacity exceeds target address space")

  result.capacity = capacity
  result.ownsMemory = true
  result.live = true
  if capacity == 0:
    return

  let byteCount = int(capacity) * sizeof(T)
  result.data = cast[ptr UncheckedArray[T]](alloc0(byteCount))
  if result.data.isNil:
    raise newException(OutOfMemDefect, "Eido storage allocation failed")

  var index = 0
  while index < int(capacity):
    result.data[index] = initialValue
    inc index

## Creates an allocation-free typed borrowed view over raw Storage<Byte> backing.
proc eidoStorageView*[T](
  storage: EidoStorage[int8],
  byteOffset: int64,
  count: int64
): EidoStorage[T] =
  requireEidoStorageLive(storage)
  if byteOffset < 0 or count < 0:
    raise newException(IndexDefect, "Eido storage view range is invalid")
  if count > int64(high(int) div sizeof(T)):
    raise newException(ValueError, "Eido storage view exceeds target address space")

  let requiredBytes = count * int64(sizeof(T))
  if byteOffset > storage.capacity or requiredBytes > storage.capacity - byteOffset:
    raise newException(IndexDefect, "Eido storage view out of bounds")
  let targetAddress = cast[uint](storage.data) + uint(byteOffset)
  if targetAddress mod uint(alignof(T)) != 0'u:
    raise newException(ValueError, "Eido storage view is misaligned")

  result.data = cast[ptr UncheckedArray[T]](targetAddress)
  result.capacity = count
  result.ownsMemory = false
  result.live = true

## Creates an allocation-free borrowed subrange of existing typed storage.
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
    cast[uint](storage.data) + uint(start) * uint(sizeof(T))
  result.data = cast[ptr UncheckedArray[T]](targetAddress)
  result.capacity = count
  result.ownsMemory = false
  result.live = true

## Returns the typed slot count represented by one live storage capability.
proc eidoStorageCapacity*[T](storage: EidoStorage[T]): int64 =
  requireEidoStorageLive(storage)
  storage.capacity
## Reads one initialized typed slot after live and bounds validation.
proc eidoStorageRead*[T](storage: EidoStorage[T], index: int64): T =
  requireEidoStorageLive(storage)
  requireEidoStorageIndex(storage, index)
  storage.data[int(index)]

## Replaces one initialized typed slot after live and bounds validation.
proc eidoStorageWrite*[T](storage: EidoStorage[T], index: int64, value: T) =
  requireEidoStorageLive(storage)
  requireEidoStorageIndex(storage, index)
  storage.data[int(index)] = value

## Releases backing memory owned by one root storage capability and invalidates that handle.
proc eidoStorageRelease*[T](storage: var EidoStorage[T]) =
  requireEidoStorageLive(storage)
  if not storage.ownsMemory:
    raise newException(
      AssertionDefect,
      "borrowed Storage views cannot release backing memory"
    )

  var index = 0
  while index < int(storage.capacity):
    storage.data[index] = default(T)
    inc index

  if not storage.data.isNil:
    dealloc(storage.data)
  storage.data = nil
  storage.capacity = 0
  storage.ownsMemory = false
  storage.live = false
