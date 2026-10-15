# eido.stdlib.memory.managed

Compiler-private default managed-memory runtime. This SDK module exports nothing to ordinary applications.

- `ManagedHeapAllocator` is the simple Eido-written default heap allocator: one raw `Storage<Byte>` allocation per managed object, exact release on sweep, plus live block/byte accounting.
- `ManagedGcRuntime` implements allocation-header layout, precise mark/sweep, safepoints, threshold policy, and shutdown in Eido; it delegates physical allocation/release to `ManagedHeapAllocator`.
- `ManagedGcNative` exposes only machine operations Eido cannot yet express directly, such as precise-root pointer traversal and indirect callbacks.

The compiler removes all three sources during initial analysis/planning and injects them only when the default `gc` strategy actually needs managed runtime support. Primitive-only/manual targets therefore pay no collector/allocator runtime cost.
