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

## Strategy boundary

The compiler owns a generic build-machine runner. The runner contains no memory-layout, root-selection, or tracing policy:

```eido
function main() {
    SelectedMemoryStrategy.plan();
}
```

The selected strategy module supplies the private static `SelectedMemoryStrategy.plan()` contract. The current `gc` strategy is written in Eido and plans:

- class payload size and alignment
- source-field offsets
- which class fields contain managed references
- which function parameters and locals are precise roots
- instance-method receivers, parameters, locals, and managed postcondition result bindings

The compiler supplies semantic facts through private invocation-local handles (`Compiler`, `TypeInfo`, `FieldInfo`, `CallableInfo`, `ValueInfo`) and dynamic Storage layout through the private `StorageInfo` adapter. Strategy code records decisions through `MemoryPlan`. These contracts are compiler-extension APIs only; ordinary Eido programs cannot name them and they do not enter target binaries.

Adding another built-in automatic strategy therefore means supplying another strategy implementation behind the same runner contract and registering its compiler selection. A public third-party strategy package format remains deferred until the contract has been exercised by more than one automatic strategy.

## GC strategy

`--memory=gc` currently implements a precise, non-moving, stop-the-world mark-and-sweep collector for Eido class and interface identity.

Ordinary class values lower to one-pointer `EidoManagedRef` handles. Each class has a separate payload containing only its Eido-declared fields. Generated compile-time assertions require the Eido strategy's planned size/alignment to match the backend payload representation for every non-empty payload.

Interface values are also managed references. Their managed box stores the concrete managed receiver plus static method thunks, so interface identity no longer depends on Nim `ref object` or closure ownership.

The compiler lowers strategy-selected roots to stack-owned root descriptors. Parameters and instance receivers are rooted for the callable activation; source locals are pushed after their declaration and popped by block-scoped `defer`, so their root lifetime follows lexical scope rather than the whole function. Collection occurs only at generated statement safe points, never during raw allocation. Compound calls/constructions that temporarily hold managed values outside source roots use a short `eidoGcProtected(...)` barrier, so nested calls cannot collect an earlier managed temporary before it reaches a persistent root or traced field.

Generated class trace procedures follow exactly the fields selected by the Eido strategy. Mark walks roots and recursively follows those trace procedures. Sweep destroys unreachable payloads and releases their backing Storage. Cycles therefore do not require special handling: an unreachable cycle is unmarked and swept normally.

The managed runtime itself is a backend/native mechanism because Eido does not yet expose the raw heterogeneous payload/header primitives needed to implement it safely in Eido. Its physical allocation still obeys the language memory invariant:

```text
Eido managed allocation
        ↓
eidoGcAllocate
        ↓
eidoStorageAllocateRaw
        ↓
physical allocator
```

The GC runtime contains no direct `alloc0`/`dealloc` path. Reclamation returns backing through `eidoStorageRelease`.

The current collection trigger is intentionally simple: allocation pressure raises a threshold and generated safe points run collection after the threshold is crossed. The collector is currently single-threaded and mark traversal is recursive. Managed finalizers/destructors are not part of v0 semantics.

## Manual mode

`--memory=manual` performs no managed-memory planning and emits no managed GC runtime.

Primitive, String, static API, and compiler-owned `Storage<T>` programs can already use manual mode. Ordinary class construction is rejected until Eido defines explicit manual class representation/lifetime semantics; classes that intrinsically require managed instance representation are rejected as well. This prevents manual mode from silently falling back to Nim object allocation.

The Nim backend memory-manager option (`--mm:none` in backend tests) is separate from Eido's `--memory=manual`; Eido strategy selection must not be conflated with the implementation language's memory manager.

## Backend/runtime boundary

Invocation-local phase handles are resolved back to stable canonical class/field/callable identities before the plan reaches code generation. `CompilationPlan.memory` is therefore backend-stable rather than coupled to snapshot numbering.

The Nim backend consumes that plan to generate:

- class payload size/alignment constants
- traced-field metadata
- class trace and destroy callbacks
- Storage-backed managed allocation helpers
- representation-neutral field getters/setters and constructors
- managed interface boxes, adapters, upcasts, and dispatchers
- precise root registration for functions and methods
- statement safe points
- process-shutdown collection

Eido class/interface identity is therefore managed by the Eido GC rather than Nim's `ref object` ownership. Other backend facilities are still independently Nim-backed where Eido has not replaced them; notably `String` and some generated helper containers such as graph-copy memo tables still use Nim runtime representations. This GC implementation should not be read as whole-program `--mm:none` readiness.
