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
Storage<T>.view(Storage<Byte> raw, Int start) returns Storage<T>;
Storage<T>.viewAt(Storage<Byte> raw, Int byteOffset) returns Storage<T>;
Storage<T>.slice(Storage<T> storage, Int start, Int count) returns Storage<T>;
Storage<T>.capacity(Storage<T> storage) returns Int;
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
Storage<Byte>.fromAddress(
    Int startingAddress,
    Int allocations,
    Int bytesPerAllocation
) returns Storage<Byte>;
Storage<Byte>.borrowAddress(
    Int startingAddress,
    Int allocations,
    Int bytesPerAllocation
) returns Storage<Byte>;
```

`size()` and `alignment()` expose the target representation facts for `T`. Memory-policy compile-time code can query the equivalent dynamic facts through `StorageInfo.sizeOf(type)` and `StorageInfo.alignmentOf(type)`.

## Typed Storage is Eido code

Typed allocation is ordinary Eido orchestration:

```eido
function allocate(Int allocations) returns Storage<T> {
    var raw = Storage<Byte>.allocateRaw(allocations, Storage<T>.size());
    return Storage<T>.compilerFromRaw(raw);
}
```

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

`allocate(100)` asks `Storage<Byte>` for 100 raw blocks, each `Storage<Int>.size()` bytes wide. No second backing allocation occurs when those bytes become typed Storage.

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

## Ownership

`allocate` and `allocateRaw` create owning Storage roots. `fromAddress` also creates an owning descriptor, but over an existing allocation at a known address; releasing it frees that backing. `borrowAddress`, `view`, `viewAt`, and `slice` are non-owning and cannot release backing memory. `borrowAddress` is the fixed-address access primitive for memory whose lifetime is controlled elsewhere, such as MMIO or foreign/OS-owned buffers.

Storage parameters are borrowed. Ordinary Eido callable results preserve inferred owned/borrowed provenance. Current straight-line semantic analysis rejects obvious use-after-release, releasing borrowed results/views, borrowed escape into owning Storage fields, and overwriting a live owning Storage local without releasing it first.

## Current element support

Primitive and `String` elements are currently supported. Nominal/class elements remain intentionally rejected until identity-bearing values stored inside raw Storage participate correctly in the selected lifetime policy (for example GC tracing/root discovery). This restriction is separate from the Storage layering described here.

## Backend boundary

The hosted Nim implementation lives in `stdlib/native/nim/eido_storage.nim`. It owns:

- the allocation-free raw descriptor representation;
- raw physical allocation and owning/non-owning address descriptors;
- bounds/liveness checks;
- private raw↔typed descriptor reinterpretation;
- typed machine load/store;
- target `size`/`alignment` facts.

The public typed allocation/view/slice/capacity/address/read/write/release algorithms are Eido methods. Generated real-project code calls those Eido methods; it does not lower public typed operations directly to `eidoStorageAllocate[T]`, `eidoStorageView[T]`, `eidoStorageSlice[T]`, or `eidoStorageRelease[T]`.

Because memory-management policies are themselves implemented above Storage, the compiler does not inject selected-policy lifetime or execution-boundary instrumentation inside `stdlib/storage/storage.eido` method bodies. Instrumenting Storage would make a policy recursively re-enter itself while allocating, reading, writing, or releasing its own bookkeeping storage.
