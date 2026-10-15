# eido.stdlib.memory.managed

The SDK's default managed-memory policy and runtime, written in Eido. It is the implementation selected by the CLI alias `--memory=gc`; it is **not** privileged compiler logic.

`module.yaml` declares two roles:

- `policySources: [policy.eido]` — build-machine policy code that binds generic compiler lifecycle events through the public `MemoryPolicy` API.
- `sources:` — target-runtime Eido code injected only when this module is the selected policy.

The runtime contains:

- `MemoryValueRegistry` — Storage-backed live identity reports selected by this policy.
- `MemoryTypeRegistry` — Storage-backed generic field/layout facts.
- `ManagedHeapAllocator` — managed-object backing over `Storage<Byte>`.
- `ManagedGcRuntime` — private headers, heap links, mark/sweep, collection triggers, temporary protection, invariant depth, and shutdown.
- `MemoryRuntime` — typed handlers bound by `policy.eido` to generic compiler events.

The compiler knows none of those implementation classes or GC concepts. It exposes program/type metadata and neutral events such as binding enter/write/leave, object storage acquisition, temporary scopes, execution boundaries, invariant lifecycle, and program exit. The selected policy decides whether and how to use them.

A project may select another module with its own `policySources` and runtime sources instead. Such a module goes through the same compiler path as this standard policy and may acquire physical memory only through normal Eido capabilities such as `Storage<T>`.

Runtime-backed identity currently points directly at object payload storage. This managed implementation keeps its private header before the payload and stores a Storage-backed header back-pointer immediately before the payload. Generated class/interface access therefore performs only representation glue; allocation and lifetime remain policy-owned Eido code.
