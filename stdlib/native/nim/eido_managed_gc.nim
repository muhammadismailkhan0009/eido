## Minimal Nim bridge for Eido's managed-memory runtime.
##
## Collector policy/orchestration lives in stdlib/src/managed_gc_runtime.eido.
## This module exposes only machine primitives Eido cannot yet express:
## process-global anchors, raw allocation-header/root interpretation, managed-ref
## representation, and indirect trace/destroy callback invocation.
##
## IMPORTANT: this module performs no physical allocation or reclamation.
## Eido runtime code calls Storage<Byte>.allocateRaw/release for those operations.

import eido_storage

type
  EidoManagedRef* = object
    allocation*: ptr EidoManagedAllocation

  EidoGcTraceProc* = proc(payload: pointer) {.nimcall.}
  EidoGcDestroyProc* = proc(payload: pointer) {.nimcall.}

  EidoManagedAllocation* = object
    storage*: EidoStorage[int8]
    next*: ptr EidoManagedAllocation
    marked*: bool
    invariantDepth*: int
    payloadOffset*: int64
    payloadSize*: int64
    traceProc*: EidoGcTraceProc
    destroyProc*: EidoGcDestroyProc

  EidoGcRoot* = object
    previous*: ptr EidoGcRoot
    slot*: ptr EidoManagedRef

var
  eidoGcHeapHead: ptr EidoManagedAllocation
  eidoGcRoots: ptr EidoGcRoot
  eidoGcLiveAllocations: int64
  eidoGcCollectionThreshold = 64'i64
  eidoGcProtectionDepth: int

## Converts one private integer handle to its allocation header pointer.
proc eidoGcAllocation(handle: int64): ptr EidoManagedAllocation =
  cast[ptr EidoManagedAllocation](uint(handle))

## Converts one allocation header pointer to its private integer handle.
proc eidoGcAllocationHandle(
  allocation: ptr EidoManagedAllocation
): int64 =
  int64(cast[uint](allocation))

## Returns the raw payload address behind one allocation header.
proc eidoGcPayloadAddress(
  allocation: ptr EidoManagedAllocation
): pointer =
  if allocation.isNil:
    raise newException(AssertionDefect, "managed allocation is nil")
  cast[pointer](
    cast[uint](allocation.storage.data) +
      uint(allocation.payloadOffset)
  )

## Reports whether one managed reference denotes an object identity.
proc eidoGcIsSome*(reference: EidoManagedRef): bool =
  not reference.allocation.isNil

## Requires and returns one present managed reference.
proc eidoGcGet*(reference: EidoManagedRef): EidoManagedRef =
  if reference.allocation.isNil:
    raise newException(AssertionDefect, "optional managed value is absent")
  reference

## Converts a backend managed reference to the opaque Eido runtime handle.
proc eidoGcHandle*(reference: EidoManagedRef): int64 =
  eidoGcAllocationHandle(reference.allocation)

## Converts an opaque Eido runtime handle to a backend managed reference.
proc eidoGcRefFromHandle*(handle: int64): EidoManagedRef =
  EidoManagedRef(allocation: eidoGcAllocation(handle))

## Converts one generated trace callback to an opaque address passed through Eido.
proc eidoGcTraceAddress*(traceProc: EidoGcTraceProc): int64 =
  int64(cast[uint](traceProc))

## Converts one generated destroy callback to an opaque address passed through Eido.
proc eidoGcDestroyAddress*(destroyProc: EidoGcDestroyProc): int64 =
  int64(cast[uint](destroyProc))

## Returns the raw payload address behind one present managed reference.
proc eidoGcPayloadAddress*(reference: EidoManagedRef): pointer =
  eidoGcPayloadAddress(reference.allocation)

## Returns a typed pointer over one managed payload without allocating.
proc eidoGcPayload*[T](reference: EidoManagedRef): ptr T =
  cast[ptr T](eidoGcPayloadAddress(reference))

## Returns the backend-only invariant recursion counter stored outside the Eido payload.
proc eidoGcInvariantDepth*(reference: EidoManagedRef): var int =
  if reference.allocation.isNil:
    raise newException(AssertionDefect, "managed reference is nil")
  reference.allocation.invariantDepth

## Pushes one stack-owned precise root descriptor.
proc eidoGcPushRoot*(root: ptr EidoGcRoot, slot: ptr EidoManagedRef) =
  root.previous = eidoGcRoots
  root.slot = slot
  eidoGcRoots = root

## Pops the most recently pushed precise root descriptor.
proc eidoGcPopRoot*(root: ptr EidoGcRoot) =
  if eidoGcRoots != root:
    raise newException(
      AssertionDefect,
      "Eido GC roots must be popped in stack order"
    )
  eidoGcRoots = root.previous
  root.previous = nil
  root.slot = nil

## Protects one expression evaluation while managed temporaries have not yet
## reached precise Eido root slots. Collection policy itself lives in Eido.
template eidoGcProtected*(body: untyped): untyped =
  block:
    inc eidoGcProtectionDepth
    defer:
      dec eidoGcProtectionDepth
    body

## Returns the current number of registered allocations for verification/tooling.
proc eidoGcAllocationCount*(): int64 =
  eidoGcLiveAllocations

