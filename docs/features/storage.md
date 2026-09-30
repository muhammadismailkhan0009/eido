# Storage

`Storage<T>` is Eido's single compiler-owned low-level memory capability. It models a consecutive sequence of allocation slots. Typed storage derives each slot's size and alignment from `T`; raw byte storage receives an explicit bytes-per-allocation stride.

The API is static/type-associated so the capability value itself remains allocation-free. Higher-level objects, arrays, strings, arenas, pools, pages, vectors, and other policies are intended to build above this same substrate.

## API surface

```eido
Storage<T>.allocate(Int allocations) returns Storage<T>;

Storage<Byte>.allocateRaw(
    Int allocations,
    Int bytesPerAllocation
) returns Storage<Byte>;

Storage<Byte>.fromAddress(
    Int startingAddress,
    Int allocations,
    Int bytesPerAllocation
) returns Storage<Byte>;

Storage<T>.view(
    Storage<Byte> raw,
    Int start
) returns Storage<T>;

Storage<T>.write(Storage<T> storage, Int index, T value);
Storage<T>.read(Storage<T> storage, Int index) returns T;
Storage<T>.capacity(Storage<T> storage) returns Int;

Storage<T>.slice(
    Storage<T> storage,
    Int start,
    Int count
) returns Storage<T>;

Storage<T>.release(Storage<T> storage);

Storage<T>.size() returns Int;
Storage<T>.alignment() returns Int;
```

`size()` and `alignment()` report the target representation of one `T` slot through Storage itself. Other subsystems do not define parallel size/alignment APIs.

`fromAddress` currently uses `Int` for the physical starting address because Eido does not yet expose a dedicated `Address` scalar type.

## Typed allocation

```eido
var values = Storage<Int>.allocate(100);
Storage<Int>.write(values, 0, 10);
Storage<Int>.write(values, 1, 20);
var second = Storage<Int>.read(values, 1);
```

`allocate(100)` reserves 100 consecutive `Int` slots. Its stride comes from `Storage<Int>.size()` and its alignment from `Storage<Int>.alignment()`; the caller never supplies byte sizes for typed storage. Typed allocation does not own a separate physical allocator: it acquires raw `Storage<Byte>` backing through `allocateRaw`, then adopts the same bytes as an owning typed descriptor.

Allocation and assignment are intentionally separate. This allows every slot to receive a different value instead of requiring one initial value to be duplicated across the whole region.

## Raw consecutive blocks

```eido
var raw = Storage<Byte>.allocateRaw(4, 8);
```

This creates four consecutive raw allocation blocks, each eight bytes wide. Capacity is four, not 32. The address of raw block `i` is conceptually `base + i * 8`.

Raw storage becomes typed through `view` before ordinary typed access:

```eido
var ints = Storage<Int>.view(raw, 0);
Storage<Int>.write(ints, 1, 55);
var value = Storage<Int>.read(ints, 1);
```

The view is allocation-free. It preserves the raw block stride, so each raw allocation block becomes one typed slot. `view` checks that `T` fits inside one raw block and that the resulting addresses satisfy `T`'s alignment.

The same raw backing may be viewed from different block starts for different supported element types. Nominal/class elements remain deferred until Eido classes themselves have a non-Nim-reference physical representation.

## Explicit starting address

```eido
var region = Storage<Byte>.fromAddress(
    536870912,
    16,
    64
);
```

`fromAddress` uses the supplied address as block zero, then advances by `bytesPerAllocation` for each following block. It does not ask the hosted allocator to choose a base address.

The resulting root capability is releasable, but release only invalidates the capability because Storage did not acquire the externally addressed backing memory.

## Slice and capacity

```eido
var values = Storage<Int>.allocate(100);
var middle = Storage<Int>.slice(values, 20, 10);
var count = Storage<Int>.capacity(middle);
```

`slice` is allocation-free and works in slots, never bytes. The example represents original slots 20 through 29 and reports capacity 10.

## Ownership and release

`allocate` and `allocateRaw` create owning roots whose backing memory is returned on `release`. `fromAddress` creates a releasable external root whose backing is not freed. `view` and `slice` create borrowed capabilities and cannot release the backing region.

Storage parameters are borrowed. Borrowed Storage may cross a callable result boundary when the callable's result provenance is statically inferable; callers retain the borrowed/non-releasable status. Straight-line semantic analysis rejects obvious owner use after release, borrowed-view use after a tracked owner release, releasing a borrowed callable result, and replacement of a live owning Storage local without release. Complete control-flow/escape-aware lifetime analysis remains follow-on work.

## Arena memory policy

The first memory-management policy implemented above Storage is ordinary Eido source in `stdlib/src/arena.eido`:

```eido
var arena = Arena<Int>.create(100);
var first = arena.allocate(10);
var second = arena.allocate(20);

Storage<Int>.write(first, 0, 5);
var free = arena.remaining();

arena.reset();
arena.release();
```

`Arena<T>` owns one `Storage<T>` root and a sequential cursor. `allocate(count)` returns a borrowed `Storage<T>.slice`, `remaining()` reports unused slots, `reset()` rewinds the cursor without reallocating, and `release()` releases the single backing root. Sizing, alignment, addresses, and physical allocation remain Storage responsibilities.

The Arena capacity precondition may query `Storage.capacity` because that compiler-owned operation is observational and explicitly recognized as contract-safe. `Storage.size()` and `Storage.alignment()` are likewise verified observational queries. Allocation, mutation, and release remain effectful or conservatively unverified.

Allocations returned by an Arena become logically invalid after `reset()` or `release()`; full compiler lifetime invalidation for that relationship is intentionally deferred to the future borrow/lifetime analysis.

## Current implementation boundary

Primitive and `String` typed storage are currently supported. `Storage<String>.view(raw, ...)` remains rejected because raw managed-value initialization tracking is not yet defined. Nominal/class elements remain deferred until object layout and identity move onto the Storage substrate.

The hosted Nim backend zeroes newly acquired backing memory, while Eido's source model separates slot allocation from assignment through `write`. Full initialized-slot tracking for arbitrary dynamic indexes is follow-on safety work; the current phase is proving the unified memory substrate before adding stronger compiler guarantees.

## Nim backend

The hosted implementation lives in `stdlib/native/nim/eido_storage.nim`. `EidoStorage<T>` is an allocation-free value descriptor carrying the base pointer, slot capacity, byte stride, release/ownership state, raw/typed state, and liveness.

`allocateRaw` is the single hosted physical allocation path and uses the explicit `bytesPerAllocation`. Typed `allocate` calls that raw path with `sizeof(T)` and then reinterprets the same owning descriptor as `Storage<T>` without acquiring a second region. `fromAddress` uses the caller-provided base without allocating backing memory. `view` and `slice` derive borrowed descriptors without allocating backing memory. `size()` and `alignment()` expose the backend's `sizeof(T)`/`alignof(T)` facts through the unified Storage API.

A primitive raw-to-typed Storage program compiles and executes under Nim `--mm:none`. The current hosted trap/error path still constructs Nim exception objects, so complete runtime memory-manager independence is not yet claimed for every failure path.
