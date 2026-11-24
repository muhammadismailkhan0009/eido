# Eido layouts: definitions, selection, and physical memory

Status: **implemented (compile-time layout selection plus native Storage/GC/RC
integration)**. Selection is a compiler-time intrinsic, not an ordinary runtime
method or a per-instance setting.

## Define named layouts in Eido

```eido
class Family {
    String father;
    String mother;
    Int children;
}

layout Compact for Family {
    var shape = Layout.create();
    shape.field("children");
    shape.field("father");
    shape.field("mother");
    return shape;
}

layout Aligned for Family {
    var shape = Layout.create();
    shape.field("father");
    shape.field("mother");
    shape.field("children");
    shape.align(32);
    return shape;
}
```

The Eido compile-time `Layout` builder exposes `create()`, `field(name)`,
`fieldAt(name, offset)`, `align(bytes)`, `size()`, and `offsetOf(name)`.
The compiler invokes its private `submit()` method. The builder uses
`StorageInfo.sizeOf()` and `StorageInfo.alignmentOf()` to place fields.
The results are validated for exact field coverage, non-overlap, bounds,
alignment, and size.

## Activate one layout at compile time

```eido
LayoutPolicy.select("Family", "Compact");
```

This is an intrinsic **compile-time statement**, not a runtime function.
Calls may be placed at file scope in any project source file (including a
source file consisting entirely of selection calls). The configuration is
resolved before the target Nim program is emitted.

An optional **user-defined** class may group the calls:

```eido
class MyLayoutOptions {
    function configure() {
        LayoutPolicy.select("Family", "Compact");
    }
}
MyLayoutOptions.configure();
```

There is **no required central configuration class**, no additional module
manifest key, and no compiler-defined ProjectLayouts class. These helper
methods are compile-time only: they take no arguments, return nothing, and
contain only selection calls or calls to other such helper methods. The
top-level invocation is required. Do not put selections in runtime
`main()` or regular runtime methods.

Unselected classes continue to use Eido's default layout.
Competing same-specificity selections for a class are compile errors.
Unknown class/layout names and unused explicit specializations are errors.

## Generics

```eido
class Box<T> {
    Byte flag;
    T value;
}

layout ValueFirst<U> for Box<U> {
    var shape = Layout.create();
    shape.field("value");
    shape.field("flag");
    return shape;
}

layout FlagFirst<U> for Box<U> {
    var shape = Layout.create();
    shape.field("flag");
    shape.field("value");
    return shape;
}

LayoutPolicy.select("Box", "FlagFirst");
LayoutPolicy.select("Box<Int>", "ValueFirst");
```

The first selection applies to every instantiated `Box<T>`; the concrete
`Box<Int>` selection overrides it. The layout builder evaluates each
concrete specialization, applying the actual size/alignment of its fields.
An ordinary class-typed generic field is a **reference**, not an inlined
copy of the parameter class's physical layout. `Storage<Box<T>>` still
stores the Box payload inline.

## Actual compiler/runtime data flow

```text
Eido class + named layouts
    -> compile-time Eido Layout builder (all named layouts)
    -> validated default/named metadata
    -> LayoutPolicy.select() (compile-time)
    -> ONE active metadata record per concrete class
        |-> generated typed field-offset reads/writes
        |-> constructors and copy/ref implementation
        |-> Storage<T> physical slot size, stride and alignment
        |-> GC/RC object size, alignment and identity-bearing field offsets
    -> runtime memory
```

Storage owns or borrows raw memory regions; GC/RC own managed objects.
These are separate ownership paths. Both consume the **same active
representation**. There is no runtime layout lookup or hidden field
reordering.

The **low-level Storage API is the foundation**. Typed
`Storage<T>.allocate()` performs one `Storage<Byte>.allocateRaw()` native
allocation, then calculates its aligned typed address in Eido using the
pure `Alignment` class. The private `compilerRebaseOwned` bridge preserves the
original native allocation pointer for proper release. The separate
`compilerAllocateRawAligned()` bridge was eliminated.

`Storage<T>.reserveAt(region, address, count)` instead places typed slots at a
chosen aligned address **inside an existing region**. It allocates no native
memory and does not free the region backing upon release. The caller/pool
controls reuse; the compiler detects simple provable fixed Byte overlaps.

`Alignment` is pure arithmetic, with no Storage dependency. GC and RC use an
SDK-internal `AlignedHeapBacking` library helper, which builds on raw Storage,
uses `Alignment` for padding, and records the native heap origin in one Int-sized
preheader when only a managed object address survives; the embedded SDK uses
a private release-only bridge rather than reconstructing a descriptor. This is not a second
compiler allocation primitive or a public memory-allocation API.

**Dependency direction:**

```text
GC / RC --> AlignedHeapBacking --> Storage<Byte> --> native raw allocator
                  |                    |
                  +----> Alignment <---+-- Storage<T> typed allocate()
```

No base Storage operation depends on GC or RC. Layout selection remains a
compile-time concern, independent of native allocation and explicit placement.
Empty classes still have a minimum byte size, rounded to selected alignment.

## Limitations and next features

- Only one selected layout for each concrete class per compilation.
- No runtime or per-instance layout switching.
- Compile-time helper class bodies support direct selection calls and calls
  to other configuration methods, not arbitrary imperative configuration.
- More advanced physical representations (AoS/SoA, bit packing, unions,
  variable-sized fields) are not implemented.
- A selected layout is part of the binary representation; values from
  incompatible layouts cannot be exchanged as though their ABIs matched.
- `Storage.define()` and `Memory.manage()` are not introduced here.

Existing **public** Storage and GC/RC policy APIs are unchanged.
