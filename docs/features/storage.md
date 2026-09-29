# Storage

`Storage<T>` is Eido's single compiler-owned low-level memory capability. It represents bounded typed access over one underlying memory region; arrays, objects, strings, arenas, pools, pages, vectors, and other policies are intended to build above this same substrate rather than introduce separate memory systems.

`Storage<Byte>` is the universal raw backing form when a heterogeneous or reinterpreted region is required. Ordinary Eido code never receives a forgeable physical address.

## Implemented API

```eido
var raw = Storage<Byte>.allocate(32, 0);
var ints = Storage<Int>.view(raw, 0, 4);

Storage<Int>.write(ints, 1, 42);
var value = Storage<Int>.read(ints, 1);
var tail = Storage<Int>.slice(ints, 1, 3);
var size = Storage<Int>.capacity(tail);

Storage<Byte>.release(raw);
```

Direct typed allocation remains available:

```eido
var values = Storage<Int>.allocate(100, 0);
```

`allocate(count, initialValue)` creates an owning fixed-capacity region and initializes every typed slot. `view(raw, byteOffset, count)` creates a typed borrowed view over `Storage<Byte>`; `slice(storage, start, count)` creates a borrowed typed subrange. Views and slices allocate no backing memory or metadata.

## Ownership and safety

Only an owning allocation may release backing memory. Storage parameters are borrowed, and `view`/`slice` results are borrowed capabilities. Releasing a borrowed local is rejected semantically and defended again by the runtime.

Straight-line semantic analysis also rejects later use of an owner after release and later use of a local view after its tracked owner is released. Complete control-flow/escape-aware lifetime analysis remains follow-on work.

Indexed access is bounds checked. Raw typed views validate byte bounds and alignment. `Storage<T>` cannot be directly constructed and cannot participate in ordinary class `copy`/`ref` relationships. Copying a class graph that owns Storage is rejected.

Primitive and `String` direct storage allocations are currently supported. Nominal/class elements remain deferred until Eido object ownership and layout are defined. Raw `Storage<String>.view` is rejected because safe initialization state for managed String values has not yet been defined.

## Unified memory model

The intended hierarchy is:

```text
Storage<Byte>
    |
    +-- typed Storage<T> views
    +-- class/object layouts
    +-- string backing
    +-- arenas / pools / pages
    +-- arrays / vectors / maps
```

Higher layers decide allocation policy and object lifetime, but they all ultimately consume the same Storage substrate.

## Nim backend

The actual hosted Storage implementation lives in `stdlib/native/nim/eido_storage.nim`. A concrete Eido specialization is emitted only as a thin alias/glue layer such as `Storage<Int> = EidoStorage[int64]`.

`EidoStorage[T]` is an allocation-free value capability containing a raw typed pointer, capacity, ownership state, and live state. Only `allocate` calls Nim's manual `alloc0`; owner release explicitly resets initialized slots and calls `dealloc`. `view` and `slice` only derive new capability values over existing memory.

The generated program therefore contains no Storage `seq[T]`, `ref object`, `newSeq`, or Storage-header allocation. The hosted allocator is still only one provider choice; embedded/freestanding targets may later back the same Eido semantics with static regions, fixed pools, caller-owned memory, or other target-specific providers.

A primitive Storage program already compiles and runs with Nim `--mm:none`. The current hosted trap/error path still constructs Nim exception objects, so full `--mm:none` independence is not yet claimed for the entire runtime; that path and the remaining String/class/interface representations are migration work before `--mm:none` becomes the default Eido backend mode.
