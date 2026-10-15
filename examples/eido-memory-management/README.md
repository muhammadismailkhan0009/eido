# Eido memory-management example

This example shows what an Eido-owned memory layer can look like with the current frozen v0 language surface. It deliberately uses only public Eido facilities: classes, contracts, class-owned state, modules, and `Storage<T>`.

## Architecture

```text
application
    ↓
MemoryManager            public static facade
    ↓
HeapRuntime              internal process runtime
    ↓
HeapState                permanent managed class-owned root
    ↓
Storage<Byte>            physical raw backing allocation
    ↓
machine memory
```

`HeapRuntime.state` is the important bootstrap point. `HeapState` is an ordinary managed Eido object, but because it is stored in class-owned state the compiler keeps that slot as a process-lifetime precise GC root.

The memory runtime can therefore keep its own long-lived Eido objects alive without moving policy into the native backend.

`HeapState` owns allocation policy: alignment, the bump cursor, allocation accounting, reset, shutdown, and construction of non-owning `MemoryBlock` handles. `MemoryBlock` rebuilds typed `Storage<Int>` views when it needs to read or write an integer.

## Enterprise boundary

Only `MemoryManager` is an explicit module export. `MemoryBlock` and `MemoryStats` become public transitively because they occur in its API. `HeapRuntime` and `HeapState` remain implementation details of the uniquely named `heap_runtime` module, avoiding ambiguity with the implicit SDK module `eido.stdlib.memory`.

This is intentionally similar to how Eido's real hidden managed GC is structured: policy and bookkeeping belong in Eido above `Storage<T>`, while only genuinely machine-specific operations should remain native.

## Run

```bash
cd examples/eido-memory-management
eido check
eido run
```

The current value-returning `main` development harness should print `42` after the two status lines.

## What this example does not pretend to solve

This is a bump heap, not the production GC. `reset()` invalidates the logical lifetime of outstanding `MemoryBlock` handles, and `shutdown()` invalidates them physically. The current language does not yet prove those borrowed lifetimes; that remains a compiler-verification problem rather than runtime policy.

The compiler-private GC additionally needs machine-specific root-slot access and generated trace/destroy callback invocation. Those are intentionally absent here because normal application code cannot and should not access `ManagedGcNative`.
