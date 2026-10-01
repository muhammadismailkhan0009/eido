## Minimal machine bridge for Eido's managed-memory runtime.
##
## GC policy, heap state, allocation-header layout, allocation, mark/sweep, and
## Storage ownership live in stdlib/memory/managed/managed_gc_runtime.eido.
## This module keeps only representation/pointer operations Eido cannot yet express.

type
  EidoManagedRef* = object
    allocation*: pointer

  EidoGcTraceProc* = proc(payload: pointer) {.nimcall.}
  EidoGcDestroyProc* = proc(payload: pointer) {.nimcall.}

  EidoGcRoot* = object
    previous*: ptr EidoGcRoot
    slot*: ptr EidoManagedRef

var
  eidoGcRoots: ptr EidoGcRoot
  eidoGcProtectionDepth: int

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
  int64(cast[uint](reference.allocation))

## Converts an opaque Eido runtime handle to a backend managed reference.
proc eidoGcRefFromHandle*(handle: int64): EidoManagedRef =
  EidoManagedRef(allocation: cast[pointer](uint(handle)))

## Converts one generated trace callback to an opaque address passed through Eido.
proc eidoGcTraceAddress*(traceProc: EidoGcTraceProc): int64 =
  int64(cast[uint](traceProc))

## Converts one generated destroy callback to an opaque address passed through Eido.
proc eidoGcDestroyAddress*(destroyProc: EidoGcDestroyProc): int64 =
  int64(cast[uint](destroyProc))

## Returns a typed pointer at one Eido-owned payload offset.
proc eidoGcPayloadAt*[T](
  reference: EidoManagedRef,
  payloadOffset: int64
): ptr T =
  if reference.allocation.isNil:
    raise newException(AssertionDefect, "managed reference is nil")
  cast[ptr T](cast[uint](reference.allocation) + uint(payloadOffset))

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
## reached precise Eido root slots.
template eidoGcProtected*(body: untyped): untyped =
  block:
    inc eidoGcProtectionDepth
    defer:
      dec eidoGcProtectionDepth
    body

# ---------------------------------------------------------------------------
# Private ManagedGcNative ABI consumed only by managed_gc_runtime.eido.
# ---------------------------------------------------------------------------

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

proc eido_native_method_ManagedGcNative_trace*(
  allocation,
  payloadOffset,
  traceAddress: int64
) =
  if allocation == 0 or traceAddress == 0:
    return
  let traceProc = cast[EidoGcTraceProc](uint(traceAddress))
  traceProc(cast[pointer](uint(allocation) + uint(payloadOffset)))

proc eido_native_method_ManagedGcNative_destroy*(
  allocation,
  payloadOffset,
  destroyAddress: int64
) =
  if allocation == 0 or destroyAddress == 0:
    return
  let destroyProc = cast[EidoGcDestroyProc](uint(destroyAddress))
  destroyProc(cast[pointer](uint(allocation) + uint(payloadOffset)))
