# Storage

`Storage<T>` is Eido's low-level memory capability. Its public generic behavior is defined in Eido under `stdlib/storage/storage.eido`; only the raw `Storage<Byte>` substrate and irreducible machine-representation operations are compiler/backend supplied.

The intended layering is:

```text
backend/compiler raw capability
        Storage<Byte>
             ↓
stdlib/storage/storage.eido
        Storage<T>
             ↓
strings, heaps, arenas, pools, collections, memory policies
```

## Public API

Typed Storage exposes:

```eido
Storage<T>.allocate(Int allocations) returns Storage<T>;
Storage<T>.reserveAt(Storage<Byte> region, Int address, Int count) returns Storage<T>;
Storage<T>.view(Storage<Byte> raw, Int start) returns Storage<T>;
Storage<T>.viewAt(Storage<Byte> raw, Int byteOffset) returns Storage<T>;
Storage<T>.slice(Storage<T> storage, Int start, Int count) returns Storage<T>;
Storage<T>.capacity(Storage<T> storage) returns Int;
Storage<T>.strideBytes(Storage<T> storage) returns Int;
Storage<T>.address(Storage<T> storage) returns Int;
Storage<T>.read(Storage<T> storage, Int index) returns T;
Storage<T>.write(Storage<T> storage, Int index, T value);
Storage<T>.release(Storage<T> storage);
Storage<T>.size() returns Int;
Storage<T>.alignment() returns Int;
```

Raw byte Storage additionally provides the physical-memory operations:

```eido
Storage<Byte>.allocateRaw(Int allocations, Int bytesPerAllocation)
    returns Storage<Byte>;
Storage<Byte>.reserveAt(
    Storage<Byte> region, Int address, Int count
) returns Storage<Byte>;
Storage<Byte>.borrowAddress(
    Int startingAddress,
    Int allocations,
    Int bytesPerAllocation
) returns Storage<Byte>;
```

`size()` and `alignment()` expose the target representation facts for `T`. Memory-policy compile-time code can query the equivalent dynamic facts through `StorageInfo.sizeOf(type)` and `StorageInfo.alignmentOf(type)`.

`strideBytes(storage)` reports the actual byte distance between consecutive slots in a live descriptor, including padded raw blocks, typed views and slices. It is not the element size. Native contiguous byte I/O requires stride 1; observation does not allocate, change ownership, or bypass liveness validation.

## Typed Storage is Eido code

Typed allocation is ordinary Eido orchestration, including alignment:

```eido
function allocate(Int count) returns Storage<T> {
    // Contracts and zero-count handling omitted for brevity.
    var stride = Storage<T>.size();
    var alignment = Storage<T>.alignment();
    var raw = Storage<Byte>.allocateRaw(1, count * stride + alignment - 1);
    var aligned = Alignment.alignUp(Storage<Byte>.address(raw), alignment);
    var owned = Storage<Byte>.compilerRebaseOwned(raw, aligned, count, stride);
    return Storage<T>.compilerFromRaw(owned);
}
```

There is exactly **one physical native allocation**. The private `compilerRebaseOwned`
bridge carries its original allocation base for correct native release; no
separate `compilerAllocateRawAligned` native path exists.

The `compiler*` operations used inside the SDK implementation are private representation bridges, not public Eido API. Ordinary user source is rejected if it tries to call them. They exist because Eido does not currently expose pointer casts/typed loads as general source-language operations.

The same pattern applies to views, slicing, capacity/address observation, release, and typed read/write: policy and orchestration live in Eido while the backend performs only the irreducible representation conversion or typed machine load/store.

Normal module projects therefore do **not** receive a compiler-synthesized public `Storage<T>` API. They receive the exported `eido.stdlib.storage.Storage` generic class and its Eido method bodies. `Storage<Byte>` is materialized as the raw compiler capability needed underneath that class.

## Allocation

```eido
var values = Storage<Int>.allocate(100);
Storage<Int>.write(values, 0, 10);
Storage<Int>.write(values, 1, 20);
var second = Storage<Int>.read(values, 1);
```

`allocate(100)` obtains one native backing allocation with enough space for 100 typed slots and alignment padding. Eido computes the aligned start and exposes the required slot stride; no second native allocation occurs.

