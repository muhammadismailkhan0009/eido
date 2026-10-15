# Memory strategies

Eido memory management is selected as compilation policy rather than being hard-wired into one backend implementation.

The current compiler accepts:

```text
eido build --memory=gc
eido build --memory=manual
eido run --memory=gc
eido compile Main.eido --memory=manual -o app
```

`gc` is the default.

## Compiler boundary

The compiler describes the program's memory-relevant structure; it does not prescribe memory-management actions.

A private compiler-standard Eido phase named `memory_metadata` derives policy-neutral facts from the semantic program:

- class payload size and alignment;
- source-field offsets;
- which fields contain object/interface identity;
- which parameters, locals, receivers, and result bindings carry identity.

The compiler supplies those facts to the phase through private invocation-local handles (`Compiler`, `TypeInfo`, `FieldInfo`, `CallableInfo`, `ValueInfo`) and target Storage layout through `StorageInfo`. The phase output is resolved back to stable semantic identities before backend generation. It contains no root set, collector plan, retain/release action, arena choice, collection threshold, or allocator selection.

The compiler also exposes generic semantic event points required to connect language execution to a runtime policy: binding enter/write/leave, object-construction storage acquisition, temporary-expression scope enter/leave, statement boundary, invariant bookkeeping, and program exit. These event points have no GC/RC/arena meaning by themselves.

A second private Eido compile-time policy chooses which event points it needs and binds them to ordinary hidden Eido methods. The current `gc` policy is implemented in `compiler/compile_time/phases/memory_policy_gc`. The compiler merely resolves the method names selected by that Eido policy; it does not know why those methods were selected or which runtime classes implement them.

This allows another policy to bind a different subset. An arena policy may need construction storage acquisition but no lexical binding registry or statement boundary. A reference-counting policy could interpret binding writes differently. Manual/embedded policy can omit automatic instrumentation entirely once explicit manual class representation is defined.

## Construction versus allocation

`Class { ... }` is language semantics. The compiler resolves the class, validates named fields, applies `ref`/`copy` rules, initializes fields, and enforces construction invariants.

Where the object's storage comes from is not class semantics. For runtime-backed objects, construction reaches a generic storage-acquisition event selected by the Eido memory policy. The current GC policy binds that event to its ordinary Eido allocator path; a future arena/region/RC implementation can bind it elsewhere without changing class syntax or semantic analysis.

## GC policy

`--memory=gc` currently implements a precise, non-moving, stop-the-world mark-and-sweep collector for Eido class and interface identity.

The architectural rule is broader than GC: **all target-memory management above the physical backend must be expressible through `Storage`**. The compiler provides generic facts and event points. Eido runtime code decides how to store metadata, track live values, allocate backing, trigger collection, traverse identities, and reclaim memory.

The hidden Eido implementation is currently split into:

```text
MemoryValueRegistry      Storage-backed live identity reports
MemoryTypeRegistry       Storage-backed compiler-provided field/layout facts
ManagedHeapAllocator     physical object backing over Storage<Byte>
ManagedGcRuntime         private headers, heap links, mark/sweep and collection policy
MemoryRuntime            ordinary Eido handlers chosen by the GC policy phase
```

`MemoryValueRegistry` is not a compiler root data structure. The GC policy chooses binding-enter/write/leave instrumentation and its Eido handlers happen to report those values into this registry. `ManagedGcRuntime` alone interprets the registry as a root source.

Likewise, `MemoryTypeRegistry` stores generic field facts. `ManagedGcRuntime` interprets `containsIdentity` fields as traversal edges and cleanup facts according to its own policy. The compiler never emits trace callbacks or mark/sweep operations.

Managed object backing is one raw `Storage<Byte>` allocation per object in the current simple allocator. Runtime-backed identity points directly at the payload address. The GC keeps its private header before the payload and writes a Storage-backed back-pointer immediately before the payload so Eido GC code can recover the allocation/header when needed. Generated class/interface field access therefore casts identity directly to the typed payload; there is no payload-offset memory-policy callback.

The current collector uses an allocation threshold and a GC-selected statement-boundary handler to decide when to collect. Temporary-expression protection is likewise a GC policy binding. These are not compiler concepts.

The dependency is therefore:

```text
semantic program
      ↓
memory_metadata.eido             policy-neutral facts
      ↓
CompileTimeMemoryMetadata
      ↓
memory_policy_gc/runner.eido     selects generic event bindings
      ↓
ordinary hidden Eido methods
      ↓
MemoryValueRegistry / MemoryTypeRegistry / ManagedGcRuntime / ManagedHeapAllocator
      ↓
Storage<T>
      ↓
eido_storage.nim                 physical Storage mechanics
```

There is no dedicated `eido_managed_gc.nim` support module.

## Runtime injection

The hidden sources owned by `eido.stdlib.memory.managed` carry `soCompilerRuntime` source origin and are exported nowhere. Initial metadata analysis filters hidden runtime origins. When the selected automatic memory policy requires managed support, target compilation analyzes those policy sources with the ordinary program.

Hidden language-runtime facilities are selected independently by semantic capability. Built-in String support lives under `eido.stdlib.text` (`lrcString`), while detached-copy memo support lives under `eido.stdlib.runtime` (`lrcClassCopy`); both carry generic `soLanguageRuntime` origin. Target compilation injects only the capabilities required by user HIR, independently of GC/manual policy.

The compiler does not identify hidden runtime implementation classes for semantics. The selected Eido memory policy provides ordinary method names for generic event bindings; String and detached-copy runtime operations likewise resolve to normal semantic `MethodId`s from capability-selected language-runtime source.

## Manual mode

`--memory=manual` performs no automatic runtime instrumentation and emits no managed GC runtime.

Primitive, String, static API, and compiler-owned `Storage<T>` programs can already use manual mode. Ordinary class construction is rejected until Eido defines explicit manual class representation/lifetime semantics; classes that intrinsically require runtime-backed identity are rejected as well. This prevents manual mode from silently falling back to Nim object allocation.

The Nim backend memory-manager option (`--mm:none` in backend tests) is separate from Eido's `--memory=manual`; Eido strategy selection must not be conflated with the implementation language's memory manager.

## Backend/runtime boundary

The Nim backend still necessarily emits representation mechanics required by the selected object representation. Current runtime-backed class/interface identities lower to `int64` payload addresses, optional identity uses zero as absence, and generated field/interface access performs a local typed pointer cast. Those are backend representation mechanics, not memory-management policy.

Allocation ownership, runtime metadata state, lifetime interpretation, collection, and reclamation remain Eido code above `Storage`.

String backing and detached-copy scratch are no longer backend-container exceptions: opaque String handles point to Storage-owned UTF-8 allocations, and copy memo pairs live in an explicitly released raw Storage block owned by hidden Eido `CopyRuntime`. The current Nim exception/trap machinery and other documented bootstrap/platform paths still prevent an unrestricted every-path `--mm:none` claim.
