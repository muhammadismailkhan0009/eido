## Precise non-moving stop-the-world managed heap for Eido class/interface values.
## Every managed allocation acquires and releases physical bytes only through Storage.

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

## Aligns one byte offset upward to a positive power-independent alignment.
proc eidoGcAlignUp(value, alignment: int64): int64 =
  if alignment <= 0:
    raise newException(ValueError, "Eido GC alignment must be positive")
  ((value + alignment - 1) div alignment) * alignment

## Reports whether one managed reference denotes a live object identity.
proc eidoGcIsSome*(reference: EidoManagedRef): bool =
  not reference.allocation.isNil

## Requires and returns one present managed reference.
proc eidoGcGet*(reference: EidoManagedRef): EidoManagedRef =
  if reference.allocation.isNil:
    raise newException(AssertionDefect, "optional managed value is absent")
  reference

## Returns the raw payload address behind one present managed reference.
proc eidoGcPayloadAddress*(reference: EidoManagedRef): pointer =
  if reference.allocation.isNil:
    raise newException(AssertionDefect, "managed reference is nil")
  cast[pointer](
    cast[uint](reference.allocation.storage.data) +
      uint(reference.allocation.payloadOffset)
  )

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

## Marks one managed allocation and recursively traces its managed payload fields.
proc eidoGcMark*(reference: EidoManagedRef) =
  let allocation = reference.allocation
  if allocation.isNil or allocation.marked:
    return

  allocation.marked = true
  if not allocation.traceProc.isNil:
    allocation.traceProc(eidoGcPayloadAddress(reference))

## Marks all currently registered stack roots.
proc eidoGcMarkRoots() =
  var root = eidoGcRoots
  while not root.isNil:
    if not root.slot.isNil:
      eidoGcMark(root.slot[])
    root = root.previous

## Sweeps every unmarked allocation and clears marks on survivors.
proc eidoGcSweep() =
  var previous: ptr EidoManagedAllocation
  var current = eidoGcHeapHead

  while not current.isNil:
    let next = current.next
    if current.marked:
      current.marked = false
      previous = current
    else:
      if previous.isNil:
        eidoGcHeapHead = next
      else:
        previous.next = next

      if not current.destroyProc.isNil:
        current.destroyProc(
          cast[pointer](
            cast[uint](current.storage.data) +
              uint(current.payloadOffset)
          )
        )

      var backing = current.storage
      dec eidoGcLiveAllocations
      eidoStorageRelease(backing)

    current = next

## Runs one complete precise stop-the-world mark/sweep collection.
proc eidoGcCollect*() =
  eidoGcMarkRoots()
  eidoGcSweep()
  eidoGcCollectionThreshold = max(
    64'i64,
    eidoGcLiveAllocations * 2'i64 + 1'i64
  )

## Protects one expression evaluation from collection while it contains managed
## temporaries that have not yet reached a precise source-level root slot.
template eidoGcProtected*(body: untyped): untyped =
  block:
    inc eidoGcProtectionDepth
    defer:
      dec eidoGcProtectionDepth
    body

## Runs a collection only when allocation pressure crosses the current threshold.
## Protected compound expressions defer collection until their managed temporaries
## have reached a precise source-level root or managed payload field.
proc eidoGcSafepoint*() =
  if eidoGcProtectionDepth == 0 and
      eidoGcLiveAllocations >= eidoGcCollectionThreshold:
    eidoGcCollect()

## Allocates one zeroed managed payload using Storage as the physical allocator.
proc eidoGcAllocate*(
  payloadSize,
  payloadAlignment: int64,
  traceProc: EidoGcTraceProc,
  destroyProc: EidoGcDestroyProc
): EidoManagedRef =
  if payloadSize < 0:
    raise newException(ValueError, "Eido GC payload size cannot be negative")

  let effectiveAlignment = max(payloadAlignment, int64(alignof(EidoManagedAllocation)))
  let payloadOffset = eidoGcAlignUp(
    int64(sizeof(EidoManagedAllocation)),
    effectiveAlignment
  )
  let totalSize = payloadOffset + payloadSize
  var storage = eidoStorageAllocateRaw(1, max(1'i64, totalSize))
  let allocation = cast[ptr EidoManagedAllocation](storage.data)

  allocation.storage = storage
  allocation.next = eidoGcHeapHead
  allocation.marked = false
  allocation.invariantDepth = 0
  allocation.payloadOffset = payloadOffset
  allocation.payloadSize = payloadSize
  allocation.traceProc = traceProc
  allocation.destroyProc = destroyProc

  eidoGcHeapHead = allocation
  inc eidoGcLiveAllocations
  EidoManagedRef(allocation: allocation)

## Returns the current number of live managed allocations for runtime verification.
proc eidoGcAllocationCount*(): int64 =
  eidoGcLiveAllocations

## Releases all currently unreachable managed allocations at process shutdown.
proc eidoGcShutdown*() =
  eidoGcCollect()