Allocation and assignment are deliberately separate so each slot can receive a different value.

## Raw blocks and typed views

```eido
var raw = Storage<Byte>.allocateRaw(4, 8);
var ints = Storage<Int>.view(raw, 0);
Storage<Int>.write(ints, 1, 55);
```

Raw storage models consecutive fixed-stride blocks. `allocateRaw(4, 8)` therefore has capacity 4, not 32. `view` borrows one or more of those blocks and validates that `T` fits and is correctly aligned before the private representation bridge exposes them as `Storage<T>`.

`viewAt` addresses one typed value at a byte offset within a raw block. The raw byte capability retains the remaining block bounds so the typed bridge can perform the same fit/alignment validation.

## Slice and capacity

```eido
var values = Storage<Int>.allocate(100);
var middle = Storage<Int>.slice(values, 20, 10);
var count = Storage<Int>.capacity(middle);
```

`slice` is allocation-free and works in logical slots. Typed `slice` converts the typed descriptor to its raw descriptor, applies raw slicing, then converts the borrowed descriptor back to `Storage<T>`.

## Explicit placement and borrowing

`allocateRaw(count, stride)` obtains **new native backing** and returns a native-owning
Storage. `reserveAt(region, address, count)` instead places a typed Storage
capability in an **existing region** without any native allocation. The address
must be correctly aligned, and all requested slots must fit inside the backing
region. `release()` on explicit placement invalidates that Storage handle; it
does **not** deallocate or return the backing region to a native heap. Reuse
and overlap management belong to the caller's arena/pool or program.

```eido
var region = Storage<Byte>.allocateRaw(1, 4096); // Linux backing
var address = Alignment.alignUp(Storage<Byte>.address(region), Storage<Int>.alignment());
var values = Storage<Int>.reserveAt(region, address, 8);
Storage<Int>.write(values, 0, 42);
Storage<Int>.release(values); // End placement; region remains allocated.
Storage<Byte>.release(region); // Free native backing separately.
```

On bare metal, `region` can be introduced with `borrowAddress(SRAM_BASE, 1,
CAPACITY)` rather than native allocation. No heap allocator is required for
`reserveAt()`. In either case, `borrowAddress()` merely provides non-owning
access to existing accessible memory, without claiming or releasing it. The hosted native backend rejects a nonempty null region and address ranges that cannot fit the target pointer width and Eido's signed `Int` address representation. This is arithmetic validation, not proof that an arbitrary non-null address is mapped or accessible.

The compiler detects overlapping **literal Byte reservations in straight-line
callable bodies** when both reference the same named region and neither has
been released. Nonliteral addresses, other layouts, control-flow branches and
interprocedural aliases are not yet covered by static overlap analysis. No
mandatory runtime allocation registry is installed; caller-managed heaps
can provide stronger overlap guarantees when needed.

## Ownership and release

