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

`release` frees the entire region owned by Storage. Any references into
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
- raw physical allocation and owning/non-owning address descriptors;
- bounds/liveness checks;
- private raw↔typed descriptor reinterpretation;
- typed machine load/store;
- target `size`/`alignment` facts.

The public typed allocation/view/slice/capacity/address/read/write/release algorithms are Eido methods. Generated real-project code calls those Eido methods; it does not lower public typed operations directly to `eidoStorageAllocate[T]`, `eidoStorageView[T]`, `eidoStorageSlice[T]`, or `eidoStorageRelease[T]`.

Because memory-management policies are themselves implemented above Storage, the compiler does not inject selected-policy lifetime or execution-boundary instrumentation inside `stdlib/storage/storage.eido` method bodies. Instrumenting Storage would make a policy recursively re-enter itself while allocating, reading, writing, or releasing its own bookkeeping storage.
