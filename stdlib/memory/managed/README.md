# eido.stdlib.memory.managed

Compiler-private default managed-memory implementation. This SDK module exports nothing to ordinary applications.

- `MemoryValueRegistry` stores Storage-backed live identity reports selected by the GC policy.
- `MemoryTypeRegistry` stores compiler-provided generic field/layout facts in Storage.
- `ManagedHeapAllocator` owns physical managed-object backing over `Storage<Byte>`.
- `ManagedGcRuntime` owns private headers, heap links, mark/sweep, collection triggers, temporary protection, invariant depth, and shutdown in ordinary Eido.
- `MemoryRuntime` contains ordinary Eido methods that the GC compile-time policy chooses as handlers for generic compiler event points.

The compiler does not know roots, tracing, safepoints, collection, or these implementation classes. It provides policy-neutral metadata and generic semantic event points. `compiler/compile_time/phases/memory_policy_gc` chooses which events the GC needs and binds them to ordinary Eido methods; `ManagedGcRuntime` then gives those generic reports their GC meaning.

Runtime-backed identity currently points directly at object payload storage. `ManagedGcRuntime` keeps its private header before the payload and stores a Storage-backed header back-pointer immediately before the payload. Generated class/interface access therefore performs only a direct typed payload cast and does not call GC code to locate the payload.

There is no dedicated native managed-GC support module. All target-memory ownership and GC policy remain Eido code above `Storage`; the Nim backend supplies physical Storage mechanics and representation glue only.

These hidden Eido sources carry generic compiler-runtime source origin. Initial metadata analysis filters that origin; when the selected automatic policy needs runtime support, target compilation analyzes the original project with those sources present. Primitive-only/manual targets therefore pay no collector/allocator runtime cost.