- Native `allocate()`/`allocateRaw()` results release through their native
  allocator (not through the memory's presented aligned address).
- `reserveAt()` results are releasable **placement handles**; release invalidates
  that handle but does not free the region's backing. The backing must remain
  available for every live placement or view.
- `borrowAddress()`, `view()`, `viewAt()` and `slice()` are non-owning and cannot
  release their backing memory.

The former public `fromAddress()` operation could reconstruct a deallocatable
owner from an arbitrary address. It has been removed. Only compiler-identified
embedded SDK runtime sources may use the release-only
`compilerReleaseNativeAddress(originalBase)` bridge. It does not reconstruct a
readable or owning descriptor, nor authenticate the pointer's actual allocation
history. The runtime must supply a live original native base exactly once. A future public `adoptAddress()` requires a provable ownership-transfer
contract; it is **not** available yet.

Storage parameters are borrowed. Straight-line semantic analysis rejects
obvious use-after-release, releasing borrowed results/views, borrowed escape
into owning Storage fields, and overwriting a live owned Storage local without
releasing it first. A released local may receive a fresh allocation via `set`;
known views and explicit placements into the released backing remain invalid
when that local is reused. This is not yet a complete lifetime/alias checker.

### Pure Alignment utility

`Alignment.alignUp(address, alignment)`, `padding(address, alignment)`,
`alignDown(address, alignment)`, and `isAligned(address, alignment)` perform
only arithmetic/validation. `padding` and `isAligned` do not need to form an out-of-range aligned address; `alignUp` checks that the rounded result fits `Int`. `Alignment` never allocates or references Storage.
GC/RC use a separate SDK-internal `AlignedHeapBacking` helper to retain
the original heap base in a single Int-sized preheader immediately before
the aligned region. Release no longer needs a saved allocation size. Typed
reservation validates requested alignment in Eido; both private reservation
and rebasing bridges share native backing-range validation.

## Current element support

Primitive, `String`, and concrete nominal **class** elements are supported,
including generic instances such as `Storage<Box<Int>>`.

`Storage<Class>` reserves contiguous **inline class payloads**. Its stride and
alignment come from the existing class layout, not the size of a reference.
The raw allocator remains the same `Storage<Byte>.allocateRaw` implementation.
A slot's address is its class identity; reading or borrowing that identity
does not allocate an object through the memory policy.

```eido
class Account { Int balance; }
function main() returns Int {
    var accounts = Storage<Account>.allocate(2);
    Storage<Account>.write(accounts, 0, Account { balance = 10; });
    Storage<Account>.write(accounts, 1, Account { balance = 20; });
    var first = ref Storage<Account>.read(accounts, 0);
    var total = first.balance + Storage<Account>.read(accounts, 1).balance;
    Storage<Account>.release(accounts);
    return total;
}
```

A fresh construction directly inside `write` initializes that slot in place
without first acquiring an object through the selected managed policy.
When writing an existing class object into inline Storage, use explicit
`copy original`. The existing detached graph-copy rules apply, with the
copy's root allocated directly in the destination slot. `ref original` is
**not** a valid write to an inline class-payload slot: a reference is not
another object payload. Directly writing an arbitrary class-returning
function/method result is also deferred, because its managed temporary
would otherwise be copied implicitly into raw Storage; instead, explicitly
copy an existing object or construct a fresh literal directly in the slot. Use `ref Storage<Class>.read(...)` to reference an
already initialized slot, or `copy Storage<Class>.read(...)` to create an
independent object using the selected policy.

`release` frees native backing only when Storage owns that native allocation; explicit placements instead invalidate their own handles. Any references into
released slots become invalid; Storage does not track such aliases or
control their lifetime. Read/write through borrowed `view`, `viewAt`, and
`slice` use the same inline representation without owning the backing.
As with other raw memory, **only read class slots after initialization**;
uninitialized slots have no safe class value or runtime initialization trap.

**Policy boundary:** Explicit Storage regions are not implicitly owned or
traced by the selected GC/RC policy. The standard policies only reclaim
objects that they themselves allocate. References to manually allocated
Storage objects are not GC roots, and references *inside* an inline payload
do not automatically protect other managed allocations. A memory policy
that wants to manage or trace external Storage must implement that
bookkeeping explicitly in Eido. No compiler `storageRegionEnter` or
`storageRegionLeave` callback is mandatory.

Interface-valued elements, optional inline class elements, and nested
owning Storage descriptors are not supported yet. The current borrow
analysis is not a complete lifetime/alias checker.

## Backend boundary

The hosted Nim implementation lives in `stdlib/native/nim/eido_storage.nim`. It owns:

- the allocation-free raw descriptor representation;
- raw physical allocation, explicit bounded placement, and non-owning address descriptors;
- bounds/liveness checks;
- private raw↔typed descriptor reinterpretation;
- typed machine load/store;
- target `size`/`alignment` facts.

The public typed allocation/view/slice/capacity/address/read/write/release algorithms are Eido methods. Generated real-project code calls those Eido methods; it does not lower public typed operations directly to `eidoStorageAllocate[T]`, `eidoStorageView[T]`, `eidoStorageSlice[T]`, or `eidoStorageRelease[T]`.

Because memory-management policies are themselves implemented above Storage, the compiler does not inject selected-policy lifetime or execution-boundary instrumentation inside `stdlib/storage/storage.eido` method bodies. Instrumenting Storage would make a policy recursively re-enter itself while allocating, reading, writing, or releasing its own bookkeeping storage.