# ---------------------------------------------------------------------------
# Private ManagedGcNative ABI consumed only by managed_gc_runtime.eido.
# ---------------------------------------------------------------------------

proc eido_native_method_ManagedGcNative_headerSize*(): int64 =
  int64(sizeof(EidoManagedAllocation))

proc eido_native_method_ManagedGcNative_headerAlignment*(): int64 =
  int64(alignof(EidoManagedAllocation))

proc eido_native_method_ManagedGcNative_initialize*(
  backing: EidoStorage[int8],
  payloadOffset,
  payloadSize,
  traceAddress,
  destroyAddress: int64
): int64 =
  if not backing.live or not backing.ownsMemory or backing.data.isNil:
    raise newException(
      AssertionDefect,
      "managed allocation requires owning live Storage<Byte>"
    )
  if payloadOffset < int64(sizeof(EidoManagedAllocation)) or
      payloadSize < 0 or
      payloadOffset + payloadSize > backing.strideBytes:
    raise newException(
      ValueError,
      "managed payload does not fit Storage<Byte> backing"
    )

  let allocation = cast[ptr EidoManagedAllocation](backing.data)
  allocation.storage = backing
  allocation.next = nil
  allocation.marked = false
  allocation.invariantDepth = 0
  allocation.payloadOffset = payloadOffset
  allocation.payloadSize = payloadSize
  allocation.traceProc =
    if traceAddress == 0:
      nil
    else:
      cast[EidoGcTraceProc](uint(traceAddress))
  allocation.destroyProc =
    if destroyAddress == 0:
      nil
    else:
      cast[EidoGcDestroyProc](uint(destroyAddress))

  eidoGcAllocationHandle(allocation)

proc eido_native_method_ManagedGcNative_backing*(
  handle: int64
): EidoStorage[int8] =
  let allocation = eidoGcAllocation(handle)
  if allocation.isNil:
    raise newException(AssertionDefect, "managed allocation is nil")
  allocation.storage

proc eido_native_method_ManagedGcNative_heapHead*(): int64 =
  eidoGcAllocationHandle(eidoGcHeapHead)

proc eido_native_method_ManagedGcNative_setHeapHead*(handle: int64) =
  eidoGcHeapHead = eidoGcAllocation(handle)

proc eido_native_method_ManagedGcNative_next*(handle: int64): int64 =
  let allocation = eidoGcAllocation(handle)
  if allocation.isNil:
    return 0
  eidoGcAllocationHandle(allocation.next)

proc eido_native_method_ManagedGcNative_setNext*(
  handle,
  nextHandle: int64
) =
  let allocation = eidoGcAllocation(handle)
  if allocation.isNil:
    raise newException(AssertionDefect, "managed allocation is nil")
  allocation.next = eidoGcAllocation(nextHandle)

proc eido_native_method_ManagedGcNative_marked*(handle: int64): bool =
  let allocation = eidoGcAllocation(handle)
  not allocation.isNil and allocation.marked

proc eido_native_method_ManagedGcNative_setMarked*(
  handle: int64,
  marked: bool
) =
  let allocation = eidoGcAllocation(handle)
  if allocation.isNil:
    raise newException(AssertionDefect, "managed allocation is nil")
  allocation.marked = marked

proc eido_native_method_ManagedGcNative_liveAllocations*(): int64 =
  eidoGcLiveAllocations

proc eido_native_method_ManagedGcNative_setLiveAllocations*(count: int64) =
  if count < 0:
    raise newException(
      AssertionDefect,
      "managed allocation count cannot be negative"
    )
  eidoGcLiveAllocations = count

proc eido_native_method_ManagedGcNative_collectionThreshold*(): int64 =
  eidoGcCollectionThreshold

proc eido_native_method_ManagedGcNative_setCollectionThreshold*(
  threshold: int64
) =
  if threshold <= 0:
    raise newException(
      AssertionDefect,
      "managed collection threshold must be positive"
    )
  eidoGcCollectionThreshold = threshold

proc eido_native_method_ManagedGcNative_rootHead*(): int64 =
  int64(cast[uint](eidoGcRoots))

proc eido_native_method_ManagedGcNative_rootNext*(rootHandle: int64): int64 =
  let root = cast[ptr EidoGcRoot](uint(rootHandle))
  if root.isNil:
    return 0
  int64(cast[uint](root.previous))

proc eido_native_method_ManagedGcNative_rootAllocation*(
  rootHandle: int64
): int64 =
  let root = cast[ptr EidoGcRoot](uint(rootHandle))
  if root.isNil or root.slot.isNil:
    return 0
  eidoGcHandle(root.slot[])

proc eido_native_method_ManagedGcNative_protectionDepth*(): int64 =
  int64(eidoGcProtectionDepth)

proc eido_native_method_ManagedGcNative_trace*(handle: int64) =
  let allocation = eidoGcAllocation(handle)
  if allocation.isNil or allocation.traceProc.isNil:
    return
  allocation.traceProc(eidoGcPayloadAddress(allocation))

proc eido_native_method_ManagedGcNative_destroy*(handle: int64) =
  let allocation = eidoGcAllocation(handle)
  if allocation.isNil or allocation.destroyProc.isNil:
    return
  allocation.destroyProc(eidoGcPayloadAddress(allocation))
