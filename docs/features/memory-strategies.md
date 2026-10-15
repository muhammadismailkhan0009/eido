# Memory policies

Eido memory management is selected as an Eido module rather than hard-wired into the compiler.

The SDK CLI currently accepts:

```text
eido build --memory=gc
eido build --memory=none
eido build --memory=myproject.memory.custom
eido run --memory=gc
eido compile Main.eido --memory=myproject.memory.custom -o app
```

`gc` is a CLI alias for the SDK module `eido.stdlib.memory.managed` and is the default. `manual` remains accepted as a compatibility alias for `none`: both mean that no automatic memory policy is selected. A custom value names a memory-policy module.

## Policy module contract

Any loaded Eido module can become a memory policy by declaring build-machine policy source separately from its target runtime source:

```yaml
module: custom_memory

sources:
  - runtime.eido

policySources:
  - policy.eido

children: []
dependencies: []
exports: []
provides: {}
adopts: []
```

`policySources` are compiled and executed on the build machine. They do not enter the target program. `sources` are ordinary Eido runtime implementation files, but the compiler marks them as hidden memory-policy runtime and injects them only when that module is selected.

A policy source uses the compiler-provided `MemoryPolicy` API to bind neutral program events to ordinary static Eido runtime methods. For example:

```eido
function main() {
    MemoryPolicy.objectAcquire("CustomRuntime.acquire");
    MemoryPolicy.programExit("CustomRuntime.shutdown");
}
```

The compiler resolves each `Class.method` reference inside the selected runtime module and validates its signature before target emission.

## Public compiler-facing policy API

Memory-policy source has access to a dedicated compile-time API that ordinary application source cannot name:

```text
Compiler
TypeInfo
FieldInfo
CallableInfo
ValueInfo
StorageInfo
MemoryPolicy
```

These APIs expose compiler-known facts rather than memory-management decisions. Current facts include the program's types/callables, identity-bearing types/values, fields, and target Storage size/alignment.

The generic lifecycle events currently available are:

```text
bindingEnter
bindingWrite
bindingLeave

typeMetadata
fieldMetadata

objectAcquire

temporaryEnter
temporaryLeave
executionBoundary

invariantEnter
invariantLeave
invariantClear

programExit
```

They intentionally do not mean `root`, `retain`, `borrow`, `safepoint`, or another policy-specific operation. A selected policy may ignore events it does not need. The event API grows only when a real memory policy requires another generic compiler fact or lifecycle point.

The current typed event contracts are:

```text
bindingEnter(Int identity) -> Int
bindingWrite(Int valueSlot, Int identity)
bindingLeave(Int valueSlot)

typeMetadata(Int typeId, Int fieldCount)
fieldMetadata(Int typeId, Int index, Int offset, Bool containsIdentity)

objectAcquire(Int payloadSize, Int payloadAlignment, Int typeId) -> Int

temporaryEnter()
temporaryLeave()
executionBoundary()

invariantEnter(Int identity)
invariantLeave(Int identity)
invariantClear(Int identity) -> Bool

programExit()
```

A runtime-backed class requires `objectAcquire`; classes with invariants additionally require the invariant lifecycle handlers. Other instrumentation is optional and receives meaning only from the selected policy.

## Compiler boundary

The compiler remains responsible for language and machine facts it alone can derive:

- class payload size and alignment;
- source-field offsets;
- which fields contain identity;
- which parameters, locals, receivers, and results carry identity;
- lexical/control-flow lifecycle event locations;
- construction, return, temporary, invariant, and program-exit boundaries.

The compiler does **not** allocate target object addresses. Construction asks the selected Eido policy for storage through `objectAcquire(payloadSize, payloadAlignment, typeId)`. The returned identity/address then becomes backend representation for field access.

The compiler also does not assign GC/RC/arena meaning to metadata or events. It contains no collector root selection, mark/sweep policy, retain/release policy, collection threshold, arena ownership rule, or allocator choice. Fixed stack/register/static slots are backend representation rather than dynamic owned regions; in particular, class-owned process-lifetime slots are inline and do not trigger compiler-generated allocation.

## Construction versus allocation

`Class { ... }` remains language semantics. The compiler resolves the class, validates fields, applies `ref`/`copy` rules, initializes state, and enforces contracts/invariants.

Where the backing storage comes from is memory-policy semantics:

```text
Class construction
       ↓
compiler computes required payload layout
       ↓
objectAcquire(size, alignment, typeId)
       ↓
selected Eido policy
       ↓
Storage<T> / Storage<Byte>
       ↓
backend physical Storage implementation
```

This separation allows another policy to replace allocation/lifetime behavior without changing class syntax or compiler class semantics.

## Standard managed policy

The SDK default lives entirely under `stdlib/memory/managed/`:

```text
policy.eido               generic event bindings
memory_runtime.eido       bound runtime handlers
memory_value_registry.eido
memory_type_registry.eido
managed_heap_allocator.eido
managed_gc_runtime.eido
```

`policy.eido` is selected through the same generic module path available to user policies. It binds lifecycle events to `MemoryRuntime` methods. Those runtime methods implement the current precise non-moving stop-the-world mark-and-sweep policy using:

```text
MemoryValueRegistry      Storage-backed live identity reports
MemoryTypeRegistry       Storage-backed field/layout facts
ManagedHeapAllocator     object backing over Storage<Byte>
ManagedGcRuntime         headers, mark/sweep and collection policy
```

The compiler does not identify those classes or call them by name.

## No-policy mode

With `--memory=none` (or compatibility alias `manual`) there is no automatic policy module and therefore no policy runtime or instrumentation.

Primitive, String, static API, and explicit `Storage<T>` programs can compile this way. A program requiring runtime-backed class identity or class construction is rejected with a generic capability error because no object-storage policy was selected. This is not a compiler-defined "manual memory strategy"; it is simply absence of an automatic memory policy.

## Storage substrate

Every target-memory implementation ultimately uses the public low-level `Storage<T>` family. `Storage<Byte>.allocateRaw(...)` is the hosted physical owned-backing path; typed Storage, views, slices, arenas, the standard managed heap, String backing, and copy scratch build above it.

The hosted Nim backend implements only Storage mechanics and representation/ABI glue. A custom policy may build its own heap, registry, arena, pool, or other current-level policy in ordinary Eido over Storage without modifying the compiler.

The Nim backend memory-manager option (`--mm:none` in backend tests) is separate from Eido memory-policy selection.

## Future policy growth

The current API is deliberately sized to what the implemented GC architecture requires. It is not pretending to model every future ownership system today.

If a future RC, region, or Rust-like policy requires an additional compiler-known fact—such as a generic move/borrow/control-flow fact—the policy API should be extended at that time. The new API must describe program semantics generically rather than hard-coding the requesting policy.
