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
```

`fromAddress` currently uses `Int` for the physical starting address because Eido does not yet expose a dedicated `Address` scalar type.

## Typed allocation

```eido
var values = Storage<Int>.allocate(100);
Storage<Int>.write(values, 0, 10);
Storage<Int>.write(values, 1, 20);
var second = Storage<Int>.read(values, 1);
```

`allocate(100)` reserves 100 consecutive `Int` slots. Their physical stride is `sizeof(Int)` and their alignment is derived by the backend; the caller never supplies byte sizes for typed storage.

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

Storage parameters are borrowed. Straight-line semantic analysis rejects obvious owner use after release, borrowed-view use after tracked owner release, borrowed Storage return escape, and replacement of a live owning Storage local without release. Complete control-flow/escape-aware lifetime analysis remains follow-on work.

## Current implementation boundary

Primitive and `String` typed storage are currently supported. `Storage<String>.view(raw, ...)` remains rejected because raw managed-value initialization tracking is not yet defined. Nominal/class elements remain deferred until object layout and identity move onto the Storage substrate.

The hosted Nim backend zeroes newly acquired backing memory, while Eido's source model separates slot allocation from assignment through `write`. Full initialized-slot tracking for arbitrary dynamic indexes is follow-on safety work; the current phase is proving the unified memory substrate before adding stronger compiler guarantees.

## Nim backend

The hosted implementation lives in `stdlib/native/nim/eido_storage.nim`. `EidoStorage<T>` is an allocation-free value descriptor carrying the base pointer, slot capacity, byte stride, release/ownership state, raw/typed state, and liveness.

Typed `allocate` uses `sizeof(T)` as its stride. `allocateRaw` uses the explicit `bytesPerAllocation`. `fromAddress` uses the caller-provided base without allocating backing memory. `view` and `slice` derive new descriptors without allocating backing memory.

A primitive raw-to-typed Storage program compiles and executes under Nim `--mm:none`. The current hosted trap/error path still constructs Nim exception objects, so complete runtime memory-manager independence is not yet claimed for every failure path.
